# xtx.api 0.1.0.1

* Add `transition()`: generate a bridging clip between two pieces of video via
  the WanGP API `/transition` endpoint (LTX-2 keyframe-conditioned generation).
  Continue from a source clip's trailing frames, optionally arrive at a
  destination keyframe, optionally route through interior keyframe anchors, with
  optional audio. Per-user `num_frames`/`conditioning_frames` defaults read from
  the `xtx.transition.*` options (set in `~/.Rprofile`); fallbacks are the
  LTX-2.3 pipeline defaults (121 frames, 17-frame overlap). Adds
  `transition_available()`. (#4)
