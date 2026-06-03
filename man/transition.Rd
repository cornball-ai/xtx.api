% tinyrox says don't edit this manually, but it can't stop you!
\name{transition}
\alias{transition}
\title{Generate a Bridging / Transition Clip (Video-to-Video)}
\usage{
transition(start_clip, end_image = NULL, keyframe_images = NULL,
           keyframe_positions = NULL, prompt = NULL, audio = NULL,
           num_frames = NULL, conditioning_frames = NULL, resolution = "720p",
           quality = "balanced", seed = NULL, output = "transition_output.mp4",
           timeout = 1800, backend = c("wan2gp_api"))
}
\arguments{
\item{start_clip}{Path to the source video (MP4). Its trailing frames seed
the bridge.}

\item{end_image}{Optional path to a destination keyframe (PNG/JPG). Bounds
drift by forcing the bridge to arrive here.}

\item{keyframe_images}{Optional character vector of image paths (PNG/JPG)
used as interior anchors. Must be the same length as
\code{keyframe_positions}, in the same order.}

\item{keyframe_positions}{Optional integer vector of 1-indexed frame
positions, one per \code{keyframe_images}, each within \code{1:num_frames}.}

\item{prompt}{Optional scene/motion description. Keep it stable across a chain.
When unset, a generic transition prompt is sent (the backend requires a
non-empty prompt).}

\item{audio}{Optional path to an audio file. Requires a checkpoint with the
AV connector; unavailable on GGUF-light.}

\item{num_frames}{Frames to generate; must be 8n+1 (LTX-2 constraint).
\code{NULL} (default) falls back to \code{getOption("xtx.transition.num_frames")}
and, if that is unset, to the server's canonical default.}

\item{conditioning_frames}{Trailing frames of \code{start_clip} used as motion
conditioning. \code{NULL} (default) falls back to
\code{getOption("xtx.transition.conditioning_frames")} and, if unset, to the
server default. Set per-box prefs in \code{~/.Rprofile}, e.g.
\code{options(xtx.transition.num_frames = 49, xtx.transition.conditioning_frames = 9)}.}

\item{resolution}{\code{"480p"} or \code{"720p"} (default \code{"720p"}).}

\item{quality}{\code{"fast"}, \code{"balanced"}, or \code{"quality"}
(default \code{"balanced"}).}

\item{seed}{Random seed. \code{NULL} (default) defers to the server (random).
Pass a fixed integer >= 0 for reproducible output / clean A/B comparisons.}

\item{output}{Output file path (default \code{"transition_output.mp4"}).}

\item{timeout}{Timeout in seconds (default 1800; transitions can be slow).}

\item{backend}{Backend to use. Only \code{"wan2gp_api"} is supported.}
}
\value{
Invisibly, the path to the written MP4. Note the clip has
  \code{num_frames + conditioning_frames - 1} frames, not \code{num_frames}:
  the server's \code{video_source} continuation prepends the conditioning tail
  of \code{start_clip} as continuity context (e.g. 49 + 9 -> 57 frames). When
  assembling \code{start_clip + bridge + clipB}, drop the bridge's first
  \code{conditioning_frames} (a copy of \code{start_clip}'s tail) or trim
  \code{start_clip}'s tail, so the join isn't double-played; the bridge ->
  clipB join is seamless when clipB starts on \code{end_image}.
}
\description{
Generate a short clip that continues from the trailing frames of
\code{start_clip} and, when \code{end_image} is supplied, arrives at it.
Useful for smoothing the cut between two existing clips, or for anchored
video extension. Unlike \code{stv()}, this path conditions on \emph{frames},
not audio, so it runs on checkpoints without an audio-video connector
(e.g. the GGUF-light build).
}
\details{
Shapes:
\itemize{
\item \strong{A -> B bridge} (pass \code{end_image}): smooth the cut
between two existing clips. \code{end_image} bounds drift -- arriving at a
known frame limits how far the bridge can wander.
\item \strong{Anchored extension} (omit \code{end_image}): continue a clip
with no fixed destination.
\item \strong{Multi-keyframe} (pass \code{keyframe_images} +
\code{keyframe_positions}): route the bridge through interior anchor
images at chosen 1-indexed frame positions. Anchors are \emph{soft}:
their influence bleeds into neighbouring frames and persists forward
(temporal coherence), rather than replacing exactly one frame.
}

}
\examples{
\dontrun{
  wan2gp_api_base("http://localhost:8000")

  # Smooth the cut between two clips
  transition("clipA.mp4", end_image = "clipB_frame1.png",
             prompt = "camera pulls back to a wide shot",
             output = "bridge.mp4")

  # Route through interior keyframe anchors
  transition("clipA.mp4", end_image = "clipB_frame1.png",
             keyframe_images = c("mid1.png", "mid2.png"),
             keyframe_positions = c(17, 33),
             num_frames = 49, output = "bridge.mp4")
}
}
