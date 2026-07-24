% tinyrox says don't edit this manually, but it can't stop you!
\name{rembg_base}
\alias{rembg_base}
\title{Set Rembg API Base URL}
\usage{
rembg_base(url)
}
\arguments{
\item{url}{Base URL (e.g., "http://localhost:7824")}
}
\value{
Invisibly returns the previous value
}
\description{
Configure the base URL for the rembg background removal service.
}
\examples{
\dontrun{
  rembg_base("http://localhost:7824")
  rembg_base("http://gpu-server:7824")
}
}
