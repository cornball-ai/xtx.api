#' Create Morph Video Between Two Images
#'
#' Generate a smooth transition video from a start image to an end image
#' using RIFE frame interpolation. Wrapper around rife::rife_morph().
#'
#' @param start Path to the starting image
#' @param end Path to the ending image
#' @param output Path for output video file (default: "morph.mp4")
#' @param frames Number of frames in output video (default: 60)
#' @param duration Alternative to frames: duration in seconds
#' @param fps Output video frame rate (default: 30)
#' @param model RIFE model: "rife-v4.6" (default) or "rife-v4"
#' @param gpu GPU device ID, -1 for CPU (default: 0)
#'
#' @return Path to the output video (invisibly)
#'
#' @examples
#' \dontrun{
#' # 2-second morph between images
#' rvf_morph("start.png", "end.png", "morph.mp4", duration = 2)
#'
#' # Specific frame count
#' rvf_morph("a.png", "b.png", "transition.mp4", frames = 120)
#' }
#'
#' @export
rvf_morph <- function(
  start,
  end,
  output = "morph.mp4",
  frames = 60L,
  duration = NULL,
  fps = 30,
  model = "rife-v4.6",
  gpu = 0L
) {
  .check_rife()
  rife::rife_morph(start, end, output,
    frames = frames, duration = duration, fps = fps,
    model = model, gpu = gpu)
}

#' Smooth Video with Frame Interpolation
#'
#' Increase video frame rate by generating intermediate frames using RIFE.
#' Wrapper around rife::rife_video().
#'
#' @param input Path to input video file
#' @param output Path for output video file (default: "smooth.mp4")
#' @param factor Frame multiplication factor: 2 = double FPS, 4 = 4x FPS (default: 2)
#' @param model RIFE model: "rife-v4.6" (default) or "rife-v4"
#' @param gpu GPU device ID, -1 for CPU (default: 0)
#'
#' @return Path to the output video (invisibly)
#'
#' @examples
#' \dontrun{
#' # Double the frame rate
#' rvf_smooth("input.mp4", "smooth.mp4")
#'
#' # 4x for slow motion
#' rvf_smooth("input.mp4", "slowmo.mp4", factor = 4)
#' }
#'
#' @export
rvf_smooth <- function(
  input,
  output = "smooth.mp4",
  factor = 2L,
  model = "rife-v4.6",
  gpu = 0L
) {
  .check_rife()
  rife::rife_video(input, output, factor = factor, model = model, gpu = gpu)
}

#' Interpolate Between Two Images
#'
#' Generate an intermediate frame between two images using RIFE.
#' Wrapper around rife::rife_interpolate().
#'
#' @param img0 Path to the first image
#' @param img1 Path to the second image
#' @param output Path for output image (default: auto-generated)
#' @param timestep Interpolation position 0-1 (default: 0.5)
#' @param model RIFE model: "rife-v4.6" (default) or "rife-v4"
#' @param gpu GPU device ID, -1 for CPU (default: 0)
#'
#' @return Path to the output image (invisibly)
#'
#' @examples
#' \dontrun{
#' # Middle frame between two images
#' rvf_interp("frame1.png", "frame2.png", "middle.png")
#'
#' # 25% between first and second
#' rvf_interp("a.png", "b.png", "out.png", timestep = 0.25)
#' }
#'
#' @export
rvf_interp <- function(
  img0,
  img1,
  output = NULL,
  timestep = 0.5,
  model = "rife-v4.6",
  gpu = 0L
) {
  .check_rife()
  rife::rife_interpolate(img0, img1, output,
    timestep = timestep, model = model, gpu = gpu)
}

#' Check RIFE Availability
#'
#' Check if the rife package is installed and working.
#'
#' @return TRUE if rife is available, FALSE otherwise
#'
#' @examples
#' rvf_available()
#'
#' @export
rvf_available <- function() {
  tryCatch({
      requireNamespace("rife", quietly = TRUE) &&
      !is.null(rife::rife_info()$binary)
    }, error = function(e) FALSE)
}

#' Get RIFE Package Info
#'
#' @return List with rife package version, models, and binary path
#'
#' @examples
#' \dontrun{
#' rvf_info()
#' }
#'
#' @export
rvf_info <- function() {
  .check_rife()
  rife::rife_info()
}

# Internal ----------------------------------------------------------------

.check_rife <- function() {
  if (!requireNamespace("rife", quietly = TRUE)) {
    stop("rife package is required. Install with: remotes::install_github('cornball-ai/rife')")
  }
}

