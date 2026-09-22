% tinyrox says don't edit this manually, but it can't stop you!
\name{.t2v_wan2gp_api}
\alias{.t2v_wan2gp_api}
\title{Internal function for the t2v endpoint. Uses LTX-2.}
\usage{
.t2v_wan2gp_api(
  prompt,
  output = "t2v_output.mp4",
  num_frames = 97L,
  resolution = "720p",
  quality = "balanced",
  timeout = 600,
  poll_interval = 2
)
}
\description{
Generation holds the GPU for minutes, so the API is a job: create it,
poll until it is done, then download the file. \code{timeout} is the
whole budget for the job to complete, not a single request.
}
\keyword{internal}
