# transition() — validation paths (no container) + gated live smoke test.

old_base <- getOption("xtx.wan2gp_api_base")

# Dummy base; validation fails before any request, so the server isn't contacted.
options(xtx.wan2gp_api_base = "http://127.0.0.1:59999")

# Missing start_clip.
expect_error(transition("/no/such/clip.mp4"), "start_clip file not found")

clip <- tempfile(fileext = ".mp4")
file.create(clip)

# num_frames must be 8n+1 when set explicitly.
expect_error(transition(clip, num_frames = 50L), "8n\\+1")

# keyframe_images / keyframe_positions length must match.
expect_error(
  transition(clip, keyframe_images = clip, keyframe_positions = c(1L, 2L)),
  "same length"
)

# Unset base URL is a clear error.
options(xtx.wan2gp_api_base = NULL)
expect_error(transition(clip), "base URL not set")

unlink(clip)
options(xtx.wan2gp_api_base = old_base)

# --- live smoke test: only at_home() with a reachable container ------------
# No prompt passed: exercises the generic-default-prompt path (wgp.py rejects
# empty prompts). Generates a real minimal clip, so needs the WanGP API up.
if (at_home() && transition_available()) {
  td <- tempfile("xtx_transition")
  dir.create(td)
  clip <- file.path(td, "src.mp4")
  end_png <- file.path(td, "end.png")
  out <- file.path(td, "bridge.mp4")
  if (nzchar(Sys.which("ffmpeg"))) {
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
      "testsrc=size=640x360:rate=24:duration=1", "-pix_fmt", "yuv420p", clip))
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
      "color=c=blue:size=640x360", "-frames:v", "1", end_png))
    transition(clip, end_image = end_png, output = out,
      num_frames = 9L, conditioning_frames = 5L, quality = "fast")
    expect_true(file.exists(out) && file.size(out) > 0)
  }
  unlink(td, recursive = TRUE)
}
