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
- **stv**: sadtalker (default), wan2gp_api (LTX-2), wan2gp (Docker), fal (cloud)
- **itv**: wan2gp_api (LTX-2, recommended), cogvideo, wan2gp (Docker), fal (cloud)
- **ttv**: wan2gp_api (LTX-2, recommended), wan2gp (Docker)

## WanGP API (Recommended)

The `wan2gp_api` backend connects to a FastAPI service running LTX-2 19B.
This is the recommended approach - the service stays warm with models loaded.

```r
# Configure once
wan2gp_api_base("http://localhost:8000")

# Text-to-video
ttv("A cat playing piano in a jazz club")

# Image-to-video
itv("scene.jpg", "Camera slowly zooms in", backend = "wan2gp_api")

# Speech-to-video (talking head with audio)
stv("portrait.jpg", "speech.wav", backend = "wan2gp_api")

# Quality presets: "fast", "balanced" (default), "quality"
ttv("Mountain sunset", quality = "quality")  # 40 steps, best quality
```

Start the service with: `docker-compose up -d` in ~/Wan2GP_api

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
xtx.gpu.ctl  # Enable gpu.ctl service acquisition (TRUE/FALSE); gpu.ctl is not in Suggests, resolved at call time
```
