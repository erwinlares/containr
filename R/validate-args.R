#' Validate a file argument
#'
#' Internal helper used by \code{generate_dockerfile()} to check that
#' optional file arguments (e.g. \code{data_file}, \code{code_file},
#' \code{misc_file}) are valid. Accepts a single path, a character vector
#' of paths, or a path to a directory (copied whole). Returns each path
#' relative to the current working directory, which serves as the
#' Docker/Podman build context.
#'
#' @param arg_name Character string, the name of the argument being checked
#'   (used only in error messages).
#' @param value A character vector of paths to files and/or directories, or
#'   \code{NULL}. Every element is validated independently, so a vector may
#'   freely mix files and directories.
#'
#' @return A character vector of paths relative to the current working
#'   directory, one per element of \code{value}, if validation succeeds, or
#'   \code{NULL} if the input was \code{NULL}.
#'
#' @keywords internal
#'

.validate_file_arg <- function(arg_name, value) {
    if (is.null(value)) {
        return(NULL)
    }

    # type & length -- any length >= 1 is fine; NA anywhere is not.
    if (!is.character(value) || length(value) == 0L || anyNA(value)) {
        cli::cli_abort(
            "{.arg {arg_name}} must be a character vector of paths, or {.val NULL}."
        )
    }

    # Reference point for relative-path conversion, computed once rather
    # than per element.
    abs_wd <- normalizePath(getwd(), winslash = "/")

    vapply(value, function(v) {
        path <- path.expand(v)

        # existence -- files and directories are both accepted; Docker's
        # COPY instruction copies an entire directory tree when the source
        # is a directory, so no separate handling is needed downstream.
        if (!file.exists(path)) {
            cli::cli_abort(
                "{.arg {arg_name}}: path {.path {v}} does not exist."
            )
        }

        # Convert to a path relative to the working directory.
        # Dockerfile COPY instructions require source paths relative to the
        # build context. Files outside the build context cannot be copied
        # into a container image.
        abs_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
        rel      <- fs::path_rel(abs_path, start = abs_wd)

        # fs::path_rel() returns a path starting with ".." when the file is
        # above the working directory, or an absolute path on Windows when
        # the file is on a different drive. Either case means the file is
        # outside the build context.
        if (grepl("^\\.\\.", rel) || fs::is_absolute_path(rel)) {
            cli::cli_abort(c(
                "{.arg {arg_name}}: {.path {v}} is outside the build context.",
                "i" = "Dockerfile COPY can only access files inside the working",
                " " = "  directory. Move the file into your project or set your",
                " " = "  working directory to a parent that contains it."
            ))
        }

        as.character(rel)
    }, FUN.VALUE = character(1L), USE.NAMES = FALSE)
}
