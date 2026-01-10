\name{xtx_models}
\alias{xtx_models}
\title{List Available Models}
\description{List the image generation models available from the configured API.}
\usage{
xtx_models()
}
\value{
A data frame of available models, or NULL if the endpoint is not available.
}
\examples{
\dontrun{
xtx_set_api_key("sk-...")
xtx_models()
}

}
