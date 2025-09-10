#' Retrieve Docker tags for a Rocker image
#'
#' Queries the Docker Hub API to retrieve all available tags for a specified Rocker image.
#' Supports user-friendly modes: \code{"base"}, \code{"rstudio"}, and \code{"tidyverse"}.
#' Returns a structured list containing the image name, tag vector, and source URL.
#'
#' @param r_mode Character string. One of \code{"base"}, \code{"rstudio"}, or \code{"tidyverse"}.
#' Determines which Rocker image to query. \code{"base"} maps to \code{"rocker/r-ver"}.
#' @param verbose Logical. If \code{TRUE}, prints progress messages during tag retrieval and pagination.
#'
#' @return A named list with the following elements:
#' \describe{
#'   \item{image}{Character string. The full Docker image name, e.g. \code{"rocker/r-ver"}.}
#'   \item{tags}{Character vector. All available tags for the specified image, e.g. \code{c("latest", "devel", "4.4", "4.4.3", ...)}.}
#'   \item{source}{Character string. The base URL of the Docker Hub API used to retrieve the tags.}
#' }
#'
#' @examples
#' \dontrun{
#' get_r_ver_tags("base")
#' get_r_ver_tags("rstudio", verbose = TRUE)
#' }
#'
#' @keywords internal
get_r_ver_tags <- function(r_mode = "base", verbose = FALSE) {
    # Map user-friendly r_mode to actual Rocker image names
    mode_map <- c(base = "r-ver", rstudio = "rstudio", tidyverse = "tidyverse")

    # Validate input
    if (!r_mode %in% names(mode_map)) {
        stop(sprintf("Invalid r_mode: '%s'. Must be one of: %s", r_mode, paste(names(mode_map), collapse = ", ")))
    }

    # Construct full image path and API URL
    image <- paste0("rocker/", mode_map[[r_mode]])
    base_url <- "https://hub.docker.com/v2/repositories"
    url <- sprintf("%s/%s/tags?page_size=100", base_url, image)

    if (verbose) message("Fetching tags from: ", url)

    # Initialize tag list and pagination
    tags <- c()
    while (!is.null(url)) {
        res <- httr::GET(url)
        stopifnot(httr::status_code(res) == 200)
        content <- httr::content(res)

        # Extract tag names
        tags <- c(tags, vapply(content$results, `[[`, "", "name"))

        # Follow pagination
        url <- content$`next`
        if (verbose && !is.null(url)) message("Following pagination to: ", url)
    }

    # Return structured output
    return(list(
        image = image,
        tags = tags,
        source = base_url
    ))
}
