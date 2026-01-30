% tinyrox says don't edit this manually, but it can't stop you!
\name{wan2gp_api_base}
\alias{wan2gp_api_base}
\title{Set WanGP API Base URL}
\usage{
wan2gp_api_base(url)
}
\arguments{
\item{url}{Base URL (e.g., "http://localhost:8000")}
}
\value{
Invisibly returns the previous value
}
\description{
Configure the base URL for the WanGP FastAPI service.
}
\examples{
\dontrun{
  wan2gp_api_base("http://localhost:8000")
  wan2gp_api_base("http://gpu-server:8000")
}
}
