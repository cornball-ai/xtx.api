\name{rvf_interp}
\alias{rvf_interp}
\title{Interpolate Between Two Images}
\description{Generate an intermediate frame between two images using RIFE. Wrapper around rife::rife_interpolate().}
\usage{
rvf_interp(img0, img1, output, timestep, model, gpu)
}
\arguments{
  \item{img0}{Path to the first image}
  \item{img1}{Path to the second image}
  \item{output}{Path for output image (default: auto-generated)}
  \item{timestep}{Interpolation position 0-1 (default: 0.5)}
  \item{model}{RIFE model: "rife-v4.6" (default) or "rife-v4"}
  \item{gpu}{GPU device ID, -1 for CPU (default: 0)}
}
\value{
Path to the output image (invisibly)
}
\examples{
\dontrun{
# Middle frame between two images
rvf_interp("frame1.png", "frame2.png", "middle.png")

# 25% between first and second
rvf_interp("a.png", "b.png", "out.png", timestep = 0.25)
}

}
