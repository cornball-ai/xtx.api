# xtxapi

`xtxapi` provides a lightweight R interface for **cross-modal generative models** —
systems that transform text, images, audio, and video into new media.

It is designed to work alongside:

- **sttapi** — speech → text  
- **ttsapi** — text → speech  
- **xtxapi** — cross-modal generation  

Together, these packages form a minimal, composable toolkit for multimodal AI workflows in R.

---

## Supported Modalities

`xtxapi` is intended to support:

- Text → Image
- Text → Video
- Image → Video
- Audio → Video

Backends may include:
- Diffusion-based image/video models
- Talking-head systems (e.g., SadTalker, DiD)
- Hosted APIs (OpenAI, Replicate, etc.)

---

## Example

```r
library(xtxapi)

xtx_generate(
  input = "A cinematic shot of a robot walking through fog",
  modality = "text2video"
)
