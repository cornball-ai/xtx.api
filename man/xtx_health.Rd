\name{xtx_health}
\alias{xtx_health}
\title{Check API Health}
\description{Check connectivity and authentication with the configured API endpoint.}
\usage{
xtx_health()
}
\value{
A list with:
  \\item\{ok\}\{Logical. TRUE if the API is reachable and authenticated.\}
  \\item\{status\}\{Character. Status message.\}
  \\item\{models\}\{Character vector. Available models (if retrievable).\}
}
\examples{
\dontrun{
xtx_set_api_key("sk-...")
xtx_health()
}

}
