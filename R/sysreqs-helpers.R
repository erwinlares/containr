# Internal helpers for auto-detecting system library requirements
# from an renv.lock file via the r-hub sysreqs API.


#' Read package names from renv.lock
#'
#' Parses `renv.lock` in the current working directory and returns a
#' character vector of all package names recorded in the `Packages` section.
#'
#' @param lockfile A character string. Path to the `renv.lock` file.
#'   Defaults to `"renv.lock"` in the current working directory.
#' @return A character vector of package names.
#' @keywords internal
.read_renv_packages <- function(lockfile = "renv.lock") {
    lock <- jsonlite::read_json(lockfile)
    packages <- lock[["Packages"]]
    if (is.null(packages) || length(packages) == 0L) {
        return(character(0))
    }
    names(packages)
}


#' Fetch system requirements for a set of R packages
#'
#' Uses `remotes::system_requirements()` to retrieve Ubuntu/Debian `apt`
#' package names required by a set of R packages. Returns a deduplicated
#' character vector of bare `apt` package names suitable for passing to
#' `apt-get install`. Warns and returns an empty character vector if the
#' lookup fails.
#'
#' @param packages A character vector of R package names.
#' @param os_version A character string. The Ubuntu version to query against.
#'   Defaults to `"22.04"` to match the Rocker base image.
#' @param verbose Logical. If `TRUE`, prints progress messages.
#' @return A deduplicated character vector of `apt` package names.
#' @keywords internal
.fetch_sysreqs <- function(packages,
                           os_version = "22.04",
                           verbose    = FALSE) {

    if (length(packages) == 0L) return(character(0))

    if (verbose) {
        cli::cli_inform(
            "Querying system requirements for {length(packages)} package{?s}..."
        )
    }

    raw <- tryCatch(
        remotes::system_requirements("ubuntu", os_version, package = packages),
        error = function(e) {
            cli::cli_warn(c(
                "Could not retrieve system requirements: {conditionMessage(e)}",
                "i" = "No system libraries will be auto-detected.",
                "i" = "Check your internet connection and try again, or supply",
                " " = "  libraries manually via {.arg install_syslibs}."
            ))
            character(0)
        }
    )

    if (length(raw) == 0L) return(character(0))

    # remotes returns full "apt-get install -y <pkg>" strings -- strip the
    # prefix to get bare package names for the Dockerfile apt-get block
    syslibs <- unique(sub("apt-get install -y ", "", raw, fixed = TRUE))
    syslibs <- syslibs[nchar(syslibs) > 0]

    if (verbose && length(syslibs) > 0) {
        cli::cli_inform(
            "Detected {length(syslibs)} system librar{?y/ies}: {.val {syslibs}}"
        )
    }

    syslibs
}
