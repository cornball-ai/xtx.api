% tinyrox says don't edit this manually, but it can't stop you!
\name{.transition_wan2gp_api}
\alias{.transition_wan2gp_api}
\title{WanGP API Transition Backend}
\usage{
.transition_wan2gp_api(start_clip = NULL, image_start = NULL, end_image = NULL,
                       keyframe_images = NULL, keyframe_positions = NULL,
                       prompt = NULL, audio = NULL, num_frames = NULL,
                       conditioning_frames = NULL, fill_window = FALSE,
                       sliding_window_size = NULL,
                       sliding_window_overlap = NULL,
                       sliding_window_overlap_noise = NULL,
                       sliding_window_discard_last_frames = NULL, fps = 24,
                       window = 129, resolution = "720p", quality = "balanced",
                       seed = NULL, output = "transition_output.mp4",
                       timeout = 1800)
}
\description{
WanGP API Transition Backend
}
\keyword{internal}
