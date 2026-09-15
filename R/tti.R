# Text-to-Image (TTI) functions with multiple backends

#' Set Text-to-Image API Base URL
#'
#' Configure the base URL for the diffusers_api service (Z-Image-Turbo, SD).
#'
#' @param url Base URL (e.g., "http://localhost:8000")
#' @return Invisibly returns the previous value
#' @examples
#' \dontrun{
#'   tti_base("http://localhost:8000")
#' }
#' @export
tti_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    old <- getOption("xtx.tti_base")
    options(xtx.tti_base = url)
    invisible(old)
}

#' Get TTI API Base URL
#' @keywords internal
.tti_get_base <- function() {
    base <- getOption("xtx.tti_base")
    if (is.null(base) || nchar(base) == 0) {
        stop("TTI API base URL not set. Use tti_base() to configure it.\n",
             "Example: tti_base(\"http://localhost:8000\")", call. = FALSE)
    }
    base
}

#' Generate Image from Text
#'
#' Generate an image from a text prompt using multiple backends.
#'
#' @param prompt Character. The text description of the image to generate.
#' @param backend Character. Which backend to use:
#'   - "openai": DALL-E API (requires API key)
#'   - "diffuseR": Local diffuseR package
#'   - "diffusers_api": HTTP API (Z-Image-Turbo, SD)
#'   - "gpuhost": the viento-managed gpu.ctl service, which generates on
#'     ITS card rather than in this process. Set
#'     \code{options(xtx.gpuhost_base = "http://host:7878")}. Prefer this
#'     on any machine where a gpu.ctl host is resident: the in-process
#'     diffuseR backends compete with it for the same device.
#'   - "auto": Use diffuseR if available, else openai
#' @param model Character. Model to use. Depends on backend:
#'   - OpenAI: "dall-e-3", "dall-e-2"
#'   - diffuseR: "sd21", "sdxl"
#'   - diffusers_api: "Tongyi-MAI/Z-Image-Turbo", any HF model ID
#' @param negative_prompt Character or NULL. Negative prompt (diffuseR, diffusers_api only).
#' @param size Character. Image dimensions (e.g., "1024x1024").
#' @param quality Character. Image quality: "standard" or "hd" (DALL-E 3 only).
#' @param style Character. Image style: "vivid" or "natural" (DALL-E 3 only).
#' @param n Integer. Number of images (OpenAI only).
#' @param steps Integer. Inference steps (diffuseR, diffusers_api only). Default 50.
#' @param guidance_scale Numeric. CFG scale. Default 7.5.
#' @param seed Integer or NULL. Random seed for reproducibility.
#' @param lora Character or list. LoRA model(s) for character/style consistency
#'   (diffusers_api only). Can be a path string for single LoRA, or a list of
#'   lists with `path` and `scale` elements for multiple LoRAs.
#' @param lora_scale Numeric. Weight for single LoRA (0-1). Default 0.8.
#'   Ignored if `lora` is a list with explicit scales.
#' @param devices Device configuration for diffuseR: "cpu", "cuda", or list.
#' @param response_format Character. "url" or "b64_json" (OpenAI only).
#' @param file Character or NULL. If provided, save the image to this path.
#' @param timeout Timeout in seconds (diffusers_api only). Default 120.
#'
#' @return A list containing the generated image data. Structure varies by backend.
#'
#' @examples
#' \dontrun{
#' # Using OpenAI DALL-E
#' set_api_key("sk-...")
#' result <- tti("A white cat on a windowsill")
#' browseURL(result$data[[1]]$url)
#'
#' # Using local diffuseR
#' result <- tti("A sunset over mountains", backend = "diffuseR")
#'
#' # Using diffusers_api with Z-Image-Turbo
#' tti_base("http://localhost:8000")
#' result <- tti("A robot DJ", backend = "diffusers_api",
#'               model = "Tongyi-MAI/Z-Image-Turbo")
#'
#' # Using LoRA for character consistency
#' tti("photo of sks person smiling", backend = "diffusers_api",
#'     lora = "/models/loras/my_character.safetensors",
#'     lora_scale = 0.85, file = "character.png")
#'
#' # Multiple LoRAs
#' tti("photo of sks person in anime style", backend = "diffusers_api",
#'     lora = list(
#'       list(path = "character.safetensors", scale = 0.8),
#'       list(path = "anime_style.safetensors", scale = 0.6)
#'     ))
#'
#' # Save to file
#' tti("A sunset over mountains", file = "sunset.png")
#' }
#'
#' @export
tti <- function(prompt,
                backend = c("openai", "diffuseR", "diffusers_api", "gpuhost",
                            "auto"),
                model = NULL, negative_prompt = NULL, size = NULL,
                quality = "standard", style = "vivid", n = 1, steps = 50,
                guidance_scale = 7.5, seed = NULL, lora = NULL,
                lora_scale = 0.8, devices = "cpu", response_format = "url",
                file = NULL, timeout = 120) {
    .sidecar_arm(environment(), "file")
    # ASKED FOR, OR DEFAULTED? Read before anything can force it. `steps`
    # defaults to 50, the SD family's number; FLUX.2 klein is a 4-step
    # distilled model, so sending 50 to the gpuhost would be twelve times
    # the work for no gain, while a caller who genuinely asked for 50 must
    # get it. Only `missing()` distinguishes those, and only here.
    steps_asked <- !missing(steps)
    if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
        stop("'prompt' must be a non-empty character string", call. = FALSE)
    }

    backend <- match.arg(backend)

    # Auto backend selection
    if (backend == "auto") {
        if (.has_diffuser()) {
            backend <- "diffuseR"
            message("Using diffuseR backend")
        } else {
            backend <- "openai"
        }
    }

    # Acquire GPU if using local backend
    if (backend == "diffusers_api") {
        .gpuctl_acquire("diffusers")
    }

    # Dispatch to appropriate backend
    if (backend == "gpuhost") {
        .tti_gpuhost(prompt = prompt, size = size, seed = seed,
                     steps = if (steps_asked) steps else NULL,
                     negative_prompt = negative_prompt, file = file,
                     timeout = timeout)
    } else if (backend == "diffusers_api") {
        .tti_diffusers_api(prompt = prompt, model = model,
                           negative_prompt = negative_prompt, size = size,
                           steps = steps, guidance_scale = guidance_scale,
                           lora = lora, lora_scale = lora_scale, file = file,
                           timeout = timeout)
    } else if (backend == "diffuseR") {
        .tti_diffuser(
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
        .tti_openai(
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

#' Text-to-image via diffusers_api
#' @keywords internal
.tti_diffusers_api <- function(prompt, model = NULL, negative_prompt = NULL,
                               size = NULL, steps = 50, guidance_scale = 7.5,
                               lora = NULL, lora_scale = 0.8, file = NULL,
                               timeout = 120) {
    base <- .tti_get_base()
    url <- paste0(base, "/text-to-image")

    # Default model
    model <- model %||% "Tongyi-MAI/Z-Image-Turbo"

    # Parse size
    if (is.null(size)) {
        width <- 1024L
        height <- 1024L
    } else {
        dims <- as.integer(strsplit(size, "x")[[1]])
        width <- dims[1]
        height <- dims[2]
    }

    # Build request body
    body <- list(model_id = model, prompt = prompt,
                 num_inference_steps = as.integer(steps),
                 guidance_scale = guidance_scale, width = width,
                 height = height)

    if (!is.null(negative_prompt) && nchar(negative_prompt) > 0) {
        body$negative_prompt <- negative_prompt
    }

    # Add LoRA models if specified
    if (!is.null(lora)) {
        if (is.character(lora)) {
            # Single LoRA as string
            body$lora_models <- list(list(path = lora, scale = lora_scale))
        } else if (is.list(lora)) {
            # Multiple LoRAs as list of lists
            body$lora_models <- lora
        }
    }

    # Make request
    h <- curl::new_handle()
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
        stop("TTI API error (", status, "): ", err_msg, call. = FALSE)
    }

    result <- jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)

    # Save to file if requested
    if (!is.null(file) && !is.null(result$image)) {
        img_bytes <- base64enc::base64decode(result$image)
        writeBin(img_bytes, file)
        message("Image saved to: ", file)
    }

    result$backend <- "diffusers_api"
    result
}

#' Text-to-image via OpenAI DALL-E
#' @keywords internal
.tti_openai <- function(prompt, model = NULL, size = NULL,
                        quality = "standard", style = "vivid", n = 1,
                        response_format = "url", file = NULL) {
    model <- model %||% "dall-e-3"
    model <- match.arg(model, c("dall-e-3", "dall-e-2"))

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

    body <- list(
                 model = model,
                 prompt = prompt,
                 n = as.integer(n),
                 size = size,
                 response_format = response_format
    )

    if (model == "dall-e-3") {
        body$quality <- match.arg(quality, c("standard", "hd"))
        body$style <- match.arg(style, c("vivid", "natural"))
        if (n != 1) {
            warning("DALL-E 3 only supports n=1, ignoring n parameter", call. = FALSE)
            body$n <- 1L
        }
    }

    result <- .post_json("/v1/images/generations", body)

    if (!is.null(result$parse_error)) {
        stop("Failed to parse API response: ", result$parse_error,
             "\nRaw content: ", substr(result$raw_content, 1, 200), call. = FALSE)
    }

    result$backend <- "openai"

    if (!is.null(file) && !is.null(result$data) && length(result$data) > 0) {
        .save_image(result$data[[1]], file, response_format)
    }

    result
}

#' Text-to-image via diffuseR
#' @keywords internal
.tti_diffuser <- function(prompt, model = NULL, negative_prompt = NULL,
                          size = NULL, steps = 50, guidance_scale = 7.5,
                          seed = NULL, devices = "cpu", file = NULL) {
    if (!.has_diffuser()) {
        stop(
             "diffuseR package is not installed.\n",
             "Install from local source or GitHub to use local diffusion models.",
             call. = FALSE
        )
    }

    model <- model %||% "flux2"

    diffuser_model <- switch(
                             model,
                             "sd21" = "sd21",
                             "sd2.1" = "sd21",
                             "sdxl" = "sdxl",
                             "sd-xl" = "sdxl",
                             "flux2" = "flux2",
                             "flux" = "flux2",
                             stop("Unsupported diffuseR model: ", model,
                                  ". Use 'flux2', 'sdxl', or 'sd21'.", call. = FALSE)
    )

    if (diffuser_model == "flux2") {
        # FLUX.2 klein-4B: guidance-free 4-step distilled model. It has
        # no CFG (negative prompts don't apply), and the tti default of
        # 50 steps belongs to the SD family, so it runs its own default.
        return(.tti_flux2(prompt, size = size, seed = seed, file = file))
    }

    # Get cached pipeline (loads once, reuses thereafter)
    p <- .get_diffuser_pipeline(diffuser_model, devices)

    # Use model-specific function with cached pipeline
    # Wrap in no_grad to prevent gradient tracking during inference
    torch::with_no_grad({
        if (diffuser_model == "sdxl") {
            diffuseR::txt2img_sdxl(
                                   prompt = prompt,
                                   devices = p$devices,
                                   pipeline = p$pipeline,
                                   unet_dtype_str = p$unet_dtype,
                                   negative_prompt = negative_prompt,
                                   num_inference_steps = as.integer(steps),
                                   guidance_scale = guidance_scale,
                                   seed = seed,
                                   filename = file
            )
        } else {
            diffuseR::txt2img_sd21(
                                   prompt = prompt,
                                   devices = p$devices,
                                   pipeline = p$pipeline,
                                   unet_dtype_str = p$unet_dtype,
                                   negative_prompt = negative_prompt,
                                   num_inference_steps = as.integer(steps),
                                   guidance_scale = guidance_scale,
                                   seed = seed,
                                   filename = file
            )
        }
    })

    list(
         data = list(
                     list(
                          image = if (!is.null(file)) file else NULL,
                          revised_prompt = NULL
            )
        ),
         backend = "diffuseR"
    )
}

#' Text-to-image via diffuseR FLUX.2 klein-4B
#'
#' Guidance-free 4-step distilled model; the pipeline is cached in the
#' session like the SD pipelines (first call pays the ~32s load, later
#' calls generate in ~48s at 1024x1024 on a 16GB card).
#' @keywords internal
.tti_flux2 <- function(prompt, size = NULL, seed = NULL, file = NULL) {
    dims <- if (is.null(size)) {
        c(1024L, 1024L)
    } else {
        as.integer(strsplit(size, "x", fixed = TRUE)[[1]])
    }

    pipe <- .diffuser_cache[["flux2"]]
    if (is.null(pipe)) {
        message("Loading diffuseR pipeline for flux2...")
        pipe <- diffuseR::flux2_load_pipeline(device = "cuda")
        .diffuser_cache[["flux2"]] <- pipe
    }

    torch::with_no_grad({
        diffuseR::txt2img_flux2(prompt = prompt, pipeline = pipe,
                                width = dims[1], height = dims[2],
                                seed = seed, filename = file,
                                verbose = "progress")
    })

    list(
         data = list(
                     list(
                          image = if (!is.null(file)) file else NULL,
                          revised_prompt = NULL
            )
        ),
         backend = "diffuseR"
    )
}
