# WanGP Video Generation (LTX-2, VACE, Hunyuan Avatar, etc.)
#
# CLI-based Docker integration for DeepBeepMeep's Wan2GP framework.
# Unlike HTTP-based backends, WanGP uses JSON config files and docker run.

#' Configure WanGP Settings
#'
#' Set default paths and options for WanGP docker integration.
#'
#' @param workspace Path to Wan2GP workspace (default: "~/Wan2GP")
#' @param cache Path to HuggingFace cache (default: "~/.cache/huggingface")
#' @param output_dir Default output directory (default: current working dir)
#' @param profile Memory profile 1-4 (4 = low VRAM, default: 4)
#' @param container Docker image name (default: "wan2gp:blackwell")
#' @return Invisibly returns previous settings as a list
#' @examples
#' \dontrun{
#'   wan2gp_config(profile = 3)  # Use medium VRAM profile
#'   wan2gp_config(output_dir = "/data/videos")
#' }
#' @export
wan2gp_config <- function(workspace = NULL, cache = NULL, output_dir = NULL,
                          profile = NULL, container = NULL) {
  old <- list(
    workspace = getOption("xtx.wan2gp.workspace"),
    cache = getOption("xtx.wan2gp.cache"),
    output_dir = getOption("xtx.wan2gp.output_dir"),
    profile = getOption("xtx.wan2gp.profile"),
    container = getOption("xtx.wan2gp.container")
  )

  if (!is.null(workspace)) options(xtx.wan2gp.workspace = path.expand(workspace))
  if (!is.null(cache)) options(xtx.wan2gp.cache = path.expand(cache))
  if (!is.null(output_dir)) options(xtx.wan2gp.output_dir = path.expand(output_dir))

  if (!is.null(profile)) options(xtx.wan2gp.profile = as.integer(profile))
  if (!is.null(container)) options(xtx.wan2gp.container = container)

  invisible(old)
}

#' Get WanGP Configuration
#' @keywords internal
.wan2gp_get_config <- function() {
  list(
    workspace = getOption("xtx.wan2gp.workspace", path.expand("~/Wan2GP")),
    cache = getOption("xtx.wan2gp.cache", path.expand("~/.cache/huggingface")),
    output_dir = getOption("xtx.wan2gp.output_dir", getwd()),
    profile = getOption("xtx.wan2gp.profile", 4L),
    container = getOption("xtx.wan2gp.container", "wan2gp:blackwell")
  )
}

#' Generate Video with WanGP (LTX-2)
#'
#' Generate video using LTX-2 19B via WanGP Docker container.
#' Supports text-to-video, image-to-video, and audio-guided generation.
#'
#' @param prompt Text prompt describing the video content
#' @param image Path to starting image (optional, for image-to-video)
#' @param audio Path to audio file for lip-sync/audio-guided generation (optional
#' @param output Path for output video file
#' @param width Video width in pixels (default: 832)
#' @param height Video height in pixels (default: 832)
#' @param num_frames Number of frames to generate (default: 129, ~5.4s at 24fps)
#' @param steps Number of inference steps (default: 8 for distilled model)
#' @param guidance_scale CFG scale (default: 4.0)
#' @param seed Random seed for reproducibility (default: random)
#' @param model Model variant: "distilled" or "dev" (default: "distilled")
#' @param timeout Maximum time to wait in seconds (default: 600)
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # Text-to-video
#'   wan2gp("A cat playing piano", output = "cat_piano.mp4")
#'
#'   # Image-to-video
#'   wan2gp("Person talking and gesturing",
#'          image = "portrait.jpg",
#'          output = "talking.mp4")
#'
#'   # Audio-guided video
#'   wan2gp("Person speaking into microphone",
#'          image = "dj.jpg",
#'          audio = "speech.wav",
#'          output = "dj_speaking.mp4")
#' }
#' @export
wan2gp <- function(prompt,
                   image = NULL,
                   audio = NULL,
                   output = "wan2gp_output.mp4",
                   width = 832L,
                   height = 832L,
                   num_frames = 129L,
                   steps = 8L,
                   guidance_scale = 4.0,
                   seed = NULL,
                   model = c("distilled", "dev"),
                   timeout = 600) {


  model <- match.arg(model)
  cfg <- .wan2gp_get_config()

  # Validate inputs
  if (!is.null(image) && !file.exists(image)) {
    stop("Image file not found: ", image, call. = FALSE)
  }
  if (!is.null(audio) && !file.exists(audio)) {
    stop("Audio file not found: ", audio, call. = FALSE)
  }

  # Generate seed if not provided
  if (is.null(seed)) {
    seed <- sample.int(.Machine$integer.max, 1L)
  }

  # Create temporary directory for config and I/O

tmp_dir <- tempfile("wan2gp_")
  dir.create(tmp_dir, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  input_dir <- file.path(tmp_dir, "input")
  dir.create(input_dir)

  # Copy input files to temp directory
  image_container_path <- NULL
  if (!is.null(image)) {
    image_basename <- basename(image)
    file.copy(image, file.path(input_dir, image_basename))
    image_container_path <- paste0("/input/", image_basename)
  }

  audio_container_path <- NULL
  if (!is.null(audio)) {
    audio_basename <- basename(audio)
    file.copy(audio, file.path(input_dir, audio_basename))
    audio_container_path <- paste0("/input/", audio_basename)
  }

  # Build config
  config <- .wan2gp_build_config(
    prompt = prompt,
    image_path = image_container_path,
    audio_path = audio_container_path,
    width = width,
    height = height,
    num_frames = num_frames,
    steps = steps,
    guidance_scale = guidance_scale,
    seed = seed,
    model = model
  )

  # Write config file
  config_file <- file.path(tmp_dir, "config.json")
  jsonlite::write_json(config, config_file, auto_unbox = TRUE, pretty = TRUE)

  # Build docker command
  cmd <- .wan2gp_build_docker_cmd(
    config_file = "/input/config.json",  # Container path
    input_dir = input_dir,
    output_dir = cfg$output_dir,
    workspace = cfg$workspace,
    cache = cfg$cache,
    profile = cfg$profile,
    container = cfg$container
  )

  # Copy config to input dir so it's accessible in container
  file.copy(config_file, file.path(input_dir, "config.json"))

  # Record start time to find new files
  start_time <- Sys.time()

  # Run docker
  message("Running WanGP (", model, " model, ", num_frames, " frames)...")
  exit_code <- system(cmd, timeout = timeout)

  if (exit_code != 0) {
    stop("WanGP failed with exit code ", exit_code, call. = FALSE)
  }

  # Find output file - look for mp4 files created after we started
  output_files <- list.files(cfg$output_dir, pattern = "\\.mp4$", full.names = TRUE)
  file_info <- file.info(output_files)
  new_files <- output_files[file_info$mtime > start_time]

  if (length(new_files) == 0) {
    # Fall back to most recent file with matching seed
    seed_pattern <- paste0("seed", seed)
    matching <- grep(seed_pattern, output_files, value = TRUE)
    if (length(matching) > 0) {
      new_files <- matching[order(file_info[matching, "mtime"], decreasing = TRUE)]
    }
  }

  if (length(new_files) == 0) {
    stop("WanGP did not produce output. Check docker logs.", call. = FALSE)
  }

  # Get the generated file (most recent if multiple)
  generated_file <- new_files[1]

  # Copy/rename to requested output path
  if (!identical(normalizePath(generated_file, mustWork = FALSE),
                 normalizePath(output, mustWork = FALSE))) {
    file.copy(generated_file, output, overwrite = TRUE)
    message("Video saved to: ", output)
  } else {
    message("Video saved to: ", generated_file)
    output <- generated_file
  }

  invisible(output)
}

#' Build WanGP Config
#' @keywords internal
.wan2gp_build_config <- function(prompt, image_path, audio_path,
                                  width, height, num_frames, steps,
                                  guidance_scale, seed, model) {
  # Model configuration
  if (model == "distilled") {
    model_config <- list(
      name = "LTX-2 Distilled 19B",
      architecture = "ltx2_19B",
      URLs = list(
        "https://huggingface.co/DeepBeepMeep/LTX-2/resolve/main/ltx-2-19b-distilled_diffusion_model.safetensors"
      ),
      preload_URLs = "ltx2_19B",
      ltx2_pipeline = "distilled"
    )
  } else {
    model_config <- list(
      name = "LTX-2 Dev 19B",
      architecture = "ltx2_19B",
      URLs = list(
        "https://huggingface.co/DeepBeepMeep/LTX-2/resolve/main/ltx-2-19b-dev_diffusion_model.safetensors"
      ),
      preload_URLs = "ltx2_19B",
      ltx2_pipeline = "dev"
    )
  }

  config <- list(
    model_type = "ltx2_19B",
    model = model_config,
    prompt = prompt,
    num_inference_steps = as.integer(steps),
    video_length = as.integer(num_frames),
    guidance_scale = guidance_scale,
    width = as.integer(width),
    height = as.integer(height),
    seed = as.integer(seed)
  )

  # Add image if provided
  if (!is.null(image_path)) {
    config$image_start <- image_path
    config$image_prompt_type <- "S"  # Start frame
  }

  # Add audio if provided
  if (!is.null(audio_path)) {
    config$audio_guide <- audio_path
    config$audio_prompt_type <- "AV"  # Audio + Vocal
  }

  config
}

#' Build Docker Command
#' @keywords internal
.wan2gp_build_docker_cmd <- function(config_file, input_dir, output_dir,
                                      workspace, cache, profile, container) {
  # Volume mounts
  volumes <- c(
    paste0("-v ", workspace, ":/workspace"),
    paste0("-v ", cache, ":/home/user/.cache/huggingface"),
    paste0("-v ", input_dir, ":/input"),
    paste0("-v ", output_dir, ":/output")
  )

  paste(
    "docker run --rm --gpus all",
    paste(volumes, collapse = " "),
    container,
    "--process", config_file,
    "--output-dir /output",
    "--profile", profile,
    "2>&1"
  )
}

#' List Available WanGP Models
#'
#' Show available model types and their requirements.
#'
#' @return A data.frame with model information
#' @export
wan2gp_models <- function() {
  data.frame(
    model = c("ltx2_19B", "vace_1.3B", "hunyuan_avatar", "fantasy_talking"),
    name = c("LTX-2 19B", "VACE 1.3B", "Hunyuan Avatar 13B", "Fantasy Talking 14B"),
    vram_min = c(16, 12, 24, 24),
    speed = c("fast", "slow", "very slow", "very slow"),
    use_case = c(
      "General video, talking heads",
      "Motion transfer",
      "Talking heads (real faces)",
      "Talking heads (stylized)"
    ),
    stringsAsFactors = FALSE
  )
}
