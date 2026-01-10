\name{xtx_set_api_base}
\alias{xtx_set_api_base}
\title{Set API Base URL}
\description{Configure the base URL for the image generation API. Defaults to OpenAI's API endpoint.}
\usage{
xtx_set_api_base(url)
}
\arguments{
  \item{url}{Character. The base URL (without trailing slash).}
}
\value{
Invisibly returns the previous base URL value.
}
\examples{
\dontrun{
# Use OpenAI
xtx_set_api_base("https://api.openai.com")

# Use a local server
xtx_set_api_base("http://localhost:8000")
}

}
