% tinyrox says don't edit this manually, but it can't stop you!
\name{img_edit}
\alias{img_edit}
\title{Edit Image with Text Prompt}
\usage{
img_edit(
  image,
  prompt,
  backend = c("openai", "diffuser", "flux3", "gpuhost"),
  model = NULL,
  mask = NULL,
  negative_prompt = NULL,
  size = "1024x1024",
  strength = 0.8,
  steps = 50,
  guidance_scale = 7.5,
  seed = NULL,
  devices = "cpu",
  n = 1,
  response_format = "url",
  file = NULL,
  timeout = 300
)
}
\arguments{
\item{image}{Character. Path to the input image file.}

\item{prompt}{Character. The text description of the desired edit/transformation.}

\item{backend}{Character. Which backend to use: "openai", "diffuser",
"flux3" (FLUX 3 in this process) or "gpuhost" (the same edit on a
gpu.ctl host's \code{flux3-klein} entry, through
\code{options(xtx.gpuhost_base)} or \code{GPU_HOST_BASE};
\code{options(xtx.gpuhost_edit_entry)}
names another entry).}

\item{model}{Character. Model to use. For OpenAI: "dall-e-2".
For diffuseR: "sd21", "sdxl". Ignored by flux3.}

\item{mask}{Character or NULL. Path to mask image (OpenAI only).
Transparent areas indicate where to edit.}

\item{negative_prompt}{Character or NULL. Negative prompt (diffuseR only).}

\item{size}{Character. Output size. For OpenAI: "256x256", "512x512", "1024x1024".
For diffuseR: "512x512", "768x768", "1024x1024". For flux3 the
area cap the input is scaled to fit (its canvas is the output size),
so a 1024x1024 input at "512x512" is edited at 512x512. For gpuhost
the output size when given; left unset, the output is the
reference's size (within the entry's 1024x1024 bound).}

\item{strength}{Numeric. Transformation strength 0-1 (diffuseR only). Default 0.8.}

\item{steps}{Integer. Number of inference steps (diffuseR, flux3 and
gpuhost). Default 50; flux3 is a distilled model and defaults to 16,
and gpuhost leaves an unset count to the entry.}

\item{guidance_scale}{Numeric. CFG scale (diffuseR only). Default 7.5.}

\item{seed}{Integer or NULL. Random seed (diffuseR and flux3).}

\item{devices}{Character or list. Device configuration (diffuseR and
flux3; flux3 takes one device, "cuda" or "cpu").}

\item{n}{Integer. Number of images to generate (OpenAI only).}

\item{response_format}{Character. "url" or "b64_json" (OpenAI only).}

\item{file}{Character or NULL. If provided, save the first result to this path.}

\item{timeout}{Seconds to wait for a gpuhost reply (gpuhost only; at
least 300, since a swap can precede the edit).}
}
\value{
A list containing the generated image data.
}
\description{
Edit an existing image using a text prompt. Uses the DALL-E 2 edits
endpoint for the OpenAI backend, diffuseR's SD img2img for local
models, or FLUX 3 Image Klein's reference edit (\code{backend =
"flux3"}), which keeps the subject of the input image and renders the
caption around it.
}
\details{
The FLUX 3 caption is a full description of the edited result, not an
instruction: "the same Bigfoot from the reference image, now wearing a
vampire cape, on a plain light grey backdrop". The pipeline loads once
per device and stays cached (see \code{\link{clear_diffuser_cache}}).
Its support files (VAE, tokenizer) are read from
\code{options(xtx.flux3_support_dir)} when set, else from the cached
\code{cornball-ai/flux3-klein-support} snapshot, else from wherever
\code{diffuseR::flux3_load_pipeline} looks by default.

}
\examples{
\dontrun{
# OpenAI edit with mask
result <- img_edit(
  image = "photo.png",
  prompt = "Add a red hat",
  mask = "mask.png"
)

# diffuseR img2img
result <- img_edit(
  image = "photo.png",
  prompt = "Make it look like a painting",
  backend = "diffuser",
  strength = 0.7
)

# FLUX 3 reference edit: the same subject, a new outfit
img_edit("bigfoot.png",
         paste("A studio portrait of the same Bigfoot from the reference",
               "image, now wearing a black vampire cape. Plain flat light",
               "grey backdrop."),
         backend = "flux3", devices = "cuda", seed = 7L,
         file = "bigfoot_vampire.png")
}

}
