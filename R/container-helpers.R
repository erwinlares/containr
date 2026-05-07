# Internal helpers for build_image() and push_image()
# These are not exported — they are called by the container workflow functions.


#' Resolve which container tool to use
#'
#' Checks the PATH for `podman` and `docker`. When `tool = NULL`, prefers
#' `podman` if both are found. Errors informatively if neither is found.
#'
#' @param tool A character string (`"podman"` or `"docker"`) or `NULL`.
#' @return A character string, either `"podman"` or `"docker"`.
#' @keywords internal
.resolve_tool <- function(tool = NULL) {
    valid_tools <- c("podman", "docker")

    if (!is.null(tool)) {
        tool <- match.arg(tool, choices = valid_tools)
        path <- Sys.which(tool)
        if (nchar(path) == 0) {
            cli::cli_abort(c(
                "{.val {tool}} was requested but is not available on this system.",
                "i" = "Install {.val {tool}} or use {.code tool = NULL} to auto-detect."
            ))
        }
        return(tool)
    }

    # Auto-detect: prefer podman, fall back to docker
    for (candidate in valid_tools) {
        if (nchar(Sys.which(candidate)) > 0) {
            return(candidate)
        }
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
#' @param tool A character string, either `"podman"` or `"docker"`.
#' @return Called for its side effects. Returns `invisible(NULL)`.
#' @keywords internal
.check_tool_responsive <- function(tool) {
    exit_code <- system2(
        tool,
        args   = "info",
        stdout = FALSE,
        stderr = FALSE
    )

    if (exit_code != 0) {
        if (tool == "docker") {
            cli::cli_abort(c(
                "{.val docker} is installed but the Docker daemon is not running.",
                "i" = "Start Docker Desktop or run {.code sudo systemctl start docker}",
                " " = "  in your terminal, then try again."
            ))
        } else {
            cli::cli_abort(c(
                "{.val podman} is installed but is not responsive.",
                "i" = "If using Podman Desktop, ensure it is running.",
                "i" = "On Linux, try {.code systemctl --user start podman.socket}",
                " " = "  then try again."
            ))
        }
    }

    invisible(NULL)
}
