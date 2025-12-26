# Internal diffuseR integration helpers

#' Check if diffuseR is available
#' @keywords internal
.xtx_has_diffuser <- function() {
  requireNamespace("diffuseR", quietly = TRUE)
}
