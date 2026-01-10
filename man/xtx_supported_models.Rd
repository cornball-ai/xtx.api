\name{xtx_supported_models}
\alias{xtx_supported_models}
\title{Get Supported Image Models}
\description{Returns information about known image generation models by backend.}
\usage{
xtx_supported_models(backend)
}
\arguments{
  \item{backend}{Character or NULL. Filter by backend: "openai", "diffuser", or NULL for all.}
}
\value{
A data frame with columns: model, backend, type, description.
}
\examples{
xtx_supported_models()
xtx_supported_models("diffuser")

}
