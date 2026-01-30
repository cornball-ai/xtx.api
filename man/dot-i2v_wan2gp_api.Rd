% tinyrox says don't edit this manually, but it can't stop you!
\name{.i2v_wan2gp_api}
\alias{.i2v_wan2gp_api}
\title{Image-to-video via WanGP API (without audio)}
\usage{
.i2v_wan2gp_api(
  image,
  output = "i2v_output.mp4",
  prompt = "Camera slowly zooms in",
  num_frames = 97L,
  resolution = "720p",
  quality = "balanced",
  timeout = 600
)
}
\description{
Internal function for i2v endpoint. Uses LTX-2 19B.
}
\keyword{internal}
