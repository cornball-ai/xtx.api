% tinyrox says don't edit this manually, but it can't stop you!
\name{.transition_diffuseR}
\alias{.transition_diffuseR}
\title{transition() via diffuseR: continue a clip's tail, audio-driven}
\usage{
.transition_diffuseR(start_clip = NULL, image_start = NULL, prompt = NULL,
                     audio = NULL, num_frames = NULL,
                     conditioning_frames = NULL, fps = 24, resolution = "720p",
                     quality = "balanced", seed = NULL,
                     output = "transition_output.mp4", timeout = NULL)
}
\description{
Matches the wan2gp_api contract: the output contains
\code{conditioning_frames} overlap frames from \code{start_clip}
followed by the generated continuation (total
\code{num_frames + conditioning_frames - 1} frames).
}
\keyword{internal}
