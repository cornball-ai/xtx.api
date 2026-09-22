# Text-to-video async client (.t2v_wan2gp_api): create, poll, download.
# The HTTP seams (.wan2gp_api_post_json / .wan2gp_api_get) are stubbed in the
# package namespace so the job lifecycle runs without a server or GPU.

# --- pure helper: error-message extraction --------------------------------
em <- xtx.api:::.wan2gp_api_error_message
expect_equal(em(charToRaw('{"detail":{"message":"boom"}}')), "boom")
expect_equal(em(charToRaw('{"error":"nope"}')), "nope")
expect_equal(em(charToRaw('not json at all')), "not json at all")

# --- orchestration with stubbed HTTP --------------------------------------
resp <- function(code, content) list(status_code = code, content = content)
json_raw <- function(x) charToRaw(jsonlite::toJSON(x, auto_unbox = TRUE))

orig_post <- xtx.api:::.wan2gp_api_post_json
orig_get <- xtx.api:::.wan2gp_api_get

local({
    on.exit({
        assignInNamespace(".wan2gp_api_post_json", orig_post, "xtx.api")
        assignInNamespace(".wan2gp_api_get", orig_get, "xtx.api")
    }, add = TRUE)

    options(xtx.wan2gp_api_base = "http://test:8000")
    assignInNamespace(".wan2gp_api_post_json",
                      function(url, body, timeout = 60)
                          resp(202, json_raw(list(id = "vid_1", status = "queued"))),
                      "xtx.api")

    # Happy path: one "running" poll, then "completed", then content bytes.
    polls <- new.env(); polls$n <- 0L
    assignInNamespace(".wan2gp_api_get", function(url, timeout = 30) {
        if (grepl("/content$", url)) return(resp(200, as.raw(c(0, 1, 2, 3))))
        polls$n <- polls$n + 1L
        st <- if (polls$n < 2L) "running" else "completed"
        resp(200, json_raw(list(id = "vid_1", status = st)))
    }, "xtx.api")

    out <- tempfile(fileext = ".mp4")
    res <- suppressMessages(
        xtx.api:::.t2v_wan2gp_api("a cat", output = out, poll_interval = 0))
    expect_equal(res, out)
    expect_true(file.exists(out))
    expect_equal(readBin(out, "raw", 4), as.raw(c(0, 1, 2, 3)))
    expect_true(polls$n >= 2L)  # actually polled through "running"

    # Failed job surfaces the server's error and never fetches content.
    assignInNamespace(".wan2gp_api_get", function(url, timeout = 30) {
        if (grepl("/content$", url)) stop("must not fetch content on failure")
        resp(200, json_raw(list(id = "vid_1", status = "failed",
                                error = list(message = "oom"))))
    }, "xtx.api")
    expect_error(
        suppressMessages(xtx.api:::.t2v_wan2gp_api("x", output = tempfile(),
                                                   poll_interval = 0)),
        "generation failed: oom")

    # A job that never settles hits the time budget.
    assignInNamespace(".wan2gp_api_get", function(url, timeout = 30)
        resp(200, json_raw(list(id = "vid_1", status = "running"))), "xtx.api")
    expect_error(
        suppressMessages(xtx.api:::.t2v_wan2gp_api("x", output = tempfile(),
                                                   timeout = 0, poll_interval = 0)),
        "timed out")

    # A create error is reported with the server's message.
    assignInNamespace(".wan2gp_api_post_json", function(url, body, timeout = 60)
        resp(503, json_raw(list(detail = list(message = "no GPU")))), "xtx.api")
    expect_error(
        suppressMessages(xtx.api:::.t2v_wan2gp_api("x", output = tempfile(),
                                                   poll_interval = 0)),
        "no GPU")
})

# --- the file-input clients post to the new /v1/videos/{...} paths --------
orig_post_form <- xtx.api:::.wan2gp_api_post_form
orig_get2 <- xtx.api:::.wan2gp_api_get

local({
    on.exit({
        assignInNamespace(".wan2gp_api_post_form", orig_post_form, "xtx.api")
        assignInNamespace(".wan2gp_api_get", orig_get2, "xtx.api")
    }, add = TRUE)

    options(xtx.wan2gp_api_base = "http://test:8000")
    seen <- new.env()
    seen$url <- NULL
    assignInNamespace(".wan2gp_api_post_form",
                      function(url, form_args, timeout = 300) {
                          seen$url <- url
                          resp(202, json_raw(list(id = "vid_1", status = "queued")))
                      }, "xtx.api")
    assignInNamespace(".wan2gp_api_get", function(url, timeout = 30) {
        if (grepl("/content$", url)) return(resp(200, as.raw(c(1, 2, 3, 4))))
        resp(200, json_raw(list(id = "vid_1", status = "completed")))
    }, "xtx.api")

    img <- tempfile(fileext = ".png")
    writeBin(as.raw(rep(0, 8)), img)
    aud <- tempfile(fileext = ".wav")
    writeBin(as.raw(rep(0, 8)), aud)
    clip <- tempfile(fileext = ".mp4")
    writeBin(as.raw(rep(0, 8)), clip)

    out <- tempfile(fileext = ".mp4")
    suppressMessages(xtx.api:::.i2v_wan2gp_api(image = img, output = out))
    expect_equal(seen$url, "http://test:8000/v1/videos/i2v")
    expect_equal(readBin(out, "raw", 4), as.raw(c(1, 2, 3, 4)))

    out <- tempfile(fileext = ".mp4")
    suppressMessages(xtx.api:::.stv_wan2gp_api(image = img, audio = aud, output = out))
    expect_equal(seen$url, "http://test:8000/v1/videos/avatar")

    out <- tempfile(fileext = ".mp4")
    suppressMessages(
        xtx.api:::.transition_wan2gp_api(start_clip = clip, output = out))
    expect_equal(seen$url, "http://test:8000/v1/videos/transition")
    expect_true(file.exists(out))
})
