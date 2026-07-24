#' Edit Image with Text Prompt
#'
#' Edit an existing image using a text prompt. Uses DALL-E 2 edits endpoint
#' for OpenAI backend, or diffuseR img2img for local models.
#'
#' @param image Character. Path to the input image file.
#' @param prompt Character. The text description of the desired edit/transformation.
#' @param backend Character. Which backend to use: "openai" or "diffuser".
#' @param model Character. Model to use. For OpenAI: "dall-e-2".
#'   For diffuseR: "sd21", "sdxl".
#' @param mask Character or NULL. Path to mask image (OpenAI only).
#'   Transparent areas indicate where to edit.
#' @param negative_prompt Character or NULL. Negative prompt (diffuseR only).
#' @param size Character. Output size. For OpenAI: "256x256", "512x512", "1024x1024".
#'   For diffuseR: "512x512", "768x768", "1024x1024".
#' @param strength Numeric. Transformation strength 0-1 (diffuseR only). Default 0.8.
#' @param steps Integer. Number of inference steps (diffuseR only). Default 50.
#' @param guidance_scale Numeric. CFG scale (diffuseR only). Default 7.5.
#' @param seed Integer or NULL. Random seed (diffuseR only).
#' @param devices Character or list. Device configuration (diffuseR only).
#' @param n Integer. Number of images to generate (OpenAI only).
#' @param response_format Character. "url" or "b64_json" (OpenAI only).
#' @param file Character or NULL. If provided, save the first result to this path.
#'
#' @return A list containing the generated image data.
#'
#' @examples
#' \dontrun{
#' # OpenAI edit with mask
#' result <- img_edit(
#'   image = "photo.png",
#'   prompt = "Add a red hat",
#'   mask = "mask.png"
#' )
#'
#' # diffuseR img2img
#' result <- img_edit(
#'   image = "photo.png",
#'   prompt = "Make it look like a painting",
#'   backend = "diffuser",
#'   strength = 0.7
#' )
#' }
#'
#' @export
img_edit <- function(image, prompt, backend = c("openai", "diffuser"),
                         model = NULL, mask = NULL, negative_prompt = NULL,
                         size = "1024x1024", strength = 0.8, steps = 50,
                         guidance_scale = 7.5, seed = NULL, devices = "cpu",
                         n = 1, response_format = "url", file = NULL) {
    .sidecar_arm(environment(), "file")
    # Validate inputs
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }
    if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
        stop("'prompt' must be a non-empty character string", call. = FALSE)
    }

    backend <- match.arg(backend)

    if (backend == "diffuser") {
        .img_edit_diffuser(image = image, prompt = prompt, model = model,
                               negative_prompt = negative_prompt, size = size,
                               strength = strength, steps = steps,
                               guidance_scale = guidance_scale, seed = seed,
                               devices = devices, file = file)
    } else {
        .img_edit_openai(
                             image = image,
                             prompt = prompt,
                             model = model,
                             mask = mask,
                             size = size,
                             n = n,
                             response_format = response_format,
                             file = file
        )
    }
}

#' Image edit via OpenAI DALL-E
#' @keywords internal
.img_edit_openai <- function(image, prompt, model = NULL, mask = NULL,
                                 size = "1024x1024", n = 1,
                                 response_format = "url", file = NULL) {
    if (!is.null(mask) && !file.exists(mask)) {
        stop("Mask file not found: ", mask, call. = FALSE)
    }

    model <- model %||% "dall-e-2"

    # Validate size
    valid_sizes <- c("256x256", "512x512", "1024x1024")
    if (!size %in% valid_sizes) {
        stop("size must be one of: ", paste(valid_sizes, collapse = ", "),
             call. = FALSE)
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
    result <- .post_multipart("/v1/images/edits", form_data)
    result$backend <- "openai"

    # Save to file if requested
    if (!is.null(file) && length(result$data) > 0) {
        .save_image(result$data[[1]], file, response_format)
    }

    result
}

#' Image edit via diffuseR img2img
#' @keywords internal
.img_edit_diffuser <- function(image, prompt, model = NULL,
                                   negative_prompt = NULL, size = "512x512",
                                   strength = 0.8, steps = 50,
                                   guidance_scale = 7.5, seed = NULL,
                                   devices = "cpu", file = NULL) {
    if (!.has_diffuser()) {
        stop(
             "diffuseR package is not installed.\n",
             "Install from local source or GitHub to use local diffusion models.",
             call. = FALSE
        )
    }

    # Default model - use sdxl to match tti default
    model <- model %||% "sdxl"

    # Map model names
    diffuser_model <- switch(
                             model,
                             "sd21" = "sd21",
                             "sd2.1" = "sd21",
                             "sdxl" = "sdxl",
                             "sd-xl" = "sdxl",
                             stop("Unsupported diffuseR model: ", model,
                                  ". Use 'sd21' or 'sdxl'.", call. = FALSE)
    )

    # Parse size
    dims <- as.integer(strsplit(size, "x")[[1]])
    img_dim <- dims[1]

    # Determine save behavior
    save_file <- !is.null(file)
    filename <- file

    # Get cached pipeline (reuses the same pipeline as tti)
    p <- .get_diffuser_pipeline(diffuser_model, devices)

    # Call diffuseR::img2img with cached pipeline
    torch::with_no_grad({
        result <- diffuseR::img2img(
                                    input_image = image,
                                    prompt = prompt,
                                    model_name = diffuser_model,
                                    pipeline = p$pipeline,
                                    devices = p$devices,
                                    unet_dtype_str = p$unet_dtype,
                                    negative_prompt = negative_prompt,
                                    img_dim = img_dim,
                                    num_inference_steps = as.integer(steps),
                                    strength = strength,
                                    guidance_scale = guidance_scale,
                                    seed = seed,
                                    save_file = save_file,
                                    filename = filename
        )
    })

    # Normalize return structure
    list(
         data = list(list(image = result$image, revised_prompt = NULL)),
         metadata = result$metadata,
         backend = "diffuser"
    )
}

#' Create Image Variations
#'
#' Generate variations of an existing image using DALL-E 2.
#' Note: This function only works with the OpenAI backend.
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
#' set_api_key("sk-...")
#' result <- img_variation("photo.png", n = 3)
#' }
#'
#' @export
img_variation <- function(image, model = "dall-e-2", size = "1024x1024",
                              n = 1, response_format = "url", file = NULL) {
    .sidecar_arm(environment(), "file")
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }

    # Validate size
    valid_sizes <- c("256x256", "512x512", "1024x1024")
    if (!size %in% valid_sizes) {
        stop("size must be one of: ", paste(valid_sizes, collapse = ", "),
             call. = FALSE)
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
    result <- .post_multipart("/v1/images/variations", form_data)
    result$backend <- "openai"

    # Save to file if requested
    if (!is.null(file) && length(result$data) > 0) {
        .save_image(result$data[[1]], file, response_format)
    }

    result
}
