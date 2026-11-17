#' Edit Image with Text Prompt
#'
#' Edit an existing image using a text prompt. Uses the DALL-E 2 edits
#' endpoint for the OpenAI backend, diffuseR's SD img2img for local
#' models, or FLUX 3 Image Klein's reference edit (\code{backend =
#' "flux3"}), which keeps the subject of the input image and renders the
#' caption around it.
#'
#' The FLUX 3 caption is a full description of the edited result, not an
#' instruction: "the same Bigfoot from the reference image, now wearing a
#' vampire cape, on a plain light grey backdrop". The pipeline loads once
#' per device and stays cached (see \code{\link{clear_diffuser_cache}}).
#' Its support files (VAE, tokenizer) are read from
#' \code{options(xtx.flux3_support_dir)} when set, else from the cached
#' \code{cornball-ai/flux3-klein-support} snapshot, else from wherever
#' \code{diffuseR::flux3_load_pipeline} looks by default.
#'
#' @param image Character. Path to the input image file.
#' @param prompt Character. The text description of the desired edit/transformation.
#' @param backend Character. Which backend to use: "openai", "diffuser",
#'   "flux3" (FLUX 3 in this process) or "gpuhost" (the same edit on a
#'   gpu.ctl host's \code{flux3-klein} entry, through
#'   \code{options(xtx.gpuhost_base)} or \code{GPU_HOST_BASE};
#'   \code{options(xtx.gpuhost_edit_entry)}
#'   names another entry).
#' @param model Character. Model to use. For OpenAI: "dall-e-2".
#'   For diffuseR: "sd21", "sdxl". Ignored by flux3.
#' @param mask Character or NULL. Path to mask image (OpenAI only).
#'   Transparent areas indicate where to edit.
#' @param negative_prompt Character or NULL. Negative prompt (diffuseR only).
#' @param size Character. Output size. For OpenAI: "256x256", "512x512", "1024x1024".
#'   For diffuseR: "512x512", "768x768", "1024x1024". For flux3 the
#'   area cap the input is scaled to fit (its canvas is the output size),
#'   so a 1024x1024 input at "512x512" is edited at 512x512. For gpuhost
#'   the output size when given; left unset, the output is the
#'   reference's size (within the entry's 1024x1024 bound).
#' @param strength Numeric. Transformation strength 0-1 (diffuseR only). Default 0.8.
#' @param steps Integer. Number of inference steps (diffuseR, flux3 and
#'   gpuhost). Default 50; flux3 is a distilled model and defaults to 16,
#'   and gpuhost leaves an unset count to the entry.
#' @param guidance_scale Numeric. CFG scale (diffuseR only). Default 7.5.
#' @param seed Integer or NULL. Random seed (diffuseR and flux3).
#' @param devices Character or list. Device configuration (diffuseR and
#'   flux3; flux3 takes one device, "cuda" or "cpu").
#' @param n Integer. Number of images to generate (OpenAI only).
#' @param response_format Character. "url" or "b64_json" (OpenAI only).
#' @param file Character or NULL. If provided, save the first result to this path.
#' @param timeout Seconds to wait for a gpuhost reply (gpuhost only; at
#'   least 300, since a swap can precede the edit).
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
#'
#' # FLUX 3 reference edit: the same subject, a new outfit
#' img_edit("bigfoot.png",
#'          paste("A studio portrait of the same Bigfoot from the reference",
#'                "image, now wearing a black vampire cape. Plain flat light",
#'                "grey backdrop."),
#'          backend = "flux3", devices = "cuda", seed = 7L,
#'          file = "bigfoot_vampire.png")
#' }
#'
#' @export
img_edit <- function(image, prompt,
                     backend = c("openai", "diffuser", "flux3", "gpuhost"),
                     model = NULL, mask = NULL, negative_prompt = NULL,
                     size = "1024x1024", strength = 0.8, steps = 50,
                     guidance_scale = 7.5, seed = NULL, devices = "cpu",
                     n = 1, response_format = "url", file = NULL,
                     timeout = 300) {
    .sidecar_arm(environment(), "file")
    # Validate inputs
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }
    if (!is.character(prompt) || length(prompt) != 1 || nchar(prompt) == 0) {
        stop("'prompt' must be a non-empty character string", call. = FALSE)
    }

    backend <- match.arg(backend)

    if (backend == "gpuhost") {
        # The entry's own defaults stand for what the caller did not say:
        # its step count, and the reference's size for the output.
        .img_edit_gpuhost(image = image, prompt = prompt,
                          size = if (missing(size)) NULL else size,
                          steps = if (missing(steps)) NULL else steps,
                          seed = seed, file = file, timeout = timeout)
    } else if (backend == "flux3") {
        .img_edit_flux3(image = image, prompt = prompt, size = size,
                        steps = if (missing(steps)) 16L else steps,
                        seed = seed, devices = devices, file = file)
    } else if (backend == "diffuser") {
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

#' Image edit via diffuseR FLUX 3 Image Klein
#'
#' A reference edit: the input goes in whole as the model's reference
#' and the caption describes the edited result (see
#' \code{diffuseR::img2img_flux3}). The pipeline is loaded once per
#' device, in bfloat16 on either device, and cached beside the SD ones.
#' @keywords internal
.img_edit_flux3 <- function(image, prompt, size = "1024x1024", steps = 16L,
                            seed = NULL, devices = "cuda", file = NULL) {
    if (!.has_diffuser()) {
        stop(
             "diffuseR package is not installed.\n",
             "Install from local source or GitHub to use local diffusion models.",
             call. = FALSE
        )
    }
    device <- as.character(unlist(devices))[1]
    max_area <- .flux3_max_area(size)

    key <- paste0("flux3_", device)
    pipe <- .diffuser_cache[[key]]
    if (is.null(pipe)) {
        message("Loading diffuseR pipeline for flux3 on ", device, "...")
        pipe <- diffuseR::flux3_load_pipeline(device = device, encoder = TRUE,
                                              dtype = "bfloat16",
                                              support_dir = .flux3_support_dir(),
                                              verbose = FALSE)
        .diffuser_cache[[key]] <- pipe
        message("diffuseR pipeline loaded and cached.")
    }

    result <- torch::with_no_grad({
        diffuseR::img2img_flux3(prompt, image, pipeline = pipe,
                                max_area = max_area,
                                num_inference_steps = as.integer(steps),
                                seed = seed, save_file = !is.null(file),
                                filename = file, verbose = "progress")
    })
    if (!is.null(file)) {
        .sidecar_note(file, backend = "flux3", model = "flux3-klein",
                      max_area = max_area, steps = as.integer(steps),
                      device = device, dtype = "bfloat16")
    }

    list(
         data = list(list(image = if (!is.null(file)) file else result$image,
                          revised_prompt = NULL)),
         metadata = result$metadata,
         backend = "flux3"
    )
}

# The FLUX 3 reference canvas cap from a "WIDTHxHEIGHT" size string.
.flux3_max_area <- function(size) {
    dims <- suppressWarnings(as.integer(strsplit(size, "x", fixed = TRUE)[[1]]))
    if (length(dims) != 2 || anyNA(dims) || any(dims < 16L)) {
        stop("'size' must be \"WIDTHxHEIGHT\", e.g. \"1024x1024\"",
             call. = FALSE)
    }
    prod(dims)
}

# Where the FLUX 3 VAE and tokenizer are read from: the option, else the
# cached cornball-ai/flux3-klein-support snapshot (the raw BFL repo's
# snapshot may be gone from the cache once the quantized artifacts are
# built), else NULL for diffuseR's own default.
.flux3_support_dir <- function() {
    opt <- getOption("xtx.flux3_support_dir")
    if (!is.null(opt)) {
        if (!dir.exists(opt)) {
            stop("options(xtx.flux3_support_dir) is ", opt,
                 ", which is not a directory", call. = FALSE)
        }
        return(opt)
    }
    cfg <- tryCatch(
        hfhub::hub_download("cornball-ai/flux3-klein-support",
                            "vae/config.json", local_files_only = TRUE),
        error = function(e) NULL)
    if (is.null(cfg)) {
        return(NULL)
    }
    dirname(dirname(cfg))
}

#' Image edit on a gpu.ctl host
#'
#' The reference travels as \code{image_b64} to an entry whose generator
#' edits (the fleet's \code{flux3-klein}, \code{options(xtx.gpuhost_edit_entry)}
#' to name another) and the reply is PNG bytes, the same wire as
#' \code{\link{tti}}'s gpuhost backend. The entry's own defaults stand for
#' what the caller leaves NULL: its step count, and the reference's size
#' for the output.
#' @keywords internal
.img_edit_gpuhost <- function(image, prompt, size = NULL, steps = NULL,
                              seed = NULL, file = NULL, timeout = 300,
                              entry = getOption("xtx.gpuhost_edit_entry",
                                                "flux3-klein")) {
    input <- .gpuhost_edit_input(image, prompt, size = size, steps = steps,
                                 seed = seed)
    # A swap can precede the work (the video row moves LTX off the card
    # and FLUX 3 on, 45 s), then the edit itself is a minute or two.
    out <- .gpuhost_infer(entry, input, timeout = max(timeout, 300))
    path <- file %||% tempfile(fileext = ".png")
    writeBin(out$content, path)
    if (!is.null(file)) {
        .sidecar_note(file, backend = "gpuhost", entry = entry)
    }
    list(data = list(list(image = path, revised_prompt = NULL)),
         backend = "gpuhost", entry = entry, meta = out$meta)
}

# The edit request: the prompt, the reference's bytes, and only the
# fields the caller set, so the entry's defaults decide the rest.
.gpuhost_edit_input <- function(image, prompt, size = NULL, steps = NULL,
                                seed = NULL) {
    bytes <- readBin(image, "raw", file.size(image))
    input <- list(prompt = prompt, image_b64 = jsonlite::base64_enc(bytes))
    if (!is.null(size)) {
        dims <- as.integer(strsplit(size, "x", fixed = TRUE)[[1]])
        input$width <- dims[[1L]]
        input$height <- dims[[2L]]
    }
    if (!is.null(steps)) {
        input$steps <- as.integer(steps)
    }
    if (!is.null(seed)) {
        input$seed <- as.integer(seed)
    }
    input
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
