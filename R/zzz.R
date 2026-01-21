# Package initialization

.onLoad <- function(
  libname,
  pkgname
) {
  op <- options()
  op_xtx <- list(
    # OpenAI API settings
    xtx.api_base = "https://api.openai.com",
    xtx.api_key = NULL,
    xtx.timeout = 120,
    # Text-to-image backend: "openai", "diffuser", "diffusers_api"
    xtx.tti_backend = "openai",
    xtx.tti_base = "http://localhost:8000",
    # Image-to-video (diffusers_api with CogVideoX)
    xtx.itv_base = "http://localhost:8000",
    # Speech-to-video (faster-SadTalker-API)
    xtx.stv_base = "http://localhost:10364"
  )
  toset <- !(names(op_xtx) %in% names(op))
  if (any(toset)) options(op_xtx[toset])
  invisible()
}

# Null coalescing operator
`%||%` <- function(
  x,
  y
) if (is.null(x)) y else x

