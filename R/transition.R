# Video Transition / Bridging (WanGP API)
#
# Generate a short bridging clip between two pieces of video: continue from the
# tail of a start clip, optionally arrive at a destination keyframe, and
# optionally pass through interior keyframe anchors. Mirrors the itv/stv curl
# shape. Talks to the FastAPI /transition endpoint in the Wan2GP_api container.

#' Generate a Bridging / Transition Clip (Video-to-Video)
#'
#' Generate a short clip that continues from the trailing frames of
#' \code{start_clip} and, when \code{end_image} is supplied, arrives at it.
#' Useful for smoothing the cut between two existing clips, or for anchored
#' video extension. Unlike \code{stv()}, this path conditions on \emph{frames},
#' not audio, so it runs on checkpoints without an audio-video connector
#' (e.g. the GGUF-light build).
#'
#' Shapes:
#' \itemize{
#'   \item \strong{A -> B bridge} (pass \code{end_image}): smooth the cut
#'     between two existing clips. \code{end_image} bounds drift -- arriving at a
#'     known frame limits how far the bridge can wander.
#'   \item \strong{Anchored extension} (omit \code{end_image}): continue a clip
#'     with no fixed destination.
#'   \item \strong{Multi-keyframe} (pass \code{keyframe_images} +
#'     \code{keyframe_positions}): route the bridge through interior anchor
#'     images at chosen 1-indexed frame positions. Anchors are \emph{soft}:
#'     their influence bleeds into neighbouring frames and persists forward
#'     (temporal coherence), rather than replacing exactly one frame.
#' }
#'
#' @param start_clip Path to the source video (MP4). Its trailing frames seed
#'   the bridge (prompt-type "V"). Supply this OR \code{image_start}, not both.
#' @param image_start Path to a single start image (PNG/JPG) to begin from
#'   (prompt-type "S"), the avatar-style start. Alternative to \code{start_clip}.
#' @param end_image Optional path to a destination keyframe (PNG/JPG). Bounds
#'   drift by forcing the bridge to arrive here.
#' @param keyframe_images Optional character vector of image paths (PNG/JPG)
#'   used as interior anchors. Must be the same length as
#'   \code{keyframe_positions}, in the same order.
#' @param keyframe_positions Optional integer vector of 1-indexed frame
#'   positions, one per \code{keyframe_images}, each within \code{1:num_frames}.
#' @param prompt Optional scene/motion description. Keep it stable across a chain.
#'   When unset, a generic transition prompt is sent (the backend requires a
#'   non-empty prompt).
#' @param audio Optional path to an audio file. Requires a checkpoint with the
#'   AV connector; unavailable on GGUF-light.
#' @param num_frames Frames to generate (the new/diffused content; 8n+1).
#'   \code{NULL} (default) is sized from \code{audio} (\code{round(seconds*fps)},
#'   snapped to 8n+1) when audio is given, else the \code{xtx.transition.num_frames}
#'   option, else the server default. Generation time scales with this.
#' @param conditioning_frames Trailing frames of \code{start_clip} used as motion
#'   conditioning (free context, not diffused). \code{NULL} (default) falls back
#'   to \code{getOption("xtx.transition.conditioning_frames")} then the server
#'   default. Set per-box prefs in \code{~/.Rprofile}, e.g.
#'   \code{options(xtx.transition.num_frames = 49, xtx.transition.conditioning_frames = 9)}.
#' @param fill_window If TRUE, pad \code{conditioning_frames} to
#'   \code{window - num_frames} so every call feeds the model a full
#'   \code{window}-frame context (clamped to a valid range). Same diffusion cost
#'   (conditioning isn't diffused), smoother continuity. Start-clip only.
#' @param sliding_window_size,sliding_window_overlap,sliding_window_overlap_noise,sliding_window_discard_last_frames
#'   LTX-2 sliding-window controls for content longer than one window (\code{NULL}
#'   defers to the server). Only engaged when \code{num_frames > window}.
#' @param fps,window Frame rate (default 24) and LTX-2 window size in frames
#'   (default 129) used for audio-sizing and \code{fill_window} math.
#' @param resolution \code{"480p"} or \code{"720p"} (default \code{"720p"}).
#' @param quality \code{"fast"}, \code{"balanced"}, or \code{"quality"}
#'   (default \code{"balanced"}).
#' @param seed Random seed. \code{NULL} (default) defers to the server (random).
#'   Pass a fixed integer >= 0 for reproducible output / clean A/B comparisons.
#' @param output Output file path (default \code{"transition_output.mp4"}).
#' @param timeout Timeout in seconds (default 1800; transitions can be slow).
#' @param backend Backend to use. Only \code{"wan2gp_api"} is supported.
#' @return Invisibly, the path to the written MP4. Note the clip has
#'   \code{num_frames + conditioning_frames - 1} frames, not \code{num_frames}:
#'   the server's \code{video_source} continuation prepends the conditioning tail
#'   of \code{start_clip} as continuity context (e.g. 49 + 9 -> 57 frames). When
#'   assembling \code{start_clip + bridge + clipB}, drop the bridge's first
#'   \code{conditioning_frames} (a copy of \code{start_clip}'s tail) or trim
#'   \code{start_clip}'s tail, so the join isn't double-played; the bridge ->
#'   clipB join is seamless when clipB starts on \code{end_image}.
#' @examples
#' \dontrun{
#'   wan2gp_api_base("http://localhost:8000")
#'
#'   # Smooth the cut between two clips
#'   transition("clipA.mp4", end_image = "clipB_frame1.png",
#'              prompt = "camera pulls back to a wide shot",
#'              output = "bridge.mp4")
#'
#'   # Route through interior keyframe anchors
#'   transition("clipA.mp4", end_image = "clipB_frame1.png",
#'              keyframe_images = c("mid1.png", "mid2.png"),
#'              keyframe_positions = c(17, 33),
#'              num_frames = 49, output = "bridge.mp4")
#' }
#' @export
transition <- function(start_clip = NULL, image_start = NULL,
                       end_image = NULL, keyframe_images = NULL,
                       keyframe_positions = NULL, prompt = NULL,
                       audio = NULL, num_frames = NULL,
                       conditioning_frames = NULL, fill_window = FALSE,
                       sliding_window_size = NULL,
                       sliding_window_overlap = NULL,
                       sliding_window_overlap_noise = NULL,
                       sliding_window_discard_last_frames = NULL, fps = 24,
                       window = 129, resolution = "720p",
                       quality = "balanced", seed = NULL,
                       output = "transition_output.mp4", timeout = 1800,
                       backend = c("wan2gp_api", "diffuseR")) {
    .sidecar_arm(environment())
    backend <- match.arg(backend)

    if (backend == "diffuseR") {
        return(.transition_diffuseR(start_clip = start_clip,
                                    image_start = image_start,
                                    prompt = prompt, audio = audio,
                                    num_frames = num_frames,
                                    conditioning_frames = conditioning_frames,
                                    fps = fps, resolution = resolution,
                                    quality = quality, seed = seed,
                                    output = output))
    }

    .transition_wan2gp_api(
                           start_clip = start_clip, image_start = image_start,
                           end_image = end_image, keyframe_images = keyframe_images,
                           keyframe_positions = keyframe_positions, prompt = prompt, audio = audio,
                           num_frames = num_frames, conditioning_frames = conditioning_frames,
                           fill_window = fill_window, sliding_window_size = sliding_window_size,
                           sliding_window_overlap = sliding_window_overlap,
                           sliding_window_overlap_noise = sliding_window_overlap_noise,
                           sliding_window_discard_last_frames = sliding_window_discard_last_frames,
                           fps = fps, window = window, resolution = resolution, quality = quality,
                           seed = seed, output = output, timeout = timeout)
}

#' Duration of a media file in seconds via ffprobe (NA on failure)
#' @keywords internal
.probe_duration <- function(file) {
    out <- suppressWarnings(system2("ffprobe",
                                    shQuote(c("-v", "error", "-show_entries", "format=duration",
                    "-of", "csv=p=0", file)), stdout = TRUE, stderr = FALSE))
    suppressWarnings(as.numeric(out[1]))
}

#' Snap a frame count to LTX-2's 8n+1 grid (floor at one step)
#' @keywords internal
.align_8nplus1 <- function(n) max(9L, as.integer(8 * round((n - 1) / 8) + 1))

#' Snap a frame count UP to LTX-2's 8n+1 grid
#'
#' For sizing generation from audio: the video must always cover the audio,
#' so the frame budget rounds up. Nearest-rounding here shaved up to 4 frames
#' off a chunk's speech and desynced whole chained tracks (the shortfall also
#' contaminated the conditioning-head measurement downstream).
#' @keywords internal
.ceil_8nplus1 <- function(n) max(9L, as.integer(8 * ceiling((n - 1) / 8) + 1))

#' WanGP API Transition Backend
#' @keywords internal
.transition_wan2gp_api <- function(start_clip = NULL, image_start = NULL,
                                   end_image = NULL, keyframe_images = NULL,
                                   keyframe_positions = NULL, prompt = NULL,
                                   audio = NULL, num_frames = NULL,
                                   conditioning_frames = NULL,
                                   fill_window = FALSE,
                                   sliding_window_size = NULL,
                                   sliding_window_overlap = NULL,
                                   sliding_window_overlap_noise = NULL,
                                   sliding_window_discard_last_frames = NULL,
                                   fps = 24, window = 129,
                                   resolution = "720p", quality = "balanced",
                                   seed = NULL,
                                   output = "transition_output.mp4",
                                   timeout = 1800) {
    # Per-box prefs live client-side (xtx.* option namespace), not in the repo's
    # canonical server defaults: explicit arg > ~/.Rprofile option > server default.
    num_frames <- num_frames %||% getOption("xtx.transition.num_frames")
    conditioning_frames <- conditioning_frames %||%
    getOption("xtx.transition.conditioning_frames")

    base <- .wan2gp_api_get_base()
    url <- paste0(base, "/transition")

    # Start conditioning: a start image (prompt-type S) or a start clip's tail
    # (V). Exactly one is required.
    if (is.null(start_clip) && is.null(image_start)) {
        stop("transition(): supply start_clip (video continuation) or ",
             "image_start (single start frame).", call. = FALSE)
    }
    if (!is.null(start_clip) && !is.null(image_start)) {
        stop("transition(): supply only one of start_clip / image_start.",
             call. = FALSE)
    }
    if (!is.null(start_clip) && !file.exists(start_clip)) {
        stop("start_clip file not found: ", start_clip, call. = FALSE)
    }
    if (!is.null(image_start) && !file.exists(image_start)) {
        stop("image_start file not found: ", image_start, call. = FALSE)
    }
    if (!is.null(end_image) && !file.exists(end_image)) {
        stop("end_image file not found: ", end_image, call. = FALSE)
    }
    if (!is.null(audio) && !file.exists(audio)) {
        stop("audio file not found: ", audio, call. = FALSE)
    }

    # Size num_frames (the new/diffused content) to the audio when unset -- a
    # chunk's audio maps to its generated frames (num_frames is the new-content
    # count, verified empirically, not the total).
    if (is.null(num_frames) && !is.null(audio)) {
        adur <- .probe_duration(audio)
        if (!is.na(adur)) {
            num_frames <- .align_8nplus1(round(adur * fps))
        }
    }
    # fill_window: pad conditioning to a full `window`-frame context (free, not
    # diffused) so every call feeds the model the same context size. Clamp to
    # 1 <= conditioning < num_frames; only applies to a start-clip continuation.
    if (isTRUE(fill_window) && !is.null(num_frames) && !is.null(start_clip)) {
        conditioning_frames <- max(1L, min(num_frames - 1L,
                as.integer(window) - num_frames))
    }

    # Keyframes: images and positions must line up; check files exist.
    n_kf <- length(keyframe_images)
    if (n_kf != length(keyframe_positions)) {
        stop("keyframe_images (", n_kf, ") and keyframe_positions (",
             length(keyframe_positions), ") must have the same length.",
             call. = FALSE)
    }
    for (img in keyframe_images) {
        if (!file.exists(img)) {
            stop("keyframe image not found: ", img, call. = FALSE)
        }
    }

    # LTX-2 requires frames = 8n+1. Catch it here when the caller set num_frames;
    # otherwise the server picks its (already-valid) default.
    if (!is.null(num_frames) && num_frames %% 8 != 1) {
        stop("num_frames must be 8n+1 (9, 17, 25, ..., 49, ...), got ", num_frames,
             call. = FALSE)
    }

    # Build multipart form
    h <- curl::new_handle()
    curl::handle_setopt(h,
                        timeout = timeout,
                        low_speed_time = 0, # Disable low-speed timeout (generation is slow)
                        low_speed_limit = 0
    )

    # wgp.py rejects an empty prompt (the task is skipped, surfacing as a 500), so
    # fall back to a generic transition prompt when the caller gives none.
    form_args <- list(
                      prompt = prompt %||% "smooth cinematic transition",
                      resolution = resolution,
                      quality = quality
    )
    # Start conditioning: video continuation (start_clip) or single frame
    # (image_start). Exactly one is set (validated above).
    if (!is.null(start_clip)) {
        form_args$start_clip <- curl::form_file(start_clip)
    }
    if (!is.null(image_start)) {
        form_args$image_start <- curl::form_file(image_start)
    }
    # Optional files / params: send only when provided so the server applies its
    # own defaults otherwise.
    if (!is.null(end_image)) {
        form_args$end_image <- curl::form_file(end_image)
    }
    # Interior keyframe anchors: one repeated `keyframe_images` file field per
    # image (matches FastAPI list[UploadFile]) plus a comma-separated positions
    # string. Duplicate list names are passed through to curl as repeated parts.
    if (n_kf > 0) {
        for (img in keyframe_images) {
            form_args <- c(form_args, stats::setNames(list(curl::form_file(img)), "keyframe_images"))
        }
        form_args$keyframe_positions <- paste(keyframe_positions, collapse = ",")
    }
    if (!is.null(audio)) {
        form_args$audio <- curl::form_file(audio)
    }
    if (!is.null(num_frames)) {
        form_args$num_frames <- as.character(num_frames)
    }
    if (!is.null(conditioning_frames)) {
        form_args$conditioning_frames <- as.character(conditioning_frames)
    }
    if (!is.null(sliding_window_size)) {
        form_args$sliding_window_size <- as.character(sliding_window_size)
    }
    if (!is.null(sliding_window_overlap)) {
        form_args$sliding_window_overlap <- as.character(sliding_window_overlap)
    }
    if (!is.null(sliding_window_overlap_noise)) {
        form_args$sliding_window_overlap_noise <-
        as.character(sliding_window_overlap_noise)
    }
    if (!is.null(sliding_window_discard_last_frames)) {
        form_args$sliding_window_discard_last_frames <-
        as.character(sliding_window_discard_last_frames)
    }
    if (!is.null(seed)) {
        form_args$seed <- as.character(seed)
    }
    do.call(curl::handle_setform, c(list(h), form_args))

    message("Calling WanGP API (LTX-2) for transition generation...")

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Connection to WanGP API failed: ", e$message, call. = FALSE)
    }
    )

    status <- response$status_code
    if (status >= 400) {
        err_content <- rawToChar(response$content)
        err_msg <- tryCatch({
            parsed <- jsonlite::fromJSON(err_content)
            parsed$detail$message %||% parsed$detail %||% parsed$error %||% err_content
        }, error = function(e) err_content)
        stop("WanGP API error (", status, "): ", err_msg, call. = FALSE)
    }

    # Write video to output file
    writeBin(response$content, output)
    message("Transition video saved to: ", output)

    invisible(output)
}

#' Check if the WanGP Transition Endpoint is Reachable
#'
#' Quick check that the WanGP API is reachable and healthy. Returns TRUE/FALSE
#' and never throws. Configure the base URL first with \code{wan2gp_api_base()}.
#'
#' @param timeout Timeout in seconds (default 2).
#' @return TRUE if the service responds 200 on /health, FALSE otherwise.
#' @examples
#' \dontrun{
#'   wan2gp_api_base("http://localhost:8000")
#'   if (transition_available()) transition("clipA.mp4", end_image = "b.png")
#' }
#' @export
transition_available <- function(timeout = 2) {
    base <- tryCatch(.wan2gp_api_get_base(), error = function(e) NULL)
    if (is.null(base)) {
        return(FALSE)
    }
    url <- paste0(base, "/health")

    tryCatch({
        h <- curl::new_handle()
        curl::handle_setopt(h, timeout = timeout)
        res <- curl::curl_fetch_memory(url, handle = h)
        res$status_code == 200
    }, error = function(e) FALSE)
}
