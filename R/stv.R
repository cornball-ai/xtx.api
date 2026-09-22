# Speech-to-Video (STV) functions using faster-SadTalker-API

#' Set Speech-to-Video API Base URL
#'
#' Configure the base URL for the faster-SadTalker-API service.
#'
#' @param url Base URL (e.g., "http://localhost:10364")
#' @return Invisibly returns the previous value
#' @examples
#' \dontrun{
#'   stv_base("http://localhost:10364")
#'   stv_base("http://gpu-server:10364")
#' }
#' @export
stv_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    old <- getOption("xtx.stv_base")
    options(xtx.stv_base = url)
    invisible(old)
}

#' Get STV API Base URL
#' @keywords internal
.stv_get_base <- function() {
    base <- getOption("xtx.stv_base")
    if (is.null(base) || nchar(base) == 0) {
        stop("STV API base URL not set. Use stv_base() to configure it.\n",
             "Example: stv_base(\"http://localhost:10364\")", call. = FALSE)
    }
    base
}

#' Set WanGP API Base URL
#'
#' Configure the base URL for the WanGP FastAPI service.
#'
#' @param url Base URL (e.g., "http://localhost:8000")
#' @return Invisibly returns the previous value
#' @examples
#' \dontrun{
#'   wan2gp_api_base("http://localhost:8000")
#'   wan2gp_api_base("http://gpu-server:8000")
#' }
#' @export
wan2gp_api_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    old <- getOption("xtx.wan2gp_api_base")
    options(xtx.wan2gp_api_base = url)
    invisible(old)
}

#' Get WanGP API Base URL
#' @keywords internal
.wan2gp_api_get_base <- function() {
    base <- getOption("xtx.wan2gp_api_base")
    if (is.null(base) || nchar(base) == 0) {
        stop(
             "WanGP API base URL not set. Use wan2gp_api_base() to configure it.\n",
             "Example: wan2gp_api_base(\"http://localhost:8000\")",
             call. = FALSE
        )
    }
    base
}

#' POST JSON to STV API
#' @keywords internal
.stv_post_json <- function(endpoint, body, timeout = NULL) {
    base <- .stv_get_base()
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
        err_msg <- .parse_error(response$content)
        stop("STV API error (", status, "): ", err_msg, call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

#' Check Speech-to-Video API Health
#'
#' Check the health status of the faster-SadTalker-API service.
#'
#' @return A list with status, version, and cached face count
#' @examples
#' \dontrun{
#'   stv_health()
#' }
#' @export
stv_health <- function() {
    base <- .stv_get_base()
    url <- paste0(base, "/v1/health")

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
        stop("STV API error (", response$status_code, ")", call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content))
}

#' Check if SadTalker Service is Available
#'
#' Quick check if the SadTalker API is reachable and healthy.
#' Unlike stv_health(), this returns TRUE/FALSE and never throws errors.
#'
#' @param port Port to check (default from SADTALKER_PORT env var or 10364)
#' @param timeout Timeout in seconds (default 2)
#' @return TRUE if service is available, FALSE otherwise
#' @export
#' @examples
#' \dontrun{
#'   if (stv_available()) {
#'     stv("portrait.jpg", "speech.wav")
#'   }
#' }
stv_available <- function(port = NULL, timeout = 2) {
    if (is.null(port)) {
        port <- Sys.getenv("SADTALKER_PORT", "10364")
    }
    url <- paste0("http://localhost:", port, "/v1/health")

    tryCatch({
        h <- curl::new_handle()
        curl::handle_setopt(h, timeout = timeout)
        res <- curl::curl_fetch_memory(url, handle = h)
        res$status_code == 200

    }, error = function(e) FALSE)
}

#' Generate Talking Head Video (Speech-to-Video)
#'
#' Generate an audio-driven talking head video from a portrait image and audio.
#' Supports multiple backends: SadTalker (default), WanGP Docker, or WanGP API.
#'
#' @param image Path to portrait image (PNG/JPG, front-facing) or base64 string
#' @param audio Path to speech audio file (WAV/MP3) or base64 string
#' @param output Path for output video file (default: "stv_output.mp4")
#' @param backend Backend to use: "sadtalker" (default), "wan2gp" (Docker),
#'   "wan2gp_api" (HTTP API), "diffuseR" (LTX-2.3 in this process), or
#'   "gpuhost" (LTX-2.3 on the viento-managed gpu.ctl service, on ITS
#'   card rather than this one). For gpuhost set
#'   \code{options(xtx.gpuhost_base = "http://host:7878")}; the entry name is
#'   the endpoint's (\code{xtx.gpuhost_video_entry}, default
#'   \code{"ltx-2.3"}). Prefer it wherever a gpu.ctl host is resident: the
#'   in-process backend competes with it for the same device.
#' @param model Model for wan2gp backend: "hunyuan" (real faces), "fantasy" (stylized),
#'   or "ltx2" (general). Ignored for sadtalker.
#' @param face_id Cached face ID for sadtalker (use instead of image for faster generation)
#' @param enhance Apply GFPGAN face enhancement (sadtalker only)
#' @param prompt Text prompt describing the scene (wan2gp)
#' @param resolution Resolution for wan2gp_api: "480p" or "720p" (default: "720p")
#' @param quality Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")
#' @param width Video width (wan2gp Docker only, default: 832)
#' @param height Video height (wan2gp Docker only, default: 832)
#' @param num_frames Number of frames (wan2gp, default: 129)
#' @param num_inference_steps Number of inference steps (unused; reserved)
#' @param turbo_mode Use turbo mode for faster generation (unused; reserved)
#' @param seed Random seed (wan2gp only)
#' @param device Device to use: "cuda" or "cpu" (sadtalker only)
#' @param timeout Request timeout in seconds (default: 600)
#' @param sliding_window_size LTX-2 sliding-window size in frames
#'   (wan2gp_api only). Default 129 = ~5.4s at 24fps, LTX-2's native context.
#'   Must be 8n+1. `NULL` (default) defers to the server's configured default.
#' @param sliding_window_overlap Frames reused as motion conditioning between
#'   adjacent sliding windows (wan2gp_api only). Higher = smoother joins, more
#'   frames generated overall. `NULL` (default) defers to the server.
#' @param sliding_window_overlap_noise Noise injected into the overlap region,
#'   0-100 (wan2gp_api only). Lower = stricter continuity, can flicker if too
#'   strict. `NULL` (default) defers to the server.
#' @param sliding_window_discard_last_frames Frames trimmed off the end of each
#'   window before joining (wan2gp_api only). `NULL` (default) defers to the
#'   server.
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # SadTalker (default, fastest for real faces)
#'   stv("portrait.jpg", "speech.wav", "talking.mp4")
#'
#'   # Hunyuan Avatar via WanGP Docker (needs 24GB VRAM)
#'   stv("portrait.jpg", "speech.wav", backend = "wan2gp", model = "hunyuan")
#'
#'   # LTX-2 via WanGP API (remote server)
#'   wan2gp_api_base("http://gpu-server:8000")
#'   stv("portrait.jpg", "speech.wav", backend = "wan2gp_api",
#'       prompt = "Person speaking into microphone")
#' }
#' @export
stv <- function(image = NULL, audio, output = "stv_output.mp4",
                backend = c("sadtalker", "wan2gp", "wan2gp_api", "diffuseR", "gpuhost"),
                model = NULL, face_id = NULL, enhance = FALSE,
                prompt = "Person speaking naturally", resolution = "720p",
                quality = "balanced", width = 832L, height = 832L,
                num_frames = 129L, num_inference_steps = 30L,
                turbo_mode = TRUE, seed = NULL, device = "cuda",
                timeout = 600, sliding_window_size = NULL,
                sliding_window_overlap = NULL,
                sliding_window_overlap_noise = NULL,
                sliding_window_discard_last_frames = NULL) {
    .sidecar_arm(environment())
    backend <- match.arg(backend)

    if (backend == "diffuseR") {
        # Native in-process LTX-2.3 via diffuseR (no container)
        return(.stv_diffuseR(image = image, audio = audio, output = output,
                             prompt = prompt, resolution = resolution,
                             quality = quality, seed = seed))
    }

    if (backend == "gpuhost") {
        # The same LTX-2.3 contract, generated on the gpu.ctl host's card
        return(.stv_gpuhost(image = image, audio = audio, output = output,
                            prompt = prompt, resolution = resolution,
                            quality = quality, seed = seed,
                            timeout = timeout))
    }

    if (backend == "wan2gp_api") {
        # WanGP FastAPI backend (remote server via HTTP)
        if (is.null(image)) {
            stop("'image' is required for wan2gp_api backend", call. = FALSE)
        }

        .stv_wan2gp_api(
                        image = image,
                        audio = audio,
                        output = output,
                        prompt = prompt,
                        resolution = resolution,
                        quality = quality,
                        timeout = timeout,
                        sliding_window_size = sliding_window_size,
                        sliding_window_overlap = sliding_window_overlap,
                        sliding_window_overlap_noise = sliding_window_overlap_noise,
                        sliding_window_discard_last_frames = sliding_window_discard_last_frames
        )
    } else if (backend == "wan2gp") {
        # WanGP backend (Hunyuan/Fantasy/LTX-2)
        model <- model %||% "hunyuan"
        model <- match.arg(model, c("hunyuan", "fantasy", "ltx2"))

        if (is.null(image)) {
            stop("'image' is required for wan2gp backend", call. = FALSE)
        }

        .wan2gp_generate(
                         prompt = prompt,
                         model = model,
                         image = image,
                         audio = audio,
                         output = output,
                         width = width,
                         height = height,
                         num_frames = num_frames,
                         seed = seed,
                         timeout = timeout
        )
    } else {
        # SadTalker backend (default)

        # Validate inputs
        if (is.null(face_id) && is.null(image)) {
            stop("Either 'image' or 'face_id' must be provided", call. = FALSE)
        }

        # Acquire GPU for sadtalker service
        .gpuctl_acquire("sadtalker")

        # Encode audio
        if (file.exists(audio)) {
            audio_b64 <- base64enc::base64encode(audio)
        } else if (grepl("^[A-Za-z0-9+/]", audio) && nchar(audio) > 100) {
            audio_b64 <- audio
        } else {
            stop("Audio file not found: ", audio, call. = FALSE)
        }

        # Build request body
        body <- list(
                     model = "sadtalker-v1",
                     audio = audio_b64,
                     enhance = enhance,
                     device = device,
                     response_format = "b64_json"
        )

        if (!is.null(face_id)) {
            body$face_id <- face_id
        } else {
            # Encode image
            if (file.exists(image)) {
                body$source_image <- base64enc::base64encode(image)
            } else if (grepl("^[A-Za-z0-9+/]", image) && nchar(image) > 100) {
                body$source_image <- image
            } else {
                stop("Image file not found: ", image, call. = FALSE)
            }
        }

        # Make request
        result <- .stv_post_json("/v1/video/generations", body, timeout = timeout)

        # Decode and save video
        if (!is.null(result$data) && length(result$data) > 0) {
            video_b64 <- result$data[[1]]$b64_json
            if (!is.null(video_b64)) {
                video_bytes <- base64enc::base64decode(video_b64)
                writeBin(video_bytes, output)
                message("STV video saved to: ", output)
            }
        }

        invisible(output)
    }
}

#' Create Cached Face for STV
#'
#' Preprocess and cache a face image for faster video generation.
#' Subsequent calls to stv() with this face_id will be faster.
#'
#' @param image Path to portrait image (PNG/JPG)
#' @param name Optional name for the face
#' @param device Device for preprocessing: "cuda" or "cpu"
#' @return A list with face id and metadata
#' @examples
#' \dontrun{
#'   face <- stv_face_create("portrait.jpg", name = "host")
#'   stv(face_id = face$id, audio = "speech.wav")
#' }
#' @export
stv_face_create <- function(image, name = NULL, device = "cuda") {
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }

    image_b64 <- base64enc::base64encode(image)

    body <- list(image = image_b64, device = device)
    if (!is.null(name)) {
        body$name <- name
    }

    .stv_post_json("/v1/faces", body)
}

#' List Cached Faces
#'
#' List all cached faces in the STV service.
#'
#' @return A list with face information
#' @examples
#' \dontrun{
#'   stv_face_list()
#' }
#' @export
stv_face_list <- function() {
    base <- .stv_get_base()
    url <- paste0(base, "/v1/faces")

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
        stop("STV API error (", response$status_code, ")", call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

#' Delete Cached Face
#'
#' Delete a cached face from the STV service.
#'
#' @param face_id The face ID to delete
#' @return A list with deletion confirmation
#' @examples
#' \dontrun{
#'   stv_face_delete("face-abc123")
#' }
#' @export
stv_face_delete <- function(face_id) {
    base <- .stv_get_base()
    url <- paste0(base, "/v1/faces/", face_id)

    h <- curl::new_handle()
    timeout <- getOption("xtx.timeout", 30)
    curl::handle_setopt(h, customrequest = "DELETE", timeout = timeout)

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Connection failed: ", e$message, call. = FALSE)
    }
    )

    if (response$status_code >= 400) {
        err_msg <- .parse_error(response$content)
        stop("STV API error (", response$status_code, "): ", err_msg,
             call. = FALSE)
    }

    jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

#' Speech-to-video via WanGP API
#'
#' Internal function to generate video using the WanGP FastAPI server.
#' Sends image and audio as multipart/form-data.
#'
#' @keywords internal
.stv_wan2gp_api <- function(image, audio, output = "stv_output.mp4",
                            prompt = "Person speaking naturally, clear speech, facing camera",
                            resolution = "720p", quality = "balanced",
                            timeout = 600, sliding_window_size = NULL,
                            sliding_window_overlap = NULL,
                            sliding_window_overlap_noise = NULL,
                            sliding_window_discard_last_frames = NULL) {
    base <- .wan2gp_api_get_base()
    url <- paste0(base, "/avatar")

    # Validate input files
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }
    if (!file.exists(audio)) {
        stop("Audio file not found: ", audio, call. = FALSE)
    }

    # Build multipart form
    h <- curl::new_handle()
    curl::handle_setopt(h,
                        timeout = timeout,
                        low_speed_time = 0, # Disable low-speed timeout (quality mode is slow)
                        low_speed_limit = 0
    )

    form_args <- list(image = curl::form_file(image),
                      audio = curl::form_file(audio), prompt = prompt,
                      resolution = resolution, quality = quality)
    # Forward sliding-window overrides only when provided; otherwise the server
    # picks its own DEFAULT_SLIDING_WINDOW_* values.
    if (!is.null(sliding_window_size)) {
        form_args$sliding_window_size <- as.character(sliding_window_size)
    }
    if (!is.null(sliding_window_overlap)) {
        form_args$sliding_window_overlap <- as.character(sliding_window_overlap)
    }
    if (!is.null(sliding_window_overlap_noise)) {
        form_args$sliding_window_overlap_noise <- as.character(sliding_window_overlap_noise)
    }
    if (!is.null(sliding_window_discard_last_frames)) {
        form_args$sliding_window_discard_last_frames <- as.character(sliding_window_discard_last_frames)
    }
    do.call(curl::handle_setform, c(list(h), form_args))

    message("Calling WanGP API (LTX-2) for avatar generation...")

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
    message("STV video saved to: ", output)

    invisible(output)
}

#' Image-to-video via WanGP API (without audio)
#'
#' Internal function for i2v endpoint. Uses LTX-2 19B.
#'
#' @keywords internal
.i2v_wan2gp_api <- function(image, output = "i2v_output.mp4",
                            prompt = "Camera slowly zooms in",
                            num_frames = 97L, resolution = "720p",
                            quality = "balanced", timeout = 600) {
    base <- .wan2gp_api_get_base()
    url <- paste0(base, "/i2v")

    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }

    h <- curl::new_handle()
    curl::handle_setopt(h, timeout = timeout, low_speed_time = 0,
                        low_speed_limit = 0) # Disable low-speed timeout (quality mode is slow)

    curl::handle_setform(h, image = curl::form_file(image), prompt = prompt,
                         num_frames = as.character(num_frames),
                         resolution = resolution, quality = quality)

    message("Calling WanGP API (LTX-2) for i2v generation...")

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
    message("I2V video saved to: ", output)

    invisible(output)
}

#' Text-to-video via WanGP API
#'
#' Extract an error message from a WanGP API response body.
#'
#' The API reports errors as JSON \code{{detail: {error, message}}}; fall
#' back to the raw text when it is not JSON.
#' @keywords internal
.wan2gp_api_error_message <- function(content) {
    txt <- tryCatch(rawToChar(content), error = function(e) "")
    tryCatch({
        parsed <- jsonlite::fromJSON(txt)
        parsed$detail$message %||% parsed$detail %||% parsed$error %||% txt
    }, error = function(e) txt)
}

#' GET a URL from the WanGP API, stopping on a connection failure.
#' @keywords internal
.wan2gp_api_get <- function(url, timeout = 30) {
    h <- curl::new_handle()
    curl::handle_setopt(h, timeout = timeout)
    tryCatch(
        curl::curl_fetch_memory(url, handle = h),
        error = function(e) stop("Connection to WanGP API failed: ",
                                 e$message, call. = FALSE)
    )
}

#' POST a JSON body to the WanGP API, stopping on a connection failure.
#' @keywords internal
.wan2gp_api_post_json <- function(url, body, timeout = 60) {
    h <- curl::new_handle()
    curl::handle_setheaders(h, "Content-Type" = "application/json")
    curl::handle_setopt(h, post = TRUE, postfields = body, timeout = timeout)
    tryCatch(
        curl::curl_fetch_memory(url, handle = h),
        error = function(e) stop("Connection to WanGP API failed: ",
                                 e$message, call. = FALSE)
    )
}

#' Internal function for the t2v endpoint. Uses LTX-2.
#'
#' Generation holds the GPU for minutes, so the API is a job: create it,
#' poll until it is done, then download the file. \code{timeout} is the
#' whole budget for the job to complete, not a single request.
#' @keywords internal
.t2v_wan2gp_api <- function(prompt, output = "t2v_output.mp4",
                            num_frames = 97L, resolution = "720p",
                            quality = "balanced", timeout = 600,
                            poll_interval = 2) {
    base <- .wan2gp_api_get_base()

    # 1. Create the job. The API answers at once with an id and a status;
    #    it does not hold the connection open for the generation.
    body <- jsonlite::toJSON(
        list(prompt = prompt, num_frames = num_frames,
             resolution = resolution, quality = quality),
        auto_unbox = TRUE
    )
    message("Requesting WanGP API (LTX-2) t2v generation...")
    created <- .wan2gp_api_post_json(paste0(base, "/v1/videos"), body)
    if (created$status_code >= 400) {
        stop("WanGP API error (", created$status_code, "): ",
             .wan2gp_api_error_message(created$content), call. = FALSE)
    }
    job_id <- jsonlite::fromJSON(rawToChar(created$content))$id
    if (is.null(job_id) || !nzchar(job_id)) {
        stop("WanGP API did not return a job id.", call. = FALSE)
    }

    # 2. Poll until the job settles or the budget runs out.
    status_url <- paste0(base, "/v1/videos/", job_id)
    deadline <- Sys.time() + timeout
    repeat {
        poll <- .wan2gp_api_get(status_url, timeout = 30)
        if (poll$status_code >= 400) {
            stop("WanGP API error (", poll$status_code, "): ",
                 .wan2gp_api_error_message(poll$content), call. = FALSE)
        }
        state <- jsonlite::fromJSON(rawToChar(poll$content))
        if (identical(state$status, "completed")) break
        if (identical(state$status, "failed")) {
            stop("WanGP API generation failed: ",
                 state$error$message %||% "unknown error", call. = FALSE)
        }
        if (Sys.time() > deadline) {
            stop("WanGP API t2v timed out after ", timeout, "s (job ",
                 job_id, " still ", state$status %||% "unknown", ").",
                 call. = FALSE)
        }
        Sys.sleep(poll_interval)
    }

    # 3. Download the finished mp4.
    dl <- .wan2gp_api_get(paste0(base, "/v1/videos/", job_id, "/content"),
                          timeout = 120)
    if (dl$status_code >= 400) {
        stop("WanGP API error (", dl$status_code, "): ",
             .wan2gp_api_error_message(dl$content), call. = FALSE)
    }
    writeBin(dl$content, output)
    message("T2V video saved to: ", output)

    invisible(output)
}

#' Check if WanGP API is available
#'
#' @return TRUE if the WanGP API is reachable, FALSE otherwise
#' @export
wan2gp_api_available <- function() {
    base <- tryCatch(.wan2gp_api_get_base(), error = function(e) NULL)
    if (is.null(base)) {
        return(FALSE)
    }

    url <- paste0(base, "/health")
    tryCatch({
        h <- curl::new_handle()
        curl::handle_setopt(h, timeout = 5)
        res <- curl::curl_fetch_memory(url, handle = h)
        res$status_code == 200
    }, error = function(e) FALSE)
}
