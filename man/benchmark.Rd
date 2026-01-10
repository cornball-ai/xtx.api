\name{benchmark}
\alias{benchmark}
\title{Benchmark a Generation Function}
\description{Run a generation function and return timing information along with results.}
\usage{
benchmark(expr, times, verbose)
}
\arguments{
  \item{expr}{An expression to benchmark (typically a call to tti, itv, or stv)}
  \item{times}{Number of times to repeat (default: 1)}
  \item{verbose}{Print timing information (default: TRUE)}
}
\value{
A list with:
  \\item\{result\}\{The result from the last run\}
  \\item\{elapsed\}\{Elapsed time in seconds for each run\}
  \\item\{mean\}\{Mean elapsed time\}
  \\item\{total\}\{Total elapsed time\}
}
\examples{
\dontrun{
  # Benchmark text-to-image
  result <- benchmark(tti("A sunset", backend = "diffusers_api"))

  # Multiple runs for comparison
  result <- benchmark(tti("A cat", backend = "openai"), times = 3)
  result$mean  # average time

  # Compare backends
  t1 <- benchmark(tti("A dog", backend = "openai"))
  t2 <- benchmark(tti("A dog", backend = "diffusers_api"))
  cat("OpenAI:", t1$elapsed, "s\n")
  cat("diffusers_api:", t2$elapsed, "s\n")
}

}
