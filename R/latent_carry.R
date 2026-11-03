# Latent carry for chained LTX chunks.
#
# transition(carry = "latents") continues a clip from the previous chunk's
# last denoised latent frames instead of its decoded pixels, as Lightricks'
# ltx-pipelines `chunks` package does: no H.264 round trip and no VAE
# re-encode. The tail travels in a file next to the chunk,
# <chunk>.latents.safetensors, holding one float32 tensor `latents`
# [1, 128, k, height/32, width/32] with k = (conditioning_frames - 1) / 8 + 1.
# The file is the whole carry: the next call reads it, a resumed run finds it
# next to the chunk, and the gpuhost backend sends its bytes as they are.
#
# safetensors is read and written here in base R. The format is an 8-byte
# little-endian header length, a JSON header naming each tensor's dtype,
# shape and byte range, then the data. That keeps the gpuhost backend free
# of torch, and xtx.api free of a new dependency.

# Where a chunk's tail latents live.
.latents_path <- function(clip) {
    paste0(clip, ".latents.safetensors")
}

# Latent frames carried for a pixel overlap on the 8k+1 grid: 9 -> 2, 25 -> 4.
.carry_latent_frames <- function(conditioning_frames) {
    cf <- as.integer(conditioning_frames)
    if (length(cf) != 1L || is.na(cf) || cf < 9L || (cf - 1L) %% 8L != 0L) {
        stop("conditioning_frames must be 8k + 1 and at least 9 for a ",
             "latent carry; got ", conditioning_frames, call. = FALSE)
    }
    (cf - 1L) %/% 8L + 1L
}

# Split safetensors bytes into a named list of
# list(dtype, shape, data = raw), in header order.
.safetensors_split <- function(bytes) {
    if (length(bytes) < 8L) {
        stop("not a safetensors file: shorter than its header length",
             call. = FALSE)
    }
    n <- sum(as.numeric(bytes[1:8]) * 256 ^ (0:7))
    if (n < 2 || 8 + n > length(bytes)) {
        stop("not a safetensors file: bad header length", call. = FALSE)
    }
    hdr <- jsonlite::fromJSON(rawToChar(bytes[9:(8 + n)]),
                              simplifyVector = FALSE)
    hdr[["__metadata__"]] <- NULL
    data <- bytes[-seq_len(8 + n)]
    lapply(hdr, function(h) {
        off <- as.numeric(unlist(h$data_offsets))
        if (length(off) != 2L || off[2] > length(data) || off[1] > off[2]) {
            stop("safetensors header points past the data", call. = FALSE)
        }
        list(dtype = h$dtype, shape = as.integer(unlist(h$shape)),
             data = data[seq_len(off[2] - off[1]) + off[1]])
    })
}

# The inverse: tensors as list(name = list(dtype, shape, data = raw)) to
# safetensors bytes. The header is space-padded to 8 bytes so the data
# starts aligned.
.safetensors_join <- function(tensors) {
    off <- 0
    hdr <- list()
    for (nm in names(tensors)) {
        t <- tensors[[nm]]
        hdr[[nm]] <- list(dtype = t$dtype, shape = as.list(t$shape),
                          data_offsets = list(off, off + length(t$data)))
        off <- off + length(t$data)
    }
    js <- charToRaw(as.character(jsonlite::toJSON(hdr, auto_unbox = TRUE,
                                                  digits = NA)))
    js <- c(js, rep(charToRaw(" "), (8L - length(js) %% 8L) %% 8L))
    n <- length(js)
    len <- as.raw(floor(n / 256 ^ (0:7)) %% 256)
    c(len, js, unlist(lapply(tensors, `[[`, "data"), use.names = FALSE))
}

# Write an R array as a float32 `latents` tensor. R arrays are column-major
# and safetensors is row-major, hence the aperm.
.latents_write <- function(arr, path) {
    d <- dim(arr)
    flat <- as.numeric(aperm(arr, rev(seq_along(d))))
    con <- rawConnection(raw(0), "wb")
    writeBin(flat, con, size = 4L, endian = "little")
    data <- rawConnectionValue(con)
    close(con)
    writeBin(.safetensors_join(list(latents = list(dtype = "F32",
                                                   shape = d, data = data))),
             path)
    invisible(path)
}

# Read a `latents` tensor back as an R array. F32 and BF16 (the host may
# send either); bfloat16 is the high half of a float32, so its two bytes
# are widened with two zero bytes below them.
.latents_read <- function(path) {
    if (!file.exists(path)) {
        stop("no carried latents at ", path, "; the previous chunk was not ",
             "rendered with carry = \"latents\"", call. = FALSE)
    }
    t <- .safetensors_split(readBin(path, "raw", file.size(path)))$latents
    if (is.null(t)) {
        stop(path, " holds no `latents` tensor", call. = FALSE)
    }
    data <- switch(t$dtype,
                   F32 = t$data,
                   BF16 = {
                       m <- matrix(t$data, nrow = 2L)
                       as.vector(rbind(raw(1), raw(1), m))
                   },
                   stop(path, ": unsupported latents dtype ", t$dtype,
                        call. = FALSE))
    n <- prod(t$shape)
    if (length(data) != 4 * n) {
        stop(path, ": latents data does not match its shape", call. = FALSE)
    }
    v <- readBin(data, "numeric", n = n, size = 4L, endian = "little")
    aperm(array(v, dim = rev(t$shape)), rev(seq_along(t$shape)))
}

# Check carried latents against the chunk about to use them.
.latents_check <- function(arr, k, width, height, path) {
    want <- c(1L, 128L, k, height %/% 32L, width %/% 32L)
    if (!identical(as.integer(dim(arr)), want)) {
        stop(sprintf("%s is [%s]; this chunk needs [%s]", path,
                     paste(dim(arr), collapse = ", "),
                     paste(want, collapse = ", ")), call. = FALSE)
    }
    invisible(arr)
}
