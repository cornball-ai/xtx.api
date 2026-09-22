% tinyrox says don't edit this manually, but it can't stop you!
\name{.wan2gp_api_await}
\alias{.wan2gp_api_await}
\title{Poll a created WanGP job to completion and download it to \code{output}.}
\usage{
.wan2gp_api_await(base, created, output, timeout, poll_interval = 2)
}
\description{
\code{created} is the response from the create POST (JSON or multipart).
\code{timeout} is the whole budget for the job to finish; the download is
separate. Shared by every video-generation client (t2v, i2v, avatar,
transition), which differ only in how they create the job.
}
\keyword{internal}
