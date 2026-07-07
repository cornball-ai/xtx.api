% tinyrox says don't edit this manually, but it can't stop you!
\name{diffuseR_backend}
\alias{diffuseR_backend}
\title{Native diffuseR backend for stv() and transition()}
\description{
Runs LTX-2.3 in-process through the diffuseR package (NF4-quantized
22B checkpoint, JIT block stack) instead of the wan2gp-api
container: no docker, no HTTP, same calling contracts. The
generation pipeline loads once per session and is reused across
chunks; prompt embeddings are memoized per prompt text (a track's
chunks share one prompt, so Gemma3 runs once per track).
}
\keyword{internal}
