% tinyrox says don't edit this manually, but it can't stop you!
\name{supported_models}
\alias{supported_models}
\title{Get Supported Image Models}
\usage{
supported_models(backend = NULL)
}
\arguments{
\item{backend}{Character or NULL. Filter by backend: "openai", "diffuser", or NULL for all.}
}
\value{
A data frame with columns: model, backend, type, description.
}
\description{
Returns information about known image generation models by backend.
}
\examples{
supported_models()
supported_models("diffuser")

}
