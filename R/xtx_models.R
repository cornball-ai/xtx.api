#' List Available Models
#'
#' List the image generation models available from the configured API.
#'
#' @return A data frame of available models, or NULL if the endpoint is not available.
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#' xtx_models()
#' }
#'
#' @export
xtx_models <- function() {
  result <- tryCatch(
    .xtx_get("/v1/models"),
    error = function(e) NULL
  )

  if (is.null(result)) {
    message("Could not retrieve models from API")
    return(invisible(NULL))
  }

  # Filter for image models if we have data
  if (!is.null(result$data)) {
    models <- result$data
    # Try to filter for DALL-E / image models
    if (is.data.frame(models) && "id" %in% names(models)) {
      image_models <- models[grepl("dall-e|image|diffusion", models$id, ignore.case = TRUE), ]
      if (nrow(image_models) > 0) {
        return(image_models)
      }
    }
    return(models)
  }

  result
}

#' Get Supported Image Models
#'
#' Returns information about known image generation models by backend.
#'
#' @param backend Character or NULL. Filter by backend: "openai", "diffuser", or NULL for all.
#'
#' @return A data frame with columns: model, backend, type, description.
#'
#' @examples
#' xtx_supported_models()
#' xtx_supported_models("diffuser")
#'
#' @export
xtx_supported_models <- function(backend = NULL) {
  models <- data.frame(
    model = c(
      # OpenAI
      "dall-e-3",
      "dall-e-2",
      # diffuseR
      "sd21",
      "sdxl"
    ),
    backend = c(
      "openai", "openai",
      "diffuser", "diffuser"
    ),
    type = c(
      "txt2img", "txt2img/img2img/variations",
      "txt2img/img2img", "txt2img/img2img"
    ),
    description = c(
      "DALL-E 3 - highest quality, 1024px",
      "DALL-E 2 - edits, variations, smaller sizes",
      "Stable Diffusion 2.1 - local, 768px default",
      "Stable Diffusion XL - local, 1024px default"
    ),
    stringsAsFactors = FALSE
  )

  if (!is.null(backend)) {
    backend <- match.arg(backend, c("openai", "diffuser"))
    models <- models[models$backend == backend, ]
  }

  models
}

#' Check Available Backends
#'
#' Check which backends are currently available and configured.
#'
#' @return A list with backend availability status.
#'
#' @examples
#' xtx_backends()
#'
#' @export
xtx_backends <- function() {
  list(
    openai = list(
      available = TRUE,
      configured = !is.null(getOption("xtx.api_key")),
      api_base = getOption("xtx.api_base")
    ),
    diffuser = list(
      available = .xtx_has_diffuser(),
      configured = .xtx_has_diffuser(),
      models = if (.xtx_has_diffuser()) c("sd21", "sdxl") else NULL
    )
  )
}
