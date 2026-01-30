% tinyrox says don't edit this manually, but it can't stop you!
\name{tti_base}
\alias{tti_base}
\title{Set Text-to-Image API Base URL}
\usage{
tti_base(url)
}
\arguments{
\item{url}{Base URL (e.g., "http://localhost:8000")}
}
\value{
Invisibly returns the previous value
}
\description{
Configure the base URL for the diffusers_api service (Z-Image-Turbo, SD).
}
\examples{
\dontrun{
  tti_base("http://localhost:8000")
}
}
