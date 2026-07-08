#' Set API Base URL
#'
#' Configure the base URL for the image generation API.
#' Defaults to OpenAI's API endpoint.
#'
#' @param url Character. The base URL (without trailing slash).
#'
#' @return Invisibly returns the previous base URL value.
#'
#' @examples
#' \dontrun{
#' # Use OpenAI
#' xtx_set_api_base("https://api.openai.com")
#'
#' # Use a local server
#' xtx_set_api_base("http://localhost:8000")
#' }
#'
#' @export
xtx_set_api_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    url <- sub("/$", "", url) # Remove trailing slash
    old <- getOption("xtx.api_base")
    options(xtx.api_base = url)
    invisible(old)
}
