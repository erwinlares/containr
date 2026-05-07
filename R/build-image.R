#' Build a container image from a Dockerfile
#'
#' `build_image()` builds a container image from a `Dockerfile` using either
#' `podman` or `docker`. It auto-detects which tool is available on the system
#' unless `tool` is specified explicitly. Use `dry_run = TRUE` to preview the
#' exact command that would be run without executing it.
#'
#' @param dockerfile A character string. Path to the `Dockerfile` to build
#'   from. Defaults to `"Dockerfile"` in the current working directory.
#' @param tag A character string or `NULL`. The full image tag to assign to
#'   the built image, including the registry prefix, e.g.
#'   `"registry.doit.wisc.edu/netid/myimage"`. If `NULL`, no tag is applied
#'   and the image is identified only by its image ID. Defaults to `NULL`.
#' @param tool A character string or `NULL`. The container tool to use for
#'   building. One of `"podman"` or `"docker"`. If `NULL` (the default),
#'   the function auto-detects which tool is available, preferring `podman`
#'   if both are found.
#' @param dry_run Logical. If `TRUE`, prints the command that would be run
#'   without executing it. Useful for verifying the command before committing
#'   to a potentially slow build. Defaults to `FALSE`.
#' @param verbose Logical. If `TRUE`, prints progress messages at each step.
#'   Defaults to `FALSE`.
#' @param comments Logical. If `TRUE`, prints explanatory context before each
#'   step — what the command does, why it is needed, and common pitfalls.
#'   Useful for first-time users learning the container build workflow.
#'   Defaults to `FALSE`.
#'
#' @return Called for its side effects. Returns `invisible(NULL)`.
#'
#' @section Prerequisites:
#' Before calling `build_image()`, ensure the following are in place:
#'
#' 1. A `Dockerfile` exists at `dockerfile`. Use
#'    [generate_dockerfile()] to create one if needed.
#' 2. An `renv.lock` file is present in `output` — the generated `Dockerfile`
#'    uses it to restore the R package environment inside the container.
#' 3. Either `podman` or `docker` is installed and the daemon (for `docker`)
#'    or the Podman service is running. Verify with `podman info` or
#'    `docker info` in a terminal.
#'
#' @section Tagging convention for CHTC:
#' For UW-Madison CHTC, the full tag format is:
#' `registry.doit.wisc.edu/<netid>/<image-name>:<version>`
#'
#' For example: `registry.doit.wisc.edu/erwin.lares/my-analysis:1.0.0`
#'
#' The version tag defaults to `latest` if omitted. Using explicit version
#' tags (e.g. `1.0.0`) is recommended for reproducibility — `latest` will
#' be overwritten each time you push.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Build with auto-detected tool and no tag
#' build_image()
#'
#' # Build and tag for CHTC registry
#' build_image(tag = "registry.doit.wisc.edu/netid/my-analysis:1.0.0")
#'
#' # Preview the build command without running it
#' build_image(
#'   tag     = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
#'   dry_run = TRUE
#' )
#'
#' # Guided build for first-time users — run from your project directory
#' build_image(
#'   tag      = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
#'   verbose  = TRUE,
#'   comments = TRUE
#' )
#' }
build_image <- function(dockerfile = "Dockerfile",
                        tag        = NULL,
                        tool       = NULL,
                        dry_run    = FALSE,
                        verbose    = FALSE,
                        comments   = FALSE) {

    # -- 1. Validate dockerfile ------------------------------------------------
    if (!file.exists(dockerfile)) {
        cli::cli_abort(c(
            "Dockerfile not found at {.path {dockerfile}}.",
            "i" = "Use {.fn generate_dockerfile} to create one, or supply the correct path."
        ))
    }

    # -- 2. Resolve tool -------------------------------------------------------
    resolved_tool <- .resolve_tool(tool)

    # -- 3. Check tool is responsive -------------------------------------------
    .check_tool_responsive(resolved_tool)

    # -- 4. Build command ------------------------------------------------------
    args <- c("build")

    if (!is.null(tag)) {
        args <- c(args, "-t", tag)
    }

    args <- c(args, "-f", dockerfile, ".")

    # -- 5. Execute or preview -------------------------------------------------
    if (comments) {
        cli::cli_inform(c(
            "i" = "The {.strong build} command creates a container image from your Dockerfile.",
            "i" = "The build context is your current working directory. {resolved_tool}",
            " " = "  uses as the root when copying files into the image.",
            "i" = "The {.code renv.lock} file must be present in the build context --",
            " " = "  it is used inside the container to restore your R package environment.",
            "i" = "Build times vary: a first build that installs many R packages may take",
            " " = "  10-30 minutes. Subsequent builds reuse cached layers and are much faster.",
            "i" = "If the build fails, check the error output carefully -- missing system",
            " " = "  libraries or unavailable CRAN packages are the most common causes."
        ))
    }

    if (verbose) {
        cli::cli_inform("Resolving tool: using {.val {resolved_tool}}")
        if (!is.null(tag)) {
            cli::cli_inform("Building image with tag {.val {tag}}")
        } else {
            cli::cli_inform("Building image (no tag applied)")
        }
        cli::cli_inform(
            "Build context: {.path {getwd()}}, Dockerfile: {.path {dockerfile}}"
        )
    }

    cmd <- paste(resolved_tool, paste(args, collapse = " "))

    if (dry_run) {
        cli::cli_inform(c(
            "v" = "Dry run -- command that would be executed:",
            " " = "{.code {cmd}}"
        ))
        return(invisible(NULL))
    }

    if (verbose) cli::cli_inform("Running: {.code {cmd}}")

    exit_code <- system2(resolved_tool, args = args)

    if (exit_code != 0) {
        cli::cli_abort(c(
            "{resolved_tool} build failed with exit code {exit_code}.",
            "i" = "Check the output above for error details.",
            "i" = "Common causes: missing system libraries in the Dockerfile,",
            " " = "  unavailable R packages, or insufficient disk space."
        ))
    }

    if (verbose) {
        cli::cli_alert_success("Image built successfully.")
        if (!is.null(tag)) {
            cli::cli_inform("Tagged as {.val {tag}}")
        }
    }

    invisible(NULL)
}
