% tinyrox says don't edit this manually, but it can't stop you!
\name{clear_diffuser_cache}
\alias{clear_diffuser_cache}
\title{Clear diffuseR pipeline cache}
\usage{
clear_diffuser_cache()
}
\value{
Invisibly \code{NULL}; called for its side effect.
}
\description{
Drops every cached diffuseR pipeline so the next call reloads it,
freeing the GPU memory the pipelines held.
}
\examples{
clear_diffuser_cache()
}
