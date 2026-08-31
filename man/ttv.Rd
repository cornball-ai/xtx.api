% tinyrox says don't edit this manually, but it can't stop you!
\name{ttv}
\alias{ttv}
\title{Generate Video from Text (Text-to-Video)}
\usage{
ttv(
  prompt,
  output = "ttv_output.mp4",
  backend = c("wan2gp_api", "wan2gp"),
  model = "ltx2",
  num_frames = 97L,
  resolution = "720p",
  quality = "balanced",
  width = 832L,
  height = 832L,
  num_steps = NULL,
  guidance_scale = NULL,
  seed = NULL,
  timeout = 600
)
}
\arguments{
\item{prompt}{Text prompt describing the video content}

\item{output}{Path for output video file (default: "ttv_output.mp4")}

\item{backend}{Backend to use: "wan2gp_api" (default, HTTP) or "wan2gp" (Docker)}

\item{model}{Model ID for Docker backend: "ltx2" (default)}

\item{num_frames}{Number of frames to generate (default: 97, ~4s at 24fps)}

\item{resolution}{Resolution for wan2gp_api: "480p" or "720p" (default: "720p")}

\item{quality}{Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")}

\item{width}{Video width in pixels (wan2gp Docker only, default: 832)}

\item{height}{Video height in pixels (wan2gp Docker only, default: 832)}

\item{num_steps}{Number of inference steps (NULL = model default)}

\item{guidance_scale}{CFG scale (NULL = model default)}

\item{seed}{Random seed for reproducibility}

\item{timeout}{Request timeout in seconds (default: 600)}
}
\value{
Invisibly returns the output file path
}
\description{
Generate a video from a text prompt alone (no input image).
Uses LTX-2 via WanGP API or Docker.
}
\examples{
\dontrun{
  # Via WanGP API (recommended)
  wan2gp_api_base("http://localhost:8000")
  ttv("A cat playing piano in a jazz club", output = "cat_piano.mp4")

  # High quality mode
  ttv("Aerial view of mountains at sunset",
      quality = "quality", output = "mountains.mp4")

  # Via Docker (direct)
  ttv("Ocean waves at sunset", backend = "wan2gp",
      width = 1280, height = 720, num_frames = 129)
}
}
