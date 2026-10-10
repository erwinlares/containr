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
#' `remotes::system_requirements()` validates the Ubuntu release against a
#' fixed internal list (remotes 2.5.0 stops at `"22.04"`), so asking about a
#' newer release, such as the `"24.04"` that backs R 4.4.2 and later, is
#' rejected before any lookup happens. When that happens, the error message
#' itself names the releases `remotes` accepts, so this function reads that
#' list, picks the newest accepted release that is not newer than the one
#' requested, and repeats the lookup against it, with a message saying so.
#' Nothing about the accepted releases is hardcoded here, which means that
#' once `remotes` learns about a newer release the fallback simply stops
#' being needed. A failure that is not a rejected release, a network error
#' for instance, is never retried.
#'
#' With `verbose = TRUE`, the function also reports which package asked for
#' which library, by looking each package up on its own (see
#' `.report_sysreqs_sources()`). The report never changes the returned
#' value.
#'
#' @param packages A character vector of R package names.
#' @param os_version A character string. The Ubuntu version to query
#'   against. Defaults to `"22.04"` when this function is called directly.
#'   [generate_dockerfile()] never relies on that default (C14): it always
#'   passes an explicit `os_version`, derived from the resolved `r_version`
#'   via `.resolve_os_version()` unless its own `os_version` argument
#'   overrides that derivation, since a single hardcoded value here only
#'   matched the Ubuntu release actually backing some R versions and not
#'   others.
#' @param verbose Logical. If `TRUE`, prints progress messages and the
#'   per-package report.
#' @param chunk_size A positive integer. The most packages sent to
#'   `remotes::system_requirements()` in one request, a guard against very
#'   long request URLs for large lockfiles. Defaults to `50L`.
#' @return A deduplicated character vector of `apt` package names.
#' @keywords internal
.fetch_sysreqs <- function(packages,
                           os_version = "22.04",
                           verbose    = FALSE,
                           chunk_size = 50L) {

    if (length(packages) == 0L) return(character(0))

    if (verbose) {
        cli::cli_inform(
            "Querying system requirements for {length(packages)} package{?s}..."
        )
    }

    release <- os_version
    result  <- tryCatch(
        .query_sysreqs(packages, release, chunk_size),
        error = function(e) e
    )

    # Only a rejected release is worth a second attempt. A network failure
    # would fail the same way again, so it goes straight to the warning.
    if (inherits(result, "error") && .is_release_error(result)) {
        accepted <- .accepted_releases(result)
        fallback <- .pick_fallback_release(os_version, accepted)

        if (!is.null(fallback)) {
            second <- tryCatch(
                .query_sysreqs(packages, fallback, chunk_size),
                error = function(e) e
            )

            if (!inherits(second, "error")) {
                cli::cli_inform(c(
                    "i" = "{.pkg remotes} does not accept Ubuntu {.val {os_version}} (it accepts {.val {accepted}}); looked up {.val {fallback}} instead.",
                    " " = "Package names are usually the same across releases, but read the {.code apt-get} block before building."
                ))
                release <- fallback
            }

            result <- second
        }
    }

    if (inherits(result, "error")) {
        cli::cli_warn(c(
            "Could not retrieve system requirements: {conditionMessage(result)}",
            "i" = "No system libraries will be auto-detected.",
            "i" = "Check your internet connection and try again, or supply",
            " " = "  libraries manually via {.arg install_syslibs}."
        ))
        return(character(0))
    }

    if (length(result) == 0L) return(character(0))

    syslibs <- .strip_apt_prefix(result)

    if (verbose && length(syslibs) > 0) {
        cli::cli_inform(
            "Detected {length(syslibs)} system librar{?y/ies}: {.val {syslibs}}"
        )
    }

    if (verbose) {
        .report_sysreqs_sources(packages, release, syslibs)
    }

    syslibs
}


#' Ask remotes for system requirements, in groups
#'
#' @param packages Character vector of R package names.
#' @param os_version Character. An Ubuntu release `remotes` accepts.
#' @param chunk_size Positive integer. The most packages per request.
#' @return A character vector of `"apt-get install -y <pkg>"` strings,
#'   deduplicated across requests.
#' @keywords internal
.query_sysreqs <- function(packages, os_version, chunk_size = 50L) {
    chunk_size <- max(1L, as.integer(chunk_size))
    groups     <- split(packages, ceiling(seq_along(packages) / chunk_size))

    answers <- lapply(groups, function(x) {
        remotes::system_requirements("ubuntu", os_version, package = x)
    })

    unique(unlist(answers, use.names = FALSE))
}


#' Strip the apt-get prefix remotes puts on every answer
#'
#' @param raw A character vector of `"apt-get install -y <pkg>"` strings.
#' @return A deduplicated character vector of bare package names.
#' @keywords internal
.strip_apt_prefix <- function(raw) {
    syslibs <- unique(sub("apt-get install -y ", "", raw, fixed = TRUE))
    syslibs[nchar(syslibs) > 0]
}


#' Is this error `remotes` rejecting the Ubuntu release it was asked about?
#'
#' `remotes::system_requirements()` checks the release with
#' `match.arg()`, which produces "'arg' should be one of ...".
#'
#' @param e A condition object.
#' @return A single logical.
#' @keywords internal
.is_release_error <- function(e) {
    grepl("should be one of", conditionMessage(e), fixed = TRUE)
}


#' Ubuntu releases named in a `match.arg()` error
#'
#' The error `remotes` raises for an unknown release lists the releases it
#' does accept, for instance "'arg' should be one of 14.04, 16.04, 18.04,
#' 20.04, 22.04" with curly quotes around each. This reads them back out of
#' the message, so the list never has to be copied into this package.
#'
#' @param e A condition object.
#' @return A character vector of releases such as `"22.04"`, possibly empty.
#' @keywords internal
.accepted_releases <- function(e) {
    msg <- cli::ansi_strip(conditionMessage(e))
    unique(regmatches(msg, gregexpr("[0-9]{2}\\.[0-9]{2}", msg))[[1]])
}


#' Newest accepted release that is not newer than the requested one
#'
#' A release newer than the request is never chosen: library names drift
#' in one direction, and a lookup against a future release would be
#' guessing.
#'
#' @param requested Character. The Ubuntu release that was rejected.
#' @param accepted Character vector. The releases `remotes` accepts, from
#'   `.accepted_releases()`.
#' @return A single release, or `NULL` when none qualifies.
#' @keywords internal
.pick_fallback_release <- function(requested, accepted) {
    if (length(accepted) == 0L) return(NULL)

    not_newer <- tryCatch(
        numeric_version(accepted) <= numeric_version(requested),
        error = function(e) rep(FALSE, length(accepted))
    )

    candidates <- accepted[not_newer]
    if (length(candidates) == 0L) return(NULL)

    candidates[order(numeric_version(candidates), decreasing = TRUE)][[1L]]
}


#' Report which package asked for which system library
#'
#' Looks each package up on its own and prints, for every library, the
#' packages that reported it. The grouped lookup that builds the
#' `apt-get` block answers "which libraries", never "because of what", so
#' a library missing from the image used to leave no trail. Run only in
#' `verbose` mode, since it makes one request per package, and it never
#' changes what `.fetch_sysreqs()` returns: a library that shows up here
#' but not in the grouped answer is named in a message and left for the
#' caller to add through `install_syslibs`.
#'
#' A failure while tracing is reported and otherwise ignored, because the
#' report is a diagnostic and not part of building the image.
#'
#' @param packages Character vector of R package names.
#' @param os_version Character. The release the grouped lookup used.
#' @param syslibs Character vector. The libraries the grouped lookup found.
#' @return `invisible(NULL)`.
#' @keywords internal
.report_sysreqs_sources <- function(packages, os_version, syslibs) {
    cli::cli_inform(
        "Tracing each library to the package that needs it (one lookup per package)..."
    )

    traced <- tryCatch(
        lapply(packages, function(p) {
            .strip_apt_prefix(
                remotes::system_requirements("ubuntu", os_version, package = p)
            )
        }),
        error = function(e) e
    )

    if (inherits(traced, "error")) {
        cli::cli_inform(c(
            "i" = "Could not trace libraries to packages: {conditionMessage(traced)}"
        ))
        return(invisible(NULL))
    }

    names(traced) <- packages
    per_lib       <- .invert_sysreqs(traced)
    n_with_libs   <- sum(lengths(traced) > 0L)

    if (length(per_lib) == 0L) {
        cli::cli_inform(
            "None of the {length(packages)} package{?s} reported a system library."
        )
        return(invisible(NULL))
    }

    lines <- vapply(
        names(per_lib),
        function(lib) paste0(lib, ": ", paste(per_lib[[lib]], collapse = ", ")),
        character(1)
    )

    bullets        <- lines
    names(bullets) <- rep("*", length(bullets))

    cli::cli_inform(c(
        "i" = "{n_with_libs} of {length(packages)} package{?s} reported system libraries:",
        bullets
    ))

    only_traced <- setdiff(names(per_lib), syslibs)
    if (length(only_traced) > 0L) {
        cli::cli_inform(c(
            "!" = "The per-package lookup found {length(only_traced)} librar{?y/ies} the grouped lookup did not return: {.val {only_traced}}.",
            " " = "They were not added to the {.code apt-get} block. Pass them through {.arg install_syslibs} if the image needs them."
        ))
    }

    invisible(NULL)
}


#' Turn "package -> libraries" into "library -> packages"
#'
#' @param traced A named list. Each element is the character vector of
#'   libraries one package reported.
#' @return A named list: each element is the character vector of packages
#'   that reported the library it is named after, libraries in alphabetical
#'   order. Empty when no package reported anything.
#' @keywords internal
.invert_sysreqs <- function(traced) {
    libs <- sort(unique(unlist(traced, use.names = FALSE)))

    if (length(libs) == 0L) return(list())

    out <- lapply(libs, function(lib) {
        names(traced)[vapply(traced, function(x) lib %in% x, logical(1))]
    })
    names(out) <- libs
    out
}


#' Posit Package Manager codename for an Ubuntu release
#'
#' @param os_version Character. An Ubuntu release, e.g. `"24.04"`.
#' @return A character string, e.g. `"noble"`, or `NA_character_` for a
#'   release this package has no codename for.
#' @keywords internal
.os_codename <- function(os_version) {
    codenames <- c("20.04" = "focal", "22.04" = "jammy", "24.04" = "noble")
    name      <- unname(codenames[as.character(os_version)])

    if (length(name) != 1L) return(NA_character_)

    name
}


#' Dockerfile instructions that restore packages from precompiled binaries
#'
#' Posit Package Manager serves precompiled Linux binaries at
#' `.../cran/__linux__/<codename>/<snapshot>`. Restoring from there skips
#' compilation, which is where almost all of a source restore's time goes.
#' The binaries are still linked against system libraries, so the
#' `apt-get` block that `.fetch_sysreqs()` and `install_syslibs` build is
#' needed just as much as for a source restore. The `-dev` packages in it
#' also pull in the matching runtime libraries, for instance `libwebpmux3`
#' through `libwebp-dev`.
#'
#' The codename must name the Ubuntu release the image is actually built
#' on, not the release a system-requirements lookup was asked about, since
#' a binary built for one release is not guaranteed to load on another.
#'
#' @param image_os_version Character. The Ubuntu release backing the
#'   image's `FROM` line, from `.resolve_os_version()`.
#' @param snapshot Character. `"latest"` or a `"YYYY-MM-DD"` snapshot date.
#' @return A character vector of two `RUN` instructions, or `NULL` when
#'   there is no codename for `image_os_version`, in which case the caller
#'   keeps the source restore.
#' @keywords internal
.binary_restore_instructions <- function(image_os_version, snapshot = "latest") {
    codename <- .os_codename(image_os_version)

    if (is.na(codename)) return(NULL)

    url <- paste0(
        "https://packagemanager.posit.co/cran/__linux__/",
        codename, "/", snapshot
    )

    c(
        paste0("RUN R -e \"install.packages('renv', repos = '", url, "')\""),
        paste0("RUN R -e \"renv::restore(repos = c(CRAN = '", url, "'))\"")
    )
}
