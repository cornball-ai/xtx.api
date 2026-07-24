# .diffuseR_stash_tail: set/match semantics for the in-memory chain
# fast path (pure R; no torch, no generation).

library(xtx.api)
env <- xtx.api:::.diffuseR_env
rm(list = ls(env), envir = env)

res <- list(video = array(runif(12 * 8 * 8 * 3), dim = c(12L, 8L, 8L, 3L)))
out <- file.path(tempdir(), "chunkA.mp4")
xtx.api:::.diffuseR_stash_tail(res, out, n = 9L)
st <- env$last_tail
expect_false(is.null(st))
expect_equal(dim(st$frames), c(9L, 8L, 8L, 3L))
expect_identical(st$path, normalizePath(out, mustWork = FALSE))
# the stash holds the LAST n frames
expect_equal(st$frames[9L, , , ], res$video[12L, , , ])
expect_equal(st$frames[1L, , , ], res$video[4L, , , ])

# too-short videos and NULL videos leave the stash untouched
xtx.api:::.diffuseR_stash_tail(list(video = array(0, dim = c(4L, 8L, 8L, 3L))),
                               out, n = 9L)
expect_equal(env$last_tail$frames[9L, , , ], res$video[12L, , , ])
xtx.api:::.diffuseR_stash_tail(list(video = NULL), out, n = 9L)
expect_false(is.null(env$last_tail))

# path mismatch is how the consumer decides: identical() on normalized
# paths, so a different chunk file never matches a stale stash
expect_false(identical(env$last_tail$path,
                       normalizePath(file.path(tempdir(), "chunkB.mp4"),
                                     mustWork = FALSE)))
rm(list = ls(env), envir = env)
