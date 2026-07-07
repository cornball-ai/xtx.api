#' Native diffuseR backend for stv() and transition()
#'
#' Runs LTX-2.3 in-process through the diffuseR package (NF4-quantized
#' 22B checkpoint, JIT block stack) instead of the wan2gp-api
#' container: no docker, no HTTP, same calling contracts. The
#' generation pipeline loads once per session and is reused across
#' chunks; prompt embeddings are memoized per prompt text (a track's
#' chunks share one prompt, so Gemma3 runs once per track).
#'
#' @name diffuseR_backend
#' @keywords internal
NULL

.diffuseR_env <- new.env(parent = emptyenv())

#' Unload the diffuseR backend's cached models
#'
#' The stand-up is lazy: the first \code{stv()}/\code{transition()}
#' call with \code{backend = "diffuseR"} loads the LTX-2.3 pipeline
#' (and, on first prompt, the Gemma3 text encoder) into a session
#' cache that later chunks reuse. This is the teardown: it drops the
#' cached pipeline, text encoder, and prompt embeddings so the host
#' RAM (roughly 20 GB weights plus 48 GB Gemma3 when kept) returns to
#' the system. Call it after a batch run -- the docker-stop
#' equivalent. The next diffuseR call reloads from disk.
#'
#' @return Invisibly, NULL.
#' @export
diffuseR_unload <- function() {
    rm(list = ls(.diffuseR_env), envir = .diffuseR_env)
    gc(verbose = FALSE)
    if (requireNamespace("torch", quietly = TRUE) &&
        torch::cuda_is_available()) {
        tryCatch(torch::cuda_empty_cache(), error = function(e) NULL)
    }
    invisible(NULL)
}

# Resolution presets for the avatar/talking-head convention (square,
# /32-aligned; 960 matches the historical wan2gp chunk size)
.diffuseR_size <- function(resolution) {
    switch(resolution,
           "480p" = 640L,
           "720p" = 960L,
           stop("Unsupported resolution: ", resolution, call. = FALSE)
    )
}

.diffuseR_pipeline <- function() {
    pipe <- .diffuseR_env$pipeline
    if (is.null(pipe)) {
        if (!requireNamespace("diffuseR", quietly = TRUE)) {
            stop("The diffuseR backend requires the diffuseR package.",
                 call. = FALSE)
        }
        nf4_dir <- file.path(tools::R_user_dir("diffuseR", "data"),
                             "ltx2.3-nf4")
        if (!dir.exists(nf4_dir)) {
            stop("NF4 checkpoint artifact not found at ", nf4_dir,
                 "; run diffuseR::download_ltx2() first.", call. = FALSE)
        }
        message("diffuseR backend: loading LTX-2.3 pipeline (once per session)...")
        pipe <- diffuseR::ltx23_load_pipeline(nf4_dir, device = "cuda",
                                              verbose = FALSE)
        .diffuseR_env$pipeline <- pipe
    }
    pipe
}

.diffuseR_prompt_embeds <- function(prompt) {
    key <- paste0("embeds:", prompt)
    emb <- .diffuseR_env[[key]]
    if (!is.null(emb)) {
        return(emb)
    }
    te <- .diffuseR_env$text_encoder
    if (is.null(te)) {
        message("diffuseR backend: loading Gemma3 text encoder (CPU)...")
        te_dir <- dirname(hfhub::hub_download(
            "Lightricks/LTX-2", "text_encoder/config.json",
            local_files_only = TRUE
        ))
        tok_dir <- dirname(hfhub::hub_download(
            "Lightricks/LTX-2", "tokenizer/tokenizer.json",
            local_files_only = TRUE
        ))
        te <- list(
                   model = diffuseR::load_gemma3_text_encoder(te_dir,
                device = "cpu", dtype = "float32"),
                   tokenizer = diffuseR::gemma3_tokenizer(tok_dir)
        )
        if (isTRUE(getOption("xtx.diffuseR.keep_text_encoder", TRUE))) {
            .diffuseR_env$text_encoder <- te
        }
    }
    emb <- diffuseR::encode_with_gemma3(prompt, model = te$model,
                                        tokenizer = te$tokenizer,
                                        max_sequence_length = 1024L,
                                        device = "cpu")
    .diffuseR_env[[key]] <- emb
    emb
}

#' stv() via diffuseR: start image + audio -> audio-driven talking head
#' @keywords internal
.stv_diffuseR <- function(image, audio, output, prompt, resolution,
                          quality, seed = NULL, timeout = NULL) {
    if (is.null(image)) {
        stop("'image' is required for the diffuseR backend", call. = FALSE)
    }
    size <- .diffuseR_size(resolution)
    dur <- .probe_duration(audio)
    if (is.na(dur)) {
        stop("Could not probe audio duration: ", audio, call. = FALSE)
    }
    num_frames <- .align_8nplus1(round(dur * 24))

    pipe <- .diffuseR_pipeline()
    emb <- .diffuseR_prompt_embeds(prompt)
    diffuseR::txt2vid_ltx2(
                           prompt = prompt,
                           pipeline = pipe,
                           prompt_embeds = emb,
                           image = image,
                           audio = audio,
                           width = size, height = size,
                           num_frames = num_frames, frame_rate = 24,
                           seed = seed,
                           device = "cuda", dtype = "bfloat16",
                           filename = output,
                           verbose = FALSE
    )
    invisible(output)
}

#' transition() via diffuseR: continue a clip's tail, audio-driven
#'
#' Matches the wan2gp_api contract: the output contains
#' \code{conditioning_frames} overlap frames from \code{start_clip}
#' followed by the generated continuation (total
#' \code{num_frames + conditioning_frames - 1} frames).
#' @keywords internal
.transition_diffuseR <- function(start_clip = NULL, image_start = NULL,
                                 prompt = NULL, audio = NULL,
                                 num_frames = NULL,
                                 conditioning_frames = NULL,
                                 fps = 24, resolution = "720p",
                                 quality = "balanced", seed = NULL,
                                 output = "transition_output.mp4",
                                 timeout = NULL) {
    if (is.null(start_clip) && is.null(image_start)) {
        stop("Provide start_clip or image_start", call. = FALSE)
    }
    prompt <- prompt %||% "smooth cinematic transition"
    conditioning_frames <- conditioning_frames %||%
    getOption("xtx.transition.conditioning_frames", 9L)

    if (is.null(num_frames) && !is.null(audio)) {
        adur <- .probe_duration(audio)
        if (!is.na(adur)) {
            num_frames <- .align_8nplus1(round(adur * fps))
        }
    }
    if (is.null(num_frames)) {
        stop("num_frames is required (or provide audio to size from)",
             call. = FALSE)
    }

    pipe <- .diffuseR_pipeline()
    emb <- .diffuseR_prompt_embeds(prompt)

    if (!is.null(start_clip)) {
        # Continuation: match the source clip's geometry; total frames
        # include the conditioning overlap (consumer trims/crossfades)
        info <- suppressWarnings(system2("ffprobe",
                shQuote(c("-v", "error", "-select_streams", "v:0",
                          "-show_entries", "stream=width,height",
                          "-of", "csv=p=0", start_clip)),
                stdout = TRUE, stderr = FALSE))
        dims <- as.integer(strsplit(info[1], ",")[[1]])
        total_frames <- .align_8nplus1(num_frames + conditioning_frames - 1L)

        # The overlap head replays the previous chunk; this chunk's
        # audio belongs to the generated portion, so delay it by the
        # overlap duration (silence under the conditioning frames).
        # After the consumer trims the head, audio and video align.
        cond_audio <- audio
        if (!is.null(audio)) {
            wav <- diffuseR::ltx23_read_audio(audio)
            lead <- matrix(0, nrow = 2L,
                           ncol = round((conditioning_frames - 1L) / fps * 16000))
            cond_audio <- cbind(lead, wav)
        }
        diffuseR::txt2vid_ltx2(
                               prompt = prompt,
                               pipeline = pipe,
                               prompt_embeds = emb,
                               condition_video = start_clip,
                               conditioning_frames = as.integer(conditioning_frames),
                               audio = cond_audio,
                               width = dims[1], height = dims[2],
                               num_frames = total_frames, frame_rate = fps,
                               seed = seed,
                               device = "cuda", dtype = "bfloat16",
                               filename = output,
                               verbose = FALSE
        )
    } else {
        size <- .diffuseR_size(resolution)
        diffuseR::txt2vid_ltx2(
                               prompt = prompt,
                               pipeline = pipe,
                               prompt_embeds = emb,
                               image = image_start,
                               audio = audio,
                               width = size, height = size,
                               num_frames = num_frames, frame_rate = fps,
                               seed = seed,
                               device = "cuda", dtype = "bfloat16",
                               filename = output,
                               verbose = FALSE
        )
    }
    invisible(output)
}
