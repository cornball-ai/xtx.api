% tinyrox says don't edit this manually, but it can't stop you!
\name{gpuhost_resume}
\alias{gpuhost_resume}
\title{Give the GPU back to the gpuhost before the hold expires}
\usage{
gpuhost_resume()
}
\value{
Invisibly the host's report, including whether a hold was
  actually in force. Resuming a host that was not yielded is not an
  error, and the answer distinguishes the two.
}
\description{
The other half of \code{\link{gpuhost_release}}. Not required -- the
hold expires on its own, which is the property that makes a crashed
caller recoverable -- but a stage that finished early should say so
rather than leaving the host idle for the rest of the window.
}
