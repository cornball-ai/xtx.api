# Background removal using rembg container

#' Set Rembg API Base URL
#'
#' Configure the base URL for the rembg background removal service.
#'
#' @param url Base URL (e.g., "http://localhost:7824")
#' @return Invisibly returns the previous value
#' @examples
#' \dontrun{
#'   rembg_base("http://localhost:7824")
#'   rembg_base("http://gpu-server:7824")
#' }
#' @export
rembg_base <- function(url) {
    if (!is.character(url) || length(url) != 1 || nchar(url) == 0) {
        stop("'url' must be a non-empty character string", call. = FALSE)
    }
    old <- getOption("xtx.rembg_base")
    options(xtx.rembg_base = url)
    invisible(old)
}

#' Get Rembg API Base URL
#' @keywords internal
.rembg_get_base <- function() {
    base <- getOption("xtx.rembg_base")
    if (is.null(base) || nchar(base) == 0) {
        stop("Rembg API base URL not set. Use rembg_base() to configure it.\n",
             "Example: rembg_base(\"http://localhost:7824\")", call. = FALSE)
    }
    base
}

#' Check Rembg Service Health
#'
#' Check if the rembg background removal service is reachable.
#'
#' @return TRUE if service is reachable, FALSE otherwise
#' @export
rembg_health <- function() {
    base <- tryCatch(.rembg_get_base(), error = function(e) NULL)
    if (is.null(base)) {
        return(FALSE)
    }

    tryCatch({
        h <- curl::new_handle()
        curl::handle_setopt(h, timeout = 5, nobody = TRUE)
        response <- curl::curl_fetch_memory(paste0(base, "/api"), handle = h)
        response$status_code < 500
    }, error = function(e) FALSE)
}

#' Remove Image Background
#'
#' Remove the background from an image using the rembg service (U2-Net).
#' Returns a PNG with transparent background. Works on any background color -
#' no greenscreen needed.
#'
#' The rembg service must be running. Start it with:
#' \code{docker run -d --name rembg -p 7824:7824 danielgatis/rembg s --host 0.0.0.0 --port 7824}
#'
#' @param image Character. Path to the input image file.
#' @param file Character or NULL. Output path. If NULL, replaces the input file
#'   extension with \code{_rembg.png}.
#' @param model Character. Segmentation model to use. Default "u2net".
#'   Options: "u2net", "u2netp", "u2net_human_seg", "u2net_cloth_seg",
#'   "silueta", "isnet-general-use", "isnet-anime", "birefnet-general".
#' @return The output file path (invisibly).
#'
#' @examples
#' \dontrun{
#' rembg_base("http://localhost:7824")
#'
#' # Basic usage
#' rembg("photo.png")  # saves to photo_rembg.png
#'
#' # Specify output
#' rembg("photo.png", file = "cutout.png")
#'
#' # Use anime-optimized model
#' rembg("anime.png", model = "isnet-anime")
#' }
#'
#' @export
rembg <- function(image, file = NULL, model = "u2net") {
    if (!file.exists(image)) {
        stop("Image file not found: ", image, call. = FALSE)
    }

    # Default output path
    if (is.null(file)) {
        file <- sub("(\\.[^.]+)$", "_rembg.png", image)
    }

    base <- .rembg_get_base()
    url <- paste0(base, "/api/remove")

    # Add model parameter if not default
    if (model != "u2net") {
        url <- paste0(url, "?model=", model)
    }

    h <- curl::new_handle()
    curl::handle_setopt(h, timeout = 120)
    curl::handle_setform(h, file = curl::form_file(image))

    response <- tryCatch(
                         curl::curl_fetch_memory(url, handle = h),
                         error = function(e) {
        stop("Rembg request failed: ", e$message, "\n",
             "Is the rembg container running? Check with: rembg_health()",
             call. = FALSE)
    }
    )

    if (response$status_code >= 400) {
        stop("Rembg error (HTTP ", response$status_code, "): ",
             rawToChar(response$content), call. = FALSE)
    }

    writeBin(response$content, file)
    message("Saved to: ", file)
    invisible(file)
}

