\name{compare_backends}
\alias{compare_backends}
\title{Compare Multiple Backends}
\description{Run the same prompt across multiple backends and compare timing.}
\usage{
compare_backends(prompt, backends, ...)
}
\arguments{
  \item{prompt}{Text prompt for image generation}
  \item{backends}{Character vector of backends to compare (default: all available)}
  \item{...}{Additional arguments passed to tti()}
}
\value{
A data frame with backend, elapsed time, and status
}
\examples{
\dontrun{
  # Compare all available backends
  results <- compare_backends("A beautiful sunset")

  # Compare specific backends
  results <- compare_backends("A cat", backends = c("openai", "diffusers_api"))
}

}
