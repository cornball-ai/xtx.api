\name{stv_available}
\alias{stv_available}
\title{Check if SadTalker Service is Available}
\description{Quick check if the SadTalker API is reachable and healthy. Unlike stv_health(), this returns TRUE/FALSE and never throws errors.}
\usage{
stv_available(port, timeout)
}
\arguments{
  \item{port}{Port to check (default from SADTALKER_PORT env var or 10364)}
  \item{timeout}{Timeout in seconds (default 2)}
}
\value{
TRUE if service is available, FALSE otherwise
}
\examples{
\dontrun{
  if (stv_available()) {
    stv("portrait.jpg", "speech.wav")
  }
}
}
