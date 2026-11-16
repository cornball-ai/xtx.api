# img_edit(): argument checks and the FLUX 3 backend's pure helpers. No
# model is loaded here; a real edit is a multi-minute, model-weight job.

library(xtx.api)

img <- tempfile(fileext = ".png")
file.create(img)

# --- input validation ---
expect_error(img_edit("no-such-file.png", "a hat"), pattern = "not found")
expect_error(img_edit(img, ""), pattern = "non-empty")
expect_error(img_edit(img, "a hat", backend = "bogus"), pattern = "arg")

# --- FLUX 3 canvas cap from the size string ---
max_area <- xtx.api:::.flux3_max_area
expect_equal(max_area("1024x1024"), 1024L^2)
expect_equal(max_area("512x512"), 512L^2)
expect_equal(max_area("768x512"), 768L * 512L)
expect_error(max_area("big"), pattern = "WIDTHxHEIGHT")
expect_error(max_area("1024"), pattern = "WIDTHxHEIGHT")

# --- support directory: the option wins, a missing cache is NULL ---
support <- xtx.api:::.flux3_support_dir
old <- getOption("xtx.flux3_support_dir")
d <- tempfile("support")
dir.create(d)
options(xtx.flux3_support_dir = d)
expect_equal(support(), d)
options(xtx.flux3_support_dir = file.path(d, "missing"))
expect_error(support(), pattern = "xtx.flux3_support_dir")
options(xtx.flux3_support_dir = NULL)
res <- support()
expect_true(is.null(res) || dir.exists(res))

options(xtx.flux3_support_dir = old)

# --- gpuhost: the request the edit sends ---
edit_input <- xtx.api:::.gpuhost_edit_input
png <- tempfile(fileext = ".png")
bytes <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1, 2, 3))
writeBin(bytes, png)
inp <- edit_input(png, "a hat")
expect_equal(names(inp), c("prompt", "image_b64"))
expect_equal(jsonlite::base64_dec(inp$image_b64), bytes)
inp <- edit_input(png, "a hat", size = "768x512", steps = 8, seed = 7)
expect_equal(inp[c("width", "height", "steps", "seed")],
             list(width = 768L, height = 512L, steps = 8L, seed = 7L))
# no base configured: refused before anything is sent
old_base <- getOption("xtx.gpuhost_base")
options(xtx.gpuhost_base = NULL)
expect_error(img_edit(png, "a hat", backend = "gpuhost"), pattern = "gpuhost")
options(xtx.gpuhost_base = old_base)

unlink(c(img, d, png), recursive = TRUE)
