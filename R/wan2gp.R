# WanGP Internal Backend
#
# Low-level Docker integration for DeepBeepMeep's Wan2GP framework.
# This is an internal module - use itv(), stv(), ttv(), vtv() instead.

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
#' @export
wan2gp_config <- function(workspace = NULL, cache = NULL, output_dir = NULL,
                          profile = NULL, container = NULL) {
    old <- list(workspace = getOption("xtx.wan2gp.workspace"),
                cache = getOption("xtx.wan2gp.cache"),
                output_dir = getOption("xtx.wan2gp.output_dir"),
                profile = getOption("xtx.wan2gp.profile"),
                container = getOption("xtx.wan2gp.container"))

    if (!is.null(workspace)) {
        options(xtx.wan2gp.workspace = path.expand(workspace))
    }
    if (!is.null(cache)) {
        options(xtx.wan2gp.cache = path.expand(cache))
    }
    if (!is.null(output_dir)) {
        options(xtx.wan2gp.output_dir = path.expand(output_dir))
    }
    if (!is.null(profile)) {
        options(xtx.wan2gp.profile = as.integer(profile))
    }
    if (!is.null(container)) {
        options(xtx.wan2gp.container = container)
    }

    invisible(old)
}

#' Get WanGP Configuration
#' @keywords internal
.wan2gp_get_config <- function() {
    list(
         workspace = getOption("xtx.wan2gp.workspace", path.expand("~/Wan2GP")),
         cache = getOption("xtx.wan2gp.cache",
                           path.expand("~/.cache/huggingface")),
         output_dir = getOption("xtx.wan2gp.output_dir", getwd()),
         profile = getOption("xtx.wan2gp.profile", 4L),
         container = getOption("xtx.wan2gp.container", "wan2gp:blackwell")
    )
}

#' WanGP Model Definitions
#' @keywords internal
.wan2gp_models <- list(
                       ltx2 = list(
                                   model_type = "ltx2_19B",
                                   name = "LTX-2 Distilled 19B",
                                   architecture = "ltx2_19B",
                                   URLs = list("https://huggingface.co/DeepBeepMeep/LTX-2/resolve/main/ltx-2-19b-distilled_diffusion_model.safetensors"),
                                   preload_URLs = "ltx2_19B",
                                   ltx2_pipeline = "distilled",
                                   default_steps = 8L,
                                   default_guidance = 4.0,
                                   supports_audio = TRUE,
                                   supports_image = TRUE,
                                   supports_video = TRUE
    ),
                       hunyuan = list(model_type = "hunyuan_avatar", name = "Hunyuan Avatar 13B",
                                      architecture = "hunyuan_avatar", default_steps = 30L,
                                      default_guidance = 7.5, supports_audio = TRUE,
                                      supports_image = TRUE, supports_video = FALSE),
                       fantasy = list(
                                      model_type = "fantasy_talking",
                                      name = "Fantasy Talking 14B",
                                      architecture = "fantasy_talking",
                                      default_steps = 30L,
                                      default_guidance = 7.5,
                                      supports_audio = TRUE,
                                      supports_image = TRUE,
                                      supports_video = FALSE
    ),
                       vace = list(
                                   model_type = "vace_1.3B",
                                   name = "VACE 1.3B",
                                   architecture = "vace_1.3B",
                                   default_steps = 20L,
                                   default_guidance = 7.5,
                                   supports_audio = FALSE,
                                   supports_image = FALSE,
                                   supports_video = TRUE
    )
)

#' List Available WanGP Models
#'
#' Show available model types and their requirements.
#'
#' @return A data.frame with model information
#' @export
wan2gp_models <- function() {
    data.frame(
               id = c("ltx2", "hunyuan", "fantasy", "vace"),
               name = c("LTX-2 19B", "Hunyuan Avatar 13B", "Fantasy Talking 14B",
                        "VACE 1.3B"),
               vram_min = c(16, 24, 24, 12),
               speed = c("fast", "very slow", "very slow", "slow"),
               use_case = c(
                            "General video, talking heads",
                            "Talking heads (real faces)",
                            "Talking heads (stylized)",
                            "Motion transfer"
        ),
               supports_image = c(TRUE, TRUE, TRUE, FALSE),
               supports_audio = c(TRUE, TRUE, TRUE, FALSE),
               supports_video = c(TRUE, FALSE, FALSE, TRUE),
               stringsAsFactors = FALSE
    )
}

#' Internal WanGP Video Generation
#'
#' Low-level function to generate video via WanGP Docker container.
#' Use itv(), stv(), ttv(), or vtv() instead.
#'
#' @param prompt Text prompt
#' @param model Model ID: "ltx2", "hunyuan", "fantasy", "vace"
#' @param image Path to input image (optional)
#' @param audio Path to audio file (optional)
#' @param video Path to source video (optional, for vtv)
#' @param output Output file path
#' @param width Video width
#' @param height Video height
#' @param num_frames Number of frames
#' @param steps Inference steps (NULL = model default)
#' @param guidance_scale CFG scale (NULL = model default)
#' @param seed Random seed
#' @param timeout Timeout in seconds
#' @return Output file path
#' @keywords internal
.wan2gp_generate <- function(prompt, model = "ltx2", image = NULL,
                             audio = NULL, video = NULL, output = NULL,
                             width = 832L, height = 832L, num_frames = 129L,
                             steps = NULL, guidance_scale = NULL,
                             seed = NULL, timeout = 600) {
    # Validate model
    if (!model %in% names(.wan2gp_models)) {
        stop("Unknown model: ", model, ". Use one of: ",
             paste(names(.wan2gp_models), collapse = ", "), call. = FALSE)
    }
    model_def <- .wan2gp_models[[model]]

    # Use model defaults if not specified
    steps <- steps %||% model_def$default_steps
    guidance_scale <- guidance_scale %||% model_def$default_guidance

    cfg <- .wan2gp_get_config()

    # Validate inputs
    if (!is.null(image) && !file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }
    if (!is.null(audio) && !file.exists(audio)) {
        stop("Audio file not found: ", audio, call. = FALSE)
    }
    if (!is.null(video) && !file.exists(video)) {
        stop("Video file not found: ", video, call. = FALSE)
    }

    # Generate seed if not provided
    if (is.null(seed)) {
        seed <- sample.int(.Machine$integer.max, 1L)
    }

    # Generate output filename if not provided
    if (is.null(output)) {
        output <- file.path(cfg$output_dir, paste0("wan2gp_", model, "_", seed, ".mp4"))
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

    video_container_path <- NULL
    if (!is.null(video)) {
        video_basename <- basename(video)
        file.copy(video, file.path(input_dir, video_basename))
        video_container_path <- paste0("/input/", video_basename)
    }

    # Build config
    config <- .wan2gp_build_config(
                                   prompt = prompt,
                                   model_def = model_def,
                                   image_path = image_container_path,
                                   audio_path = audio_container_path,
                                   video_path = video_container_path,
                                   width = width,
                                   height = height,
                                   num_frames = num_frames,
                                   steps = steps,
                                   guidance_scale = guidance_scale,
                                   seed = seed
    )

    # Write config file
    config_file <- file.path(input_dir, "config.json")
    jsonlite::write_json(config, config_file, auto_unbox = TRUE, pretty = TRUE)

    # Build docker command
    cmd <- .wan2gp_build_docker_cmd(
                                    config_file = "/input/config.json",
                                    input_dir = input_dir,
                                    output_dir = cfg$output_dir,
                                    workspace = cfg$workspace,
                                    cache = cfg$cache,
                                    profile = cfg$profile,
                                    container = cfg$container
    )

    # Record start time to find new files
    start_time <- Sys.time()

    # Run docker
    message("Running WanGP (", model_def$name, ", ", num_frames, " frames)...")
    exit_code <- system(cmd, timeout = timeout)

    if (exit_code != 0) {
        stop("WanGP failed with exit code ", exit_code, call. = FALSE)
    }

    # Find output file
    output_files <- list.files(cfg$output_dir, pattern = "\\.mp4$", full.names = TRUE)
    file_info <- file.info(output_files)
    new_files <- output_files[file_info$mtime > start_time]

    if (length(new_files) == 0) {
        seed_pattern <- paste0("seed", seed)
        matching <- grep(seed_pattern, output_files, value = TRUE)
        if (length(matching) > 0) {
            new_files <- matching[order(file.info(matching)$mtime, decreasing = TRUE)]
        }
    }

    if (length(new_files) == 0) {
        stop("WanGP did not produce output. Check docker logs.", call. = FALSE)
    }

    # Sort by mtime descending to get the latest (concatenated) file
    new_files <- new_files[order(file.info(new_files)$mtime, decreasing = TRUE)]
    generated_file <- new_files[1]

    # Copy to requested output path
    if (!identical(normalizePath(generated_file, mustWork = FALSE),
                   normalizePath(output, mustWork = FALSE))) {
        file.copy(generated_file, output, overwrite = TRUE)
        message("Video saved to: ", output)
    } else {
        output <- generated_file
        message("Video saved to: ", output)
    }

    invisible(output)
}

#' Build WanGP Config
#' @keywords internal
.wan2gp_build_config <- function(prompt, model_def, image_path, audio_path,
                                 video_path, width, height, num_frames,
                                 steps, guidance_scale, seed) {
    config <- list(model_type = model_def$model_type, prompt = prompt,
                   num_inference_steps = as.integer(steps),
                   video_length = as.integer(num_frames),
                   guidance_scale = guidance_scale, width = as.integer(width),
                   height = as.integer(height), seed = as.integer(seed))

    # Add model-specific config for LTX-2
    if (model_def$model_type == "ltx2_19B") {
        config$model <- list(
                             name = model_def$name,
                             architecture = model_def$architecture,
                             URLs = model_def$URLs,
                             preload_URLs = model_def$preload_URLs,
                             ltx2_pipeline = model_def$ltx2_pipeline
        )
    }

    # Add image if provided
    if (!is.null(image_path)) {
        config$image_start <- image_path
        config$image_prompt_type <- "S"
    }

    # Add audio if provided
    if (!is.null(audio_path)) {
        config$audio_guide <- audio_path
        config$audio_prompt_type <- "AV"
    }

    # Add video if provided (for vtv/motion transfer)
    if (!is.null(video_path)) {
        config$video_source <- video_path
        config$image_prompt_type <- "V"
    }

    config
}

#' Build Docker Command
#' @keywords internal
.wan2gp_build_docker_cmd <- function(config_file, input_dir, output_dir,
                                     workspace, cache, profile, container) {
    volumes <- c(paste0("-v ", workspace, ":/workspace"),
                 paste0("-v ", cache, ":/home/user/.cache/huggingface"),
                 paste0("-v ", input_dir, ":/input"),
                 paste0("-v ", output_dir, ":/output"))

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

#' Check if WanGP is Available
#'
#' Check if the WanGP Docker container is available.
#'
#' @return TRUE if available, FALSE otherwise
#' @export
wan2gp_available <- function() {
    cfg <- .wan2gp_get_config()
    result <- tryCatch({
        exit_code <- system(paste("docker image inspect", cfg$container,
                                  "> /dev/null 2>&1"))
        exit_code == 0
    }, error = function(e) FALSE)
    result
}
