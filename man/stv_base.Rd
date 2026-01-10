\name{stv_base}
\alias{stv_base}
\title{Set Speech-to-Video API Base URL}
\description{Configure the base URL for the faster-SadTalker-API service.}
\usage{
stv_base(url)
}
\arguments{
  \item{url}{Base URL (e.g., "http://localhost:10364")}
}
\value{
Invisibly returns the previous value
}
\examples{
\dontrun{
  stv_base("http://localhost:10364")
  stv_base("http://gpu-server:10364")
}
}
