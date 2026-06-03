# Image-to-Video (ITV) functions using diffusers_api

#' Set Image-to-Video API Base URL
#'
#' Configure the base URL for the diffusers_api service (CogVideoX).
#'
#' @param url Base URL (e.g., "http://localhost:8000")
#' @return Invisibly returns the previous value
#' @examples
#' \dontrun{
#'   itv_base("http://localhost:8000")
#'   itv_base("http://gpu-server:8000")
#' }
#' @export
itv_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    old <- getOption("xtx.itv_base")
    options(xtx.itv_base = url)
    invisible(old)
}

#' Get ITV API Base URL
#' @keywords internal
.itv_get_base <- function() {
    base <- getOption("xtx.itv_base")
    if (is.null(base) || nchar(base) == 0) {
        stop("ITV API base URL not set. Use itv_base() to configure it.\n",
             "Example: itv_base(\"http://localhost:8000\")", call. = FALSE)
    }
    base
}

#' POST JSON to ITV API
#' @keywords internal
.itv_post_json <- function(endpoint, body, timeout = NULL) {
    base <- .itv_get_base()
    url <- paste0(base, endpoint)

    h <- curl::new_handle()
    timeout <- timeout %||% getOption("xtx.timeout", 600)
    curl::handle_setopt(h, timeout = timeout)
    curl::handle_setheaders(h, "Content-Type" = "application/json")

    json_body <- jsonlite::toJSON(body, auto_unbox = TRUE)
    curl::handle_setopt(h, post = TRUE, postfields = json_body)

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Connection failed: ", e$message, call. = FALSE)
    }
    )

    status <- response$status_code
    if (status >= 400) {
        err_msg <- .xtx_parse_error(response$content)
        stop("ITV API error (", status, "): ", err_msg, call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

#' Check Image-to-Video API Health
#'
#' Check the health status of the diffusers_api service.
#'
#' @return A list with status, device, and loaded models
#' @examples
#' \dontrun{
#'   itv_health()
#' }
#' @export
itv_health <- function() {
    base <- .itv_get_base()
    url <- paste0(base, "/health")

    h <- curl::new_handle()
    timeout <- getOption("xtx.timeout", 30)
    curl::handle_setopt(h, timeout = timeout)

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Connection failed: ", e$message, call. = FALSE)
    }
    )

    if (response$status_code >= 400) {
        stop("ITV API error (", response$status_code, ")", call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content))
}

#' Generate Video from Image (Image-to-Video)
#'
#' Generate a video from an input image and motion prompt.
#' Supports multiple backends: CogVideoX, WanGP, or fal.ai.
#'
#' @param image Path to starting frame image (PNG/JPG) or base64 string
#' @param prompt Motion/scene description
#' @param output Path for output video file (default: "itv_output.mp4")
#' @param backend Backend to use: "cogvideo" (default), "wan2gp" (Docker), "wan2gp_api" (HTTP), or "fal"
#' @param model Model ID. For cogvideo: "THUDM/CogVideoX-5b-I2V".
#'   For wan2gp: "ltx2" (default). For fal: "fal-ai/ltx-video" (default)
#' @param num_frames Number of frames to generate (default: 49 for cogvideo, 129 for wan2gp)
#' @param num_steps Number of inference steps (default varies by backend/model)
#' @param width Video width (wan2gp only, default: 832)
#' @param height Video height (wan2gp only, default: 832)
#' @param guidance_scale CFG scale (wan2gp only)
#' @param seed Random seed (wan2gp only)
#' @param timeout Request timeout in seconds (default: 900)
#' @return Invisibly returns the output file path
#' @param resolution Resolution for wan2gp_api: "480p" or "720p" (default: "720p")
#' @param quality Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")
#' @examples
#' \dontrun{
#'   # CogVideoX (default)
#'   itv("scene.jpg", "Camera slowly zooms in", "video.mp4")
#'
#'   # LTX-2 via WanGP API (recommended)
#'   wan2gp_api_base("http://localhost:8000")
#'   itv("scene.jpg", "Camera slowly zooms in, leaves rustling",
#'       backend = "wan2gp_api")
#'
#'   # LTX-2 via WanGP Docker (direct)
#'   itv("portrait.jpg", "Person talking and gesturing",
#'       backend = "wan2gp", model = "ltx2")
#' }
#' @export
itv <- function(image, prompt = "", output = "itv_output.mp4",
                backend = c("cogvideo", "wan2gp_api", "wan2gp", "fal"),
                model = NULL, num_frames = NULL, num_steps = NULL,
                width = 832L, height = 832L, resolution = "720p",
                quality = "balanced", guidance_scale = NULL, seed = NULL,
                timeout = 900) {
    backend <- match.arg(backend)

    if (backend == "wan2gp_api") {
        # WanGP FastAPI backend (LTX-2 via HTTP)
        if (!file.exists(image)) {
            stop("Image file not found: ", image, call. = FALSE)
        }
        num_frames <- num_frames %||% 97L

        .i2v_wan2gp_api(image = image, output = output, prompt = prompt,
                        num_frames = num_frames, resolution = resolution,
                        quality = quality, timeout = timeout)
    } else if (backend == "fal") {
        # fal.ai backend (LTX-2, etc.)
        .itv_fal(
                 image = image,
                 prompt = prompt,
                 output = output,
                 model = model,
                 timeout = timeout
        )
    } else if (backend == "wan2gp") {
        # WanGP backend (LTX-2)
        model <- model %||% "ltx2"
        num_frames <- num_frames %||% 129L

        .wan2gp_generate(
                         prompt = prompt,
                         model = model,
                         image = image,
                         output = output,
                         width = width,
                         height = height,
                         num_frames = num_frames,
                         steps = num_steps,
                         guidance_scale = guidance_scale,
                         seed = seed,
                         timeout = timeout
        )
    } else {
        # CogVideoX backend (default)
        model <- model %||% "THUDM/CogVideoX-5b-I2V"
        num_frames <- num_frames %||% 49L
        num_steps <- num_steps %||% 50L

        # Encode image
        if (file.exists(image)) {
            image_b64 <- base64enc::base64encode(image)
        } else if (grepl("^[A-Za-z0-9+/]", image) && nchar(image) > 100) {
            image_b64 <- image
        } else {
            stop("Image file not found: ", image, call. = FALSE)
        }

        # Build request body
        body <- list(
                     model_id = model,
                     image = image_b64,
                     prompt = prompt,
                     num_inference_steps = as.integer(num_steps),
                     num_frames = as.integer(num_frames)
        )

        # Make request
        result <- .itv_post_json("/image-to-video", body, timeout = timeout)

        # Decode and save video
        if (!is.null(result$video)) {
            video_bytes <- base64enc::base64decode(result$video)
            writeBin(video_bytes, output)
            message("ITV video saved to: ", output)
        }

        invisible(output)
    }
}

#' List Available Models
#'
#' List models available in the diffusers_api service.
#'
#' @return A list with downloaded and loaded models
#' @examples
#' \dontrun{
#'   itv_models()
#' }
#' @export
itv_models <- function() {
    base <- .itv_get_base()
    url <- paste0(base, "/models")

    h <- curl::new_handle()
    timeout <- getOption("xtx.timeout", 30)
    curl::handle_setopt(h, timeout = timeout)

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Connection failed: ", e$message, call. = FALSE)
    }
    )

    if (response$status_code >= 400) {
        stop("ITV API error (", response$status_code, ")", call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content))
}

#' Image-to-video via fal.ai
#' @keywords internal
.itv_fal <- function(image, prompt = "", output = "itv_output.mp4",
                     model = NULL, timeout = 600) {
    if (!.xtx_has_fal()) {
        stop("fal.api package is not installed.\n",
             "Install with: remotes::install_github(\"cornball-ai/fal.api\")",
             call. = FALSE)
    }

    # Default model
    model <- model %||% "fal-ai/ltx-video"

    # Call fal.api::fal_itv
    result <- fal.api::fal_itv(
                               image = image,
                               prompt = prompt,
                               model = model,
                               .timeout = timeout
    )

    # Save video to output file
    if (!is.null(result$video$url)) {
        video_response <- curl::curl_fetch_memory(result$video$url)
        writeBin(video_response$content, output)
        message("ITV video saved to: ", output)
    }

    invisible(output)
}

