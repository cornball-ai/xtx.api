% tinyrox says don't edit this manually, but it can't stop you!
\name{.img_edit_flux3}
\alias{.img_edit_flux3}
\title{Image edit via diffuseR FLUX 3 Image Klein}
\usage{
.img_edit_flux3(
  image,
  prompt,
  size = "1024x1024",
  steps = 16L,
  seed = NULL,
  devices = "cuda",
  file = NULL
)
}
\description{
A reference edit: the input goes in whole as the model's reference
and the caption describes the edited result (see
\code{diffuseR::img2img_flux3}). The pipeline is loaded once per
device, in bfloat16 on either device, and cached beside the SD ones.
}
\keyword{internal}
