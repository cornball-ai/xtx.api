% tinyrox says don't edit this manually, but it can't stop you!
\name{gpuhost_health}
\alias{gpuhost_health}
\title{Probe the gpuhost service before a batch starts}
\usage{
gpuhost_health(entries = NULL)
}
\arguments{
\item{entries}{Optional character vector of catalog entry names this
run will ask for.}
}
\value{
The health payload's \code{value}, invisibly.
}
\description{
GET /health against the configured base, and -- when \code{entries} is
given -- a check that the host's catalog actually carries them. "ok"
alone says the front is serving and nothing about the catalog behind
it, so a base pointed at the wrong host in the fleet passes and then
fails on the first real request.
}
\examples{
\dontrun{
  old <- options(xtx.gpuhost_base = "http://gpu-server:7878")
  gpuhost_health(entries = c("flux2-klein-4b", "ltx-2.3"))
  options(old)
}
}
