#' Generate Image from Text
#'
#' Generate an image from a text prompt using DALL-E or compatible API.
#'
#' @param prompt Character. The text description of the image to generate.
#' @param model Character. The model to use. Options: "dall-e-3", "dall-e-2".
#'   Default is "dall-e-3".
#' @param size Character. Image dimensions. For DALL-E 3: "1024x1024",
#'   "1024x1792", "1792x1024". For DALL-E 2: "256x256", "512x512", "1024x1024".
#' @param quality Character. Image quality. "standard" or "hd" (DALL-E 3 only).
#' @param style Character. Image style. "vivid" or "natural" (DALL-E 3 only).
#' @param n Integer. Number of images to generate (1 for DALL-E 3, 1-10 for DALL-E 2).
#' @param response_format Character. "url" or "b64_json". Default is "url".
#' @param file Character or NULL. If provided, save the image to this path.
#'
#' @return A list containing:
#'   \item{url}{The URL of the generated image (if response_format = "url")}
#'   \item{b64_json}{Base64-encoded image data (if response_format = "b64_json")}
#'   \item{revised_prompt}{The prompt after DALL-E 3 revision (if applicable)}
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#'
#' # Generate an image
#' result <- xtx_txt2img("A white cat sitting on a windowsill")
#' browseURL(result$data[[1]]$url)
#'
#' # Generate and save to file
#' xtx_txt2img("A sunset over mountains", file = "sunset.png")
#' }
#'
#' @export
xtx_txt2img <- function(prompt,
                        model = "dall-e-3",
                        size = "1024x1024",
                        quality = "standard",
                        style = "vivid",
                        n = 1,
                        response_format = "url",
                        file = NULL) {

  # Validate prompt
  if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
    stop("'prompt' must be a non-empty character string", call. = FALSE)
  }

  # Validate model
  model <- match.arg(model, c("dall-e-3", "dall-e-2"))

  # Validate size based on model
  valid_sizes_dalle3 <- c("1024x1024", "1024x1792", "1792x1024")
  valid_sizes_dalle2 <- c("256x256", "512x512", "1024x1024")

  if (model == "dall-e-3" && !size %in% valid_sizes_dalle3) {
    stop("For DALL-E 3, size must be one of: ",
         paste(valid_sizes_dalle3, collapse = ", "), call. = FALSE)
  }
  if (model == "dall-e-2" && !size %in% valid_sizes_dalle2) {
    stop("For DALL-E 2, size must be one of: ",
         paste(valid_sizes_dalle2, collapse = ", "), call. = FALSE)
  }

  # Build request body
  body <- list(
    model = model,
    prompt = prompt,
    n = as.integer(n),
    size = size,
    response_format = response_format
  )

  # DALL-E 3 specific parameters
  if (model == "dall-e-3") {
    body$quality <- match.arg(quality, c("standard", "hd"))
    body$style <- match.arg(style, c("vivid", "natural"))
    if (n != 1) {
      warning("DALL-E 3 only supports n=1, ignoring n parameter", call. = FALSE)
      body$n <- 1L
    }
  }

  # Make request
  result <- .xtx_post_json("/v1/images/generations", body)

  # Save to file if requested
  if (!is.null(file) && length(result$data) > 0) {
    .xtx_save_image(result$data[[1]], file, response_format)
  }

  result
}

#' Save image from API response
#' @keywords internal
.xtx_save_image <- function(image_data, file, response_format) {
  if (response_format == "url" && !is.null(image_data$url)) {
    # Download from URL
    tryCatch({
      h <- curl::new_handle()
      curl::handle_setopt(h, timeout = .xtx_get_timeout())
      response <- curl::curl_fetch_memory(image_data$url, handle = h)
      if (response$status_code == 200) {
        writeBin(response$content, file)
        message("Image saved to: ", file)
      } else {
        warning("Failed to download image: HTTP ", response$status_code, call. = FALSE)
      }
    }, error = function(e) {
      warning("Failed to save image: ", e$message, call. = FALSE)
    })
  } else if (response_format == "b64_json" && !is.null(image_data$b64_json)) {
    # Decode base64
    tryCatch({
      img_bytes <- jsonlite::base64_dec(image_data$b64_json)
      writeBin(img_bytes, file)
      message("Image saved to: ", file)
    }, error = function(e) {
      warning("Failed to save image: ", e$message, call. = FALSE)
    })
  }
  invisible(file)
}
