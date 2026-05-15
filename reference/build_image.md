# Build a container image from a Dockerfile

`build_image()` builds a container image from a `Dockerfile` using
either `podman` or `docker`. It auto-detects which tool is available on
the system unless `tool` is specified explicitly. Use `dry_run = TRUE`
to preview the exact command that would be run without executing it.

## Usage

``` r
build_image(
  dockerfile = "Dockerfile",
  tag = NULL,
  platform = "linux/amd64",
  tool = NULL,
  dry_run = FALSE,
  verbose = FALSE,
  comments = FALSE
)
```

## Arguments

- dockerfile:

  A character string. Path to the `Dockerfile` to build from. Defaults
  to `"Dockerfile"` in the current working directory.

- tag:

  A character string or `NULL`. The full image tag to assign to the
  built image, including the registry prefix, e.g.
  `"registry.doit.wisc.edu/netid/myimage"`. If `NULL`, no tag is applied
  and the image is identified only by its image ID. Defaults to `NULL`.

- platform:

  A character string or `NULL`. The target platform for the container
  image. Defaults to `"linux/amd64"`, which is the architecture used by
  most HPC and HTC clusters. Set to `"linux/arm64"` for ARM-based
  systems (Apple Silicon, AWS Graviton). Set to `NULL` to let the
  container tool build for the host architecture.

- tool:

  A character string or `NULL`. The container tool to use for building.
  One of `"podman"` or `"docker"`. If `NULL` (the default), the function
  auto-detects which tool is available, preferring `podman` if both are
  found.

- dry_run:

  Logical. If `TRUE`, prints the command that would be run without
  executing it. Useful for verifying the command before committing to a
  potentially slow build. Defaults to `FALSE`.

- verbose:

  Logical. If `TRUE`, prints progress messages at each step. Defaults to
  `FALSE`.

- comments:

  Logical. If `TRUE`, prints explanatory context before each step – what
  the command does, why it is needed, and common pitfalls. Useful for
  first-time users learning the container build workflow. Defaults to
  `FALSE`.

## Value

Called for its side effects. Returns `invisible(NULL)`.

## Details

When the target `platform` differs from the host architecture (e.g.
building `linux/amd64` on an Apple Silicon Mac), `build_image()`
automatically uses `docker buildx build` instead of `docker build`, and
includes `--load` to ensure the image is available in the local store.
For `podman`, `--platform` is passed directly to `podman build`.

## Prerequisites

Before calling `build_image()`, ensure the following are in place:

1.  A `Dockerfile` exists at `dockerfile`. Use
    [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
    to create one if needed.

2.  An `renv.lock` file is present in the build context – the generated
    `Dockerfile` uses it to restore the R package environment inside the
    container.

3.  Either `podman` or `docker` is installed and the daemon (for
    `docker`) or the Podman service is running. Verify with
    `podman info` or `docker info` in a terminal.

## Cross-platform builds

Building for a different architecture than the host requires emulation.
On Apple Silicon Macs, building `linux/amd64` images uses QEMU emulation
under Podman, which can be slow and unstable. Docker Desktop handles
cross-platform builds more reliably via `buildx` and Rosetta 2.

If builds fail with QEMU segfaults, consider:

- Using Docker Desktop instead of Podman (`tool = "docker"`)

- Building on a native x86_64 machine (e.g. via GitHub Actions)

- Building directly on the target cluster if it supports container
  builds

## Tagging convention for CHTC

For UW-Madison CHTC, the full tag format is:
`registry.doit.wisc.edu/<netid>/<image-name>:<version>`

For example: `registry.doit.wisc.edu/erwin.lares/my-analysis:1.0.0`

The version tag defaults to `latest` if omitted. Using explicit version
tags (e.g. `1.0.0`) is recommended for reproducibility – `latest` will
be overwritten each time you push.

## Examples

``` r
if (FALSE) { # \dontrun{
# Build for linux/amd64 (default) with auto-detected tool
build_image()

# Build and tag for CHTC registry
build_image(tag = "registry.doit.wisc.edu/netid/my-analysis:1.0.0")

# Build for the host architecture (no --platform flag)
build_image(platform = NULL)

# Build for ARM64 (e.g. local use on Apple Silicon)
build_image(platform = "linux/arm64")

# Preview the build command without running it
build_image(
  tag     = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
  dry_run = TRUE
)

# Guided build for first-time users
build_image(
  tag      = "registry.doit.wisc.edu/netid/my-analysis:1.0.0",
  verbose  = TRUE,
  comments = TRUE
)
} # }
```
