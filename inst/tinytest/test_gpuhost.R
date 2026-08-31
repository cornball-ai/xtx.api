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
with_capture <- function(expr) {
    sent <<- NULL
    fake <- function(entry, input, timeout) {
        sent <<- list(entry = entry, input = input, timeout = timeout)
        list(content = png1, meta = list(width = 8L, height = 8L))
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
# to. The in-process path drops it in silence, which is how lc40 kept
# passing one for months without anything saying so.
expect_message(with_capture(
    xtx.api::tti("a red cube", backend = "gpuhost",
                 negative_prompt = "people, text")), "no CFG")
expect_false("negative_prompt" %in% names(sent$input))
