# IP-Adapter functions for face/style consistency with single reference image

#' Generate Image with IP-Adapter
#'
#' Generate an image using IP-Adapter with a reference image for face or style
#' consistency. This is ideal when you only have 1-2 reference images and don't
#' want to train a LoRA.
#'
#' @param prompt Character. The text description of the image to generate.
#' @param reference_image Character. Path to reference image file OR base64 string.
#' @param ip_adapter_type Character. Type of IP-Adapter to use:
#'   - "standard": Basic style/content transfer
#'   - "plus": Better detail preservation (ViT-H encoder)
#'   - "face": Face generation using CLIP (good for faces)
#'   - "faceid": Uses InsightFace embeddings (best for face accuracy)
#'   - "faceid-plus": Combines FaceID + CLIP (best quality faces)
#' @param model Character. Base model to use. Default "stabilityai/stable-diffusion-xl-base-1.0".
#' @param ip_adapter_scale Numeric. Influence of reference image (0-1). Default 0.6.
#' @param negative_prompt Character. What to avoid in the image.
#' @param steps Integer. Number of inference steps. Default 30.
#' @param guidance_scale Numeric. CFG scale. Default 7.5.
#' @param width Integer. Output image width. Default 1024.
#' @param height Integer. Output image height. Default 1024.
#' @param file Character or NULL. If provided, save the image to this path.
#' @param timeout Numeric. Request timeout in seconds. Default 300.
#'
#' @return A list with the generated image data, or invisibly returns the file path
#'   if `file` is specified.
#'
#' @examples
#' \dontrun{
#' # Face consistency with single reference photo
#' tti_base("http://localhost:8000")
#' ip_adapter(
#'   prompt = "A photo of a man as an astronaut on the moon",
#'   reference_image = "face_photo.jpg",
#'   ip_adapter_type = "faceid",
#'   file = "astronaut.png"
#' )
#'
#' # Style transfer
#' ip_adapter(
#'   prompt = "A cat sitting on a windowsill",
#'   reference_image = "painting_style.jpg",
#'   ip_adapter_type = "standard",
#'   ip_adapter_scale = 0.8,
#'   file = "styled_cat.png"
#' )
#'
#' # Best face quality with FaceID Plus
#' ip_adapter(
#'   prompt = "Portrait photo, professional lighting, studio background",
#'   reference_image = "my_face.jpg",
#'   ip_adapter_type = "faceid-plus",
#'   ip_adapter_scale = 0.7,
#'   file = "portrait.png"
#' )
#' }
#'
#' @export
ip_adapter <- function(
  prompt,
  reference_image,
  ip_adapter_type = c("faceid", "faceid-plus", "face", "plus", "standard"),
  model = "stabilityai/stable-diffusion-xl-base-1.0",
  ip_adapter_scale = 0.6,
  negative_prompt = "lowres, bad anatomy, worst quality, low quality",
  steps = 30,
  guidance_scale = 7.5,
  width = 1024,
  height = 1024,
  file = NULL,
  timeout = 300
) {

  if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
    stop("'prompt' must be a non-empty character string", call. = FALSE)
  }

  ip_adapter_type <- match.arg(ip_adapter_type)

  # Acquire GPU if gpuctl integration is enabled
  .gpuctl_acquire("diffusers")

  # Convert reference image to base64
  ref_b64 <- .image_to_base64(reference_image)

  # Make API request
  .ip_adapter_api(
    prompt = prompt,
    reference_image = ref_b64,
    ip_adapter_type = ip_adapter_type,
    model = model,
    ip_adapter_scale = ip_adapter_scale,
    negative_prompt = negative_prompt,
    steps = steps,
    guidance_scale = guidance_scale,
    width = width,
    height = height,
    file = file,
    timeout = timeout
  )
}

#' List Available IP-Adapter Types
#'
#' Get information about available IP-Adapter types and recommendations.
#'
#' @return A list with available types and recommendations.
#'
#' @examples
#' \dontrun{
#' tti_base("http://localhost:8000")
#' ip_adapter_types()
#' }
#'
#' @export
ip_adapter_types <- function() {
  base <- .tti_get_base()
  url <- paste0(base, "/ip-adapter/types")

  h <- curl::new_handle()
  curl::handle_setopt(h, timeout = 30)

  response <- tryCatch(
    curl::curl_fetch_memory(url, handle = h),
    error = function(e) stop("Connection failed: ", e$message, call. = FALSE)
  )

  if (response$status_code != 200) {
    stop("Failed to get IP-Adapter types: ", rawToChar(response$content), call. = FALSE)
  }

  jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

#' @keywords internal
.image_to_base64 <- function(image) {
  # If already base64 (no file extension, long string), return as-is

  if (is.character(image) && nchar(image) > 500 && !grepl("\\.[a-zA-Z]+$", image)) {
    return(image)
  }

  # Otherwise, read file and convert
  if (!file.exists(image)) {
    stop("Reference image file not found: ", image, call. = FALSE)
  }

  raw_data <- readBin(image, "raw", file.info(image)$size)
  base64enc::base64encode(raw_data)
}

#' @keywords internal
.ip_adapter_api <- function(
  prompt,
  reference_image,
  ip_adapter_type,
  model,
  ip_adapter_scale,
  negative_prompt,
  steps,
  guidance_scale,
  width,
  height,
  file,
  timeout
) {

  base <- .tti_get_base()
  url <- paste0(base, "/ip-adapter")

  body <- list(
    model_id = model,
    prompt = prompt,
    negative_prompt = negative_prompt,
    reference_image = reference_image,
    ip_adapter_type = ip_adapter_type,
    ip_adapter_scale = ip_adapter_scale,
    num_inference_steps = as.integer(steps),
    guidance_scale = guidance_scale,
    width = as.integer(width),
    height = as.integer(height)
  )

  h <- curl::new_handle()
  curl::handle_setopt(h, timeout = timeout, post = TRUE,
    postfields = jsonlite::toJSON(body, auto_unbox = TRUE))
  curl::handle_setheaders(h, "Content-Type" = "application/json")

  response <- tryCatch(
    curl::curl_fetch_memory(url, handle = h),
    error = function(e) stop("Connection failed: ", e$message, call. = FALSE)
  )

  if (response$status_code != 200) {
    err_msg <- tryCatch({
        err <- jsonlite::fromJSON(rawToChar(response$content))
        if (!is.null(err$detail)) err$detail else rawToChar(response$content)
      }, error = function(e) rawToChar(response$content))
    stop("IP-Adapter generation failed: ", err_msg, call. = FALSE)
  }

  result <- jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)

  # Save to file if requested
  if (!is.null(file)) {
    img_raw <- base64enc::base64decode(result$image)
    writeBin(img_raw, file)
    message("Image saved to: ", file)
    return(invisible(file))
  }

  result
}

#' IP-Adapter for Face Consistency (Convenience Function)
#'
#' Shortcut for generating face-consistent images using FaceID.
#' Uses sensible defaults optimized for face generation.
#'
#' @param prompt Character. What the person should be doing/wearing/where.
#' @param face_image Character. Path to a clear face photo.
#' @param file Character. Output file path.
#' @param scale Numeric. Face similarity strength (0-1). Default 0.6.
#'   Higher = more similar but less prompt adherence.
#' @param ... Additional arguments passed to ip_adapter().
#'
#' @return Invisibly returns the file path.
#'
#' @examples
#' \dontrun{
#' # Generate person as astronaut
#' ip_adapter_face(
#'   prompt = "Professional photo of a person as an astronaut, NASA suit, space background",
#'   face_image = "my_face.jpg",
#'   file = "me_astronaut.png"
#' )
#'
#' # Generate person in different style
#' ip_adapter_face(
#'   prompt = "Oil painting portrait, renaissance style, dramatic lighting",
#'   face_image = "my_face.jpg",
#'   file = "me_renaissance.png",
#'   scale = 0.5  # Lower scale for more style influence
#' )
#' }
#'
#' @export
ip_adapter_face <- function(
  prompt,
  face_image,
  file,
  scale = 0.6,
  ...
) {
  ip_adapter(
    prompt = prompt,
    reference_image = face_image,
    ip_adapter_type = "faceid",
    ip_adapter_scale = scale,
    file = file,
    ...
  )
}

#' IP-Adapter for Style Transfer (Convenience Function)
#'
#' Shortcut for style transfer using IP-Adapter Plus.
#'
#' @param prompt Character. What to generate.
#' @param style_image Character. Path to style reference image.
#' @param file Character. Output file path.
#' @param scale Numeric. Style strength (0-1). Default 0.8.
#' @param ... Additional arguments passed to ip_adapter().
#'
#' @return Invisibly returns the file path.
#'
#' @examples
#' \dontrun{
#' ip_adapter_style(
#'   prompt = "A mountain landscape at sunset",
#'   style_image = "van_gogh_starry_night.jpg",
#'   file = "mountain_vangogh.png"
#' )
#' }
#'
#' @export
ip_adapter_style <- function(
  prompt,
  style_image,
  file,
  scale = 0.8,
  ...
) {
  ip_adapter(
    prompt = prompt,
    reference_image = style_image,
    ip_adapter_type = "plus",
    ip_adapter_scale = scale,
    file = file,
    ...
  )
}

