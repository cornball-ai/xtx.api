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
    stop(
      "STV API base URL not set. Use stv_base() to configure it.\n",
      "Example: stv_base(\"http://localhost:10364\")",
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
    err_msg <- .xtx_parse_error(response$content)
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
#' Supports multiple backends: SadTalker (default) or WanGP (Hunyuan/Fantasy/LTX-2).
#'
#' @param image Path to portrait image (PNG/JPG, front-facing) or base64 string
#' @param audio Path to speech audio file (WAV/MP3) or base64 string
#' @param output Path for output video file (default: "stv_output.mp4")
#' @param backend Backend to use: "sadtalker" (default) or "wan2gp"
#' @param model Model for wan2gp backend: "hunyuan" (real faces), "fantasy" (stylized),
#'   or "ltx2" (general). Ignored for sadtalker.
#' @param face_id Cached face ID for sadtalker (use instead of image for faster generation)
#' @param enhance Apply GFPGAN face enhancement (sadtalker only)
#' @param prompt Text prompt describing the scene (wan2gp only)
#' @param width Video width (wan2gp only, default: 832)
#' @param height Video height (wan2gp only, default: 832)
#' @param num_frames Number of frames (wan2gp only, default: 129)
#' @param seed Random seed (wan2gp only)
#' @param device Device to use: "cuda" or "cpu" (sadtalker only)
#' @param timeout Request timeout in seconds (default: 600)
#' @return Invisibly returns the output file path
#' @examples
#' \dontrun{
#'   # SadTalker (default, fastest for real faces)
#'   stv("portrait.jpg", "speech.wav", "talking.mp4")
#'
#'   # Hunyuan Avatar (better quality, slower, needs 24GB VRAM)
#'   stv("portrait.jpg", "speech.wav", backend = "wan2gp", model = "hunyuan")
#'
#'   # LTX-2 with audio guide (16GB VRAM, fast)
#'   stv("portrait.jpg", "speech.wav", backend = "wan2gp", model = "ltx2",
#'       prompt = "Person speaking into microphone")
#' }
#' @export
stv <- function(image = NULL, audio, output = "stv_output.mp4",
                backend = c("sadtalker", "wan2gp"),
                model = c("hunyuan", "fantasy", "ltx2"),
                face_id = NULL, enhance = FALSE,
                prompt = "Person speaking",
                width = 832L, height = 832L, num_frames = 129L,
                seed = NULL, device = "cuda", timeout = 600) {

  backend <- match.arg(backend)

  if (backend == "wan2gp") {
    # WanGP backend (Hunyuan/Fantasy/LTX-2)
    model <- match.arg(model)

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

  body <- list(
    image = image_b64,
    device = device
  )
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
    err_msg <- .xtx_parse_error(response$content)
    stop("STV API error (", response$status_code, "): ", err_msg, call. = FALSE)
  }

  jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}
