# Internal HTTP request helpers

#' Get API base URL
#' @keywords internal
.xtx_get_api_base <- function() {
  base <- getOption("xtxapi.api_base")
  if (is.null(base) || nchar(base) == 0) {
    stop(
      "API base URL not set. Use xtx_set_api_base() to configure it.\n",
      "Example: xtx_set_api_base(\"https://api.openai.com\")",
      call. = FALSE
    )
  }
  base
}

#' Get API key (optional for some backends)
#' @keywords internal
.xtx_get_api_key <- function(required = TRUE) {
  key <- getOption("xtxapi.api_key")
  if (required && (is.null(key) || nchar(key) == 0)) {
    stop(
      "API key not set. Use xtx_set_api_key() to configure it.\n",
      "Example: xtx_set_api_key(\"sk-...\")",
      call. = FALSE
    )
  }
  key
}

#' Get timeout setting
#' @keywords internal
.xtx_get_timeout <- function() {
  getOption("xtxapi.timeout", 120)
}

#' Make HTTP request
#' @keywords internal
.xtx_request <- function(endpoint, method = "GET", body = NULL,
                         expect_binary = FALSE, content_type = "application/json") {
  base <- .xtx_get_api_base()
  url <- paste0(base, endpoint)

  h <- curl::new_handle()
  timeout <- .xtx_get_timeout()
  curl::handle_setopt(h, timeout = timeout)

  # Build headers
  headers <- c("Content-Type" = content_type)
  api_key <- .xtx_get_api_key(required = FALSE)
  if (!is.null(api_key) && nchar(api_key) > 0) {
    headers <- c(headers, "Authorization" = paste("Bearer", api_key))
  }
  curl::handle_setheaders(h, .list = headers)

  # Handle POST body
  if (method == "POST" && !is.null(body)) {
    json_body <- jsonlite::toJSON(body, auto_unbox = TRUE)
    curl::handle_setopt(h, post = TRUE, postfields = json_body)
  }

  # Make request
  response <- tryCatch(
    curl::curl_fetch_memory(url, handle = h),
    error = function(e) {
      stop("Connection failed: ", e$message, call. = FALSE)
    }
  )

  # Check HTTP status
  status <- response$status_code
  if (status >= 400) {
    err_msg <- .xtx_parse_error(response$content)
    stop("API error (", status, "): ", err_msg, call. = FALSE)
  }

  # Return binary or JSON
  if (expect_binary) {
    response$content
  } else {
    tryCatch(
      jsonlite::fromJSON(rawToChar(response$content)),
      error = function(e) rawToChar(response$content)
    )
  }
}

#' Parse error message from API response
#' @keywords internal
.xtx_parse_error <- function(content) {
  tryCatch({
    err <- jsonlite::fromJSON(rawToChar(content))
    if (!is.null(err$error$message)) err$error$message
    else if (!is.null(err$error)) as.character(err$error)
    else if (!is.null(err$detail)) as.character(err$detail)
    else rawToChar(content)
  }, error = function(e) rawToChar(content))
}

#' POST JSON request
#' @keywords internal
.xtx_post_json <- function(endpoint, body, expect_binary = FALSE) {
  .xtx_request(endpoint, method = "POST", body = body, expect_binary = expect_binary)
}

#' GET request
#' @keywords internal
.xtx_get <- function(endpoint) {
  .xtx_request(endpoint, method = "GET", expect_binary = FALSE)
}

#' POST multipart form data
#' @keywords internal
.xtx_post_multipart <- function(endpoint, form_data, expect_binary = FALSE) {
  base <- .xtx_get_api_base()
  url <- paste0(base, endpoint)

  h <- curl::new_handle()
  timeout <- .xtx_get_timeout()
  curl::handle_setopt(h, timeout = timeout)

  # Add auth header
  api_key <- .xtx_get_api_key(required = FALSE)
  if (!is.null(api_key) && nchar(api_key) > 0) {
    curl::handle_setheaders(h, "Authorization" = paste("Bearer", api_key))
  }

  # Set form data

curl::handle_setform(h, .list = form_data)

  # Make request
  response <- tryCatch(
    curl::curl_fetch_memory(url, handle = h),
    error = function(e) {
      stop("Connection failed: ", e$message, call. = FALSE)
    }
  )

  # Check HTTP status
  status <- response$status_code
  if (status >= 400) {
    err_msg <- .xtx_parse_error(response$content)
    stop("API error (", status, "): ", err_msg, call. = FALSE)
  }

  # Return binary or JSON
  if (expect_binary) {
    response$content
  } else {
    tryCatch(
      jsonlite::fromJSON(rawToChar(response$content)),
      error = function(e) rawToChar(response$content)
    )
  }
}
