# Transition: LTX-2 keyframe-conditioned bridging clips via the WanGP API.
#
# transition() generates a short clip that continues from the tail of a source
# clip and (optionally) arrives at a destination keyframe -- the "bridge the cut
# between clip A and clip B" primitive. The work happens on the WanGP
# /transition endpoint; this is the R client over it, mirroring .stv_wan2gp_api().

#' Generate a Bridging Transition Clip (LTX-2)
#'
#' Generate a short video that continues from the trailing frames of
#' `start_clip` and, optionally, arrives at `end_image` -- the primitive for
#' smoothing a cut between two clips. Served by the WanGP API `/transition`
#' endpoint (LTX-2). Set the server with [wan2gp_api_base()].
#'
#' Per-user defaults for `num_frames` and `conditioning_frames` come from the
#' `xtx.transition.num_frames` / `xtx.transition.conditioning_frames` options
#' (set them in your `~/.Rprofile`); an explicit argument always wins. The
#' built-in fallbacks are the LTX-2.3 pipeline defaults: 121 frames (~5s at
#' 24fps) and a 17-frame conditioning overlap.
#'
#' @param start_clip Path to the source video (MP4). Its trailing
#'   `conditioning_frames` frames seed the bridge.
#' @param end_image Optional path to a destination keyframe (PNG/JPG). Forces the
#'   bridge to arrive there, bounding how far appearance drifts. `NULL` (default)
#'   leaves the destination open (an anchored extension).
#' @param output Path for the output video (default `"transition.mp4"`).
#' @param prompt Optional scene/motion description.
#' @param num_frames Frames to generate; must be 8n+1 (LTX-2 constraint). `NULL`
#'   (default) uses `getOption("xtx.transition.num_frames", 121)`.
#' @param conditioning_frames Trailing frames of `start_clip` used as motion
#'   conditioning. `NULL` (default) uses
#'   `getOption("xtx.transition.conditioning_frames", 17)`.
#' @param keyframe_images Optional character vector of interior keyframe image
#'   paths to route the bridge through. Pair with `keyframe_positions`.
#' @param keyframe_positions Optional integer vector of 1-indexed frame positions
#'   for `keyframe_images` (same length, same order; each in `1..num_frames`).
#' @param audio Optional path to an audio file (needs an AV-capable checkpoint;
#'   unavailable on the GGUF-light build).
#' @param resolution Output resolution: `"480p"` or `"720p"` (default `"720p"`).
#' @param quality Quality preset: `"fast"`, `"balanced"`, or `"quality"`
#'   (default `"balanced"`).
#' @param seed Random seed; `-1` (default) picks a random seed. A fixed seed
#'   `>= 0` gives reproducible output.
#' @param timeout Request timeout in seconds (default 1800; LTX-2 quality runs
#'   are slow).
#' @return Invisibly returns the output file path.
#'
#' @details
#' The returned clip is `num_frames + conditioning_frames - 1` frames long: the
#' WanGP continuation prepends the conditioning tail of `start_clip`. To assemble
#' `start_clip + transition + clipB` seamlessly, drop the transition's first
#' `conditioning_frames` (a copy of the source tail).
#'
#' @examples
#' \dontrun{
#'   wan2gp_api_base("http://gpu-server:8000")
#'
#'   # Bridge the cut from a source clip to a destination shot
#'   transition("chapter07.mp4", end_image = "cornelius_first_frame.png",
#'              output = "bridge.mp4")
#'
#'   # Anchored extension (no fixed destination)
#'   transition("chapter07.mp4", output = "extended.mp4", prompt = "slow push in")
#'
#'   # Route through an interior keyframe
#'   transition("a.mp4", end_image = "b.png", keyframe_images = "mid.png",
#'              keyframe_positions = 61L)
#' }
#' @seealso [transition_available()], [wan2gp_api_base()]
#' @export
transition <- function(start_clip, end_image = NULL,
                       output = "transition.mp4", prompt = "",
                       num_frames = NULL, conditioning_frames = NULL,
                       keyframe_images = NULL, keyframe_positions = NULL,
                       audio = NULL, resolution = "720p",
                       quality = "balanced", seed = -1L, timeout = 1800) {
    num_frames <- num_frames %||% getOption("xtx.transition.num_frames", 121L)
    conditioning_frames <- conditioning_frames %||%
    getOption("xtx.transition.conditioning_frames", 17L)

    .transition_wan2gp_api(
                           start_clip = start_clip,
                           end_image = end_image,
                           output = output,
                           prompt = prompt,
                           num_frames = as.integer(num_frames),
                           conditioning_frames = as.integer(conditioning_frames),
                           keyframe_images = keyframe_images,
                           keyframe_positions = keyframe_positions,
                           audio = audio,
                           resolution = resolution,
                           quality = quality,
                           seed = as.integer(seed),
                           timeout = timeout
    )
}

#' Transition via WanGP API
#'
#' Internal worker for [transition()]. POSTs the inputs as multipart/form-data to
#' the WanGP `/transition` endpoint and writes the returned MP4.
#'
#' @keywords internal
.transition_wan2gp_api <- function(start_clip, end_image = NULL,
                                   output = "transition.mp4", prompt = "",
                                   num_frames = 121L,
                                   conditioning_frames = 17L,
                                   keyframe_images = NULL,
                                   keyframe_positions = NULL, audio = NULL,
                                   resolution = "720p", quality = "balanced",
                                   seed = -1L, timeout = 1800) {
    base <- .wan2gp_api_get_base()
    url <- paste0(base, "/transition")

    # --- validation (fail before the network round-trip) ---------------------
    if (!file.exists(start_clip)) {
        stop("start_clip file not found: ", start_clip, call. = FALSE)
    }
    if (num_frames %% 8 != 1) {
        stop("num_frames must be 8n+1 (9, 17, 25, ..., 121, ...), got ",
             num_frames, call. = FALSE)
    }
    if (conditioning_frames < 1 || conditioning_frames >= num_frames) {
        stop("conditioning_frames must be between 1 and num_frames-1, got ",
             conditioning_frames, call. = FALSE)
    }
    if (!is.null(end_image) && !file.exists(end_image)) {
        stop("end_image file not found: ", end_image, call. = FALSE)
    }
    if (!is.null(audio) && !file.exists(audio)) {
        stop("audio file not found: ", audio, call. = FALSE)
    }
    n_kf <- length(keyframe_images)
    if (n_kf > 0L) {
        if (length(keyframe_positions) != n_kf) {
            stop("keyframe_images (", n_kf, ") and keyframe_positions (",
                 length(keyframe_positions), ") must have the same length", call. = FALSE)
        }
        missing_kf <- keyframe_images[!file.exists(keyframe_images)]
        if (length(missing_kf) > 0L) {
            stop("keyframe image(s) not found: ", paste(missing_kf, collapse = ", "),
                 call. = FALSE)
        }
        if (any(keyframe_positions < 1 | keyframe_positions > num_frames)) {
            stop("each keyframe position must be in 1..", num_frames, call. = FALSE)
        }
    }

    # --- multipart form ------------------------------------------------------
    h <- curl::new_handle()
    curl::handle_setopt(h,
                        timeout = timeout,
                        low_speed_time = 0, # quality mode is slow; don't trip the low-speed timeout
                        low_speed_limit = 0
    )

    form_args <- list(start_clip = curl::form_file(start_clip))
    if (!is.null(end_image)) {
        form_args$end_image <- curl::form_file(end_image)
    }
    if (n_kf > 0L) {
        # Repeated multipart field: one `keyframe_images` part per image.
        for (kf in keyframe_images) {
            kf_part <- list(curl::form_file(kf))
            names(kf_part) <- "keyframe_images"
            form_args <- c(form_args, kf_part)
        }
        form_args$keyframe_positions <- paste(keyframe_positions, collapse = ",")
    }
    if (!is.null(audio)) {
        form_args$audio <- curl::form_file(audio)
    }
    form_args$prompt <- prompt
    form_args$num_frames <- as.character(num_frames)
    form_args$conditioning_frames <- as.character(conditioning_frames)
    form_args$resolution <- resolution
    form_args$quality <- quality
    form_args$seed <- as.character(seed)

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

    writeBin(response$content, output)
    message("Transition video saved to: ", output)

    invisible(output)
}

#' Check if the Transition Endpoint is Available
#'
#' Convenience health probe for [transition()]. The transition endpoint is served
#' by the WanGP API, so this is an alias for [wan2gp_api_available()]: it returns
#' `TRUE`/`FALSE` and never throws.
#'
#' @return `TRUE` if the WanGP API is reachable, `FALSE` otherwise.
#' @examples
#' \dontrun{
#'   if (transition_available()) {
#'     transition("a.mp4", end_image = "b.png")
#'   }
#' }
#' @seealso [wan2gp_api_available()]
#' @export
transition_available <- function() {
    wan2gp_api_available()
}

