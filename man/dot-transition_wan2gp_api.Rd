% tinyrox says don't edit this manually, but it can't stop you!
\name{.transition_wan2gp_api}
\alias{.transition_wan2gp_api}
\title{Transition via WanGP API}
\usage{
.transition_wan2gp_api(start_clip, end_image = NULL, output = "transition.mp4",
                       prompt = "", num_frames = 121L,
                       conditioning_frames = 17L, keyframe_images = NULL,
                       keyframe_positions = NULL, audio = NULL,
                       resolution = "720p", quality = "balanced", seed = -1L,
                       timeout = 1800)
}
\description{
Internal worker for [transition()]. POSTs the inputs as multipart/form-data to
the WanGP `/transition` endpoint and writes the returned MP4.
}
\keyword{internal}
