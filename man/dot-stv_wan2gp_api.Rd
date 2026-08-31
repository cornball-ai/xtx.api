% tinyrox says don't edit this manually, but it can't stop you!
\name{.stv_wan2gp_api}
\alias{.stv_wan2gp_api}
\title{Speech-to-video via WanGP API}
\usage{
.stv_wan2gp_api(
  image,
  audio,
  output = "stv_output.mp4",
  prompt = "Person speaking naturally, clear speech, facing camera",
  resolution = "720p",
  quality = "balanced",
  timeout = 600,
  sliding_window_size = NULL,
  sliding_window_overlap = NULL,
  sliding_window_overlap_noise = NULL,
  sliding_window_discard_last_frames = NULL
)
}
\description{
Internal function to generate video using the WanGP FastAPI server.
Sends image and audio as multipart/form-data.
}
\keyword{internal}
