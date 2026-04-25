#' Validate a file argument
#'
#' Internal helper used by \code{generate_dockerfile()} to check that
#' optional file arguments (e.g. \code{data_file}, \code{code_file},
#' \code{misc_file}) are valid.
#'
#' @param arg_name Character string, the name of the argument being checked
#'   (used only in error messages).
#' @param value A character path to a file, or \code{NULL}.
#'
#' @return A normalized file path if validation succeeds, or \code{NULL}
#'   if the input was \code{NULL}.
#'
#' @keywords internal
#'

.validate_file_arg <- function(arg_name, value) {
    if (is.null(value)) {
        return(NULL)
    }

    # type & length
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
        stop(sprintf("Argument `%s` must be a length-1 character path or NULL.", arg_name),
            call. = FALSE
        )
    }

    path <- path.expand(value)

    # existence & file-ness
    if (!file.exists(path)) {
        stop(sprintf("Argument `%s`: '%s' does not exist.", arg_name, value),
            call. = FALSE
        )
    }
    # Disallow directories
    if (file.info(path)$isdir) {
        stop(sprintf("Argument `%s`: '%s' is a directory, expected a file.", arg_name, value),
            call. = FALSE
        )
    }

    normalizePath(path, winslash = "/", mustWork = TRUE)
}
