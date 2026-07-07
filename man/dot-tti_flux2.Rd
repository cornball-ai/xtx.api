% tinyrox says don't edit this manually, but it can't stop you!
\name{.tti_flux2}
\alias{.tti_flux2}
\title{Text-to-image via diffuseR FLUX.2 klein-4B}
\usage{
.tti_flux2(prompt, size = NULL, seed = NULL, file = NULL)
}
\description{
Guidance-free 4-step distilled model; the pipeline is cached in the
session like the SD pipelines (first call pays the ~32s load, later
calls generate in ~48s at 1024x1024 on a 16GB card).
}
\keyword{internal}
