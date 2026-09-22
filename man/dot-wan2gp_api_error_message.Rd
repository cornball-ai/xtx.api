% tinyrox says don't edit this manually, but it can't stop you!
\name{.wan2gp_api_error_message}
\alias{.wan2gp_api_error_message}
\title{Text-to-video via WanGP API}
\usage{
.wan2gp_api_error_message(content)
}
\description{
Extract an error message from a WanGP API response body.
}
\details{
The API reports errors as JSON \code{{detail: {error, message}}}; fall
back to the raw text when it is not JSON.
}
\keyword{internal}
