% tinyrox says don't edit this manually, but it can't stop you!
\name{.transition_frames}
\alias{.transition_frames}
\title{Frame count and audio lead for a diffuseR or gpuhost transition}
\usage{
.transition_frames(
  audio,
  num_frames,
  conditioning_frames,
  fps,
  audio_includes_head,
  continuation
)
}
\value{
\code{list(total, lead_s)}: frames to render and seconds of
  silence to put in front of the audio.
}
\description{
A continuation renders \code{num_frames} new frames after a
\code{conditioning_frames} head, \code{num_frames + conditioning_frames - 1}
in all, and its audio is delayed by the head unless
\code{audio_includes_head}; then the audio covers the whole clip and,
with no \code{num_frames}, sizes it. A start from a still has no head.
}
\keyword{internal}
