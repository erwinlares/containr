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
#'
#' @keywords internal
#'
.r_ver_exists <- function(version, r_mode = "base", verbose = FALSE) {
    # Define valid modes
    valid_modes <- c("base", "rstudio", "tidyverse", "tidystudio")

    # Validate r_mode early
    if (!r_mode %in% valid_modes) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Must be one of {.val {valid_modes}}."
        ))
    }

    # Validate version input type
    if (!is.character(version) || length(version) != 1 || is.na(version)) {
        cli::cli_abort(
            "{.arg version} must be a single character string, e.g. {.val 4.4.0} or {.val devel}."
        )
    }

    # Define valid tag pattern
    valid_pattern <- "^(latest|devel|\\d+(\\.\\d+){0,2}(-cuda\\d+(\\.\\d+)?(-ubuntu\\d{2}\\.\\d{2})?)?(-ubuntu\\d{2}\\.\\d{2})?)$"

    # Validate format using regex
    if (!grepl(valid_pattern, version)) {
        cli::cli_abort(c(
            "{.val {version}} is not a valid version format.",
            "i" = "Must match semantic versioning (e.g. {.val 4.4.0}) or be {.val latest} or {.val devel}."
        ))
    }

    # Get tag info
    tag_info <- .get_r_ver_tags(r_mode = r_mode, verbose = verbose)

    # Check existence
    exists <- version %in% tag_info$tags

    if (verbose) {
        if (exists) {
            cli::cli_inform("Version {.val {version}} found in {.val {tag_info$image}}.")
        } else {
            cli::cli_inform("Version {.val {version}} not found in {.val {tag_info$image}}.")
        }
    }

    return(exists)
}
