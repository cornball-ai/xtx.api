#' Generate Image from Text
#'
#' Generate an image from a text prompt using DALL-E API or local diffusion models.
#'
#' @param prompt Character. The text description of the image to generate.
#' @param backend Character. Which backend to use: "openai" for DALL-E API,
#'   "diffuser" for local diffuseR models, or "auto" to use diffuser if available.
#' @param model Character. The model to use. For OpenAI: "dall-e-3", "dall-e-2".
#'   For diffuseR: "sd21", "sdxl".
#' @param negative_prompt Character or NULL. Negative prompt (diffuseR only).
#' @param size Character. Image dimensions. For DALL-E 3: "1024x1024",
#'   "1024x1792", "1792x1024". For DALL-E 2: "256x256", "512x512", "1024x1024".
#'   For diffuseR: "512x512", "768x768", "1024x1024".
#' @param quality Character. Image quality. "standard" or "hd" (DALL-E 3 only).
#' @param style Character. Image style. "vivid" or "natural" (DALL-E 3 only).
#' @param n Integer. Number of images to generate (OpenAI only).
#' @param steps Integer. Number of inference steps (diffuseR only). Default 50.
#' @param guidance_scale Numeric. CFG scale (diffuseR only). Default 7.5.
#' @param seed Integer or NULL. Random seed for reproducibility (diffuseR only).
#' @param devices Character or list. Device configuration for diffuseR.
#'   "cpu", "cuda", or list like \code{list(unet = "cuda", decoder = "cpu")}.
#' @param response_format Character. "url" or "b64_json" (OpenAI only).
#' @param file Character or NULL. If provided, save the image to this path.
#'
#' @return A list containing the generated image data. Structure varies by backend:
#'   \itemize{
#'     \item OpenAI: \code{data[[1]]$url} or \code{data[[1]]$b64_json}
#'     \item diffuseR: \code{data[[1]]$image} (array), \code{metadata}
#'   }
#'
#' @examples
#' \dontrun{
#' # Using OpenAI DALL-E
#' xtx_set_api_key("sk-...")
#' result <- xtx_txt2img("A white cat sitting on a windowsill")
#' browseURL(result$data[[1]]$url)
#'
#' # Using local diffuseR
#' result <- xtx_txt2img(
#'   "A white cat sitting on a windowsill",
#'   backend = "diffuser",
#'   model = "sd21",
#'   devices = "cuda"
#' )
#'
#' # Save to file
#' xtx_txt2img("A sunset over mountains", file = "sunset.png")
#' }
#'
#' @export
xtx_txt2img <- function(prompt,
                        backend = c("openai", "diffuser", "auto"),
                        model = NULL,
                        negative_prompt = NULL,
                        size = NULL,
                        quality = "standard",
                        style = "vivid",
                        n = 1,
                        steps = 50,
                        guidance_scale = 7.5,
                        seed = NULL,
                        devices = "cpu",
                        response_format = "url",
                        file = NULL) {

  # Validate prompt
  if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
    stop("'prompt' must be a non-empty character string", call. = FALSE)
  }

  backend <- match.arg(backend)

  # Auto backend selection
  if (backend == "auto") {
    if (.xtx_has_diffuser()) {
      backend <- "diffuser"
      message("Using diffuseR backend")
    } else {
      backend <- "openai"
    }
  }

  # Dispatch to appropriate backend
  if (backend == "diffuser") {
    .xtx_txt2img_diffuser(
      prompt = prompt,
      model = model,
      negative_prompt = negative_prompt,
      size = size,
      steps = steps,
      guidance_scale = guidance_scale,
      seed = seed,
      devices = devices,
      file = file
    )
  } else {
    .xtx_txt2img_openai(
      prompt = prompt,
      model = model,
      size = size,
      quality = quality,
      style = style,
      n = n,
      response_format = response_format,
      file = file
    )
  }
}

#' Text-to-image via OpenAI DALL-E
#' @keywords internal
.xtx_txt2img_openai <- function(prompt,
                                 model = NULL,
                                 size = NULL,
                                 quality = "standard",
                                 style = "vivid",
                                 n = 1,
                                 response_format = "url",
                                 file = NULL) {

  # Default model
  model <- model %||% "dall-e-3"
  model <- match.arg(model, c("dall-e-3", "dall-e-2"))

  # Default and validate size based on model
  valid_sizes_dalle3 <- c("1024x1024", "1024x1792", "1792x1024")
  valid_sizes_dalle2 <- c("256x256", "512x512", "1024x1024")

  if (model == "dall-e-3") {
    size <- size %||% "1024x1024"
    if (!size %in% valid_sizes_dalle3) {
      stop("For DALL-E 3, size must be one of: ",
           paste(valid_sizes_dalle3, collapse = ", "), call. = FALSE)
    }
  } else {
    size <- size %||% "1024x1024"
    if (!size %in% valid_sizes_dalle2) {
      stop("For DALL-E 2, size must be one of: ",
           paste(valid_sizes_dalle2, collapse = ", "), call. = FALSE)
    }
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

  # Check for parse errors

  if (!is.null(result$parse_error)) {
    stop("Failed to parse API response: ", result$parse_error,
         "\nRaw content: ", substr(result$raw_content, 1, 200), call. = FALSE)
  }

  result$backend <- "openai"

  # Save to file if requested
  if (!is.null(file) && !is.null(result$data) && length(result$data) > 0) {
    .xtx_save_image(result$data[[1]], file, response_format)
  }

  result
}

#' Text-to-image via diffuseR
#' @keywords internal
.xtx_txt2img_diffuser <- function(prompt,
                                   model = NULL,
                                   negative_prompt = NULL,
                                   size = NULL,
                                   steps = 50,
                                   guidance_scale = 7.5,
                                   seed = NULL,
                                   devices = "cpu",
                                   file = NULL) {

  if (!.xtx_has_diffuser()) {
    stop(
      "diffuseR package is not installed.\n",
      "Install from local source or GitHub to use local diffusion models.",
      call. = FALSE
    )
  }

  # Default model
  model <- model %||% "sd21"

  # Map model names
  diffuser_model <- switch(
    model,
    "sd21" = "sd21",
    "sd2.1" = "sd21",
    "sdxl" = "sdxl",
    "sd-xl" = "sdxl",
    stop("Unsupported diffuseR model: ", model, ". Use 'sd21' or 'sdxl'.", call. = FALSE)
  )

  # Default size based on model
  if (is.null(size)) {
    size <- if (diffuser_model == "sdxl") "1024x1024" else "768x768"
  }

  # Parse size to dimension
  dims <- as.integer(strsplit(size, "x")[[1]])
  img_dim <- dims[1]

  # Determine save behavior
  save_file <- !is.null(file)
  filename <- file

  # Call diffuseR::txt2img
  result <- diffuseR::txt2img(
    prompt = prompt,
    model_name = diffuser_model,
    negative_prompt = negative_prompt,
    img_dim = img_dim,
    devices = devices,
    num_inference_steps = as.integer(steps),
    guidance_scale = guidance_scale,
    seed = seed,
    save_file = save_file,
    filename = filename
  )

  # Normalize return structure
  list(
    data = list(
      list(
        image = result$image,
        revised_prompt = NULL
      )
    ),
    metadata = result$metadata,
    backend = "diffuser"
  )
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
