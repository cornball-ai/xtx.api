\name{xtx_set_api_key}
\alias{xtx_set_api_key}
\title{Set API Key}
\description{Configure the API key for authentication with image generation services.}
\usage{
xtx_set_api_key(key)
}
\arguments{
  \item{key}{Character. The API key string.}
}
\value{
Invisibly returns the previous API key value.
}
\examples{
\dontrun{
xtx_set_api_key("sk-...")
}

}
