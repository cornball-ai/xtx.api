% tinyrox says don't edit this manually, but it can't stop you!
\name{health}
\alias{health}
\title{Check API Health}
\usage{
health()
}
\value{
A list with:
  \item{ok}{Logical. TRUE if the API is reachable and authenticated.}
  \item{status}{Character. Status message.}
  \item{models}{Character vector. Available models (if retrievable).}
}
\description{
Check connectivity and authentication with the configured API endpoint.
}
\examples{
\dontrun{
set_api_key("sk-...")
health()
}

}
