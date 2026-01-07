# Package initialization

.onLoad <- function(libname, pkgname) {
  op <- options()
  op_xtxapi <- list(
    # OpenAI API settings
    xtxapi.api_base = "https://api.openai.com",
    xtxapi.api_key = NULL,
    xtxapi.timeout = 120,
    # Text-to-image backend: "openai", "diffuser", "diffusers_api"
    xtxapi.tti_backend = "openai",
    xtxapi.tti_base = "http://localhost:8000",
    # Image-to-video (diffusers_api with CogVideoX)
    xtxapi.itv_base = "http://localhost:8000",
    # Speech-to-video (faster-SadTalker-API)
    xtxapi.stv_base = "http://localhost:10364"
  )
  toset <- !(names(op_xtxapi) %in% names(op))
  if (any(toset)) options(op_xtxapi[toset])
  invisible()
}

# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
