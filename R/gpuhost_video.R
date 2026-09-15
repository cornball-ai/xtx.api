# The gpuhost backend's VIDEO half: stv() and transition() on the
# viento-managed gpu.ctl service, against its `ltx-2.3` entry.
#
# WHY A SECOND FILE. gpuhost.R is the transport and the picture path; this
# is what a talking head needs on top of it, and it is the half that could
# not exist until the host admitted conditioning (gpu.ctl 0.1.0.25). Before
# that, `stv(backend = "diffuseR")` loaded LTX into the caller's process on
# the same card the host serves from, and the hold/release choreography
# downstream existed to keep the two apart. Sending the work to the host
# retires it.
#
# THE CONTRACTS ARE THE diffuseR BACKEND'S, TO THE FRAME. stv(): a start
# frame plus audio, the clip sized UP to the audio on the 8k+1 grid.
# transition() from a clip: the output opens with `conditioning_frames`
# frames replayed from the source's tail and the audio is delayed under
# that head, so a consumer's trim-or-crossfade accounting holds without
# knowing which backend ran. The one difference is where the tail comes
# from: in-process the
# previous chunk's frames are stashed losslessly; here the previous FILE
# travels and the host reads its tail, which is the in-process path's own
# fallback on a resume.

# The audio the host gets is always 16 kHz stereo PCM, with `lead_s` of
# silence in front. Three reasons, one file: LTX's audio VAE reads at 16 kHz
# stereo whatever it is handed, so nothing is lost; a wav is what the host
# names by its bytes without guessing at a codec; and the continuation's
# head silence has to be put SOMEWHERE -- in-process it is a matrix prepend,
# which a client cannot do to an mp3. `adelay` in samples AFTER the
# resample, so the lead is exactly (conditioning_frames - 1) / fps seconds
# at the rate the model sees.
.gpuhost_audio_wav <- function(audio, lead_s = 0, rate = 16000L) {
    if (!file.exists(audio)) {
        stop("Audio file not found: ", audio, call. = FALSE)
    }
    if (!nzchar(Sys.which("ffmpeg"))) {
        stop("the gpuhost video backend needs ffmpeg on PATH to prepare ",
             "audio", call. = FALSE)
    }
    out <- tempfile(fileext = ".wav")
    filt <- sprintf("aresample=%d,aformat=channel_layouts=stereo", rate)
    if (lead_s > 0) {
        filt <- paste0(filt, sprintf(",adelay=%dS:all=1",
                                     as.integer(round(lead_s * rate))))
    }
    rc <- system2("ffmpeg",
                  shQuote(c("-y", "-v", "error", "-i", audio, "-af", filt,
                            "-c:a", "pcm_s16le", out)),
                  stdout = FALSE, stderr = FALSE)
    if (!identical(rc, 0L) || !file.exists(out)) {
        stop("ffmpeg could not prepare ", audio, " for the gpuhost",
             call. = FALSE)
    }
    out
}

# jsonlite's spelling, EXACTLY. The host re-encodes what it decoded and
# compares bytes, so any other encoder's line wrapping (or lack of it) is
# refused as non-canonical. base64enc is what the rest of this package
# uses; not here.
.gpuhost_b64 <- function(path) {
    jsonlite::base64_enc(readBin(path, "raw", file.size(path)))
}

# A clip's frame size via ffprobe, c(width, height).
.probe_dims <- function(file) {
    out <- suppressWarnings(system2("ffprobe",
                                    shQuote(c("-v", "error", "-select_streams", "v:0",
                    "-show_entries", "stream=width,height", "-of",
                    "csv=p=0", file)),
                                    stdout = TRUE, stderr = FALSE))
    dims <- suppressWarnings(as.integer(strsplit(out[1], ",")[[1]]))
    if (length(dims) != 2L || anyNA(dims)) {
        stop("Could not probe the frame size of ", file, call. = FALSE)
    }
    dims
}

# One video generation on the host: the closed input, the POST, the bytes
# to `output`, the sidecar note. Both public paths end here.
.gpuhost_video <- function(input, output, timeout, note = list()) {
    entry <- .gpuhost_entry("video")
    # A SWAP CAN PRECEDE THE WORK, and then the clip takes its own minutes:
    # a 137-frame 960^2 chunk ran 242 s in-process on this card, and on a
    # swap catalog the host may first move a 27 GiB pin onto it. A caller
    # who asks for more gets more; nobody gets less than this.
    timeout <- max(timeout %||% 0, 600)
    out <- .gpuhost_infer(entry, input, timeout = timeout, accept = "video/mp4")
    writeBin(out$content, output)
    do.call(.sidecar_note,
            c(list(output, backend = "gpuhost", entry = entry,
                   width = input$width, height = input$height,
                   num_frames = input$num_frames, frame_rate = 24L),
              note, list(host_meta = out$meta)))
    invisible(output)
}

#' stv() via the gpuhost: start image + audio -> audio-driven talking head
#'
#' `quality` is accepted for the contract and not sent: LTX-2.3's distilled
#' checkpoint has one schedule, the same reason the diffuseR backend
#' ignores it.
#' @keywords internal
.stv_gpuhost <- function(image, audio, output, prompt, resolution, quality,
                         seed = NULL, timeout = 600) {
    if (is.null(image)) {
        stop("'image' is required for the gpuhost backend", call. = FALSE)
    }
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }
    size <- .diffuseR_size(resolution)
    dur <- .probe_duration(audio)
    if (is.na(dur)) {
        stop("Could not probe audio duration: ", audio, call. = FALSE)
    }
    num_frames <- .ceil_8nplus1(round(dur * 24))
    wav <- .gpuhost_audio_wav(audio)
    on.exit(unlink(wav), add = TRUE)
    input <- list(prompt = prompt, width = size, height = size,
                  num_frames = num_frames, image_b64 = .gpuhost_b64(image),
                  audio_b64 = .gpuhost_b64(wav))
    if (!is.null(seed)) {
        input$seed <- as.integer(seed)
    }
    .gpuhost_video(input, output, timeout,
                   note = list(audio_duration = round(dur, 3)))
}

#' transition() via the gpuhost: continue a clip's tail, audio-driven
#'
#' Matches the diffuseR contract: from `start_clip` the output carries
#' `conditioning_frames` replayed frames followed by the continuation
#' (`num_frames + conditioning_frames - 1` frames on the grid), and the
#' audio is delayed by the head so it lines up with the generated part.
#' From `image_start` it is `.stv_gpuhost` with an explicit frame count.
#' @keywords internal
.transition_gpuhost <- function(start_clip = NULL, image_start = NULL,
                                prompt = NULL, audio = NULL,
                                num_frames = NULL,
                                conditioning_frames = NULL, fps = 24,
                                resolution = "720p", quality = "balanced",
                                seed = NULL,
                                output = file.path(tempdir(), "transition_output.mp4"),
                                timeout = 1800) {
    if (is.null(start_clip) && is.null(image_start)) {
        stop("Provide start_clip or image_start", call. = FALSE)
    }
    if (!is.null(start_clip) && !is.null(image_start)) {
        stop("transition(): supply only one of start_clip / image_start.",
             call. = FALSE)
    }
    # The host renders LTX at 24 fps and the wire carries no frame rate;
    # sizing the clip at another rate would desync it from its own audio.
    if (!isTRUE(all.equal(fps, 24))) {
        stop("the gpuhost renders at 24 fps; fps = ", fps,
             " cannot be honoured", call. = FALSE)
    }
    prompt <- prompt %||% "smooth cinematic transition"
    conditioning_frames <- as.integer(conditioning_frames %||%
                                      getOption("xtx.transition.conditioning_frames", 9L))
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
    input <- list(prompt = prompt)
    if (!is.null(seed)) {
        input$seed <- as.integer(seed)
    }
    note <- list()
    if (!is.null(start_clip)) {
        if (!file.exists(start_clip)) {
            stop("start_clip file not found: ", start_clip, call. = FALSE)
        }
        # THE CLIP'S OWN SIZE, not the preset's: a continuation that changes
        # frame size has nothing to condition on.
        dims <- .probe_dims(start_clip)
        input$width <- dims[[1L]]
        input$height <- dims[[2L]]
        input$num_frames <- .align_8nplus1(num_frames + conditioning_frames -
            1L)
        input$condition_video_b64 <- .gpuhost_b64(start_clip)
        input$conditioning_frames <- conditioning_frames
        # The head replays the previous chunk; this chunk's audio belongs to
        # the generated portion, so it starts after the head.
        lead_s <- (conditioning_frames - 1L) / fps
        note$conditioning_frames <- conditioning_frames
        note$audio_lead_s <- lead_s
    } else {
        if (!file.exists(image_start)) {
            stop("image_start file not found: ", image_start, call. = FALSE)
        }
        size <- .diffuseR_size(resolution)
        input$width <- size
        input$height <- size
        input$num_frames <- as.integer(num_frames)
        input$image_b64 <- .gpuhost_b64(image_start)
        lead_s <- 0
    }
    if (!is.null(audio)) {
        wav <- .gpuhost_audio_wav(audio, lead_s = lead_s)
        on.exit(unlink(wav), add = TRUE)
        input$audio_b64 <- .gpuhost_b64(wav)
    }
    .gpuhost_video(input, output, timeout, note = note)
}
