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
#' Returns a character vector of known image generation models.
#' This is a static list and does not query the API.
#'
#' @return Character vector of model names.
#'
#' @examples
#' xtx_supported_models()
#'
#' @export
xtx_supported_models <- function() {
  c(
    # OpenAI DALL-E
    "dall-e-3",
    "dall-e-2"
    # Future: local diffusion models, replicate, etc.
  )
}
