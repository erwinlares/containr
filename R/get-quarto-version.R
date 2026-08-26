#' Resolve and validate a Quarto CLI version
#'
#' Internal helper used by \code{generate_dockerfile()} when
#' \code{install_quarto = TRUE}. If \code{quarto_version} is \code{"latest"},
#' queries the Quarto releases API to resolve it to a concrete version at
#' generation time, so the version actually pinned into the Dockerfile is
#' recorded rather than left as a moving target. If an explicit version is
#' supplied, validates its format and confirms a matching GitHub release
#' actually exists, so a typo or unreleased version fails here rather than
#' producing a Dockerfile that 404s at build time.
#'
#' @param quarto_version Character string. Either \code{"latest"} or an
#'   explicit Quarto version, e.g. \code{"1.5.57"}.
#' @param verbose Logical. If \code{TRUE}, prints progress messages during
#'   resolution. Defaults to \code{FALSE}.
#'
#' @return Character string. The resolved version, without a leading
#'   \code{"v"} (e.g. \code{"1.5.57"}), suitable for interpolating directly
#'   into Quarto's versioned download URL.
#'
#' @keywords internal
#'
.get_quarto_version <- function(quarto_version = "latest", verbose = FALSE) {
    if (!is.character(quarto_version) || length(quarto_version) != 1L ||
        is.na(quarto_version)) {
        cli::cli_abort(
            "{.arg quarto_version} must be a single character string, e.g. {.val 1.5.57} or {.val latest}."
        )
    }

    base_url <- "https://api.github.com/repos/quarto-dev/quarto-cli/releases"

    # -- "latest": resolve to a concrete version at generation time ---------
    if (identical(quarto_version, "latest")) {
        url <- paste0(base_url, "/latest")

        if (verbose) cli::cli_inform("Resolving latest Quarto release from {.url {url}}")

        resp <- httr2::request(url) |>
            httr2::req_error(is_error = \(r) FALSE) |>
            httr2::req_perform()

        if (httr2::resp_status(resp) != 200L) {
            cli::cli_abort(c(
                "Quarto releases API request failed.",
                "i" = "HTTP status: {.val {httr2::resp_status(resp)}}"
            ))
        }

        resolved <- sub("^v", "", httr2::resp_body_json(resp)$tag_name)

        if (verbose) cli::cli_inform("Latest Quarto release resolved to {.val {resolved}}.")

        return(resolved)
    }

    # -- explicit version: validate format, then confirm it exists ----------
    # Quarto tags are plain semver, optionally with a pre-release suffix
    # (e.g. "1.7.1-beta") -- unlike Rocker's "latest"/"devel"/CUDA-suffix
    # grammar, so .r_ver_exists()'s pattern isn't reusable here.
    valid_pattern <- "^\\d+\\.\\d+\\.\\d+(-[A-Za-z0-9.]+)?$"

    if (!grepl(valid_pattern, quarto_version)) {
        cli::cli_abort(c(
            "{.val {quarto_version}} is not a valid Quarto version format.",
            "i" = "Must be plain semantic versioning, e.g. {.val 1.5.57}, or {.val latest}."
        ))
    }

    url <- paste0(base_url, "/tags/v", quarto_version)

    if (verbose) cli::cli_inform("Checking Quarto release {.val {quarto_version}} at {.url {url}}")

    resp <- httr2::request(url) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform()

    if (httr2::resp_status(resp) == 404L) {
        cli::cli_abort(c(
            "Quarto release {.val {quarto_version}} was not found.",
            "i" = "Check available releases at",
            " " = "  {.url https://github.com/quarto-dev/quarto-cli/releases}"
        ))
    }

    if (httr2::resp_status(resp) != 200L) {
        cli::cli_abort(c(
            "Quarto releases API request failed.",
            "i" = "HTTP status: {.val {httr2::resp_status(resp)}}"
        ))
    }

    quarto_version
}
