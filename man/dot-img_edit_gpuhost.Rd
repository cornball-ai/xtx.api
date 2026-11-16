% tinyrox says don't edit this manually, but it can't stop you!
\name{.img_edit_gpuhost}
\alias{.img_edit_gpuhost}
\title{Image edit on a gpu.ctl host}
\usage{
.img_edit_gpuhost(
  image,
  prompt,
  size = NULL,
  steps = NULL,
  seed = NULL,
  file = NULL,
  timeout = 300,
  entry = getOption("xtx.gpuhost_edit_entry", "flux3-klein")
)
}
\description{
The reference travels as \code{image_b64} to an entry whose generator
edits (the fleet's \code{flux3-klein}, \code{options(xtx.gpuhost_edit_entry)}
to name another) and the reply is PNG bytes, the same wire as
\code{\link{tti}}'s gpuhost backend. The entry's own defaults stand for
what the caller leaves NULL: its step count, and the reference's size
for the output.
}
\keyword{internal}
