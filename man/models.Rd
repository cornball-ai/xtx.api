% tinyrox says don't edit this manually, but it can't stop you!
\name{models}
\alias{models}
\title{List Available Models}
\usage{
models()
}
\value{
A data frame of available models, or NULL if the endpoint is not available.
}
\description{
List the image generation models available from the configured API.
}
\examples{
\dontrun{
set_api_key("sk-...")
models()
}

}
