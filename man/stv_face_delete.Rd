\name{stv_face_delete}
\alias{stv_face_delete}
\title{Delete Cached Face}
\description{Delete a cached face from the STV service.}
\usage{
stv_face_delete(face_id)
}
\arguments{
  \item{face_id}{The face ID to delete}
}
\value{
A list with deletion confirmation
}
\examples{
\dontrun{
  stv_face_delete("face-abc123")
}
}
