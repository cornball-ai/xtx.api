% tinyrox says don't edit this manually, but it can't stop you!
\name{xtx_models}
\alias{xtx_models}
\title{List Available Models}
\usage{
xtx_models()
}
\value{
A data frame of available models, or NULL if the endpoint is not available.
}
\description{
List the image generation models available from the configured API.
}
\examples{
\dontrun{
xtx_set_api_key("sk-...")
xtx_models()
}

}
