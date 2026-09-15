# xtx.api 0.1.0.13

* **`stv(backend = "gpuhost")` and `transition(backend = "gpuhost")`:**
  LTX-2.3 talking heads generated on the viento-managed gpu.ctl service
  instead of in this process. The contracts are the diffuseR backend's to
  the frame -- a start frame plus audio sized up to the audio on the 8k+1
  grid; a continuation that opens with `conditioning_frames` replayed from
  the previous clip's tail, its audio delayed under that head -- so
  cornductor's chunk accounting holds without knowing which backend ran.
  The previous chunk travels as a file and the host reads its tail, which
  is the in-process path's own fallback on a resume. Audio is sent as
  16 kHz stereo wav (what LTX's audio VAE reads anyway), prepared with
  ffmpeg. The entry name is the endpoint's (`xtx.gpuhost_video_entry`,
  default `ltx-2.3`). Requires gpu.ctl >= 0.1.0.25 on the host, which is
  where the conditioning inputs were admitted.

  This is what `gpuhost_release()`/`gpuhost_resume()` were a workaround
  for: the video stage was the last one loading a model in the caller's
  process on the host's own card. With it on the host, nothing shares the
  board and nothing needs yielding.

* The request-key hash fallback (no secretbase) now hashes every byte with
  md5. It kept the first 32 bytes as hex, which for a video request is the
  WAV header of `audio_b64` -- one key for every chunk of every track.

# xtx.api 0.1.0.12

* **`gpuhost_release(hold_s)` / `gpuhost_resume()`:** ask the gpuhost to
  deactivate its resident entry NOW and refuse activating anything for
  the stated window, so a caller can use the same card without racing
  the host's idle timer. The case it exists for is a stage that
  generates images on the host and then loads a video model in this
  process on the same board: the idle release fires only after a lull,
  so the two overlap by whatever the timer has left, and the failure is
  a CUDA OOM well into the stage.

  `hold_s` has no default. Exclusive use of a shared card is a decision,
  and no default can make it. The host bounds it at 3600 s -- a stage
  longer than that re-arms per unit of work, which is also what lets a
  crashed caller's hold expire instead of yielding the fleet's card
  forever. Requires gpu.ctl >= 0.1.0.23 on the host.

# xtx.api 0.1.0.11

* **New `tti(backend = "gpuhost")`:** generation on the viento-managed
  gpu.ctl service instead of in the caller's process. The `diffuseR`
  backends load a pipeline into this R session and generate on the local
  card, which is fine on a machine nobody else is using and wrong on a
  fleet node -- gpu.ctl's host holds the same card for its resident
  catalog, so two independent CUDA processes compete for one device.
  Measured on troy-ai: the host held 8.37 GiB of a 15.47 GiB board and the
  in-process FLUX.2 died allocating 20 MiB, mid-countdown. Configure with
  `options(xtx.gpuhost_base = "http://host:7878")`; the entry name is the
  endpoint's property (`xtx.gpuhost_image_entry`, default
  `flux2-klein-4b`), because the fleet runs more than one catalog.

* `gpuhost_health()` probes the service and, given `entries`, checks that
  the host's catalog actually carries them. "ok" alone says the front is
  serving and nothing about the catalog behind it.

* `steps` reaches the gpuhost only when the caller ASKED for it. `tti()`
  defaults it to 50, which is the SD family's number; FLUX.2 klein is a
  4-step distilled model, so sending the default would be twelve times the
  work for no gain and would look like the caller's choice.

* A `negative_prompt` on the gpuhost backend is reported, not swallowed.
  FLUX.2 klein is guidance-distilled -- no CFG for one to attach to, and
  `diffuseR::txt2img_flux2()` has no such argument -- so the in-process
  path drops it in silence, which is how a caller keeps passing something
  inert for months.

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
