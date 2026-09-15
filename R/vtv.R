# Video-to-Video (VTV) functions

#' Generate Video from Video (Video-to-Video)
#'
#' Transform or enhance an existing video. Supports motion transfer (VACE),
#' style transfer, and video enhancement/upscaling (LTX-2).
#'
#' @param video Path to source video file
#' @param prompt Text prompt describing desired output
#' @param output Path for output video file (default: "vtv_output.mp4" under
#'   \code{tempdir()}; pass a path to keep the file)
#' @param backend Backend to use: "wan2gp" (default)
#' @param model Model ID: "vace" (motion transfer) or "ltx2" (enhancement/style)
#' @param width Output video width (default: 832)
#' @param height Output video height (default: 832)
#' @param num_frames Number of output frames (default: from source video)
#' @param num_steps Number of inference steps (NULL = model default)
#' @param guidance_scale CFG scale (NULL = model default)
#' @param strength Denoising strength 0-1 (lower = more faithful to source)
#' @param seed Random seed for reproducibility
#' @param timeout Request timeout in seconds (default: 600)
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # Motion transfer with VACE
#'   vtv("dance.mp4", "Robot dancing in futuristic city",
#'       model = "vace", output = "robot_dance.mp4")
#'
#'   # Video enhancement/style with LTX-2
#'   vtv("lowres.mp4", "High quality cinematic footage",
#'       model = "ltx2", output = "enhanced.mp4")
#' }
#' @export
vtv <- function(video, prompt = "",
                output = file.path(tempdir(), "vtv_output.mp4"),
                backend = "wan2gp", model = c("vace", "ltx2"), width = 832L,
                height = 832L, num_frames = NULL, num_steps = NULL,
                guidance_scale = NULL, strength = 0.5, seed = NULL,
                timeout = 600) {
    .sidecar_arm(environment())
    model <- match.arg(model)

    if (!file.exists(video)) {
        stop("Video file not found: ", video, call. = FALSE)
    }

    # Default num_frames from source video if not specified
    if (is.null(num_frames)) {
        num_frames <- 129L # Default, could probe video
    }

    .wan2gp_generate(prompt = prompt, model = model, video = video,
                     output = output, width = width, height = height,
                     num_frames = num_frames, steps = num_steps,
                     guidance_scale = guidance_scale, seed = seed,
                     timeout = timeout)
}
