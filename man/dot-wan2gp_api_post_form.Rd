% tinyrox says don't edit this manually, but it can't stop you!
\name{.wan2gp_api_post_form}
\alias{.wan2gp_api_post_form}
\title{POST a multipart form (the file-input jobs) to the WanGP API.}
\usage{
.wan2gp_api_post_form(url, form_args, timeout = 300)
}
\description{
The create call only uploads and returns a job id, so its timeout covers
the upload, not the generation; the wait is in \code{.wan2gp_api_await}.
}
\keyword{internal}
