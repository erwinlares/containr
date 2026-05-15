#' Build a container image from a Dockerfile
#'
#' `build_image()` builds a container image from a `Dockerfile` using either
#' `podman` or `docker`. It auto-detects which tool is available on the system
#' unless `tool` is specified explicitly. Use `dry_run = TRUE` to preview the
#' exact command that would be run without executing it.
#'
#' When the target `platform` differs from the host architecture (e.g.
#' building `linux/amd64` on an Apple Silicon Mac), `build_image()`
#' automatically uses `docker buildx build` instead of `docker build`, and
#' includes `--load` to ensure the image is available in the local store.
#' For `podman`, `--platform` is passed directly to `podman build`.
#'
#' @param dockerfile A character string. Path to the `Dockerfile` to build
#'   from. Defaults to `"Dockerfile"` in the current working directory.
#' @param tag A character string or `NULL`. The full image tag to assign to
#'   the built image, including the registry prefix, e.g.
#'   `"registry.doit.wisc.edu/netid/myimage"`. If `NULL`, no tag is applied
#'   and the image is identified only by its image ID. Defaults to `NULL`.
#' @param platform A character string or `NULL`. The target platform for the
#'   container image. Defaults to `"linux/amd64"`, which is the architecture
#'   used by most HPC and HTC clusters. Set to `"linux/arm64"` for ARM-based
#'   systems (Apple Silicon, AWS Graviton). Set to `NULL` to let the
#'   container tool build for the host architecture.
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
#'   step -- what the command does, why it is needed, and common pitfalls.
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
#' 2. An `renv.lock` file is present in the build context -- the generated
#'    `Dockerfile` uses it to restore the R package environment inside the
#'    container.
#' 3. Either `podman` or `docker` is installed and the daemon (for `docker`)
#'    or the Podman service is running. Verify with `podman info` or
#'    `docker info` in a terminal.
#'
#' @section Cross-platform builds:
#' Building for a different architecture than the host requires emulation.
#' On Apple Silicon Macs, building `linux/amd64` images uses QEMU emulation
#' under Podman, which can be slow and unstable. Docker Desktop handles
#' cross-platform builds more reliably via `buildx` and Rosetta 2.
#'
#' If builds fail with QEMU segfaults, consider:
#' - Using Docker Desktop instead of Podman (`tool = "docker"`)
#' - Building on a native x86_64 machine (e.g. via GitHub Actions)
#' - Building directly on the target cluster if it supports container builds
#'
#' @section Tagging convention for CHTC:
#' For UW-Madison CHTC, the full tag format is:
#' `registry.doit.wisc.edu/<netid>/<image-name>:<version>`
#'
#' For example: `registry.doit.wisc.edu/erwin.lares/my-analysis:1.0.0`
#'
#' The version tag defaults to `latest` if omitted. Using explicit version
#' tags (e.g. `1.0.0`) is recommended for reproducibility -- `latest` will
#' be overwritten each time you push.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Build for linux/amd64 (default) with auto-detected tool
#' build_image()
#'
#' # Build and tag for CHTC registry
#' build_image(tag = "registry.doit.wisc.edu/netid/my-analysis:1.0.0")
#'
#' # Build for the host architecture (no --platform flag)
#' build_image(platform = NULL)
#'
#' # Build for ARM64 (e.g. local use on Apple Silicon)
#' build_image(platform = "linux/arm64")
#'
#' # Preview the build command without running it
#' build_image(
#'   tag     = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
#'   dry_run = TRUE
#' )
#'
#' # Guided build for first-time users
#' build_image(
#'   tag      = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
#'   verbose  = TRUE,
#'   comments = TRUE
#' )
#' }
build_image <- function(dockerfile = "Dockerfile",
                        tag        = NULL,
                        platform   = "linux/amd64",
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

    # -- 2. Validate platform --------------------------------------------------
    valid_platforms <- c("linux/amd64", "linux/arm64")

    if (!is.null(platform) && !platform %in% valid_platforms) {
        cli::cli_abort(c(
            "{.val {platform}} is not a supported {.arg platform}.",
            "i" = "Valid choices are {.val {valid_platforms}} or {.val NULL}",
            " " = "  to build for the host architecture."
        ))
    }

    # -- 3. Resolve tool -------------------------------------------------------
    resolved_tool <- .resolve_tool(tool)

    # -- 4. Check tool is responsive -------------------------------------------
    .check_tool_responsive(resolved_tool)

    # -- 5. Detect host architecture and warn if cross-compiling ---------------
    host_arch <- Sys.info()[["machine"]]
    is_cross <- FALSE

    if (!is.null(platform)) {
        # Map host machine strings to platform equivalents
        host_platform <- switch(host_arch,
                                "x86_64"  = "linux/amd64",
                                "aarch64" = "linux/arm64",
                                "arm64"   = "linux/arm64",
                                NULL
        )

        if (!is.null(host_platform) && platform != host_platform) {
            is_cross <- TRUE
            cli::cli_warn(c(
                "Building {.val {platform}} on a {.val {host_arch}} host.",
                "i" = "This requires emulation and may be slow or unstable.",
                "i" = "If the build fails with a segfault, try {.code tool = \"docker\"}",
                " " = "  (Docker Desktop handles cross-platform builds more reliably)",
                " " = "  or build on a native x86_64 machine."
            ))
        }
    }

    # -- 6. Build command ------------------------------------------------------
    # Determine whether to use buildx for docker cross-platform builds.
    # podman handles --platform natively. docker requires buildx + --load
    # when the target platform differs from the host.
    use_buildx <- resolved_tool == "docker" && is_cross

    if (use_buildx) {
        args <- c("buildx", "build")
    } else {
        args <- c("build")
    }

    if (!is.null(platform)) {
        args <- c(args, "--platform", platform)
    }

    if (!is.null(tag)) {
        args <- c(args, "-t", tag)
    }

    # --load is required for docker buildx to store the image locally
    if (use_buildx) {
        args <- c(args, "--load")
    }

    args <- c(args, "-f", dockerfile, ".")

    # -- 7. Execute or preview -------------------------------------------------
    if (comments) {
        cli::cli_inform(c(
            "i" = "The {.strong build} command creates a container image from your Dockerfile.",
            "i" = "The build context is your current working directory. {resolved_tool}",
            " " = "  uses it as the root when copying files into the image.",
            "i" = "The {.code renv.lock} file must be present in the build context --",
            " " = "  it is used inside the container to restore your R package environment.",
            "i" = "Build times vary: a first build that installs many R packages may take",
            " " = "  10-30 minutes. Subsequent builds reuse cached layers and are much faster.",
            "i" = "If the build fails, check the error output carefully -- missing system",
            " " = "  libraries or unavailable CRAN packages are the most common causes."
        ))

        if (use_buildx) {
            cli::cli_inform(c(
                "i" = "Using {.code docker buildx} for cross-platform build.",
                "i" = "The {.code --load} flag ensures the image is stored in the local",
                " " = "  image store after building. Without it, the image is built but",
                " " = "  not available to {.code docker push} or {.code list_images()}."
            ))
        }
    }

    if (verbose) {
        cli::cli_inform("Resolving tool: using {.val {resolved_tool}}")
        if (!is.null(platform)) {
            cli::cli_inform("Target platform: {.val {platform}}")
        }
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
