# Tag and push a container image to a registry

`push_image()` tags a locally built container image with a full registry
path and pushes it to a container registry. It handles both the
`podman tag` and `podman push` steps in a single call. Auto-detects
which container tool is available unless `tool` is specified explicitly.
Use `dry_run = TRUE` to preview the exact commands without executing
them. The format for the is registry.doit.wisc.edu//:

## Usage

``` r
push_image(
  image_id = NULL,
  netid = NULL,
  project = NULL,
  tag = "latest",
  registry = "registry.doit.wisc.edu",
  tool = NULL,
  check_login = TRUE,
  dry_run = FALSE,
  verbose = FALSE,
  comments = FALSE
)
```

## Arguments

- image_id:

  A character string. The local image ID or name to push, as shown in
  `podman image ls` or `docker image ls`. This is typically a
  12-character hash (e.g. `"974123909a36"`) or a locally assigned name
  if the image was built with a tag via
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md).

- netid:

  A character string. Your UW-Madison NetID, used to construct the full
  registry path, e.g. `"erwin.lares"`.

- project:

  A character string. The GitLab project name that hosts the container
  registry, e.g. `"container-registry"`.

- tag:

  A character string. The version tag to assign to the image. Defaults
  to `"latest"`. Using explicit version tags (e.g. `"1.0.0"`) is
  recommended for reproducibility — `"latest"` is overwritten on every
  push.

- registry:

  A character string. The registry hostname. Defaults to
  `"registry.doit.wisc.edu"` (UW-Madison CHTC).

- tool:

  A character string or `NULL`. The container tool to use. One of
  `"podman"` or `"docker"`. If `NULL` (the default), the function
  auto-detects which tool is available, preferring `podman`.

- check_login:

  Logical. If `TRUE` (the default), verifies that you are logged in to
  `registry` before attempting the push. If not logged in, the function
  errors with instructions on how to authenticate.

- dry_run:

  Logical. If `TRUE`, prints the commands that would be run without
  executing them. Defaults to `FALSE`.

- verbose:

  Logical. If `TRUE`, prints progress messages at each step. Defaults to
  `FALSE`.

- comments:

  Logical. If `TRUE`, prints explanatory context before each step — what
  the command does, why it is needed, and common pitfalls. Useful for
  first-time users learning the container push workflow. Defaults to
  `FALSE`.

## Value

Called for its side effects. Returns `invisible(NULL)`.

## Prerequisites

Before calling `push_image()`, ensure the following are in place:

1.  The image has been built locally with
    [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md).
    Run `podman image ls` to find the image ID.

2.  You have a GitLab account at `git.doit.wisc.edu` and a project with
    the container registry enabled.

3.  You have a Personal Access Token (PAT) with `read_registry` and
    `write_registry` scopes. Create one at:
    `https://git.doit.wisc.edu/-/user_settings/personal_access_tokens`

4.  You are logged in to the registry. Authenticate once in a terminal:
    `podman login registry.doit.wisc.edu` Enter your NetID as the
    username and your PAT as the password.

## Authentication

The GitLab container registry requires authentication before pushing.
Use a Personal Access Token (PAT) rather than your NetID password — PATs
can be scoped to registry access only and revoked independently.
Authentication is cached by `podman` or `docker` after the first login,
so you only need to run `podman login` once per machine per session.

Note that GitLab Self-Managed authentication tokens expire after five
minutes by default. If you see an
`unauthorized: authentication required` error mid-push on a large image,
re-authenticate and push again.

## Examples

``` r
if (FALSE) { # \dontrun{
# Tag and push an image to the CHTC registry
push_image(
  image_id = "974123909a36",
  netid    = "erwin.lares",
  project  = "container-registry"
)

# Push with an explicit version tag
push_image(
  image_id = "974123909a36",
  netid    = "erwin.lares",
  project  = "container-registry",
  tag      = "1.0.0"
)

# Preview the commands without running them
push_image(
  image_id = "974123909a36",
  netid    = "erwin.lares",
  project  = "container-registry",
  dry_run  = TRUE
)

# Guided push for first-time users
push_image(
  image_id = "974123909a36",
  netid    = "erwin.lares",
  project  = "container-registry",
  verbose  = TRUE,
  comments = TRUE
)
} # }
```
