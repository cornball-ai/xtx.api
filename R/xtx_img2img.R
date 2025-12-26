#' Edit Image with Text Prompt
#'
#' Edit an existing image using a text prompt and optional mask.
#' Uses the DALL-E 2 edits endpoint.
#'
#' @param image Character. Path to the input image file (PNG, max 4MB, square).
#' @param prompt Character. The text description of the desired edit.
#' @param mask Character or NULL. Path to mask image where transparent areas
#'   indicate where to edit. Must be same size as input image.
#' @param model Character. The model to use. Currently only "dall-e-2" supported.
#' @param size Character. Output size: "256x256", "512x512", or "1024x1024".
#' @param n Integer. Number of images to generate (1-10).
#' @param response_format Character. "url" or "b64_json".
#' @param file Character or NULL. If provided, save the first result to this path.
#'
#' @return A list containing the generated image data.
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#'
#' # Edit an image
#' result <- xtx_img_edit(
#'   image = "photo.png",
#'   prompt = "Add a red hat to the person",
#'   mask = "mask.png"
#' )
#' }
#'
#' @export
xtx_img_edit <- function(image,
                         prompt,
                         mask = NULL,
                         model = "dall-e-2",
                         size = "1024x1024",
                         n = 1,
                         response_format = "url",
                         file = NULL) {

  # Validate inputs
  if (!file.exists(image)) {
    stop("Image file not found: ", image, call. = FALSE)
  }
  if (!is.null(mask) && !file.exists(mask)) {
    stop("Mask file not found: ", mask, call. = FALSE)
  }
  if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
    stop("'prompt' must be a non-empty character string", call. = FALSE)
  }

  # Validate size
  valid_sizes <- c("256x256", "512x512", "1024x1024")
  if (!size %in% valid_sizes) {
    stop("size must be one of: ", paste(valid_sizes, collapse = ", "), call. = FALSE)
  }

  # Build form data
  form_data <- list(
    image = curl::form_file(image, type = "image/png"),
    prompt = prompt,
    model = model,
    n = as.character(as.integer(n)),
    size = size,
    response_format = response_format
  )

  if (!is.null(mask)) {
    form_data$mask <- curl::form_file(mask, type = "image/png")
  }

  # Make request
  result <- .xtx_post_multipart("/v1/images/edits", form_data)

  # Save to file if requested
  if (!is.null(file) && length(result$data) > 0) {
    .xtx_save_image(result$data[[1]], file, response_format)
  }

  result
}

#' Create Image Variations
#'
#' Generate variations of an existing image using DALL-E 2.
#'
#' @param image Character. Path to the input image file (PNG, max 4MB, square).
#' @param model Character. The model to use. Currently only "dall-e-2" supported.
#' @param size Character. Output size: "256x256", "512x512", or "1024x1024".
#' @param n Integer. Number of variations to generate (1-10).
#' @param response_format Character. "url" or "b64_json".
#' @param file Character or NULL. If provided, save the first result to this path.
#'
#' @return A list containing the generated image data.
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#'
#' # Create variations
#' result <- xtx_img_variation("photo.png", n = 3)
#' }
#'
#' @export
xtx_img_variation <- function(image,
                              model = "dall-e-2",
                              size = "1024x1024",
                              n = 1,
                              response_format = "url",
                              file = NULL) {

  # Validate inputs
  if (!file.exists(image)) {
    stop("Image file not found: ", image, call. = FALSE)
  }

  # Validate size
  valid_sizes <- c("256x256", "512x512", "1024x1024")
  if (!size %in% valid_sizes) {
    stop("size must be one of: ", paste(valid_sizes, collapse = ", "), call. = FALSE)
  }

  # Build form data
  form_data <- list(
    image = curl::form_file(image, type = "image/png"),
    model = model,
    n = as.character(as.integer(n)),
    size = size,
    response_format = response_format
  )

  # Make request
  result <- .xtx_post_multipart("/v1/images/variations", form_data)

  # Save to file if requested
  if (!is.null(file) && length(result$data) > 0) {
    .xtx_save_image(result$data[[1]], file, response_format)
  }

  result
}
