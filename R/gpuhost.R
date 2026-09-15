# The gpuhost backend: generation on the viento-managed gpu.ctl service
# instead of in this process.
#
# WHY IT EXISTS. The diffuseR backends load a pipeline into the CALLER's R
# session and generate on the local card. That is fine on a machine nobody
# else is using, and wrong on a fleet node: gpu.ctl's host holds the same
# card for its resident catalog, so two independent CUDA processes end up
# competing for one device. Measured on a 16 GiB card (2026-08-30): the
# host held 8.37 GiB of it and the in-process FLUX.2 died trying to
# allocate 20 MiB, mid-countdown.
#
# The wire is POST {base}/infer with a closed JSON schema
# {v, entry, key, input} and the allocation token as a Bearer header. The
# reply is raw bytes -- PNG from a picture entry, MP4 from a video one --
# with an X-GpuHost-Meta header, so nothing is base64'd on the way back.
# This file is the transport and the picture path; gpuhost_video.R is the
# talking-head path built on it.
#
# The request key is a CONTENT hash, deliberately: the host dedups by key,
# so a re-run after a crash reuses the committed result instead of paying
# the GPU again, and two different requests can never collide the way a
# constant or per-call-random key allows.

.gpuhost_base <- function() {
    b <- getOption("xtx.gpuhost_base")
    if (is.null(b) || !nzchar(b)) {
        stop("set options(xtx.gpuhost_base = \"http://host:7878\") before ",
             "using the gpuhost backend", call. = FALSE)
    }
    sub("/+$", "", b)
}

# The allocation token is read from, in order: options(xtx.gpuhost_token),
# the XTX_GPUHOST_TOKEN environment variable, then gpuhost.token under
# tools::R_user_dir("xtx.api", "config"). No default under the home
# directory: where a fleet keeps its token is the fleet's business.
.gpuhost_token_path <- function() {
    p <- getOption("xtx.gpuhost_token")
    if (is.null(p) || !nzchar(p)) p <- Sys.getenv("XTX_GPUHOST_TOKEN")
    if (!nzchar(p)) {
        p <- file.path(tools::R_user_dir("xtx.api", "config"), "gpuhost.token")
    }
    path.expand(p)
}

.gpuhost_bearer <- function() {
    p <- .gpuhost_token_path()
    if (!file.exists(p)) {
        stop("gpuhost token file not found at ", p,
             "; set options(xtx.gpuhost_token = ...) or XTX_GPUHOST_TOKEN",
             call. = FALSE)
    }
    jsonlite::base64_enc(readBin(p, "raw", file.size(p)))
}

# WHICH CATALOG ENTRY SERVES PICTURES, AND WHICH SERVES CLIPS. A property
# of the endpoint, not of xtx.api: a gpu.ctl host serves whatever its
# catalog declares, and the fleet runs more than one. Hardcoding a name
# makes this usable against exactly one host and refuse the rest with an
# unknown-entry 400, which reads as a broken service rather than as a name
# from the wrong catalog.
.gpuhost_entry <- function(what = c("image", "video")) {
    what <- match.arg(what)
    opt <- list(image = "xtx.gpuhost_image_entry",
                video = "xtx.gpuhost_video_entry")
    dflt <- list(image = "flux2-klein-4b", video = "ltx-2.3")
    v <- getOption(opt[[what]], dflt[[what]])
    if (!is.character(v) || length(v) != 1L || !nzchar(v)) {
        stop("options(", opt[[what]], ") must be a single entry name",
             call. = FALSE)
    }
    v
}

# The key carries the ENTRY and every input that changes the output. Two
# hosts serving different image models produce different pictures from the
# same prompt, and the host dedups by key -- so a shared key would hand
# back one model's result for the other's request, or trip the conflict
# check on a retry.
#
# Each part is framed netstring-style ("<length>:<bytes>") before hashing,
# so the boundaries are unambiguous: without framing, c("ab", "c") and
# c("a", "bc") hash the same bytes.
.gpuhost_key <- function(entry, input) {
    parts <- lapply(names(input)[order(names(input))], function(k) {
        charToRaw(paste0(k, "=", as.character(input[[k]])))
    })
    framed <- lapply(parts, function(p) {
        c(charToRaw(sprintf("%d:", length(p))), p)
    })
    paste0("xtx-", entry, "-", .gpuhost_hash(unlist(framed, use.names = FALSE)))
}

# secretbase's sha256 when it is there, base R's md5 otherwise. The hash
# only has to be stable and collision-resistant across THIS caller's
# requests; it is not a security boundary.
#
# THE FALLBACK HASHES EVERY BYTE. Its first version kept the first 32
# bytes of the framed input as hex, which is not a hash at all: sorted by
# field, a video request opens with `audio_b64=UklGR...` -- a WAV header --
# so every chunk of every track shared one key, and the host answers a
# shared key with the FIRST chunk's result or a conflict refusal. The tests
# never saw it because secretbase is installed here.
.gpuhost_hash <- function(x) {
    if (requireNamespace("secretbase", quietly = TRUE)) {
        return(secretbase::sha256(x))
    }
    f <- tempfile()
    on.exit(unlink(f), add = TRUE)
    writeBin(x, f)
    unname(tools::md5sum(f))
}

# POST {base}/infer and hand back the bytes. `accept` is the content type
# the caller's entry produces -- a picture entry answers image/png, a video
# entry video/mp4 -- and anything else in a 200 is a reply from a host
# whose catalog does not agree with the caller about what the entry is.
.gpuhost_infer <- function(entry, input, timeout, accept = "image/png") {
    key <- .gpuhost_key(entry, input)
    body <- jsonlite::toJSON(list(v = "gpu-host/1", entry = entry, key = key,
                                  input = input),
                             auto_unbox = TRUE)
    h <- curl::new_handle(timeout = timeout, post = TRUE, postfields = body)
    curl::handle_setheaders(h,
                            "Content-Type" = "application/json",
                            Authorization = paste("Bearer", .gpuhost_bearer()))
    r <- curl::curl_fetch_memory(paste0(.gpuhost_base(), "/infer"), h)
    if (r$status_code != 200L) {
        stop("gpuhost refused (", r$status_code, "): ",
             substr(rawToChar(r$content), 1, 300), call. = FALSE)
    }
    hl <- curl::parse_headers_list(r$headers)
    ct <- hl[["content-type"]]
    if (is.null(ct) || !grepl(accept, ct, fixed = TRUE)) {
        stop("gpuhost returned no ", accept, " (content-type ",
             ct %||% "<none>", "): ",
             substr(rawToChar(r$content), 1, 300), call. = FALSE)
    }
    list(content = r$content,
         meta = if (!is.null(hl[["x-gpuhost-meta"]])) {
            jsonlite::fromJSON(hl[["x-gpuhost-meta"]])
        })
}

# POST {base}/v1/device -- the handoff wire. Separate from `.gpuhost_infer`
# rather than folded into it: this one has no entry, no request key and no
# dedup, and its reply is JSON rather than image bytes. The only thing the
# two share is the base and the credential.
.gpuhost_device <- function(op, hold_s = NULL, timeout = 60) {
    body <- c(list(v = "gpu-host/1", op = op),
        if (!is.null(hold_s)) list(hold_s = as.numeric(hold_s)))
    h <- curl::new_handle(timeout = timeout, post = TRUE,
                          postfields = jsonlite::toJSON(body, auto_unbox = TRUE))
    curl::handle_setheaders(h,
                            "Content-Type" = "application/json",
                            Authorization = paste("Bearer", .gpuhost_bearer()))
    r <- curl::curl_fetch_memory(paste0(.gpuhost_base(), "/v1/device"), h)
    txt <- rawToChar(r$content)
    if (r$status_code != 200L) {
        stop("gpuhost refused the device ", op, " (", r$status_code, "): ",
             substr(txt, 1, 300), call. = FALSE)
    }
    out <- jsonlite::fromJSON(txt, simplifyVector = TRUE)
    invisible(out$value)
}

#' Hand the GPU back to the caller, for a stated window
#'
#' Asks the gpuhost to deactivate its resident entry NOW and to refuse
#' activating anything for \code{hold_s} seconds, so the caller can use
#' the same card without racing the host's idle timer.
#'
#' The case it exists for: a stage that generates images on the host and
#' then loads a video model in this process, on the same board. The host's
#' idle release fires only after a lull, so the two overlap by whatever the
#' timer has left -- and the failure is a CUDA OOM well into the stage.
#'
#' The window is BOUNDED (the host refuses more than 3600 s) so a caller
#' that dies does not leave the fleet's card yielded forever. A stage
#' longer than the hold calls this again per unit of work; re-arming
#' extends it, and that is also what lets a crash recover on its own.
#'
#' Refused on a co-resident catalog, where holding the card together is
#' what the declaration means.
#'
#' @param hold_s Seconds to keep the device yielded. Required: exclusive
#'   use of a shared card is a decision, and no default can make it.
#' @return Invisibly the host's report: whether anything was actually
#'   released, which entry, and the granted hold.
#' @examples
#' \dontrun{
#'   old <- options(xtx.gpuhost_base = "http://gpu-server:7878")
#'   gpuhost_release(hold_s = 600)   # the card is ours for ten minutes
#'   # ... load and run a model in this process ...
#'   gpuhost_resume()
#'   options(old)
#' }
#' @export
gpuhost_release <- function(hold_s) {
    if (!is.numeric(hold_s) || length(hold_s) != 1L || is.na(hold_s) ||
        hold_s <= 0) {
        stop("hold_s must be a positive number of seconds", call. = FALSE)
    }
    .gpuhost_device("release", hold_s = hold_s)
}

#' Give the GPU back to the gpuhost before the hold expires
#'
#' The other half of \code{\link{gpuhost_release}}. Not required -- the
#' hold expires on its own, which is the property that makes a crashed
#' caller recoverable -- but a stage that finished early should say so
#' rather than leaving the host idle for the rest of the window.
#'
#' @return Invisibly the host's report, including whether a hold was
#'   actually in force. Resuming a host that was not yielded is not an
#'   error, and the answer distinguishes the two.
#' @examples
#' \dontrun{
#'   old <- options(xtx.gpuhost_base = "http://gpu-server:7878")
#'   gpuhost_resume()$yielded   # TRUE if a hold was in force
#'   options(old)
#' }
#' @export
gpuhost_resume <- function() {
    .gpuhost_device("resume")
}

#' Probe the gpuhost service before a batch starts
#'
#' GET /health against the configured base, and -- when \code{entries} is
#' given -- a check that the host's catalog actually carries them. "ok"
#' alone says the front is serving and nothing about the catalog behind
#' it, so a base pointed at the wrong host in the fleet passes and then
#' fails on the first real request.
#'
#' @param entries Optional character vector of catalog entry names this
#'   run will ask for.
#' @return The health payload's \code{value}, invisibly.
#' @examples
#' \dontrun{
#'   old <- options(xtx.gpuhost_base = "http://gpu-server:7878")
#'   gpuhost_health(entries = c("flux2-klein-4b", "ltx-2.3"))
#'   options(old)
#' }
#' @export
gpuhost_health <- function(entries = NULL) {
    base <- .gpuhost_base()
    r <- tryCatch(curl::curl_fetch_memory(paste0(base, "/health"),
            curl::new_handle(timeout = 15)),
                  error = function(e) NULL)
    if (is.null(r) || r$status_code != 200L) {
        stop("gpuhost not healthy at ", base,
            if (!is.null(r)) paste0(" (HTTP ", r$status_code, ")"),
             " - it is fleet-managed, not a container to poke; see ",
             base, "/health", call. = FALSE)
    }
    out <- jsonlite::fromJSON(rawToChar(r$content), simplifyVector = TRUE)
    if (!isTRUE(out$ok)) {
        stop("gpuhost at ", base, " answered unhealthy: ",
             paste(out$error, collapse = " "), call. = FALSE)
    }
    if (length(entries)) {
        have <- as.character(out$value$entries)
        miss <- setdiff(entries, have)
        if (length(miss)) {
            stop("gpuhost at ", base, " serves ", paste(have, collapse = ", "),
                 " and not ", paste(miss, collapse = ", "),
                 " - point xtx.gpuhost_base at the host whose catalog has it",
                 call. = FALSE)
        }
    }
    invisible(out$value)
}

#' Text-to-image on the gpuhost service
#'
#' @keywords internal
.tti_gpuhost <- function(prompt, size = NULL, seed = NULL, steps = NULL,
                         negative_prompt = NULL, file = NULL, timeout = 120) {
    dims <- if (is.null(size)) {
        c(1024L, 1024L)
    } else {
        as.integer(strsplit(size, "x", fixed = TRUE)[[1]])
    }
    input <- list(prompt = prompt, width = dims[[1L]], height = dims[[2L]])
    if (!is.null(seed)) {
        input$seed <- as.integer(seed)
    }
    # STEPS ONLY WHEN ASKED FOR. `tti()`'s default of 50 belongs to the SD
    # family; FLUX.2 klein is a 4-step distilled model and running it at 50
    # is twelve times the work for no gain. An unset `steps` lets the
    # entry's own default stand, which is what the in-process path does.
    if (!is.null(steps)) {
        input$steps <- as.integer(steps)
    }
    # SAID, NOT SWALLOWED. FLUX.2 klein is guidance-distilled: there is no
    # CFG for a negative prompt to attach to, `diffuseR::txt2img_flux2()`
    # has no such argument, and the in-process path drops it silently. The
    # host's schema is closed, so sending it would be a 400 -- and dropping
    # it without a word is how a caller keeps passing something inert for
    # months, which is exactly what one downstream stage did.
    if (!is.null(negative_prompt) && nzchar(negative_prompt)) {
        message("gpuhost: ", .gpuhost_entry("image"), " has no CFG, so the ",
                "negative prompt is not sent (it is ignored in-process too)")
    }
    # A SWAP CAN PRECEDE THE WORK. `tti()`'s 120 s default was written for
    # a warm in-process pipeline; on a swap catalog the host may first move
    # a 12.5 GiB entry onto the card, which was measured at 37 s on one
    # host before a single step ran. A caller who asks for more gets more.
    timeout <- max(timeout, 300)
    entry <- .gpuhost_entry("image")
    out <- .gpuhost_infer(entry, input, timeout = timeout)
    path <- file %||% tempfile(fileext = ".png")
    writeBin(out$content, path)
    list(data = list(list(image = path, revised_prompt = NULL)),
         backend = "gpuhost", entry = entry, meta = out$meta)
}
