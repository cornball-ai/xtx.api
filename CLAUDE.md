# xtx.api

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

- **tti**: openai (DALL-E), diffuseR (local), diffusers_api (Docker)
- **stv**: faster-SadTalker-API (Docker)
- **itv**: diffusers_api with CogVideoX (Docker)

## diffuseR Backend Notes

The diffuseR backend uses cached pipelines for efficiency. Key implementation details:

1. **Pipeline caching**: Pipelines are cached in `.diffuser_cache` environment by model+devices key
2. **Gradient handling**: Generation is wrapped in `torch::with_no_grad()` (NOT `local_no_grad()`)
   - `local_no_grad()` only works at top-level; inside functions the scope exits before inference runs
3. **Clear cache**: Use `clear_diffuser_cache()` to free GPU memory

### Blackwell GPU Workaround (TEMPORARY)

Until diffuseR TorchScript models are re-exported for Blackwell/CUDA 12.8, use:
```r
devices = list(unet = "cuda", decoder = "cpu",
               text_encoder = "cpu", encoder = "cpu")
```
**TODO**: Replace TorchScript in diffuseR with native torch code loading from safetensors.

## Options

```r
xtx.gpuctl  # Enable GPU management (TRUE/FALSE)
```
