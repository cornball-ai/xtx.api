#' Generate Image from Text (Deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [tti()] instead.
#'
#' @inheritParams tti
#' @return See [tti()]
#' @seealso [tti()]
#' @export
xtx_txt2img <- function(prompt,
                        backend = c("openai", "diffuser", "diffusers_api", "auto"),
                        model = NULL,
                        negative_prompt = NULL,
                        size = NULL,
                        quality = "standard",
                        style = "vivid",
                        n = 1,
                        steps = 50,
                        guidance_scale = 7.5,
                        seed = NULL,
                        devices = "cpu",
                        response_format = "url",
                        file = NULL,
                        timeout = 120) {
  .Deprecated("tti")
  tti(
    prompt = prompt,
    backend = backend,
    model = model,
    negative_prompt = negative_prompt,
    size = size,
    quality = quality,
    style = style,
    n = n,
    steps = steps,
    guidance_scale = guidance_scale,
    seed = seed,
    devices = devices,
    response_format = response_format,
    file = file,
    timeout = timeout
  )
}
