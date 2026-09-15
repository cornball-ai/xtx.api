# Benchmarking utilities

#' Benchmark a Generation Function
#'
#' Run a generation function and return timing information along with results.
#'
#' @param expr An expression to benchmark (typically a call to tti, itv, or stv)
#' @param times Number of times to repeat (default: 1)
#' @param verbose Print timing information (default: TRUE)
#' @return A list with:
#'   \item{result}{The result from the last run}
#'   \item{elapsed}{Elapsed time in seconds for each run}
#'   \item{mean}{Mean elapsed time}
#'   \item{total}{Total elapsed time}
#'
#' @examples
#' \dontrun{
#'   # Benchmark text-to-image
#'   result <- benchmark(tti("A sunset", backend = "diffusers_api"))
#'
#'   # Multiple runs for comparison
#'   result <- benchmark(tti("A cat", backend = "openai"), times = 3)
#'   result$mean  # average time
#'
#'   # Compare backends
#'   t1 <- benchmark(tti("A dog", backend = "openai"))
#'   t2 <- benchmark(tti("A dog", backend = "diffusers_api"))
#'   cat("OpenAI:", t1$elapsed, "s\n")
#'   cat("diffusers_api:", t2$elapsed, "s\n")
#' }
#'
#' @export
benchmark <- function(expr, times = 1L, verbose = TRUE) {
    times <- as.integer(times)
    if (times < 1) {
        times <- 1L
    }

    elapsed <- numeric(times)
    result <- NULL

    for (i in seq_len(times)) {
        start <- Sys.time()
        result <- eval(substitute(expr), parent.frame())
        end <- Sys.time()
        elapsed[i] <- as.numeric(difftime(end, start, units = "secs"))

        if (verbose) {
            message(sprintf("Run %d: %.2f seconds", i, elapsed[i]))
        }
    }

    mean_time <- mean(elapsed)
    total_time <- sum(elapsed)

    if (verbose && times > 1) {
        message(sprintf("Mean: %.2f seconds (total: %.2f seconds)", mean_time,
                        total_time))
    }

    list(
         result = result,
         elapsed = elapsed,
         mean = mean_time,
         total = total_time
    )
}

#' Compare Multiple Backends
#'
#' Run the same prompt across multiple backends and compare timing.
#'
#' @param prompt Text prompt for image generation
#' @param backends Character vector of backends to compare (default: all available)
#' @param ... Additional arguments passed to tti()
#' @return A data frame with backend, elapsed time, and status
#'
#' @examples
#' \dontrun{
#'   # Compare all available backends
#'   results <- compare_backends("A beautiful sunset")
#'
#'   # Compare specific backends
#'   results <- compare_backends("A cat", backends = c("openai", "diffusers_api"))
#' }
#'
#' @export
compare_backends <- function(prompt, backends = NULL, ...) {
    if (is.null(backends)) {
        backends <- c("openai", "diffuser", "diffusers_api")
    }

    results <- data.frame(backend = character(), elapsed = numeric(),
                          status = character(), stringsAsFactors = FALSE)

    for (backend in backends) {
        message("Testing backend: ", backend)

        status <- "ok"
        elapsed <- NA_real_

        tryCatch({
            start <- Sys.time()
            tti(prompt, backend = backend, ...)
            end <- Sys.time()
            elapsed <- as.numeric(difftime(end, start, units = "secs"))
        }, error = function(e) {
            status <<- paste("error:", e$message)
        })

        results <- rbind(results, data.frame(
                backend = backend,
                elapsed = elapsed,
                status = status,
                stringsAsFactors = FALSE
            ))
    }

    results
}
