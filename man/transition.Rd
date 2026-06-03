% tinyrox says don't edit this manually, but it can't stop you!
\name{transition}
\alias{transition}
\title{Generate a Bridging Transition Clip (LTX-2)}
\usage{
transition(start_clip, end_image = NULL, output = "transition.mp4",
           prompt = "", num_frames = NULL, conditioning_frames = NULL,
           keyframe_images = NULL, keyframe_positions = NULL, audio = NULL,
           resolution = "720p", quality = "balanced", seed = -1L, timeout = 1800)
}
\arguments{
\item{start_clip}{Path to the source video (MP4). Its trailing
`conditioning_frames` frames seed the bridge.}

\item{end_image}{Optional path to a destination keyframe (PNG/JPG). Forces the
bridge to arrive there, bounding how far appearance drifts. `NULL` (default)
leaves the destination open (an anchored extension).}

\item{output}{Path for the output video (default `"transition.mp4"`).}

\item{prompt}{Optional scene/motion description.}

\item{num_frames}{Frames to generate; must be 8n+1 (LTX-2 constraint). `NULL`
(default) uses `getOption("xtx.transition.num_frames", 121)`.}

\item{conditioning_frames}{Trailing frames of `start_clip` used as motion
conditioning. `NULL` (default) uses
`getOption("xtx.transition.conditioning_frames", 17)`.}

\item{keyframe_images}{Optional character vector of interior keyframe image
paths to route the bridge through. Pair with `keyframe_positions`.}

\item{keyframe_positions}{Optional integer vector of 1-indexed frame positions
for `keyframe_images` (same length, same order; each in `1..num_frames`).}

\item{audio}{Optional path to an audio file (needs an AV-capable checkpoint;
unavailable on the GGUF-light build).}

\item{resolution}{Output resolution: `"480p"` or `"720p"` (default `"720p"`).}

\item{quality}{Quality preset: `"fast"`, `"balanced"`, or `"quality"`
(default `"balanced"`).}

\item{seed}{Random seed; `-1` (default) picks a random seed. A fixed seed
`>= 0` gives reproducible output.}

\item{timeout}{Request timeout in seconds (default 1800; LTX-2 quality runs
are slow).}
}
\value{
Invisibly returns the output file path.
}
\description{
Generate a short video that continues from the trailing frames of
`start_clip` and, optionally, arrives at `end_image` -- the primitive for
smoothing a cut between two clips. Served by the WanGP API `/transition`
endpoint (LTX-2). Set the server with [wan2gp_api_base()].
}
\details{
The returned clip is `num_frames + conditioning_frames - 1` frames long: the
WanGP continuation prepends the conditioning tail of `start_clip`. To assemble
`start_clip + transition + clipB` seamlessly, drop the transition's first
`conditioning_frames` (a copy of the source tail).
}
\examples{
\dontrun{
  wan2gp_api_base("http://gpu-server:8000")

  # Bridge the cut from a source clip to a destination shot
  transition("chapter07.mp4", end_image = "cornelius_first_frame.png",
             output = "bridge.mp4")

  # Anchored extension (no fixed destination)
  transition("chapter07.mp4", output = "extended.mp4", prompt = "slow push in")

  # Route through an interior keyframe
  transition("a.mp4", end_image = "b.png", keyframe_images = "mid.png",
             keyframe_positions = 61L)
}
}
\seealso{
[transition_available()], [wan2gp_api_base()]
}
