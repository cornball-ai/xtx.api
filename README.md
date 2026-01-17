# xtx.api

`xtx.api` provides a lightweight R interface for **cross-modal generative models** —
systems that transform text, images, audio, and video into new media.

It is designed to work alongside:

- **stt.api** — speech → text
- **tts.api** — text → speech
- **xtx.api** — cross-modal generation

Together, these packages form a minimal, composable toolkit for multimodal AI workflows in R.

---

## Supported Modalities

`xtx.api` is intended to support:

- Text → Image
- Text → Video
- Image → Video
- Audio → Video

Backends may include:
- Diffusion-based image/video models
- Talking-head systems (e.g., SadTalker, D-ID)
- Hosted APIs (OpenAI, Replicate, etc.)

## Docker Containers

| Container | Repo | Port | Purpose |
|-----------|------|------|---------|
| sadtalker | [cornball-ai/faster-SadTalker-API](https://github.com/cornball-ai/faster-SadTalker-API) | 10364 | Talking head video |
| diffusers-api | cornball-ai/diffusers_api (private) | 8000 | Image generation |

---

## Example

```r
library(xtx.api)

xtx_generate(
  input = "A cinematic shot of a robot walking through fog",
  modality = "text2video"
)
