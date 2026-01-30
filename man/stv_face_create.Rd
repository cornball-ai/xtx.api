% tinyrox says don't edit this manually, but it can't stop you!
\name{stv_face_create}
\alias{stv_face_create}
\title{Create Cached Face for STV}
\usage{
stv_face_create(image, name = NULL, device = "cuda")
}
\arguments{
\item{image}{Path to portrait image (PNG/JPG)}

\item{name}{Optional name for the face}

\item{device}{Device for preprocessing: "cuda" or "cpu"}
}
\value{
A list with face id and metadata
}
\description{
Preprocess and cache a face image for faster video generation.
Subsequent calls to stv() with this face_id will be faster.
}
\examples{
\dontrun{
  face <- stv_face_create("portrait.jpg", name = "host")
  stv(face_id = face$id, audio = "speech.wav")
}
}
