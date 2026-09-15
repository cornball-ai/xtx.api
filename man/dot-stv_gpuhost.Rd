% tinyrox says don't edit this manually, but it can't stop you!
\name{.stv_gpuhost}
\alias{.stv_gpuhost}
\title{stv() via the gpuhost: start image + audio -> audio-driven talking head}
\usage{
.stv_gpuhost(
  image,
  audio,
  output,
  prompt,
  resolution,
  quality,
  seed = NULL,
  timeout = 600
)
}
\description{
`quality` is accepted for the contract and not sent: LTX-2.3's distilled
checkpoint has one schedule, the same reason the diffuseR backend
ignores it.
}
\keyword{internal}
