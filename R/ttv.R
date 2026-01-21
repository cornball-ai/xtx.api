# Text-to-Video (TTV) functions

#' Generate Video from Text (Text-to-Video)
#'
#' Generate a video from a text prompt alone (no input image).
#' Uses LTX-2 via WanGP.
#'
#' @param prompt Text prompt describing the video content
#' @param output Path for output video file (default: "ttv_output.mp4")
#' @param backend Backend to use: "wan2gp" (default)
#' @param model Model ID: "ltx2" (default)
#' @param width Video width in pixels (default: 832)
#' @param height Video height in pixels (default: 832)
#' @param num_frames Number of frames to generate (default: 129, ~5.4s at 24fps)
#' @param num_steps Number of inference steps (NULL = model default)
#' @param guidance_scale CFG scale (NULL = model default)
#' @param seed Random seed for reproducibility
#' @param timeout Request timeout in seconds (default: 600)
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # Simple text-to-video
#'   ttv("A cat playing piano in a jazz club", output = "cat_piano.mp4")
#'
#'   # With custom parameters
#'   ttv("Aerial view of mountains at sunset",
#'       width = 1280, height = 720, num_frames = 161,
#'       seed = 42, output = "mountains.mp4")
#' }
#' @export
ttv <- function(
  prompt,
  output = "ttv_output.mp4",
  backend = "wan2gp",
  model = "ltx2",
  width = 832L,
  height = 832L,
  num_frames = 129L,
  num_steps = NULL,
  guidance_scale = NULL,
  seed = NULL,
  timeout = 600
) {

  if (missing(prompt) || nchar(prompt) == 0) {
    stop("'prompt' is required for text-to-video generation", call. = FALSE)
  }

  .wan2gp_generate(
    prompt = prompt,
    model = model,
    image = NULL,
    audio = NULL,
    video = NULL,
    output = output,
    width = width,
    height = height,
    num_frames = num_frames,
    steps = num_steps,
    guidance_scale = guidance_scale,
    seed = seed,
    timeout = timeout
  )
}

