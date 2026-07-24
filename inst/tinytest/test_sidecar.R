# Call-record sidecars: armed functions write <output>.json on success only.

# A toy "generation" function standing in for a backend call.
toy_gen <- function(prompt, output = tempfile(fileext = ".mp4"),
                    seed = NULL, fail = FALSE) {
    xtx.api:::.sidecar_arm(environment())
    if (fail) {
        stop("backend exploded")
    }
    writeLines("video bytes", output)
    invisible(output)
}

out <- toy_gen("a corny prompt", seed = 42L)
sc <- paste0(out, ".json")
expect_true(file.exists(sc))
rec <- jsonlite::fromJSON(sc)
expect_equal(rec$cornball_sidecar, 1L)
expect_equal(rec$package, "xtx.api")
expect_equal(rec$fn, "toy_gen")
expect_equal(rec$request$prompt, "a corny prompt")
expect_equal(rec$request$seed, 42L)
expect_equal(rec$request$fail, FALSE)
expect_true(is.numeric(rec$elapsed))
unlink(c(out, sc))

# Error path: no asset, no sidecar.
out2 <- tempfile(fileext = ".mp4")
expect_error(toy_gen("boom", output = out2, fail = TRUE))
expect_false(file.exists(paste0(out2, ".json")))

# Pre-existing stale file (cache hit / skipped work): no sidecar.
out3 <- tempfile(fileext = ".mp4")
writeLines("old", out3)
Sys.setFileTime(out3, Sys.time() - 3600)
toy_cache <- function(output) {
    xtx.api:::.sidecar_arm(environment())
    invisible(output) # touches nothing
}
toy_cache(out3)
expect_false(file.exists(paste0(out3, ".json")))
unlink(out3)

# file-named output arg, resolved inside the function (rembg shape).
toy_file <- function(image, file = NULL) {
    xtx.api:::.sidecar_arm(environment(), "file")
    if (is.null(file)) {
        file <- tempfile(fileext = ".png")
    }
    writeLines("png bytes", file)
    invisible(file)
}
res <- toy_file("in.png")
expect_true(file.exists(paste0(res, ".json")))
rec2 <- jsonlite::fromJSON(paste0(res, ".json"))
expect_equal(rec2$request$image, "in.png")
unlink(c(res, paste0(res, ".json")))

# --- .sidecar_media: delivered facts by kind --------------------------------

if (nzchar(Sys.which("ffprobe")) && nzchar(Sys.which("ffmpeg"))) {
    # Video: `frames` is the DECODED count. A 25-frame clip whose mp4 header
    # over-reports by one must still record 25 (this is the whole point).
    v <- tempfile(fileext = ".mp4")
    system2("ffmpeg", shQuote(c("-nostdin", "-y", "-f", "lavfi", "-i",
                                "testsrc2=size=64x64:rate=24", "-frames:v", "25",
                                "-pix_fmt", "yuv420p", v)),
            stdout = FALSE, stderr = FALSE)
    mv <- xtx.api:::.sidecar_media(v)
    expect_equal(mv$frames, 25L)
    expect_equal(mv$width, 64L)
    expect_equal(mv$height, 64L)
    expect_equal(mv$fps, 24)
    unlink(v)

    # Audio: duration only.
    a <- tempfile(fileext = ".wav")
    system2("ffmpeg", shQuote(c("-nostdin", "-y", "-f", "lavfi", "-i",
                                "sine=frequency=440:duration=1", "-ar", "16000",
                                a)), stdout = FALSE, stderr = FALSE)
    ma <- xtx.api:::.sidecar_media(a)
    expect_true(abs(ma$duration - 1) < 0.05)
    expect_null(ma$frames)
    unlink(a)

    # Image: dimensions only, no duration.
    p <- tempfile(fileext = ".png")
    system2("ffmpeg", shQuote(c("-nostdin", "-y", "-f", "lavfi", "-i",
                                "color=c=red:s=48x32", "-frames:v", "1", p)),
            stdout = FALSE, stderr = FALSE)
    mp <- xtx.api:::.sidecar_media(p)
    expect_equal(mp$width, 48L)
    expect_equal(mp$height, 32L)
    expect_null(mp$duration)
    unlink(p)
}

# Unknown extension and missing file yield no media block, never an error.
expect_null(xtx.api:::.sidecar_media(tempfile(fileext = ".xyz")))
expect_null(xtx.api:::.sidecar_media(tempfile(fileext = ".mp4")))

# --- parity with tts.api: enriched audio probe + measured-nothing guard ------

if (nzchar(Sys.which("ffprobe")) && nzchar(Sys.which("ffmpeg"))) {
    a2 <- tempfile(fileext = ".wav")
    system2("ffmpeg", shQuote(c("-nostdin", "-y", "-f", "lavfi", "-i",
                                "sine=frequency=440:duration=1", "-ar", "24000",
                                "-ac", "1", a2)), stdout = FALSE, stderr = FALSE)
    ma2 <- xtx.api:::.sidecar_media(a2)
    expect_equal(ma2$sample_rate, 24000L)
    expect_equal(ma2$channels, 1L)
    unlink(a2)
}
# A missing known-extension file measured nothing: no media block (not a bare
# format). Never reached in production (the file always exists), but the
# contract is "a block only when we measured something."
expect_null(xtx.api:::.sidecar_media(tempfile(fileext = ".mp3")))
expect_null(xtx.api:::.sidecar_media(tempfile(fileext = ".wav")))
