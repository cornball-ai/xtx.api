# Package initialization

.onLoad <- function(libname, pkgname) {

op <- options()
op_xtxapi <- list(
    xtxapi.api_base = "https://api.openai.com",
    xtxapi.api_key = NULL,
    xtxapi.timeout = 120,
    xtxapi.backend = "openai"
  )
  toset <- !(names(op_xtxapi) %in% names(op))
  if (any(toset)) options(op_xtxapi[toset])
  invisible()
}

# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
