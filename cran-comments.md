## xtx.api 0.1.1

First submission.

## Test environments

* local Ubuntu, R 4.6.1 (R CMD check --as-cran via tinypkgr::check())
* win-builder (R-devel, R-release): to be run by the maintainer before
  submission; not yet run at the time of this draft.

## R CMD check results

0 errors | 0 warnings | 1 note

* "New submission". The same NOTE reported the DESCRIPTION URL and
  BugReports as 404 because the GitHub repository was private while the
  package was being prepared; it is public at submission time.

## Notes for the reviewer

* Every example except `clear_diffuser_cache()` is wrapped in
  `\dontrun{}`. Each one either calls a self-hosted HTTP generation
  service (WanGP, SadTalker, a diffusers server, a gpu.ctl host), calls a
  hosted API that needs a key ('OpenAI'), or loads a multi-gigabyte
  diffusion model onto a GPU through 'diffuseR'. None of these can run on
  CRAN's machines, and `\donttest{}` would only move the failure.
* `set_api_base()`, `set_api_key()`, `tti_base()`, `stv_base()`,
  `itv_base()`, `rembg_base()`, `wan2gp_api_base()` and `wan2gp_config()`
  set package-namespaced `xtx.*` options for the session. They are the
  package's configuration setters, return the previous value invisibly,
  and are documented as such; they are not temporary changes to restore.
* One `tempfile()` in the gpuhost image backend is not unlinked because
  it is the returned result: when the caller passes no `file`, the
  generated image is written there and its path is returned.
* The in-process video backends and the sidecar media probe shell out to
  `ffmpeg`/`ffprobe` through `system2()`; both are declared in
  `SystemRequirements` and every call site checks for the binary first.
* `Depends: R (>= 4.4.0)` is for base R's `%||%`.
* No example, test, or vignette writes outside `tempdir()`;
  `tests/tinytest.R` also redirects `tools::R_user_dir()` so no dependency
  can write to the user's home during the check. All tests run against
  in-process fakes; nothing reaches the network.
* Placeholder hosts in examples (`http://gpu-server:8000`) are
  illustrative addresses for self-hosted services on a private network,
  hence http rather than https.
