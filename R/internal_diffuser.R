# Internal diffuseR integration helpers

# Module-level pipeline cache
.diffuser_cache <- new.env(parent = emptyenv())

#' Check if diffuseR is available
#' @keywords internal
.has_diffuser <- function() {
    requireNamespace("diffuseR", quietly = TRUE)
}

#' Get or create cached diffuseR pipeline
#' @param model_name Model name ("sd21" or "sdxl")
#' @param devices Device configuration
#' @return List with pipeline, model_name, devices
#' @keywords internal
.get_diffuser_pipeline <- function(model_name, devices) {
    # Create cache key from model and devices
    devices_str <- if (is.list(devices)) {
        paste(names(devices), unlist(devices), sep = "=", collapse = "_")
    } else {
        as.character(devices)
    }
    cache_key <- paste0(model_name, "_", devices_str)

    if (is.null(.diffuser_cache[[cache_key]])) {
        message("Loading diffuseR pipeline for ", model_name, "...")

        # Determine unet dtype based on device
        if (is.list(devices)) {
            unet_device <- devices$unet
        } else {
            unet_device <- devices
        }
        if (unet_device == "cuda") {
            unet_dtype <- "float16"
        } else {
            unet_dtype <- NULL
        }

        m2d <- diffuseR::models2devices(model_name = model_name,
                                        devices = devices,
                                        unet_dtype_str = unet_dtype,
                                        download_models = TRUE)

        # Use native text encoders on CUDA to avoid TorchScript device mismatch
        use_native_te <- (unet_device == "cuda")

        pipeline <- diffuseR::load_pipeline(
            model_name = model_name,
            m2d = m2d,
            i2i = TRUE,
            unet_dtype_str = unet_dtype,
            use_native_text_encoder = use_native_te
        )

        .diffuser_cache[[cache_key]] <- list(
            pipeline = pipeline,
            model_name = model_name,
            devices = devices,
            unet_dtype = unet_dtype
        )
        message("diffuseR pipeline loaded and cached.")
    }

    .diffuser_cache[[cache_key]]
}

#' Clear diffuseR pipeline cache
#' @export
clear_diffuser_cache <- function() {
    rm(list = ls(.diffuser_cache), envir = .diffuser_cache)
    invisible(NULL)
}
