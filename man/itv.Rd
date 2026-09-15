% tinyrox says don't edit this manually, but it can't stop you!
\name{itv}
\alias{itv}
\title{Generate Video from Image (Image-to-Video)}
\usage{
itv(
  image,
  prompt = "",
  output = file.path(tempdir(), "itv_output.mp4"),
  backend = c("cogvideo", "wan2gp_api", "wan2gp"),
  model = NULL,
  num_frames = NULL,
  num_steps = NULL,
  width = 832L,
  height = 832L,
  resolution = "720p",
  quality = "balanced",
  guidance_scale = NULL,
  seed = NULL,
  timeout = 900
)
}
\arguments{
\item{image}{Path to starting frame image (PNG/JPG) or base64 string}

\item{prompt}{Motion/scene description}

\item{output}{Path for output video file (default: "itv_output.mp4" under
\code{tempdir()}; pass a path to keep the file)}

\item{backend}{Backend to use: "cogvideo" (default), "wan2gp" (Docker), or "wan2gp_api" (HTTP)}

\item{model}{Model ID. For cogvideo: "THUDM/CogVideoX-5b-I2V".
For wan2gp: "ltx2" (default).}

\item{num_frames}{Number of frames to generate (default: 49 for cogvideo, 129 for wan2gp)}

\item{num_steps}{Number of inference steps (default varies by backend/model)}

\item{width}{Video width (wan2gp only, default: 832)}

\item{height}{Video height (wan2gp only, default: 832)}

\item{resolution}{Resolution for wan2gp_api: "480p" or "720p" (default: "720p")}

\item{quality}{Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")}

\item{guidance_scale}{CFG scale (wan2gp only)}

\item{seed}{Random seed (wan2gp only)}

\item{timeout}{Request timeout in seconds (default: 900)}
}
\value{
Invisibly returns the output file path
}
\description{
Generate a video from an input image and motion prompt.
Supports multiple backends: CogVideoX or WanGP.
}
\examples{
\dontrun{
  # CogVideoX (default)
  itv("scene.jpg", "Camera slowly zooms in", "video.mp4")

  # LTX-2 via WanGP API (recommended)
  wan2gp_api_base("http://localhost:8000")
  itv("scene.jpg", "Camera slowly zooms in, leaves rustling",
      backend = "wan2gp_api")

  # LTX-2 via WanGP Docker (direct)
  itv("portrait.jpg", "Person talking and gesturing",
      backend = "wan2gp", model = "ltx2")
}
}
