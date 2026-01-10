\name{stv_face_create}
\alias{stv_face_create}
\title{Create Cached Face for STV}
\description{Preprocess and cache a face image for faster video generation. Subsequent calls to stv() with this face_id will be faster.}
\usage{
stv_face_create(image, name, device)
}
\arguments{
  \item{image}{Path to portrait image (PNG/JPG)}
  \item{name}{Optional name for the face}
  \item{device}{Device for preprocessing: "cuda" or "cpu"}
}
\value{
A list with face id and metadata
}
\examples{
\dontrun{
  face <- stv_face_create("portrait.jpg", name = "host")
  stv(face_id = face$id, audio = "speech.wav")
}
}
