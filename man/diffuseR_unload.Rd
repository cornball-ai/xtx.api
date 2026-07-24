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
