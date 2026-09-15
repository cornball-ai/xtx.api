% tinyrox says don't edit this manually, but it can't stop you!
\name{tti}
\alias{tti}
\title{Generate Image from Text}
\usage{
tti(
  prompt,
  backend = c("openai", "diffuseR", "diffusers_api", "gpuhost", "auto"),
  model = NULL,
  negative_prompt = NULL,
  size = NULL,
  quality = "standard",
  style = "vivid",
  n = 1,
  steps = 50,
  guidance_scale = 7.5,
  seed = NULL,
  lora = NULL,
  lora_scale = 0.8,
  devices = "cpu",
  response_format = "url",
  file = NULL,
  timeout = 120
)
}
\arguments{
\item{prompt}{Character. The text description of the image to generate.}

\item{backend}{Character. Which backend to use:
- "openai": DALL-E API (requires API key)
- "diffuseR": Local diffuseR package
- "diffusers_api": HTTP API (Z-Image-Turbo, SD)
- "gpuhost": the viento-managed gpu.ctl service, which generates on
ITS card rather than in this process. Set
\code{options(xtx.gpuhost_base = "http://host:7878")}. Prefer this
on any machine where a gpu.ctl host is resident: the in-process
diffuseR backends compete with it for the same device.
- "auto": Use diffuseR if available, else openai}

\item{model}{Character. Model to use. Depends on backend:
- OpenAI: "dall-e-3", "dall-e-2"
- diffuseR: "sd21", "sdxl"
- diffusers_api: "Tongyi-MAI/Z-Image-Turbo", any HF model ID}

\item{negative_prompt}{Character or NULL. Negative prompt (diffuseR, diffusers_api only).}

\item{size}{Character. Image dimensions (e.g., "1024x1024").}

\item{quality}{Character. Image quality: "standard" or "hd" (DALL-E 3 only).}

\item{style}{Character. Image style: "vivid" or "natural" (DALL-E 3 only).}

\item{n}{Integer. Number of images (OpenAI only).}

\item{steps}{Integer. Inference steps (diffuseR, diffusers_api only). Default 50.}

\item{guidance_scale}{Numeric. CFG scale. Default 7.5.}

\item{seed}{Integer or NULL. Random seed for reproducibility.}

\item{lora}{Character or list. LoRA model(s) for character/style consistency
(diffusers_api only). Can be a path string for single LoRA, or a list of
lists with `path` and `scale` elements for multiple LoRAs.}

\item{lora_scale}{Numeric. Weight for single LoRA (0-1). Default 0.8.
Ignored if `lora` is a list with explicit scales.}

\item{devices}{Device configuration for diffuseR: "cpu", "cuda", or list.}

\item{response_format}{Character. "url" or "b64_json" (OpenAI only).}

\item{file}{Character or NULL. If provided, save the image to this path.}

\item{timeout}{Timeout in seconds (diffusers_api only). Default 120.}
}
\value{
A list containing the generated image data. Structure varies by backend.
}
\description{
Generate an image from a text prompt using multiple backends.
}
\examples{
\dontrun{
# Using OpenAI DALL-E
set_api_key("sk-...")
result <- tti("A white cat on a windowsill")
result$data[[1]]$url

# Using local diffuseR
result <- tti("A sunset over mountains", backend = "diffuseR")

# Using diffusers_api with Z-Image-Turbo
tti_base("http://localhost:8000")
result <- tti("A robot DJ", backend = "diffusers_api",
              model = "Tongyi-MAI/Z-Image-Turbo")

# Using LoRA for character consistency
tti("photo of sks person smiling", backend = "diffusers_api",
    lora = "/models/loras/my_character.safetensors",
    lora_scale = 0.85, file = "character.png")

# Multiple LoRAs
tti("photo of sks person in anime style", backend = "diffusers_api",
    lora = list(
      list(path = "character.safetensors", scale = 0.8),
      list(path = "anime_style.safetensors", scale = 0.6)
    ))

# Save to file
tti("A sunset over mountains", file = "sunset.png")
}

}
