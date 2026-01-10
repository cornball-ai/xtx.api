\name{itv}
\alias{itv}
\title{Generate Video from Image (Image-to-Video)}
\description{Generate a video from an input image and motion prompt. Uses CogVideoX-5b-I2V via diffusers_api.}
\usage{
itv(image, prompt, output, model, num_frames, num_steps, timeout)
}
\arguments{
  \item{image}{Path to starting frame image (PNG/JPG) or base64 string}
  \item{prompt}{Motion/scene description}
  \item{output}{Path for output video file (default: "itv_output.mp4")}
  \item{model}{Model ID (default: "THUDM/CogVideoX-5b-I2V")}
  \item{num_frames}{Number of frames to generate (default: 49)}
  \item{num_steps}{Number of inference steps (default: 50)}
  \item{timeout}{Request timeout in seconds (default: 900 for slow generation)}
}
\value{
Invisibly returns the output file path
}
\examples{
\dontrun{
  itv("scene.jpg", "Camera slowly zooms in", "video.mp4")
  itv("cat.png", "Cat stretches and yawns", num_frames = 49)
}
}
