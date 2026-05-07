#' List locally available container images
#'
#' `list_images()` returns a data frame of container images currently stored
#' in the local image store, as reported by `podman image ls` or
#' `docker image ls`. This is useful for finding the image ID to pass to
#' [push_image()] after building an image with [build_image()].
#'
#' @param tool A character string or `NULL`. The container tool to use. One
#'   of `"podman"` or `"docker"`. If `NULL` (the default), the function
#'   auto-detects which tool is available, preferring `podman`.
#' @param verbose Logical. If `TRUE`, prints a progress message before
#'   querying the local image store. Defaults to `FALSE`.
#'
#' @return A data frame with five columns: `repository`, `tag`, `image_id`,
#'   `created`, and `size`. Rows where both `repository` and `tag` are
#'   `<none>` correspond to untagged images produced by [build_image()] when
#'   no `tag` argument was supplied. The data frame is also printed to the
#'   console. Returns an empty data frame if no images are found.
#'
#' @section Finding your image ID:
#' After calling [build_image()], run `list_images()` to find the image ID
#' of the image you just built. Untagged images appear with `<none>` in the
#' `repository` and `tag` columns — the `image_id` column contains the hash
#' you need to pass to [push_image()]:
#'
#' ```r
#' imgs <- list_images()
#' push_image(
#'   image_id = imgs$image_id[1],
#'   netid    = "erwin.lares",
#'   project  = "container-registry"
#' )
#' ```
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # List all local images
#' list_images()
#'
#' # Capture the result for programmatic use
#' imgs <- list_images()
#' imgs$image_id[1]
#' }
list_images <- function(tool    = NULL,
                        verbose = FALSE) {

    # -- 1. Resolve tool -------------------------------------------------------
    resolved_tool <- .resolve_tool(tool)

    # -- 2. Check tool is responsive -------------------------------------------
    .check_tool_responsive(resolved_tool)

    if (verbose) {
        cli::cli_inform(
            "Listing local images using {.val {resolved_tool}}..."
        )
    }


    # -- 3. Query local image store --------------------------------------------
    # Build the format string by joining fields with a literal tab character.
    # Constructing it this way avoids shell interpretation of the curly braces
    # and tab escape sequences that occur when the string is passed directly.
    fmt <- paste(
        c("{{.Repository}}", "{{.Tag}}", "{{.ID}}",
          "{{.CreatedSince}}", "{{.Size}}"),
        collapse = "\t"
    )

    raw <- system2(
        resolved_tool,
        args   = c("image", "ls", "--format", shQuote(fmt)),
        stdout = TRUE,
        stderr = FALSE
    )

    # -- 4. Handle empty result ------------------------------------------------
    if (length(raw) == 0L || (length(raw) == 1L && nchar(trimws(raw)) == 0L)) {
        if (verbose) cli::cli_inform("No local images found.")
        empty <- data.frame(
            repository = character(0),
            tag        = character(0),
            image_id   = character(0),
            created    = character(0),
            size       = character(0),
            stringsAsFactors = FALSE
        )
        return(empty)
    }

    # -- 5. Parse into data frame ----------------------------------------------
    parsed <- do.call(rbind, strsplit(raw, "\t", fixed = TRUE))
    parsed <- as.data.frame(parsed, stringsAsFactors = FALSE)
    colnames(parsed) <- c("repository", "tag", "image_id", "created", "size")
    rownames(parsed) <- NULL

    # -- 6. Print and return ---------------------------------------------------
    print(parsed)
    invisible(parsed)
}
