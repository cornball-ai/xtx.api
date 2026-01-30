% tinyrox says don't edit this manually, but it can't stop you!
\name{stv}
\alias{stv}
\title{Generate Talking Head Video (Speech-to-Video)}
\usage{
stv(
  image = NULL,
  audio,
  output = "stv_output.mp4",
  backend = c("sadtalker", "wan2gp", "wan2gp_api", "fal"),
  model = NULL,
  face_id = NULL,
  enhance = FALSE,
  prompt = "Person speaking naturally",
  resolution = "720p",
  quality = "balanced",
  width = 832L,
  height = 832L,
  num_frames = 129L,
  num_inference_steps = 30L,
  turbo_mode = TRUE,
  seed = NULL,
  device = "cuda",
  timeout = 600
)
}
\arguments{
\item{image}{Path to portrait image (PNG/JPG, front-facing) or base64 string}

\item{audio}{Path to speech audio file (WAV/MP3) or base64 string}

\item{output}{Path for output video file (default: "stv_output.mp4")}

\item{backend}{Backend to use: "sadtalker" (default), "wan2gp" (Docker),
"wan2gp_api" (HTTP API), or "fal" (cloud)}

\item{model}{Model for wan2gp backend: "hunyuan" (real faces), "fantasy" (stylized),
or "ltx2" (general). For fal: "fal-ai/sadtalker" (default). Ignored for sadtalker.}

\item{face_id}{Cached face ID for sadtalker (use instead of image for faster generation)}

\item{enhance}{Apply GFPGAN face enhancement (sadtalker only)}

\item{prompt}{Text prompt describing the scene (wan2gp and fal hunyuan-avatar)}

\item{resolution}{Resolution for wan2gp_api: "480p" or "720p" (default: "720p")}

\item{quality}{Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")}

\item{width}{Video width (wan2gp Docker only, default: 832)}

\item{height}{Video height (wan2gp Docker only, default: 832)}

\item{num_frames}{Number of frames (wan2gp and fal hunyuan-avatar, default: 129)}

\item{num_inference_steps}{Number of inference steps (fal hunyuan-avatar, default: 30)}

\item{turbo_mode}{Use turbo mode for faster generation (fal hunyuan-avatar, default: TRUE)}

\item{seed}{Random seed (wan2gp only)}

\item{device}{Device to use: "cuda" or "cpu" (sadtalker only)}

\item{timeout}{Request timeout in seconds (default: 600)}
}
\value{
Invisibly returns the output file path
}
\description{
Generate an audio-driven talking head video from a portrait image and audio.
Supports multiple backends: SadTalker (default), WanGP Docker, WanGP API, or fal.ai.
}
\examples{
\dontrun{
  # SadTalker (default, fastest for real faces)
  stv("portrait.jpg", "speech.wav", "talking.mp4")

  # Hunyuan Avatar via WanGP Docker (needs 24GB VRAM)
  stv("portrait.jpg", "speech.wav", backend = "wan2gp", model = "hunyuan")

  # LTX-2 via WanGP API (remote server)
  wan2gp_api_base("http://gpu-server:8000")
  stv("portrait.jpg", "speech.wav", backend = "wan2gp_api",
      prompt = "Person speaking into microphone")

  # Hunyuan Avatar via fal.ai (cloud API)
  stv("portrait.jpg", "speech.wav", backend = "fal",
      model = "fal-ai/hunyuan-avatar", prompt = "A person speaking")
}
}
