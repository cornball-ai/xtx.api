# xtx.api 0.1.0.1

* Add `transition()` and `transition_available()`: generate a bridging clip
  between two pieces of video via the WanGP `/transition` endpoint (LTX-2
  keyframe-conditioned generation). Continue from a source clip's trailing
  frames, optionally arrive at a destination keyframe, optionally route through
  interior keyframe anchors, with optional audio. Per-box `num_frames` /
  `conditioning_frames` come from `xtx.transition.*` options (set in
  `~/.Rprofile`); unset defers to the server's canonical default. Implementation
  contributed by Jorge Krzyzaniak. (#4)
