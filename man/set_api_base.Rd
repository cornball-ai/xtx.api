% tinyrox says don't edit this manually, but it can't stop you!
\name{set_api_base}
\alias{set_api_base}
\title{Set API Base URL}
\usage{
set_api_base(url)
}
\arguments{
\item{url}{Character. The base URL (without trailing slash).}
}
\value{
Invisibly returns the previous base URL value.
}
\description{
Configure the base URL for the image generation API.
Defaults to OpenAI's API endpoint.
}
\examples{
\dontrun{
# Use OpenAI
set_api_base("https://api.openai.com")

# Use a local server
set_api_base("http://localhost:8000")
}

}
