% tinyrox says don't edit this manually, but it can't stop you!
\name{stv}
\alias{stv}
\title{Generate Talking Head Video (Speech-to-Video)}
\usage{
stv(
  image = NULL,
  audio,
  output = file.path(tempdir(), "stv_output.mp4"),
  backend = c("sadtalker", "wan2gp", "wan2gp_api", "diffuseR", "gpuhost"),
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
  timeout = 600,
  sliding_window_size = NULL,
  sliding_window_overlap = NULL,
  sliding_window_overlap_noise = NULL,
  sliding_window_discard_last_frames = NULL
)
}
\arguments{
\item{image}{Path to portrait image (PNG/JPG, front-facing) or base64 string}

\item{audio}{Path to speech audio file (WAV/MP3) or base64 string}

\item{output}{Path for output video file (default: "stv_output.mp4" under
\code{tempdir()}; pass a path to keep the file)}

\item{backend}{Backend to use: "sadtalker" (default), "wan2gp" (Docker),
"wan2gp_api" (HTTP API), "diffuseR" (LTX-2.3 in this process), or
"gpuhost" (LTX-2.3 on the viento-managed gpu.ctl service, on ITS
card rather than this one). For gpuhost set
\code{options(xtx.gpuhost_base = "http://host:7878")}; the entry name is
the endpoint's (\code{xtx.gpuhost_video_entry}, default
\code{"ltx-2.3"}). Prefer it wherever a gpu.ctl host is resident: the
in-process backend competes with it for the same device.}

\item{model}{Model for wan2gp backend: "hunyuan" (real faces), "fantasy" (stylized),
or "ltx2" (general). Ignored for sadtalker.}

\item{face_id}{Cached face ID for sadtalker (use instead of image for faster generation)}

\item{enhance}{Apply GFPGAN face enhancement (sadtalker only)}

\item{prompt}{Text prompt describing the scene (wan2gp)}

\item{resolution}{Resolution for wan2gp_api: "480p" or "720p" (default: "720p")}

\item{quality}{Quality preset for wan2gp_api: "fast", "balanced", or "quality" (default: "balanced")}

\item{width}{Video width (wan2gp Docker only, default: 832)}

\item{height}{Video height (wan2gp Docker only, default: 832)}

\item{num_frames}{Number of frames (wan2gp, default: 129)}

\item{num_inference_steps}{Number of inference steps (unused; reserved)}

\item{turbo_mode}{Use turbo mode for faster generation (unused; reserved)}

\item{seed}{Random seed (wan2gp only)}

\item{device}{Device to use: "cuda" or "cpu" (sadtalker only)}

\item{timeout}{Request timeout in seconds (default: 600)}

\item{sliding_window_size}{LTX-2 sliding-window size in frames
(wan2gp_api only). Default 129 = ~5.4s at 24fps, LTX-2's native context.
Must be 8n+1. `NULL` (default) defers to the server's configured default.}

\item{sliding_window_overlap}{Frames reused as motion conditioning between
adjacent sliding windows (wan2gp_api only). Higher = smoother joins, more
frames generated overall. `NULL` (default) defers to the server.}

\item{sliding_window_overlap_noise}{Noise injected into the overlap region,
0-100 (wan2gp_api only). Lower = stricter continuity, can flicker if too
strict. `NULL` (default) defers to the server.}

\item{sliding_window_discard_last_frames}{Frames trimmed off the end of each
window before joining (wan2gp_api only). `NULL` (default) defers to the
server.}
}
\value{
Invisibly returns the output file path
}
\description{
Generate an audio-driven talking head video from a portrait image and audio.
Supports multiple backends: SadTalker (default), WanGP Docker, or WanGP API.
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
}
}
