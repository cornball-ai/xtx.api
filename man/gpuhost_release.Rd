% tinyrox says don't edit this manually, but it can't stop you!
\name{gpuhost_release}
\alias{gpuhost_release}
\title{Hand the GPU back to the caller, for a stated window}
\usage{
gpuhost_release(hold_s)
}
\arguments{
\item{hold_s}{Seconds to keep the device yielded. Required: exclusive
use of a shared card is a decision, and no default can make it.}
}
\value{
Invisibly the host's report: whether anything was actually
  released, which entry, and the granted hold.
}
\description{
Asks the gpuhost to deactivate its resident entry NOW and to refuse
activating anything for \code{hold_s} seconds, so the caller can use
the same card without racing the host's idle timer.
}
\details{
The case it exists for: a stage that generates images on the host and
then loads a video model in this process, on the same board. The host's
idle release fires only after a lull, so the two overlap by whatever the
timer has left -- and the failure is a CUDA OOM well into the stage.

The window is BOUNDED (the host refuses more than 3600 s) so a caller
that dies does not leave the fleet's card yielded forever. A stage
longer than the hold calls this again per unit of work; re-arming
extends it, and that is also what lets a crash recover on its own.

Refused on a co-resident catalog, where holding the card together is
what the declaration means.

}
\examples{
\dontrun{
  old <- options(xtx.gpuhost_base = "http://gpu-server:7878")
  gpuhost_release(hold_s = 600)   # the card is ours for ten minutes
  # ... load and run a model in this process ...
  gpuhost_resume()
  options(old)
}
}
