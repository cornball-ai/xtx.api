## The gpuhost backend's request shape, without a host.
##
## Everything here is what the caller SENDS, which is the half that has
## been wrong twice: a field under a name the receiver does not use, and a
## default that belongs to a different model family.

library(tinytest)
library(xtx.api)

# ---- configuration refuses rather than guessing ---------------------
old <- options(xtx.gpuhost_base = NULL)
expect_error(xtx.api:::.gpuhost_base(), "xtx.gpuhost_base")
options(xtx.gpuhost_base = "http://example:7878/")
## a trailing slash would produce "//infer"
expect_equal(xtx.api:::.gpuhost_base(), "http://example:7878")
options(old)

# ---- the entry is the endpoint's, not ours --------------------------
expect_equal(xtx.api:::.gpuhost_entry("image"), "flux2-klein-4b")
options(xtx.gpuhost_image_entry = "flux2-other")
expect_equal(xtx.api:::.gpuhost_entry("image"), "flux2-other")
options(xtx.gpuhost_image_entry = 42)
expect_error(xtx.api:::.gpuhost_entry("image"), "single entry name")
options(xtx.gpuhost_image_entry = NULL)

# ---- the key binds everything that changes the picture --------------
k <- function(input) xtx.api:::.gpuhost_key("flux2-klein-4b", input)
base <- k(list(prompt = "a cube", width = 512L, height = 512L))
expect_false(identical(base, k(list(prompt = "a sphere", width = 512L,
                                    height = 512L))))
expect_false(identical(base, k(list(prompt = "a cube", width = 1024L,
                                    height = 512L))))
expect_false(identical(base, k(list(prompt = "a cube", width = 512L,
                                    height = 512L, seed = 7L))))
## the entry too: two hosts serving different image models must not
## collide on one key, because the host dedups by it
expect_false(identical(base, xtx.api:::.gpuhost_key(
    "other-model", list(prompt = "a cube", width = 512L, height = 512L))))
## and field ORDER is not an output-affecting difference
expect_equal(base, k(list(height = 512L, width = 512L, prompt = "a cube")))

# ---- what actually goes on the wire ---------------------------------
#
# Intercepted at `.gpuhost_infer` so the assertions are about the REQUEST,
# not about a mock's idea of a reply.
sent <- NULL
png1 <- as.raw(c(0x89, 0x50, 0x4e, 0x47))
with_capture <- function(expr, content = png1) {
    sent <<- NULL
    fake <- function(entry, input, timeout, accept = "image/png") {
        sent <<- list(entry = entry, input = input, timeout = timeout,
                      accept = accept)
        list(content = content, meta = list(width = 8L, height = 8L))
    }
    unlockBinding(".gpuhost_infer", asNamespace("xtx.api"))
    orig <- xtx.api:::.gpuhost_infer
    assign(".gpuhost_infer", fake, envir = asNamespace("xtx.api"))
    on.exit({
        assign(".gpuhost_infer", orig, envir = asNamespace("xtx.api"))
        lockBinding(".gpuhost_infer", asNamespace("xtx.api"))
    }, add = TRUE)
    force(expr)
}

f <- tempfile(fileext = ".png")
res <- with_capture(xtx.api::tti("a red cube", backend = "gpuhost",
                                 size = "512x512", file = f))
expect_equal(sent$entry, "flux2-klein-4b")
expect_equal(sent$input$prompt, "a red cube")
expect_equal(sent$input$width, 512L)
expect_equal(sent$input$height, 512L)
## STEPS IS ABSENT WHEN NOBODY ASKED. `tti()` defaults it to 50, which is
## the SD family's number; FLUX.2 klein is a 4-step distilled model, so
## sending the default would be twelve times the work for no gain -- and
## it would look like the caller's choice.
expect_false("steps" %in% names(sent$input))
## no seed unless given, so the host's own default randomness stands
expect_false("seed" %in% names(sent$input))
## the bytes reach the file the caller named, and the shape matches the
## other backends'
expect_equal(res$data[[1]]$image, f)
expect_equal(readBin(f, "raw", 4L), png1)
expect_equal(res$backend, "gpuhost")
unlink(f)

# ...and PRESENT when they did
res <- with_capture(xtx.api::tti("a red cube", backend = "gpuhost",
                                 size = "512x512", steps = 12, seed = 7))
expect_equal(sent$input$steps, 12L)
expect_equal(sent$input$seed, 7L)
## with no `file`, the bytes still land somewhere the caller can read
expect_true(file.exists(res$data[[1]]$image))
unlink(res$data[[1]]$image)

# ---- the swap gets a timeout that contemplates it -------------------
# `tti()`'s 120 s default was written for a warm in-process pipeline; on a
# swap catalog the host may move a 12.5 GiB entry onto the card first,
# measured at 37 s before a single step ran.
expect_true(sent$timeout >= 300)
res <- with_capture(xtx.api::tti("a red cube", backend = "gpuhost",
                                 timeout = 900))
expect_equal(sent$timeout, 900)
unlink(res$data[[1]]$image)

# ---- a negative prompt is refused out loud, not swallowed -----------
# FLUX.2 klein is guidance-distilled: no CFG, so nothing for it to attach
# to. The in-process path drops it in silence, which is how a caller kept
# passing one for months without anything saying so.
expect_message(with_capture(
    xtx.api::tti("a red cube", backend = "gpuhost",
                 negative_prompt = "people, text")), "no CFG")
expect_false("negative_prompt" %in% names(sent$input))
## and a picture is what it asked the transport for
expect_equal(sent$accept, "image/png")

# ---- the video half: the entry is the endpoint's too -----------------
expect_equal(xtx.api:::.gpuhost_entry("video"), "ltx-2.3")
options(xtx.gpuhost_video_entry = "ltx-other")
expect_equal(xtx.api:::.gpuhost_entry("video"), "ltx-other")
options(xtx.gpuhost_video_entry = NULL)
expect_error(xtx.api:::.gpuhost_entry("audio"), "should be one of")

# ---- the hash fallback hashes every byte -----------------------------
#
# Its first version kept the first 32 bytes as hex. Sorted by field, a video
# request opens with `audio_b64=UklGR...` -- a WAV header -- so every chunk
# shared one key. Two inputs that agree on their first 32 bytes must not.
hash <- xtx.api:::.gpuhost_hash
a <- c(charToRaw(strrep("x", 40)), as.raw(1L))
b <- c(charToRaw(strrep("x", 40)), as.raw(2L))
expect_false(identical(hash(a), hash(b)))
expect_equal(hash(a), hash(a))

# ---- what a talking head sends ----------------------------------------
#
# Real media, because the request is built from probing it: frame counts
# from the audio's duration, the frame size from the previous clip's, and
# the audio itself re-encoded with the continuation's lead. ffmpeg makes
# the fixtures; without it there is nothing to probe.
if (nzchar(Sys.which("ffmpeg")) && nzchar(Sys.which("ffprobe"))) {
    td <- tempfile("gpuhost-video")
    dir.create(td)
    png <- file.path(td, "start.png")
    speech <- file.path(td, "speech.wav")
    clip <- file.path(td, "prev.mp4")
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
                        "color=c=blue:size=64x64", "-frames:v", "1", png))
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
                        "sine=frequency=440:duration=1.5:sample_rate=24000",
                        "-ac", "1", speech))
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
                        "testsrc=size=96x64:rate=24:duration=1", "-pix_fmt",
                        "yuv420p", clip))
    mp4_1 <- c(as.raw(c(0, 0, 0, 0x18)), charToRaw("ftypisom"))
    b64_of <- function(p) jsonlite::base64_enc(readBin(p, "raw", file.size(p)))
    sent_wav <- function() {
        w <- file.path(td, "sent.wav")
        writeBin(jsonlite::base64_dec(sent$input$audio_b64), w)
        w
    }

    ## stv: a start frame, the audio, the clip sized UP to the audio
    out <- file.path(td, "chunk01.mp4")
    with_capture(xtx.api::stv(png, speech, output = out, backend = "gpuhost",
                              prompt = "a moth talks", resolution = "720p",
                              seed = 11), content = mp4_1)
    expect_equal(sent$entry, "ltx-2.3")
    expect_equal(sent$accept, "video/mp4")
    expect_equal(sent$input$prompt, "a moth talks")
    ## 720p is the 960^2 avatar square, as on the diffuseR path
    expect_equal(sent$input$width, 960L)
    expect_equal(sent$input$height, 960L)
    ## 1.5 s at 24 fps is 36 frames; the grid rounds UP, to 41
    expect_equal(sent$input$num_frames, 41L)
    expect_equal(sent$input$seed, 11L)
    ## the start frame's exact bytes, in jsonlite's spelling
    expect_equal(sent$input$image_b64, b64_of(png))
    expect_false("condition_video_b64" %in% names(sent$input))
    expect_false("conditioning_frames" %in% names(sent$input))
    ## the audio arrives as 16 kHz stereo wav of the same length
    w <- sent_wav()
    expect_equal(readBin(w, "raw", 4L), charToRaw("RIFF"))
    expect_equal(xtx.api:::.probe_duration(w), 1.5, tolerance = 0.01)
    ## the bytes reach the file the caller named
    expect_equal(readBin(out, "raw", 12L), mp4_1)
    ## and a swap-sized floor on the timeout
    expect_equal(sent$timeout, 600)

    ## transition from the previous clip: the clip's OWN frame size, the
    ## total is audio frames plus the replayed head, and the audio starts
    ## after that head
    nxt <- file.path(td, "chunk02.mp4.raw.mp4")
    with_capture(xtx.api::transition(start_clip = clip, audio = speech,
                                     output = nxt, conditioning_frames = 9,
                                     prompt = "a moth talks",
                                     backend = "gpuhost"), content = mp4_1)
    expect_equal(sent$input$width, 96L)
    expect_equal(sent$input$height, 64L)
    expect_equal(sent$input$num_frames, 49L)   # align(41 + 9 - 1)
    expect_equal(sent$input$conditioning_frames, 9L)
    expect_equal(sent$input$condition_video_b64, b64_of(clip))
    expect_false("image_b64" %in% names(sent$input))
    expect_equal(xtx.api:::.probe_duration(sent_wav()), 1.5 + 8 / 24,
                 tolerance = 0.01)
    expect_equal(sent$timeout, 1800)
    expect_equal(readBin(nxt, "raw", 12L), mp4_1)

    ## from a still there is no head and no lead
    with_capture(xtx.api::transition(image_start = png, audio = speech,
                                     output = nxt, backend = "gpuhost"),
                 content = mp4_1)
    expect_equal(sent$input$image_b64, b64_of(png))
    expect_equal(sent$input$num_frames, 41L)
    expect_false("conditioning_frames" %in% names(sent$input))
    expect_equal(xtx.api:::.probe_duration(sent_wav()), 1.5, tolerance = 0.01)

    ## the host renders at 24 fps; another rate cannot be honoured
    expect_error(with_capture(xtx.api::transition(
        start_clip = clip, audio = speech, output = nxt, fps = 30,
        backend = "gpuhost")), "24 fps")
    unlink(td, recursive = TRUE)
}
