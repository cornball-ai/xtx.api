\name{itv_base}
\alias{itv_base}
\title{Set Image-to-Video API Base URL}
\description{Configure the base URL for the diffusers_api service (CogVideoX).}
\usage{
itv_base(url)
}
\arguments{
  \item{url}{Base URL (e.g., "http://localhost:8000")}
}
\value{
Invisibly returns the previous value
}
\examples{
\dontrun{
  itv_base("http://localhost:8000")
  itv_base("http://gpu-server:8000")
}
}
