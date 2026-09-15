% tinyrox says don't edit this manually, but it can't stop you!
\name{.transition_gpuhost}
\alias{.transition_gpuhost}
\title{transition() via the gpuhost: continue a clip's tail, audio-driven}
\usage{
.transition_gpuhost(
  start_clip = NULL,
  image_start = NULL,
  prompt = NULL,
  audio = NULL,
  num_frames = NULL,
  conditioning_frames = NULL,
  fps = 24,
  resolution = "720p",
  quality = "balanced",
  seed = NULL,
  output = file.path(tempdir(), "transition_output.mp4"),
  timeout = 1800
)
}
\description{
Matches the diffuseR contract: from `start_clip` the output carries
`conditioning_frames` replayed frames followed by the continuation
(`num_frames + conditioning_frames - 1` frames on the grid), and the
audio is delayed by the head so it lines up with the generated part.
From `image_start` it is `.stv_gpuhost` with an explicit frame count.
}
\keyword{internal}
