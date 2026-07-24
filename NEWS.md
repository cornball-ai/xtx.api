# xtx.api 0.1.0.7

* diffuseR audio sizing rounds the frame budget UP to the 8n+1 grid
  (`.ceil_8nplus1`); nearest-snap could leave a chunk's video up to 4
  frames short of its narration and desync chained tracks.

# xtx.api 0.1.0.6

* Gemma3 fallback fixes: the fp32 path never pins (and never stages
  to the GPU), verbose options are coerced to logical, hfhub is
  declared, and the tail-stash semantics gained tests.

# xtx.api 0.1.0.5

* diffuseR chain fast path: chained transitions condition on an
  in-memory stash of the previous chunk's tail (lossless; no more
  whole-mp4 PNG extraction per chunk), prompt memos hold the ~9 MB
  connector outputs instead of ~0.4 GB raw Gemma3 stacks (passed as
  connector_embeds, skipping txt2vid's per-call connectors phase),
  and the text encoder prefers the pinned NF4 artifact (~0.3 s GPU
  swap per encode). Requires diffuseR >= 0.1.0.15.

# xtx.api 0.1.0.4

* The diffuseR backend surfaces generation progress by default: the
  stv()/transition() LTX-2.3 calls and tti()'s FLUX.2 path pass
  verbose = "progress" (diffuseR >= 0.1.0.10) instead of running
  silent; options(xtx.diffuseR.verbose =) still overrides the video
  paths.

# xtx.api 0.1.0.1

* Add `transition()` and `transition_available()`: generate a bridging clip
  between two pieces of video via the WanGP `/transition` endpoint (LTX-2
  keyframe-conditioned generation). Continue from a source clip's trailing
  frames, optionally arrive at a destination keyframe, optionally route through
  interior keyframe anchors, with optional audio. Per-box `num_frames` /
  `conditioning_frames` come from `xtx.transition.*` options (set in
  `~/.Rprofile`); unset defers to the server's canonical default. Implementation
  contributed by Jorge Krzyzaniak. (#4)
