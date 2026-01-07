# gpuctl integration for xtxapi
#
# Optionally acquires GPU resources before API calls when gpuctl is available.
# Enable with: options(xtxapi.gpuctl = TRUE)

# Service configurations
.xtx_gpu_services <- list(
  diffusers = list(
    port = 8000,
    vram = 14,
    container = "diffusers-api",
    health = "/health"
  ),
  sadtalker = list(
    port = 10364,
    vram = 12,
    container = "sadtalker",
    health = "/health"
  )
)

#' Check if gpuctl integration is enabled
#' @noRd
.gpuctl_enabled <- function() {
  isTRUE(getOption("xtxapi.gpuctl", FALSE)) &&
    requireNamespace("gpuctl", quietly = TRUE)
}

#' Register xtxapi services with gpuctl
#' @noRd
.gpuctl_register_services <- function() {
  if (!.gpuctl_enabled()) return(invisible(FALSE))

  for (name in names(.xtx_gpu_services)) {
    svc <- .xtx_gpu_services[[name]]
    tryCatch({
      # Only register if not already registered
      existing <- gpuctl::gpu_services()
      if (!name %in% existing$name) {
        gpuctl::gpu_register(
          name = name,
          port = svc$port,
          vram = svc$vram,
          container = svc$container,
          health_endpoint = svc$health
        )
      }
    }, error = function(e) {
      # Silently ignore registration errors
    })
  }
  invisible(TRUE)
}

#' Acquire GPU for a service if gpuctl is enabled
#'
#' @param service Character. Service name: "diffusers" or "sadtalker"
#' @return Invisible TRUE if acquired, FALSE if not using gpuctl
#' @noRd
.gpuctl_acquire <- function(service) {
  if (!.gpuctl_enabled()) return(invisible(FALSE))

  .gpuctl_register_services()

  tryCatch({
    gpuctl::gpu_acquire(service)
    invisible(TRUE)
  }, error = function(e) {
    warning("gpuctl: ", e$message, call. = FALSE)
    invisible(FALSE)
  })
}
