# xtx.api 0.1.0.11

* `itv(backend = "wan2gp_api")` and `ttv(backend = "wan2gp_api")` no longer
  abort a slow-but-healthy generation: `.i2v_wan2gp_api()`/`.t2v_wan2gp_api()`
  now disable curl's low-speed-abort (`low_speed_time = 0, low_speed_limit
  = 0`), matching the fix already applied to the `/avatar` (stv) and
  transition WanGP calls in this same file. Previously a long `quality`
  mode generation (~10min+) could die to curl's default low-speed abort
  regardless of the caller's own `timeout=`, since that parameter only
  sets `CURLOPT_TIMEOUT`, a different mechanism.

# xtx.api 0.1.0.10

* Drop the redundant `xtx_` prefix from exported functions (callers
  qualify with `xtx.api::`): `xtx_img_edit` -> `img_edit`,
  `xtx_img_variation` -> `img_variation`, `xtx_health` -> `health`,
  `xtx_models` -> `models`, `xtx_backends` -> `backends`,
  `xtx_supported_models` -> `supported_models`, `xtx_set_api_base` ->
  `set_api_base`, `xtx_set_api_key` -> `set_api_key`. Internal helpers
  and file names lost the prefix too. In-org callers updated together.

# xtx.api 0.1.0.9

* Sidecar `media` block: the audio branch now records sample rate and
  channels (was duration-only), and a block that measured nothing (a
  bare `format` for an unreadable file) is dropped rather than emitted.
  Keeps the `.sidecar_media` helper identical to tts.api's.

# xtx.api 0.1.0.8

* Sidecars record a `media` block of delivered facts probed from the
  produced file: for video the DECODED frame count (`-count_frames`,
  since container headers can be off by one), fps, dimensions, and
  duration; dimensions for images; duration for audio. The request is
  intent; the media block is what actually landed. Probe failure or a
  missing ffprobe drops the block and never breaks a write. Also guards
  `fn` against `do.call()` callers that spliced the closure source into
  the record. Consumed by `cornductor::recorded_frames()`.

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
