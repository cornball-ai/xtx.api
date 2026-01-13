\name{rvf_smooth}
\alias{rvf_smooth}
\title{Smooth Video with Frame Interpolation}
\description{Increase video frame rate by generating intermediate frames using RIFE. Wrapper around rife::rife_video().}
\usage{
rvf_smooth(input, output, factor, model, gpu)
}
\arguments{
  \item{input}{Path to input video file}
  \item{output}{Path for output video file (default: "smooth.mp4")}
  \item{factor}{Frame multiplication factor: 2 = double FPS, 4 = 4x FPS (default: 2)}
  \item{model}{RIFE model: "rife-v4.6" (default) or "rife-v4"}
  \item{gpu}{GPU device ID, -1 for CPU (default: 0)}
}
\value{
Path to the output video (invisibly)
}
\examples{
\dontrun{
# Double the frame rate
rvf_smooth("input.mp4", "smooth.mp4")

# 4x for slow motion
rvf_smooth("input.mp4", "slowmo.mp4", factor = 4)
}

}
