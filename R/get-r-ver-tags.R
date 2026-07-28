#' Retrieve Docker tags for a Rocker image
#'
#' Queries the Docker Hub API to retrieve all available tags for a specified
#' Rocker image. Supports user-friendly modes: `"base"`, `"tidyverse"`,
#' `"rstudio"`, and `"verse"`. Returns a structured list containing
#' the image name, tag vector, and source URL.
#'
#' @param r_mode Character string. One of `"base"`, `"tidyverse"`,
#'   `"rstudio"`, or `"verse"`. Determines which Rocker image to
#'   query. `"base"` maps to `"rocker/r-ver"`.
#' @param verbose Logical. If `TRUE`, prints progress messages during tag
#'   retrieval and pagination. Defaults to `FALSE`.
#'
#' @return A named list with three elements: `image` (the full Docker image
#'   name), `tags` (character vector of all available tags), and `source`
#'   (the base URL of the Docker Hub API).
#'
#' @keywords internal
.get_r_ver_tags <- function(r_mode = "base", verbose = FALSE) {

    if (!r_mode %in% names(.r_mode_registry)) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Must be one of {.val {names(.r_mode_registry)}}."
        ))
    }

    image    <- .r_mode_registry[[r_mode]]$tag_repo
    base_url <- "https://hub.docker.com/v2/repositories"
    url      <- sprintf("%s/%s/tags?page_size=100", base_url, image)

    if (verbose) cli::cli_inform("Fetching tags from: {.url {url}}")

    tags <- character(0)

    while (!is.null(url)) {
        resp <- httr2::request(url) |>
            httr2::req_error(is_error = \(r) FALSE) |>
            httr2::req_perform()

        if (httr2::resp_status(resp) != 200L) {
            cli::cli_abort(c(
                "Docker Hub API request failed.",
                "i" = "Image: {.val {image}}",
                "i" = "HTTP status: {.val {httr2::resp_status(resp)}}"
            ))
        }

        body <- httr2::resp_body_json(resp)
        tags <- c(tags, vapply(body$results, `[[`, "", "name"))

        url <- body$`next`
        if (verbose && !is.null(url)) {
            cli::cli_inform("Following pagination to: {.url {url}}")
        }
    }

    list(
        image  = image,
        tags   = tags,
        source = base_url
    )
}
