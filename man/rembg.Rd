% tinyrox says don't edit this manually, but it can't stop you!
\name{rembg}
\alias{rembg}
\title{Remove Image Background}
\usage{
rembg(image, file = NULL, model = "u2net")
}
\arguments{
\item{image}{Character. Path to the input image file.}

\item{file}{Character or NULL. Output path. If NULL, replaces the input file
extension with \code{_rembg.png}.}

\item{model}{Character. Segmentation model to use. Default "u2net".
Options: "u2net", "u2netp", "u2net_human_seg", "u2net_cloth_seg",
"silueta", "isnet-general-use", "isnet-anime", "birefnet-general".}
}
\value{
The output file path (invisibly).
}
\description{
Remove the background from an image using the rembg service (U2-Net).
Returns a PNG with transparent background. Works on any background color -
no greenscreen needed.
}
\details{
The rembg service must be running. Start it with:
\code{docker run -d --name rembg -p 7824:7824 danielgatis/rembg s --host 0.0.0.0 --port 7824}

}
\examples{
\dontrun{
rembg_base("http://localhost:7824")

# Basic usage
rembg("photo.png")  # saves to photo_rembg.png

# Specify output
rembg("photo.png", file = "cutout.png")

# Use anime-optimized model
rembg("anime.png", model = "isnet-anime")
}

}
