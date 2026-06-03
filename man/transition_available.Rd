% tinyrox says don't edit this manually, but it can't stop you!
\name{transition_available}
\alias{transition_available}
\title{Check if the WanGP Transition Endpoint is Reachable}
\usage{
transition_available(timeout = 2)
}
\arguments{
\item{timeout}{Timeout in seconds (default 2).}
}
\value{
TRUE if the service responds 200 on /health, FALSE otherwise.
}
\description{
Quick check that the WanGP API is reachable and healthy. Returns TRUE/FALSE
and never throws. Configure the base URL first with \code{wan2gp_api_base()}.
}
\examples{
\dontrun{
  wan2gp_api_base("http://localhost:8000")
  if (transition_available()) transition("clipA.mp4", end_image = "b.png")
}
}
