# gpu.ctl integration for xtx.api
#
# Optionally acquires GPU resources before API calls when gpu.ctl is available.
# Enable with: options(xtx.gpuctl = TRUE)

# Service configurations
.gpu_services <- list(
                      diffusers = list(port = 8000, vram = 14, container = "diffusers-api",
                                       health = "/health"),
                      sadtalker = list(
                                       port = 10364,
                                       vram = 12,
                                       container = "sadtalker",
                                       health = "/health"
    )
)

#' Check if gpu.ctl integration is enabled
#' @noRd
.gpuctl_enabled <- function() {
    isTRUE(getOption("xtx.gpuctl", FALSE)) &&
    requireNamespace("gpu.ctl", quietly = TRUE)
}

#' Register xtx.api services with gpu.ctl
#' @noRd
.gpuctl_register_services <- function() {
    if (!.gpuctl_enabled()) {
        return(invisible(FALSE))
    }

    for (name in names(.gpu_services)) {
        svc <- .gpu_services[[name]]
        tryCatch({
            # Only register if not already registered
            existing <- gpu.ctl::gpu_services()
            if (!name %in% existing$name) {
                gpu.ctl::gpu_register(name = name, port = svc$port,
                                      vram = svc$vram,
                                      container = svc$container,
                                      health_endpoint = svc$health)
            }
        }, error = function(e) {
            # Silently ignore registration errors
        })
    }
    invisible(TRUE)
}

#' Acquire GPU for a service if gpu.ctl is enabled
#'
#' @param service Character. Service name: "diffusers" or "sadtalker"
#' @return Invisible TRUE if acquired, FALSE if not using gpu.ctl
#' @noRd
.gpuctl_acquire <- function(service) {
    if (!.gpuctl_enabled()) {
        return(invisible(FALSE))
    }

    .gpuctl_register_services()

    tryCatch({
        gpu.ctl::gpu_acquire(service)
        invisible(TRUE)
    }, error = function(e) {
        warning("gpu.ctl: ", e$message, call. = FALSE)
        invisible(FALSE)
    })
}
