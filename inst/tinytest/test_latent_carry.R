# Latent carry helpers: the base-R safetensors reader and writer, the
# carry size, and transition frame sizing. Pure R; no torch, no generation.

ns <- asNamespace("xtx.api")

# ---- carry size: the official 25-frame overlap is 4 latents ------------
expect_equal(ns$.carry_latent_frames(9L), 2L)
expect_equal(ns$.carry_latent_frames(25L), 4L)
expect_error(ns$.carry_latent_frames(24L), "8k \\+ 1")
expect_error(ns$.carry_latent_frames(1L), "8k \\+ 1")
expect_equal(ns$.latents_path("/x/chunk02.mp4"),
             "/x/chunk02.mp4.latents.safetensors")

# ---- float32 round trip keeps values and row-major order ---------------
arr <- array(seq_len(1 * 128 * 4 * 2 * 3) / 7, dim = c(1L, 128L, 4L, 2L, 3L))
p <- tempfile(fileext = ".safetensors")
ns$.latents_write(arr, p)
back <- ns$.latents_read(p)
expect_equal(dim(back), dim(arr))
expect_equal(back, arr, tolerance = 1e-6)
expect_identical(ns$.latents_check(back, 4L, 96L, 64L, p), back)
expect_error(ns$.latents_check(back, 2L, 96L, 64L, p), "needs")
expect_error(ns$.latents_check(back, 4L, 64L, 64L, p), "needs")

# the data starts 8-byte aligned
b <- readBin(p, "raw", file.size(p))
n <- sum(as.numeric(b[1:8]) * 256 ^ (0:7))
expect_equal(n %% 8, 0)

# row-major: the LAST index moves fastest in the file
v <- readBin(b[-seq_len(8 + n)][1:8], "numeric", n = 2L, size = 4L,
             endian = "little")
expect_equal(v, c(arr[1, 1, 1, 1, 1], arr[1, 1, 1, 1, 2]), tolerance = 1e-6)

# the reference reader agrees, when it is installed
if (requireNamespace("safetensors", quietly = TRUE) &&
    requireNamespace("torch", quietly = TRUE) &&
    isTRUE(tryCatch(torch::torch_is_installed(), error = function(e) FALSE))) {
    ref <- safetensors::safe_load_file(p, framework = "torch")
    expect_equal(as.array(ref$latents), arr, tolerance = 1e-6)
}

# ---- bfloat16 is widened to float32 ------------------------------------
# 1.5 is 0x3FC00000 in float32, so 0x3FC0 in bfloat16; -2 is 0xC000
bf <- list(latents = list(dtype = "BF16", shape = c(1L, 2L),
                          data = as.raw(c(0xC0, 0x3F, 0x00, 0xC0))))
p2 <- tempfile(fileext = ".safetensors")
writeBin(ns$.safetensors_join(bf), p2)
expect_equal(ns$.latents_read(p2), array(c(1.5, -2), dim = c(1L, 2L)))

# ---- a container splits into its tensors -------------------------------
mp4 <- c(as.raw(c(0, 0, 0, 0x18)), charToRaw("ftypisom"))
lat <- ns$.safetensors_split(readBin(p, "raw", file.size(p)))$latents
box <- ns$.safetensors_join(list(
    video_mp4 = list(dtype = "U8", shape = length(mp4), data = mp4),
    tail_latents = lat))
parts <- ns$.safetensors_split(box)
expect_equal(names(parts), c("video_mp4", "tail_latents"))
expect_identical(parts$video_mp4$data, mp4)
expect_identical(parts$tail_latents$shape, c(1L, 128L, 4L, 2L, 3L))
out <- tempfile(fileext = ".mp4")
ns$.gpuhost_split_latents(box, out)
expect_identical(readBin(out, "raw", 100L), mp4)
expect_equal(ns$.latents_read(ns$.latents_path(out)), arr, tolerance = 1e-6)
expect_error(ns$.gpuhost_split_latents(
    ns$.safetensors_join(list(video_mp4 = parts$video_mp4)), out),
    "tail_latents")
expect_error(ns$.latents_read(tempfile()), "carry = \"latents\"")
expect_error(ns$.safetensors_split(as.raw(1:4)), "safetensors")

# ---- frame sizing ------------------------------------------------------
tf <- ns$.transition_frames
# a continuation: new frames plus the head, audio delayed by the head
r <- tf(NULL, 73L, 25L, 24, FALSE, continuation = TRUE)
expect_equal(r$total, 97L)
expect_equal(r$lead_s, 1)
# audio over the whole window: no lead
r <- tf(NULL, 73L, 25L, 24, TRUE, continuation = TRUE)
expect_equal(r, list(total = 97L, lead_s = 0))
# from a still there is no head
expect_equal(tf(NULL, 97L, 25L, 24, TRUE, continuation = FALSE),
             list(total = 97L, lead_s = 0))
expect_error(tf(NULL, NULL, 25L, 24, FALSE, TRUE), "num_frames")

if (nzchar(Sys.which("ffmpeg")) && nzchar(Sys.which("ffprobe"))) {
    w <- tempfile(fileext = ".wav")
    # 4 s of audio is 96 frames, 97 on the grid
    system2("ffmpeg", c("-v", "error", "-y", "-f", "lavfi", "-i",
                        "sine=frequency=440:duration=4:sample_rate=16000", w))
    expect_equal(tf(w, NULL, 25L, 24, TRUE, continuation = TRUE),
                 list(total = 97L, lead_s = 0))
    # covering only the new frames, the head comes on top
    expect_equal(tf(w, NULL, 25L, 24, FALSE, continuation = TRUE)$total, 121L)
    expect_error(tf(w, NULL, 97L, 24, TRUE, continuation = TRUE), "head")
}

# ---- the wan2gp backend has neither ------------------------------------
expect_error(xtx.api::transition(start_clip = "x.mp4", carry = "latents"),
             "backend")
