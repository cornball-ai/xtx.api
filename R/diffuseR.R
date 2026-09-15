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
#' It also drops \code{tti()}/\code{img2img()}'s diffuseR pipelines
#' (FLUX.2, SDXL, SD2.1), which live in a separate cache. Those cost
#' little VRAM -- the FLUX family phase-swaps from host RAM -- but
#' they pin large host staging buffers, and so do LTX and Gemma3. A
#' session that generates images and then video holds both sets at
#' once: measured here as a 43 GB shared-memory resident set, enough
#' to exhaust 125 GB of host RAM and drive phase-offload staging into
#' swap for the whole video stage (roughly 2x per-chunk time), or to
#' OOM outright.
#'
#' @return Invisibly, NULL.
#' @examples
#' \dontrun{
#'   # After an image stage, before loading a video model in this process
#'   diffuseR_unload()
#' }
#' @export
diffuseR_unload <- function() {
    rm(list = ls(.diffuseR_env), envir = .diffuseR_env)
    rm(list = ls(.diffuser_cache), envir = .diffuser_cache)
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
    switch(resolution, "480p" = 640L, "720p" = 960L,
           stop("Unsupported resolution: ", resolution, call. = FALSE))
}

# Available host RAM in GB (MemAvailable, so reclaimable cache counts);
# NA where /proc/meminfo is not readable. Pinned staging buffers make this
# the binding constraint for a mixed image+video session, not VRAM.
.diffuseR_avail_ram_gb <- function() {
    mi <- suppressWarnings(try(readLines("/proc/meminfo", warn = FALSE),
                               silent = TRUE))
    if (inherits(mi, "try-error")) {
        return(NA_real_)
    }
    ln <- grep("^MemAvailable:", mi, value = TRUE)
    if (length(ln) == 0) {
        return(NA_real_)
    }
    kb <- suppressWarnings(as.numeric(gsub("[^0-9]", "", ln[1])))
    round(kb / 1024 ^ 2, 2)
}

# Host RAM below which a batch is likely to stage through swap. LTX's
# weights and the Gemma3 encoder together want well over this; the alarm
# is sized to fire before a long run commits to the slow path, not to
# predict a precise cliff.
.diffuseR_ram_floor_gb <- function() {
    as.numeric(getOption("xtx.diffuseR.ram_floor_gb", 24))
}

# Free VRAM in GB; NA when nvidia-smi is unavailable.
.diffuseR_free_vram_gb <- function() {
    if (!nzchar(Sys.which("nvidia-smi"))) {
        return(NA_real_)
    }
    v <- suppressWarnings(try(system2("nvidia-smi",
                                      c("--query-gpu=memory.free",
                                        "--format=csv,noheader,nounits"),
                                      stdout = TRUE, stderr = FALSE),
                              silent = TRUE))
    if (inherits(v, "try-error") || length(v) == 0) {
        return(NA_real_)
    }
    round(suppressWarnings(as.numeric(v[1])) / 1024, 2)
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
        # Both budgets are decided once, here, and then govern every chunk
        # the session generates -- so a batch that is about to run for
        # hours says out loud what it is running with.
        #
        # VRAM picks the profile: "high" keeps the NF4 transformer
        # resident, below it weights stream over PCIe per step.
        #
        # Host RAM is the one that actually bites. phase_offload stages
        # components through pinned host buffers, and tti()'s image
        # pipeline pins its own; a session that generates images and then
        # video holds both unless diffuseR_unload() ran in between. Once
        # MemAvailable is gone, staging goes to swap and per-chunk time
        # roughly doubles for the rest of the run.
        free_gb <- .diffuseR_free_vram_gb()
        ram_gb <- .diffuseR_avail_ram_gb()
        prof <- tryCatch(suppressMessages(diffuseR::ltx23_memory_profile()),
                         error = function(e) NULL)
        .diffuseR_env$profile <- prof
        .diffuseR_env$profile_free_gb <- free_gb
        .diffuseR_env$profile_ram_gb <- ram_gb
        if (!is.null(prof)) {
            message(sprintf(
                "diffuseR backend: memory profile '%s' (%s, phase_offload=%s) at %.1f GB free VRAM, %.1f GB available RAM",
                prof$name, prof$precision, prof$phase_offload, free_gb,
                ram_gb))
            if (!identical(prof$name, "high")) {
                warning("diffuseR LTX profile is '", prof$name,
                        "', not 'high': weights stream per step instead of ",
                        "staying resident, which roughly doubles per-chunk ",
                        "time. Only ", sprintf("%.1f", free_gb),
                        " GB VRAM was free.", call. = FALSE)
            }
        }
        # LTX weights plus the Gemma3 encoder need room to stage; under
        # this, staging is competing with the page cache at best and
        # swapping at worst. Threshold is deliberately loose -- it is a
        # smoke alarm for a 20-hour stage, not a hard gate.
        if (!is.na(ram_gb) && ram_gb < .diffuseR_ram_floor_gb()) {
            warning("Only ", sprintf("%.1f", ram_gb), " GB of host RAM is ",
                    "available as the LTX pipeline loads. Phase-offload ",
                    "staging will contend for it, which roughly doubles ",
                    "per-chunk time across a batch. If an image stage ran ",
                    "first in this session, call xtx.api::diffuseR_unload() ",
                    "between the stages to release its pinned buffers.",
                    call. = FALSE)
        }
        message("diffuseR backend: loading LTX-2.3 pipeline (once per session)...")
        pipe <- diffuseR::ltx23_load_pipeline(nf4_dir, device = "cuda",
            verbose = isTRUE(getOption("xtx.diffuseR.verbose", FALSE)))
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
        # Prefer the NF4 artifact: ~8 GB pinned CPU-resident (vs 45 GB
        # fp32), and encode_with_gemma3 swaps it to the GPU per encode
        # (~0.3 s on at DMA rate, pointer-swap off) for a ~7 s encode
        # instead of ~24 s on the CPU
        nf4_dir <- file.path(tools::R_user_dir("diffuseR", "data"),
                             "gemma3-nf4")
        tok_dir <- dirname(hfhub::hub_download(
                "Lightricks/LTX-2", "tokenizer/tokenizer.json",
                local_files_only = TRUE
            ))
        if (dir.exists(nf4_dir)) {
            message("diffuseR backend: loading the pipeline's Gemma3 text encoder (NF4, held in RAM, swaps to GPU on use)...")
            model <- diffuseR::load_gemma3_text_encoder(nf4_dir,
                device = "cpu",
                verbose = isTRUE(getOption("xtx.diffuseR.verbose", FALSE)))
        } else {
            message("diffuseR backend: loading the pipeline's Gemma3 text encoder (fp32, CPU)...")
            te_dir <- dirname(hfhub::hub_download("Lightricks/LTX-2",
                    "text_encoder/config.json", local_files_only = TRUE))
            # pin = FALSE: the ~45 GB fp32 encoder is CPU-compute-only.
            # Pinning it would page-lock 45 GB AND make the staging
            # check below select CUDA, staging 45 GB onto the card.
            model <- diffuseR::load_gemma3_text_encoder(te_dir,
                device = "cpu", dtype = "float32", pin = FALSE,
                verbose = isTRUE(getOption("xtx.diffuseR.verbose", FALSE)))
        }
        te <- list(model = model,
                   tokenizer = diffuseR::gemma3_tokenizer(tok_dir))
        if (isTRUE(getOption("xtx.diffuseR.keep_text_encoder", TRUE))) {
            .diffuseR_env$text_encoder <- te
        }
    }
    enc_dev <- if (!is.null(attr(te$model, "staging")) &&
        torch::cuda_is_available()) {
        "cuda"
    } else {
        "cpu"
    }
    emb <- diffuseR::encode_with_gemma3(prompt, model = te$model,
                                        tokenizer = te$tokenizer,
                                        max_sequence_length = 1024L,
                                        device = enc_dev)
    emb$prompt_embeds <- emb$prompt_embeds$to(device = "cpu")
    emb$prompt_attention_mask <- emb$prompt_attention_mask$to(device = "cpu")
    .diffuseR_env[[key]] <- emb
    emb
}

# Connector outputs are what the transformer actually consumes, they
# are tiny (~9 MB vs ~0.4 GB for the raw hidden-state stack), and the
# prompt is constant across a track's chunks: compute once on the CPU,
# cache, and drop the raw embeds. Passing these as connector_embeds
# also skips txt2vid's per-call connectors phase (diffuseR >= 0.1.0.15).
.diffuseR_connector_embeds <- function(prompt) {
    key <- paste0("conn:", prompt)
    cemb <- .diffuseR_env[[key]]
    if (!is.null(cemb)) {
        return(cemb)
    }
    pipe <- .diffuseR_pipeline()
    emb <- .diffuseR_prompt_embeds(prompt)
    conn <- torch::with_no_grad(pipe$connectors(
            emb$prompt_embeds$to(dtype = torch::torch_bfloat16()),
            emb$prompt_attention_mask))
    cemb <- list(video_text_embedding = conn$video_text_embedding,
                 audio_text_embedding = conn$audio_text_embedding,
                 attention_mask = conn$attention_mask)
    .diffuseR_env[[key]] <- cemb
    rm(list = paste0("embeds:", prompt), envir = .diffuseR_env)
    cemb
}

# One-slot stash of the last delivered chunk's tail: the next
# transition conditions on these lossless in-memory frames instead of
# re-reading the H.264 file (which extracts every frame to PNG to get
# nine). Keyed by output path; a resume after a crash misses the stash
# and falls back to the file, so the per-chunk resume contract holds.
.diffuseR_stash_tail <- function(res, output, n = 9L) {
    v <- res$video
    if (is.null(v)) {
        return(invisible(NULL))
    }
    nf <- dim(v)[1]
    if (nf < n) {
        return(invisible(NULL))
    }
    .diffuseR_env$last_tail <- list(
                                    path = normalizePath(output, mustWork = FALSE),
                                    frames = v[(nf - n + 1L):nf,,,, drop = FALSE]
    )
    invisible(NULL)
}

#' stv() via diffuseR: start image + audio -> audio-driven talking head
#' @keywords internal
.stv_diffuseR <- function(image, audio, output, prompt, resolution, quality,
                          seed = NULL, timeout = NULL) {
    if (is.null(image)) {
        stop("'image' is required for the diffuseR backend", call. = FALSE)
    }
    size <- .diffuseR_size(resolution)
    dur <- .probe_duration(audio)
    if (is.na(dur)) {
        stop("Could not probe audio duration: ", audio, call. = FALSE)
    }
    num_frames <- .ceil_8nplus1(round(dur * 24))

    pipe <- .diffuseR_pipeline()
    cemb <- .diffuseR_connector_embeds(prompt)
    # stv()'s width, height, num_frames, num_inference_steps and turbo_mode
    # never reach this path -- the sidecar's request block records them
    # anyway, because it snapshots the public function's arguments. Report
    # what actually ran, so a slow batch is diagnosable from the artifacts.
    prof <- .diffuseR_env$profile
    .sidecar_note(output, backend = "diffuseR", width = size, height = size,
                  num_frames = num_frames, frame_rate = 24L,
                  dtype = "bfloat16", audio_duration = round(dur, 3),
                  memory_profile = prof$name, precision = prof$precision,
                  phase_offload = prof$phase_offload,
                  pin_weights = prof$pin_weights,
                  vram_free_gb_at_load = .diffuseR_env$profile_free_gb,
                  vram_free_gb = .diffuseR_free_vram_gb(),
                  ram_avail_gb_at_load = .diffuseR_env$profile_ram_gb,
                  ram_avail_gb = .diffuseR_avail_ram_gb())
    res <- diffuseR::txt2vid_ltx2(prompt = prompt, pipeline = pipe,
                                  connector_embeds = cemb, image = image, audio = audio,
                                  width = size, height = size,
                                  num_frames = num_frames, frame_rate = 24,
                                  seed = seed, device = "cuda", dtype = "bfloat16",
                                  filename = output,
                                  verbose = getOption("xtx.diffuseR.verbose", "progress"))
    .diffuseR_stash_tail(res, output,
                         n = as.integer(getOption("xtx.transition.conditioning_frames", 9L)))
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
                                 conditioning_frames = NULL, fps = 24,
                                 resolution = "720p", quality = "balanced",
                                 seed = NULL,
                                 output = file.path(tempdir(), "transition_output.mp4"),
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
            num_frames <- .ceil_8nplus1(round(adur * fps))
        }
    }
    if (is.null(num_frames)) {
        stop("num_frames is required (or provide audio to size from)",
             call. = FALSE)
    }

    pipe <- .diffuseR_pipeline()
    cemb <- .diffuseR_connector_embeds(prompt)

    if (!is.null(start_clip)) {
        # In-memory fast path: when this call chains directly off the
        # previous chunk, its tail is stashed as lossless frames -
        # condition on those instead of re-reading the H.264 file.
        # Falls back to the file (resume, or any non-chained caller).
        stash <- .diffuseR_env$last_tail
        cond_source <- start_clip
        if (!is.null(stash) &&
            identical(stash$path, normalizePath(start_clip, mustWork = FALSE)) &&
            dim(stash$frames)[1] == conditioning_frames) {
            cond_source <- stash$frames
            dims <- c(dim(stash$frames)[3], dim(stash$frames)[2])
        } else {
            info <- suppressWarnings(system2("ffprobe",
                    shQuote(c("-v", "error", "-select_streams", "v:0",
                              "-show_entries", "stream=width,height",
                              "-of", "csv=p=0", start_clip)),
                    stdout = TRUE, stderr = FALSE))
            dims <- as.integer(strsplit(info[1], ",")[[1]])
        }
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
        res <- diffuseR::txt2vid_ltx2(
                                      prompt = prompt,
                                      pipeline = pipe,
                                      connector_embeds = cemb,
                                      condition_video = cond_source,
                                      conditioning_frames = as.integer(conditioning_frames),
                                      audio = cond_audio,
                                      width = dims[1], height = dims[2],
                                      num_frames = total_frames, frame_rate = fps,
                                      seed = seed,
                                      device = "cuda", dtype = "bfloat16",
                                      filename = output,
                                      verbose = getOption("xtx.diffuseR.verbose", "progress")
        )
        .diffuseR_stash_tail(res, output, n = as.integer(conditioning_frames))
    } else {
        size <- .diffuseR_size(resolution)
        res <- diffuseR::txt2vid_ltx2(
                                      prompt = prompt,
                                      pipeline = pipe,
                                      connector_embeds = cemb,
                                      image = image_start,
                                      audio = audio,
                                      width = size, height = size,
                                      num_frames = num_frames, frame_rate = fps,
                                      seed = seed,
                                      device = "cuda", dtype = "bfloat16",
                                      filename = output,
                                      verbose = getOption("xtx.diffuseR.verbose", "progress")
        )
        .diffuseR_stash_tail(res, output, n = as.integer(conditioning_frames))
    }
    invisible(output)
}
