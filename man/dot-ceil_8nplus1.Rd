% tinyrox says don't edit this manually, but it can't stop you!
\name{.ceil_8nplus1}
\alias{.ceil_8nplus1}
\title{Snap a frame count UP to LTX-2's 8n+1 grid}
\usage{
.ceil_8nplus1(n)
}
\description{
For sizing generation from audio: the video must always cover the audio,
so the frame budget rounds up. Nearest-rounding here shaved up to 4 frames
off a chunk's speech and desynced whole chained tracks (the shortfall also
contaminated the conditioning-head measurement downstream).
}
\keyword{internal}
