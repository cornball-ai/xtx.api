# Text-to-Video (TTV) functions

#' Generate Video from Text (Text-to-Video)
#'
#' Generate a video from a text prompt alone (no input image).
#' Uses LTX-2 via WanGP API or Docker.
#'
#' @param prompt Text prompt describing the video content
#' @param output Path for output video file (default: "ttv_output.mp4" under
#'   \code{tempdir()}; pass a path to keep the file)
#' @param backend Backend to use: "wan2gp_api" (default, HTTP) or "wan2gp" (Docker)
#' @param model Model ID for Docker backend: "ltx2" (default)
#' @param num_frames Number of frames to generate (default: 97, ~4s at 24fps)
#' @param resolution Resolution for wan2gp_api: "480p" or "720p" (default: "720p")
#' @param quality Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")
#' @param width Video width in pixels (wan2gp Docker only, default: 832)
#' @param height Video height in pixels (wan2gp Docker only, default: 832)
#' @param num_steps Number of inference steps (NULL = model default)
#' @param guidance_scale CFG scale (NULL = model default)
#' @param seed Random seed for reproducibility
#' @param timeout Request timeout in seconds (default: 600)
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # Via WanGP API (recommended)
#'   wan2gp_api_base("http://localhost:8000")
#'   ttv("A cat playing piano in a jazz club", output = "cat_piano.mp4")
#'
#'   # High quality mode
#'   ttv("Aerial view of mountains at sunset",
#'       quality = "quality", output = "mountains.mp4")
#'
#'   # Via Docker (direct)
#'   ttv("Ocean waves at sunset", backend = "wan2gp",
#'       width = 1280, height = 720, num_frames = 129)
#' }
#' @export
ttv <- function(prompt, output = file.path(tempdir(), "ttv_output.mp4"),
                backend = c("wan2gp_api", "wan2gp"), model = "ltx2",
                num_frames = 97L, resolution = "720p", quality = "balanced",
                width = 832L, height = 832L, num_steps = NULL,
                guidance_scale = NULL, seed = NULL, timeout = 600) {
    .sidecar_arm(environment())
    if (missing(prompt) || nchar(prompt) == 0) {
        stop("'prompt' is required for text-to-video generation", call. = FALSE)
    }

    backend <- match.arg(backend)

    if (backend == "wan2gp_api") {
        # WanGP FastAPI backend (LTX-2 via HTTP)
        .t2v_wan2gp_api(prompt = prompt, output = output,
                        num_frames = num_frames, resolution = resolution,
                        quality = quality, timeout = timeout)
    } else {
        # WanGP Docker backend
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
}
