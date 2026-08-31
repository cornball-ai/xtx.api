% tinyrox says don't edit this manually, but it can't stop you!
\name{diffuseR_unload}
\alias{diffuseR_unload}
\title{Unload the diffuseR backend's cached models}
\usage{
diffuseR_unload()
}
\value{
Invisibly, NULL.
}
\description{
The stand-up is lazy: the first \code{stv()}/\code{transition()}
call with \code{backend = "diffuseR"} loads the LTX-2.3 pipeline
(and, on first prompt, the Gemma3 text encoder) into a session
cache that later chunks reuse. This is the teardown: it drops the
cached pipeline, text encoder, and prompt embeddings so the host
RAM (roughly 20 GB weights plus 48 GB Gemma3 when kept) returns to
the system. Call it after a batch run -- the docker-stop
equivalent. The next diffuseR call reloads from disk.
}
\details{
It also drops \code{tti()}/\code{img2img()}'s diffuseR pipelines
(FLUX.2, SDXL, SD2.1), which live in a separate cache. Those cost
little VRAM -- the FLUX family phase-swaps from host RAM -- but
they pin large host staging buffers, and so do LTX and Gemma3. A
session that generates images and then video holds both sets at
once: measured here as a 43 GB shared-memory resident set, enough
to exhaust 125 GB of host RAM and drive phase-offload staging into
swap for the whole video stage (roughly 2x per-chunk time), or to
OOM outright.

}
