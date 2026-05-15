#' Tag and push a container image to a registry
#'
#' `push_image()` tags a locally built container image with a full registry
#' path and pushes it to a container registry. It handles both the
#' `podman tag` and `podman push` steps in a single call. Auto-detects
#' which container tool is available unless `tool` is specified explicitly.
#' Use `dry_run = TRUE` to preview the exact commands without executing them.
#' The format for the is registry.doit.wisc.edu/<netid>/<image-name>:<version>

#'
#' @param image_id A character string. The local image ID or name to push,
#'   as shown in `podman image ls` or `docker image ls`. This is typically
#'   a 12-character hash (e.g. `"974123909a36"`) or a locally assigned name
#'   if the image was built with a tag via [build_image()].
#' @param netid A character string. Your UW-Madison NetID, used to construct
#'   the full registry path, e.g. `"erwin.lares"`.
#' @param project A character string. The GitLab project name that hosts the
#'   container registry, e.g. `"container-registry"`.
#' @param tag A character string. The version tag to assign to the image.
#'   Defaults to `"latest"`. Using explicit version tags (e.g. `"1.0.0"`)
#'   is recommended for reproducibility -- `"latest"` is overwritten on
#'   every push.
#' @param registry A character string. The registry hostname. Defaults to
#'   `"registry.doit.wisc.edu"` (UW-Madison CHTC).
#' @param tool A character string or `NULL`. The container tool to use. One
#'   of `"podman"` or `"docker"`. If `NULL` (the default), the function
#'   auto-detects which tool is available, preferring `podman`.
#' @param check_login Logical. If `TRUE` (the default), verifies that you
#'   are logged in to `registry` before attempting the push. If not logged
#'   in, the function errors with instructions on how to authenticate.
#' @param dry_run Logical. If `TRUE`, prints the commands that would be run
#'   without executing them. Defaults to `FALSE`.
#' @param verbose Logical. If `TRUE`, prints progress messages at each step.
#'   Defaults to `FALSE`.
#' @param comments Logical. If `TRUE`, prints explanatory context before each
#'   step -- what the command does, why it is needed, and common pitfalls.
#'   Useful for first-time users learning the container push workflow.
#'   Defaults to `FALSE`.
#'
#' @return Called for its side effects. Returns `invisible(NULL)`.
#'
#' @section Prerequisites:
#' Before calling `push_image()`, ensure the following are in place:
#'
#' 1. The image has been built locally with [build_image()]. Run
#'    `podman image ls` to find the image ID.
#' 2. You have a GitLab account at `git.doit.wisc.edu` and a project with
#'    the container registry enabled.
#' 3. You have a Personal Access Token (PAT) with `read_registry` and
#'    `write_registry` scopes. Create one at:
#'    `https://git.doit.wisc.edu/-/user_settings/personal_access_tokens`
#' 4. You are logged in to the registry. Authenticate once in a terminal:
#'    `podman login registry.doit.wisc.edu`
#'    Enter your NetID as the username and your PAT as the password.
#'
#' @section Authentication:
#' The GitLab container registry requires authentication before pushing.
#' Use a Personal Access Token (PAT) rather than your NetID password --
#' PATs can be scoped to registry access only and revoked independently.
#' Authentication is cached by `podman` or `docker` after the first login,
#' so you only need to run `podman login` once per machine per session.
#'
#' Note that GitLab Self-Managed authentication tokens expire after five
#' minutes by default. If you see an `unauthorized: authentication required`
#' error mid-push on a large image, re-authenticate and push again.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Tag and push an image to the CHTC registry
#' push_image(
#'   image_id = "974123909a36",
#'   netid    = "erwin.lares",
#'   project  = "container-registry"
#' )
#'
#' # Push with an explicit version tag
#' push_image(
#'   image_id = "974123909a36",
#'   netid    = "erwin.lares",
#'   project  = "container-registry",
#'   tag      = "1.0.0"
#' )
#'
#' # Preview the commands without running them
#' push_image(
#'   image_id = "974123909a36",
#'   netid    = "erwin.lares",
#'   project  = "container-registry",
#'   dry_run  = TRUE
#' )
#'
#' # Guided push for first-time users
#' push_image(
#'   image_id = "974123909a36",
#'   netid    = "erwin.lares",
#'   project  = "container-registry",
#'   verbose  = TRUE,
#'   comments = TRUE
#' )
#' }
push_image <- function(image_id    = NULL,
                       netid       = NULL,
                       project     = NULL,
                       tag         = "latest",
                       registry    = "registry.doit.wisc.edu",
                       tool        = NULL,
                       check_login = TRUE,
                       dry_run     = FALSE,
                       verbose     = FALSE,
                       comments    = FALSE) {

    # -- 1. Validate required arguments ----------------------------------------
    if (is.null(image_id)) {
        cli::cli_abort(c(
            "{.arg image_id} must be supplied.",
            "i" = "Run {.code podman image ls} to find the image ID.",
            "i" = "It is typically a 12-character hash like {.val 974123909a36},",
            " " = "  or a local name if the image was built with {.code build_image(tag = ...)}."
        ))
    }

    if (is.null(netid)) {
        cli::cli_abort(c(
            "{.arg netid} must be supplied.",
            "i" = "Provide your UW-Madison NetID, e.g. {.val erwin.lares}."
        ))
    }

    if (is.null(project)) {
        cli::cli_abort(c(
            "{.arg project} must be supplied.",
            "i" = "Provide the GitLab project name that hosts your container",
            " " = "  registry, e.g. {.val container-registry}."
        ))
    }

    # -- 2. Warn if using default tag ------------------------------------------
    # Use cli_inform rather than cli_warn here so the message fires immediately
    # before the push rather than being buffered until after system2() returns.
    if (tag == "latest") {
        cli::cli_inform(c(
            "!" = "Pushing with tag {.val latest}.",
            "i" = "Using explicit version tags (e.g. {.val 1.0.0}) is recommended",
            " " = "  for reproducibility -- {.val latest} is overwritten on every push."
        ))
    }

    # -- 3. Assemble destination tag -------------------------------------------
    destination <- glue::glue("{registry}/{netid}/{project}:{tag}")

    if (verbose) {
        cli::cli_inform("Destination: {.val {destination}}")
    }

    # -- 4. Resolve tool -------------------------------------------------------
    resolved_tool <- .resolve_tool(tool)

    # -- 5. Check tool is responsive -------------------------------------------
    .check_tool_responsive(resolved_tool)

    # -- 6. Check login --------------------------------------------------------
    if (check_login) {
        if (comments) {
            cli::cli_inform(c(
                "i" = "Checking that you are logged in to {.val {registry}}.",
                "i" = "Pushing an image requires authentication. If this check",
                " " = "  fails, run the following in your terminal:",
                " " = "  {.code {resolved_tool} login {registry}}",
                "i" = "When prompted, enter your NetID as the username and your",
                " " = "  Personal Access Token (PAT) as the password.",
                "i" = "Create a PAT at:",
                " " = "  {.url https://git.doit.wisc.edu/-/user_settings/personal_access_tokens}",
                " " = "  Select the {.val read_registry} and {.val write_registry} scopes."
            ))
        }

        if (verbose) cli::cli_inform("Checking login status for {.val {registry}}...")

        login_check <- system2(
            resolved_tool,
            args   = c("login", "--get-login", registry),
            stdout = TRUE,
            stderr = TRUE
        )
        exit_status <- attr(login_check, "status")
        login_ok    <- is.null(exit_status) || exit_status == 0L

        if (!login_ok) {
            cli::cli_abort(c(
                "Not logged in to {.val {registry}}.",
                "i" = "Authenticate by running the following in your terminal:",
                " " = "  {.code {resolved_tool} login {registry}}",
                "i" = "Enter your NetID as the username and your PAT as the password.",
                "i" = "Create a PAT at:",
                " " = "  {.url https://git.doit.wisc.edu/-/user_settings/personal_access_tokens}",
                " " = "  Select {.val read_registry} and {.val write_registry} scopes.",
                "i" = "Full authentication guide:",
                " " = "  {.url https://git.doit.wisc.edu/erwin.lares/container-registry}"
            ))
        }

        if (verbose) cli::cli_inform("Login verified for {.val {registry}}.")
    }

    # -- 7. Assemble commands --------------------------------------------------
    tag_args  <- c("tag",  image_id, destination)
    push_args <- c("push", destination)

    tag_cmd  <- paste(resolved_tool, paste(tag_args,  collapse = " "))
    push_cmd <- paste(resolved_tool, paste(push_args, collapse = " "))

    # -- 8. Execute or preview -------------------------------------------------
    if (comments) {
        cli::cli_inform(c(
            "i" = "Step 1: {.strong tag} assigns the full registry path to your",
            " " = "  local image so {resolved_tool} knows where to send it.",
            " " = "  {.code {tag_cmd}}",
            "i" = "Step 2: {.strong push} uploads the image to the registry so",
            " " = "  HTCondor can pull it onto the execute node when your job runs.",
            " " = "  {.code {push_cmd}}",
            "i" = "Push time depends on image size and network speed. A first push",
            " " = "  of a full R environment may take several minutes. Subsequent",
            " " = "  pushes reuse cached layers and are much faster.",
            "i" = "If you see {.val unauthorized: authentication required} mid-push,",
            " " = "  your token has expired. Re-authenticate and push again.",
            "i" = "Once pushed, verify the image appears in your GitLab project at:",
            " " = "  {.url https://git.doit.wisc.edu}"
        ))
    }

    if (dry_run) {
        cli::cli_inform(c(
            "v" = "Dry run -- commands that would be executed:",
            " " = "{.code {tag_cmd}}",
            " " = "{.code {push_cmd}}"
        ))
        return(invisible(NULL))
    }

    # -- 9. Tag ----------------------------------------------------------------
    if (verbose) cli::cli_inform("Tagging image: {.code {tag_cmd}}")

    tag_exit <- system2(resolved_tool, args = tag_args)

    if (tag_exit != 0L) {
        cli::cli_abort(c(
            "{resolved_tool} tag failed with exit code {tag_exit}.",
            "i" = "Check the output above for error details.",
            "i" = "Common causes: the image ID {.val {image_id}} does not exist",
            " " = "  locally. Run {.code podman image ls} to verify."
        ))
    }

    if (verbose) cli::cli_inform("Image tagged as {.val {destination}}.")

    # -- 10. Push --------------------------------------------------------------
    if (verbose) cli::cli_inform("Pushing image: {.code {push_cmd}}")

    push_exit <- system2(resolved_tool, args = push_args)

    if (push_exit != 0L) {
        cli::cli_abort(c(
            "{resolved_tool} push failed with exit code {push_exit}.",
            "i" = "Check the output above for error details.",
            "i" = "Common causes: not logged in, token expired, or the registry",
            " " = "  path {.val {destination}} does not match your GitLab project."
        ))
    }

    cli::cli_alert_success(
        "Image {.val {destination}} pushed successfully."
    )

    invisible(NULL)
}
