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
#'   the bridge.
#' @param end_image Optional path to a destination keyframe (PNG/JPG). Bounds
#'   drift by forcing the bridge to arrive here.
#' @param keyframe_images Optional character vector of image paths (PNG/JPG)
#'   used as interior anchors. Must be the same length as
#'   \code{keyframe_positions}, in the same order.
#' @param keyframe_positions Optional integer vector of 1-indexed frame
#'   positions, one per \code{keyframe_images}, each within \code{1:num_frames}.
#' @param prompt Optional scene/motion description. Keep it stable across a chain.
#' @param audio Optional path to an audio file. Requires a checkpoint with the
#'   AV connector; unavailable on GGUF-light.
#' @param num_frames Frames to generate; must be 8n+1 (LTX-2 constraint).
#'   \code{NULL} (default) defers to the server default (49, ~2s @ 24fps).
#' @param conditioning_frames Trailing frames of \code{start_clip} used as motion
#'   conditioning. \code{NULL} (default) defers to the server default (9).
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
transition <- function(
  start_clip,
  end_image = NULL,
  keyframe_images = NULL,
  keyframe_positions = NULL,
  prompt = NULL,
  audio = NULL,
  num_frames = NULL,
  conditioning_frames = NULL,
  resolution = "720p",
  quality = "balanced",
  seed = NULL,
  output = "transition_output.mp4",
  timeout = 1800,
  backend = c("wan2gp_api")
) {
  backend <- match.arg(backend)

  .transition_wan2gp_api(
    start_clip = start_clip,
    end_image = end_image,
    keyframe_images = keyframe_images,
    keyframe_positions = keyframe_positions,
    prompt = prompt,
    audio = audio,
    num_frames = num_frames,
    conditioning_frames = conditioning_frames,
    resolution = resolution,
    quality = quality,
    seed = seed,
    output = output,
    timeout = timeout
  )
}

#' WanGP API Transition Backend
#' @keywords internal
.transition_wan2gp_api <- function(
  start_clip,
  end_image = NULL,
  keyframe_images = NULL,
  keyframe_positions = NULL,
  prompt = NULL,
  audio = NULL,
  num_frames = NULL,
  conditioning_frames = NULL,
  resolution = "720p",
  quality = "balanced",
  seed = NULL,
  output = "transition_output.mp4",
  timeout = 1800
) {

  base <- .wan2gp_api_get_base()
  url <- paste0(base, "/transition")

  # Validate input files up front (clear R error before hitting the network).
  if (!file.exists(start_clip)) {
    stop("start_clip file not found: ", start_clip, call. = FALSE)
  }
  if (!is.null(end_image) && !file.exists(end_image)) {
    stop("end_image file not found: ", end_image, call. = FALSE)
  }
  if (!is.null(audio) && !file.exists(audio)) {
    stop("audio file not found: ", audio, call. = FALSE)
  }

  # Keyframes: images and positions must line up; check files exist.
  n_kf <- length(keyframe_images)
  if (n_kf != length(keyframe_positions)) {
    stop("keyframe_images (", n_kf, ") and keyframe_positions (",
      length(keyframe_positions), ") must have the same length.", call. = FALSE)
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
    low_speed_time = 0,  # Disable low-speed timeout (generation is slow)
    low_speed_limit = 0
  )

  form_args <- list(
    start_clip = curl::form_file(start_clip),
    prompt = prompt %||% "",
    resolution = resolution,
    quality = quality
  )
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
