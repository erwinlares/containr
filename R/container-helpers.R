# Internal helpers for build_image(), push_image(), and list_images()
# These are not exported -- they are called by the container workflow functions.


#' Check if a container tool's daemon is responsive (quiet)
#'
#' Runs `<tool> info` and returns `TRUE` if the exit code is 0, `FALSE`
#' otherwise. Does not error -- used by `.resolve_tool()` during
#' auto-detection to silently try each tool in preference order.
#'
#' @param tool A character string, either `"podman"` or `"docker"`.
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


#' Internal wrapper for Sys.which()
#'
#' .sys_which adds Sys.which() inside containr's namespace so that
#' local_mock_bindings() can be used
#'
#' @keywords internal
.sys_which <- function(tool) {
    Sys.which(tool)
}

#' Resolve which container tool to use
#'
#' When `tool` is specified explicitly, validates that it is installed and
#' responsive. When `tool = NULL`, tries each candidate in preference order
#' (Podman first, then Docker), selecting the first one that is both
#' installed and responsive. Errors informatively if no tool is available.
#'
#' @param tool A character string (`"podman"` or `"docker"`) or `NULL`.
#' @return A character string, either `"podman"` or `"docker"`.
#' @keywords internal
.resolve_tool <- function(tool = NULL) {
    valid_tools <- c("podman", "docker")

    if (!is.null(tool)) {
        # User specified a tool explicitly -- validate it
        tool <- match.arg(tool, choices = valid_tools)
        path <- .sys_which(tool)
        if (nchar(path) == 0) {
            cli::cli_abort(c(
                "{.val {tool}} was requested but is not installed on this system.",
                "i" = "Install {.val {tool}} or use {.code tool = NULL} to auto-detect."
            ))
        }
        if (!.is_responsive(tool)) {
            if (tool == "docker") {
                cli::cli_abort(c(
                    "{.val docker} is installed but the Docker daemon is not running.",
                    "i" = "Start Docker Desktop or run",
                    " " = "  {.code sudo systemctl start docker}",
                    " " = "  in your terminal, then try again."
                ))
            } else {
                cli::cli_abort(c(
                    "{.val podman} is installed but is not responsive.",
                    "i" = "If using Podman Desktop, ensure it is running.",
                    "i" = "On Linux, try",
                    " " = "  {.code systemctl --user start podman.socket}",
                    " " = "  then try again."
                ))
            }
        }
        return(tool)
    }

    # Auto-detect: try each in preference order, checking responsiveness
    for (candidate in valid_tools) {
        if (nchar(.sys_which(candidate)) > 0 && .is_responsive(candidate)) {
            return(candidate)
        }
    }

    # Nothing available and responsive
    # Provide a more specific error if tools are installed but not running
    installed <- vapply(valid_tools, function(t) nchar(.sys_which(t)) > 0, logical(1))

    if (any(installed)) {
        installed_names <- valid_tools[installed]
        cli::cli_abort(c(
            "{.val {installed_names}} {?is/are} installed but not responsive.",
            "i" = "Start the daemon for one of these tools and try again.",
            "i" = "For Docker: start Docker Desktop or run",
            " " = "  {.code sudo systemctl start docker}",
            "i" = "For Podman: start Podman Desktop or run",
            " " = "  {.code systemctl --user start podman.socket}"
        ))
    }

    cli::cli_abort(c(
        "Neither {.val podman} nor {.val docker} was found on this system.",
        "i" = "Install one of these container tools to use {.fn build_image}",
        " " = "  or {.fn push_image}.",
        "i" = "Podman installation: {.url https://podman.io/docs/installation}",
        "i" = "Docker installation: {.url https://docs.docker.com/get-docker/}"
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
#' @param tool A character string, either `"podman"` or `"docker"`.
#' @return Called for its side effects. Returns `invisible(NULL)`.
#' @keywords internal
.check_tool_responsive <- function(tool) {
    if (!.is_responsive(tool)) {
        if (tool == "docker") {
            cli::cli_abort(c(
                "{.val docker} is installed but the Docker daemon is not running.",
                "i" = "Start Docker Desktop or run",
                " " = "  {.code sudo systemctl start docker}",
                " " = "  in your terminal, then try again."
            ))
        } else {
            cli::cli_abort(c(
                "{.val podman} is installed but is not responsive.",
                "i" = "If using Podman Desktop, ensure it is running.",
                "i" = "On Linux, try",
                " " = "  {.code systemctl --user start podman.socket}",
                " " = "  then try again."
            ))
        }
    }

    invisible(NULL)
}
