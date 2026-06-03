% tinyrox says don't edit this manually, but it can't stop you!
\name{transition_available}
\alias{transition_available}
\title{Check if the Transition Endpoint is Available}
\usage{
transition_available()
}
\value{
`TRUE` if the WanGP API is reachable, `FALSE` otherwise.
}
\description{
Convenience health probe for [transition()]. The transition endpoint is served
by the WanGP API, so this is an alias for [wan2gp_api_available()]: it returns
`TRUE`/`FALSE` and never throws.
}
\examples{
\dontrun{
  if (transition_available()) {
    transition("a.mp4", end_image = "b.png")
  }
}
}
\seealso{
[wan2gp_api_available()]
}
