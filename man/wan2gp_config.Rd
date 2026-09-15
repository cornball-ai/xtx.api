% tinyrox says don't edit this manually, but it can't stop you!
\name{wan2gp_config}
\alias{wan2gp_config}
\title{Configure WanGP Settings}
\usage{
wan2gp_config(
  workspace = NULL,
  cache = NULL,
  output_dir = NULL,
  profile = NULL,
  container = NULL
)
}
\arguments{
\item{workspace}{Path to Wan2GP workspace (default: "~/Wan2GP")}

\item{cache}{Path to HuggingFace cache (default: "~/.cache/huggingface")}

\item{output_dir}{Default output directory (default: current working dir)}

\item{profile}{Memory profile 1-4 (4 = low VRAM, default: 4)}

\item{container}{Docker image name (default: "wan2gp:blackwell")}
}
\value{
Invisibly returns previous settings as a list
}
\description{
Set default paths and options for WanGP docker integration.
}
