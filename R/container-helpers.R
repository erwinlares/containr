# Internal helpers for build_image(), push_image(), and list_images()
# These are not exported -- they are called by the container workflow functions.


#' Check if a container tool's daemon is responsive (quiet)
#'
#' Runs `<tool> info` and returns `TRUE` if the exit code is 0, `FALSE`
#' otherwise. Does not error -- used by `.resolve_tool()` during
#' auto-detection to silently try each tool in preference order.
#'
#' @param tool A character string naming the tool to check, e.g. `"podman"`
#'   or `"docker"`.
#' @return Logical. `TRUE` if the tool responded, `FALSE` otherwise.
#' @keywords internal
.is_responsive <- function(tool) {
    exit_code <- system2(
        tool,
        args   = "info",
        stdout = FALSE,
        stderr = FALSE
    )
    exit_code == 0
}


#' Check if the user appears to be logged in to a registry
#'
#' Podman has a native way to answer this: `podman login --get-login
#' <registry>` exits 0 if a cached login exists for that registry and
#' non-zero otherwise. Docker has no equivalent flag -- `docker login
#' --get-login` is not a real Docker CLI option, and running it always
#' exits with a usage error (typically 125) regardless of whether the user
#' is actually logged in. Using it for both tools (the previous behavior)
#' meant Docker users always failed this check, logged in or not.
#'
#' For Docker (and, permissively, any other tool -- `tool_preference` isn't
#' validated against a fixed list, see `.resolve_tool()`), this instead
#' inspects `~/.docker/config.json` directly for an `auths` entry matching
#' `registry`. Docker itself has no query subcommand for "am I logged in
#' to X", so reading its own config file is the standard way tooling
#' (including most CI actions) checks this. Note that `docker login` adds
#' a per-registry entry under `auths` even when a credential helper
#' (`credHelpers`) is configured for that registry, so this check works
#' correctly in that case too.
#'
#' This is a best-effort local check, not a guarantee -- it confirms a
#' cached credential *exists*, not that it's still *valid*. An expired
#' token still leaves an entry in the config file (or Podman's auth
#' store), so a check that passes here can still fail at push time with
#' `unauthorized: authentication required`. It also can't detect a login
#' set up entirely through a global `credsStore` (as opposed to a
#' per-registry `credHelpers` entry), since Docker defers to the external
#' credential store for those without writing anything to `auths` --
#' a narrow, acknowledged gap rather than a silent one.
#'
#' @param tool A character string naming the resolved container tool.
#' @param registry A character string naming the registry hostname.
#' @return Logical. `TRUE` if a cached login appears to exist, `FALSE`
#'   otherwise.
#' @keywords internal
.is_logged_in <- function(tool, registry) {
    if (tool == "podman") {
        exit_code <- system2(
            tool,
            args   = c("login", "--get-login", registry),
            stdout = FALSE,
            stderr = FALSE
        )
        return(exit_code == 0L)
    }

    .docker_config_has_auth(registry)
}


#' Check ~/.docker/config.json for a cached auth entry for a registry
#'
#' @param registry A character string naming the registry hostname.
#' @param config_path A character string. Path to the Docker config file.
#'   Defaults to `~/.docker/config.json`, the real location -- parameterized
#'   so tests can point this at a temp file with real content instead of
#'   mocking `jsonlite::fromJSON()` across a package boundary.
#' @return Logical. `TRUE` if `registry` appears as a key under `auths` in
#'   the Docker config file, `FALSE` if the file is missing, unreadable,
#'   malformed, or simply has no entry for `registry`.
#' @keywords internal
.docker_config_has_auth <- function(registry, config_path = path.expand("~/.docker/config.json")) {
    if (!file.exists(config_path)) {
        return(FALSE)
    }

    config <- tryCatch(
        jsonlite::fromJSON(config_path, simplifyVector = FALSE),
        error = function(e) NULL
    )

    if (is.null(config) || is.null(config$auths)) {
        return(FALSE)
    }

    registry %in% names(config$auths)
}


#' Internal wrapper for Sys.which()
#'
#' .sys_which adds Sys.which() inside containr's namespace so that
#' local_mock_bindings() can be used
#'
#' @keywords internal
.sys_which <- function(tool) {
    Sys.which(tool)
}


# Known install guidance for specific tools, used when no candidate in
# tool_preference is found at all. Anything not listed here (e.g. a typo,
# or a tool from a future phase like "singularity"/"apptainer" before
# Phase 5 adds real support) still shows up in the error, just without an
# install link -- tool_preference is intentionally permissive, so this list
# can grow without a corresponding validation change elsewhere.
#
# Deliberately a list, not c(...): .tool_install_urls[[t]] must return NULL
# for a name that isn't present so the "no installation guidance available"
# fallback below can fire. On a plain character vector, [[ ]] with a
# missing name errors ("subscript out of bounds") instead of returning
# NULL -- a list is what makes the permissive/unknown-tool case work.
.tool_install_urls <- list(
    podman = "https://podman.io/docs/installation",
    docker = "https://docs.docker.com/get-docker/"
)


#' Abort with troubleshooting guidance for an installed-but-unresponsive tool
#'
#' Shared by `.resolve_tool()`'s explicit-tool path and
#' `.check_tool_responsive()`. Docker and Podman get their own specific,
#' known-good troubleshooting steps; any other tool name gets generic
#' guidance instead of being forced through instructions that would be
#' wrong for it (e.g. `systemctl start docker` for a tool that isn't
#' Docker).
#'
#' @param tool A character string naming the tool that is installed but not
#'   responding.
#' @return Called for its side effect of aborting. Never returns.
#' @keywords internal
.abort_tool_not_responsive <- function(tool) {
    if (tool == "docker") {
        cli::cli_abort(c(
            "{.val docker} is installed but the Docker daemon is not running.",
            "i" = "Start Docker Desktop or run",
            " " = "  {.code sudo systemctl start docker}",
            " " = "  in your terminal, then try again."
        ))
    } else if (tool == "podman") {
        cli::cli_abort(c(
            "{.val podman} is installed but is not responsive.",
            "i" = "If using Podman Desktop, ensure it is running.",
            "i" = "On Linux, try",
            " " = "  {.code systemctl --user start podman.socket}",
            " " = "  then try again."
        ))
    } else {
        cli::cli_abort(c(
            "{.val {tool}} is installed but is not responsive.",
            "i" = "Start the {tool} daemon or service and try again."
        ))
    }
}


#' Resolve which container tool to use
#'
#' Tries each candidate in `tool_preference`, in order, selecting the first
#' one that is both installed and responsive. A length-1 `tool_preference`
#' is treated as an explicit, non-negotiable choice -- that single tool is
#' validated (checked for installation and responsiveness) rather than
#' treated as a preference order with nothing left to fall back to if it
#' fails. Errors informatively if no candidate is available.
#'
#' `tool_preference` is not validated against a fixed list of known tool
#' names -- anything on the system's PATH that responds to `<tool> info`
#' with exit code 0 is accepted. This keeps `.resolve_tool()`
#' forward-compatible with tools this package doesn't yet have dedicated
#' support for (e.g. Singularity/Apptainer, planned for a later phase)
#' without a matching validation change here. What is validated is the
#' *shape* of `tool_preference` itself -- it must be a non-empty character
#' vector with no missing values.
#'
#' @param tool_preference A non-empty character vector of tool names, tried
#'   in order. A single value is treated as an explicit choice rather than
#'   an order with a fallback. Defaults to `c("podman", "docker")`.
#' @return A character string naming the resolved tool.
#' @keywords internal
.resolve_tool <- function(tool_preference = c("podman", "docker")) {
    if (!is.character(tool_preference) || length(tool_preference) == 0L ||
        anyNA(tool_preference)) {
        cli::cli_abort(
            "{.arg tool_preference} must be a non-empty character vector."
        )
    }

    if (length(tool_preference) == 1L) {
        # A single candidate is an explicit choice, not a preference order
        # with a fallback -- validate it directly rather than looping.
        tool <- tool_preference
        path <- .sys_which(tool)

        if (nchar(path) == 0) {
            cli::cli_abort(c(
                "{.val {tool}} was requested but is not installed on this system.",
                "i" = "Install {.val {tool}}, or supply more than one candidate in",
                " " = "  {.arg tool_preference} to auto-detect."
            ))
        }

        if (!.is_responsive(tool)) {
            .abort_tool_not_responsive(tool)
        }

        return(tool)
    }

    # Auto-detect: try each candidate in preference order
    for (candidate in tool_preference) {
        if (nchar(.sys_which(candidate)) > 0 && .is_responsive(candidate)) {
            return(candidate)
        }
    }

    # Nothing available and responsive -- give a more specific error if at
    # least one candidate is installed but not running
    installed <- vapply(
        tool_preference,
        function(t) nchar(.sys_which(t)) > 0,
        logical(1)
    )

    if (any(installed)) {
        installed_names <- tool_preference[installed]
        cli::cli_abort(c(
            "{.val {installed_names}} {?is/are} installed but not responsive.",
            "i" = "Start the daemon or service for one of these tools and try again."
        ))
    }

    install_hints <- unname(vapply(tool_preference, function(t) {
        url <- .tool_install_urls[[t]]
        if (is.null(url)) {
            glue::glue("{t}: no installation guidance available for this tool.")
        } else {
            glue::glue("{t} installation: {url}")
        }
    }, character(1)))
    names(install_hints) <- rep("i", length(install_hints))

    cli::cli_abort(c(
        "None of {.val {tool_preference}} {?was/were} found on this system.",
        "i" = "Install one of these container tools to use {.fn build_image}",
        " " = "  or {.fn push_image}.",
        install_hints
    ))
}


#' Check that the container tool daemon is responsive
#'
#' Runs `<tool> info` and checks the exit code. Errors informatively if the
#' tool is found but not responsive -- typically because the daemon is not
#' running.
#'
#' This function is retained for backward compatibility with existing
#' calling code. New code should rely on `.resolve_tool()`, which
#' incorporates responsiveness checking into tool selection.
#'
#' @param tool A character string naming the tool to check, e.g. `"podman"`
#'   or `"docker"`.
#' @return Called for its side effects. Returns `invisible(NULL)`.
#' @keywords internal
.check_tool_responsive <- function(tool) {
    if (!.is_responsive(tool)) {
        .abort_tool_not_responsive(tool)
    }

    invisible(NULL)
}
