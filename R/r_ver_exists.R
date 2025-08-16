#' Check if a specific Rocker image tag exists
#'
#' Validates the format of a version string and checks whether it exists among the available tags
#' for a specified Rocker image on Docker Hub. Supports semantic versioning, CUDA variants, and Ubuntu suffixes.
#'
#' @param version Character string. The tag to check for existence, e.g. \code{"4.4.0"}, \code{"devel"}, or \code{"4.4.0-cuda12.2-ubuntu22.04"}.
#' Must match semantic versioning or be one of \code{"latest"}, \code{"devel"}.
#' @param r_mode Character string. One of \code{"base"}, \code{"rstudio"}, or \code{"tidyverse"}.
#' Determines which Rocker image to query.
#' @param verbose Logical. If \code{TRUE}, prints messages indicating whether the version was found.
#'
#' @return Logical. \code{TRUE} if the specified version tag exists for the given Rocker image; otherwise \code{FALSE}.
#'
#' @examples
#' r_ver_exists("4.4.0")
#' r_ver_exists("devel", r_mode = "rstudio", verbose = TRUE)
#' r_ver_exists("4.4.0-cuda12.2-ubuntu22.04", r_mode = "tidyverse")
#'
#' @export
#'
r_ver_exists <- function(version, r_mode = "base", verbose = FALSE) {
    # Define valid modes
    valid_modes <- c("base", "rstudio", "tidyverse")

    # Validate r_mode early
    if (!r_mode %in% valid_modes) {
        stop(sprintf("Invalid r_mode: '%s'. Must be one of: %s", r_mode, paste(valid_modes, collapse = ", ")))
    }

    # Validate version input type
    if (!is.character(version) || length(version) != 1) {
        stop("version must be a single character string, e.g. '4.4.0' or 'devel'")
    }

    # Define valid tag pattern
    valid_pattern <- "^(latest|devel|\\d+(\\.\\d+){0,2}(-cuda\\d+(\\.\\d+)?(-ubuntu\\d{2}\\.\\d{2})?)?(-ubuntu\\d{2}\\.\\d{2})?)$"

    # Validate format using regex
    if (!grepl(valid_pattern, version)) {
        stop(sprintf("Invalid version format: '%s'. Must match semantic versioning or be 'latest'/'devel'.", version))
    }

    # Get tag info
    tag_info <- get_r_ver_tags(r_mode = r_mode, verbose = verbose)

    # Check existence
    exists <- version %in% tag_info$tags

    if (verbose) {
        msg <- if (exists) "✅ Version exists:" else "❌ Version not found:"
        message(msg, " ", version, " in ", tag_info$image)
    }

    return(exists)
}
