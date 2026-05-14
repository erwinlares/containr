#' Validate a file argument
#'
#' Internal helper used by \code{generate_dockerfile()} to check that
#' optional file arguments (e.g. \code{data_file}, \code{code_file},
#' \code{misc_file}) are valid. Returns a path relative to the current
#' working directory, which serves as the Docker/Podman build context.
#'
#' @param arg_name Character string, the name of the argument being checked
#'   (used only in error messages).
#' @param value A character path to a file, or \code{NULL}.
#'
#' @return A file path relative to the current working directory if
#'   validation succeeds, or \code{NULL} if the input was \code{NULL}.
#'
#' @keywords internal
#'

.validate_file_arg <- function(arg_name, value) {
    if (is.null(value)) {
        return(NULL)
    }

    # type & length
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
        cli::cli_abort(
            "{.arg {arg_name}} must be a length-1 character path or {.val NULL}."
        )
    }

    path <- path.expand(value)

    # existence & file-ness
    if (!file.exists(path)) {
        cli::cli_abort(
            "{.arg {arg_name}}: path {.path {value}} does not exist."
        )
    }

    # Disallow directories
    if (file.info(path)$isdir) {
        cli::cli_abort(
            "{.arg {arg_name}}: {.path {value}} is a directory, not a file."
        )
    }

    # Convert to a path relative to the working directory.
    # Dockerfile COPY instructions require source paths relative to the
    # build context. Files outside the build context cannot be copied
    # into a container image.
    abs_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    abs_wd   <- normalizePath(getwd(), winslash = "/")
    rel      <- fs::path_rel(abs_path, start = abs_wd)

    # fs::path_rel() returns a path starting with ".." when the file is
    # above the working directory, or an absolute path on Windows when
    # the file is on a different drive. Either case means the file is
    # outside the build context.
    if (grepl("^\\.\\.", rel) || fs::is_absolute_path(rel)) {
        cli::cli_abort(c(
            "{.arg {arg_name}}: {.path {value}} is outside the build context.",
            "i" = "Dockerfile COPY can only access files inside the working",
            " " = "  directory. Move the file into your project or set your",
            " " = "  working directory to a parent that contains it."
        ))
    }

    as.character(rel)
}
