#' Check API Health
#'
#' Check connectivity and authentication with the configured API endpoint.
#'
#' @return A list with:
#'   \item{ok}{Logical. TRUE if the API is reachable and authenticated.}
#'   \item{status}{Character. Status message.}
#'   \item{models}{Character vector. Available models (if retrievable).}
#'
#' @examples
#' \dontrun{
#' xtx_set_api_key("sk-...")
#' xtx_health()
#' }
#'
#' @export
xtx_health <- function() {
  base <- tryCatch(.xtx_get_api_base(), error = function(e) NULL)

  if (is.null(base)) {
    return(list(
        ok = FALSE,
        status = "API base URL not configured",
        models = NULL
      ))
  }

  # Try to list models as a health check
  result <- tryCatch({
      models <- .xtx_get("/v1/models")
      list(
        ok = TRUE,
        status = paste0("Connected to ", base),
        models = if (!is.null(models$data$id)) models$data$id else NULL
      )
    }, error = function(e) {
      # Check if it's an auth error vs connection error
      if (grepl("401|403|Unauthorized|Forbidden", e$message, ignore.case = TRUE)) {
        list(
          ok = FALSE,
          status = paste0("Authentication failed: ", e$message),
          models = NULL
        )
      } else if (grepl("Connection failed", e$message, ignore.case = TRUE)) {
        list(
          ok = FALSE,
          status = paste0("Cannot connect to ", base, ": ", e$message),
          models = NULL
        )
      } else {
        list(
          ok = FALSE,
          status = e$message,
          models = NULL
        )
      }
    })

  result
}

