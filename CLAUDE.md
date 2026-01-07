# xtxapi

Cross-modal generation API. Part of [cornyverse](~/cornyverse).

## Exports

### Text-to-Image
| Function | Purpose |
|----------|---------|
| `tti(prompt, file)` | Generate image from text |
| `tti_base(url)` | Set diffusers_api endpoint |

### Speech-to-Video (Talking Heads)
| Function | Purpose |
|----------|---------|
| `stv(image, audio, output)` | Generate talking head video |
| `stv_face_create(image)` | Cache face for faster generation |
| `stv_base(url)` | Set SadTalker API endpoint |

### Image-to-Video
| Function | Purpose |
|----------|---------|
| `itv(image, prompt, output)` | Animate image with prompt |
| `itv_base(url)` | Set video API endpoint |

## Backends

- **tti**: openai (DALL-E), diffuser (local diffuseR), diffusers_api (Docker)
- **stv**: faster-SadTalker-API (Docker)
- **itv**: diffusers_api with CogVideoX (Docker)

## Options

```r
xtxapi.gpuctl  # Enable GPU management (TRUE/FALSE)
```
