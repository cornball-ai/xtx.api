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
unlink(c(img, d), recursive = TRUE)
