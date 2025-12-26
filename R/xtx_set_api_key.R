#' Set API Key
#'
#' Configure the API key for authentication with image generation services.
#'
#' @param key Character. The API key string.
#'
#' @return Invisibly returns the previous API key value.
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#' }
#'
#' @export
xtx_set_api_key <- function(key) {
  if (!is.character(key) || length(key) != 1 || nchar(key) == 0) {
    stop("'key' must be a non-empty character string", call. = FALSE)
  }
  old <- getOption("xtxapi.api_key")
  options(xtxapi.api_key = key)
  invisible(old)
}
