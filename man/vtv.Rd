% tinyrox says don't edit this manually, but it can't stop you!
\name{vtv}
\alias{vtv}
\title{Generate Video from Video (Video-to-Video)}
\usage{
vtv(video, prompt = "", output = "vtv_output.mp4", backend = "wan2gp",
    model = c("vace", "ltx2"), width = 832L, height = 832L, num_frames = NULL,
    num_steps = NULL, guidance_scale = NULL, strength = 0.5, seed = NULL,
    timeout = 600)
}
\arguments{
\item{video}{Path to source video file}

\item{prompt}{Text prompt describing desired output}

\item{output}{Path for output video file (default: "vtv_output.mp4")}

\item{backend}{Backend to use: "wan2gp" (default)}

\item{model}{Model ID: "vace" (motion transfer) or "ltx2" (enhancement/style)}

\item{width}{Output video width (default: 832)}

\item{height}{Output video height (default: 832)}

\item{num_frames}{Number of output frames (default: from source video)}

\item{num_steps}{Number of inference steps (NULL = model default)}

\item{guidance_scale}{CFG scale (NULL = model default)}

\item{strength}{Denoising strength 0-1 (lower = more faithful to source)}

\item{seed}{Random seed for reproducibility}

\item{timeout}{Request timeout in seconds (default: 600)}
}
\value{
Invisibly returns the output file path
}
\description{
Transform or enhance an existing video. Supports motion transfer (VACE),
style transfer, and video enhancement/upscaling (LTX-2).
}
\examples{
\dontrun{
  # Motion transfer with VACE
  vtv("dance.mp4", "Robot dancing in futuristic city",
      model = "vace", output = "robot_dance.mp4")

  # Video enhancement/style with LTX-2
  vtv("lowres.mp4", "High quality cinematic footage",
      model = "ltx2", output = "enhanced.mp4")
}
}
