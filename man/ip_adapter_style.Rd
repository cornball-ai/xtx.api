\name{ip_adapter_style}
\alias{ip_adapter_style}
\title{IP-Adapter for Style Transfer (Convenience Function)}
\description{Shortcut for style transfer using IP-Adapter Plus.}
\usage{
ip_adapter_style(prompt, style_image, file, scale, ...)
}
\arguments{
  \item{prompt}{Character. What to generate.}
  \item{style_image}{Character. Path to style reference image.}
  \item{file}{Character. Output file path.}
  \item{scale}{Numeric. Style strength (0-1). Default 0.8.}
  \item{...}{Additional arguments passed to ip_adapter().}
}
\value{
Invisibly returns the file path.
}
\examples{
\dontrun{
ip_adapter_style(
  prompt = "A mountain landscape at sunset",
  style_image = "van_gogh_starry_night.jpg",
  file = "mountain_vangogh.png"
)
}

}
