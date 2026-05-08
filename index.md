# containr

![containr
logo](reference/figures/logo.png)[![R-CMD-check](https://github.com/erwinlares/containr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/erwinlares/containr/actions/workflows/R-CMD-check.yaml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19462130.svg)](https://doi.org/10.5281/zenodo.19462130)
[![CRAN
status](https://www.r-pkg.org/badges/version/containr)](https://CRAN.R-project.org/package=containr)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/containr)](https://cran.r-project.org/package=containr)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![Codecov test
coverage](https://codecov.io/gh/erwinlares/containr/graph/badge.svg)](https://app.codecov.io/gh/erwinlares/containr)

`containr` helps researchers containerize their R projects. It generates
a `Dockerfile` from a project’s `renv.lock`, builds a container image,
and pushes it to a registry — so analyses can be reliably shared,
archived, and rerun across systems without worrying about software
versions or system configuration.

## The containerized R workflow

Containerizing an R project with `containr` follows four steps. The
first three happen inside R; authentication with the container registry
happens once in the terminal before you push.

**1. Generate a Dockerfile** —
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
reads your `renv.lock` file, auto-detects the system libraries your
packages need, and writes a ready-to-use `Dockerfile`. Run this as many
times as needed while refining the configuration. It only writes a text
file, so iteration is fast and cheap.

**2. Build the container image** —
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
passes your `Dockerfile` to `podman` or `docker` and builds the image
locally. The first build takes time — it downloads the base image and
installs all R packages from scratch. Subsequent builds reuse cached
layers and are much faster, so rebuilding after adding packages to your
`renv.lock` is not as costly as it looks.

**3. Inspect local images** —
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
returns a data frame of images in the local store, equivalent to running
`podman image ls` in the terminal. Use it to find the image ID you need
to pass to
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md).

**4. Push to a registry** —
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
tags the image with the full registry path and pushes it to the
container registry. Currently targets the UW-Madison CHTC registry at
`registry.doit.wisc.edu` by default.

### Authentication — one-time setup outside R

Before pushing, you need to authenticate with the registry once in a
terminal. `containr` checks whether you are logged in before attempting
a push and errors with instructions if not. The full authentication
guide, including how to create a Personal Access Token (PAT) with the
right scopes, is at:

<https://git.doit.wisc.edu/ERWIN.LARES/container-registry>

## Installation

You can install `containr` from CRAN:

``` r

install.packages("containr")
```

Or install the development version from
[GitHub](https://github.com/erwinlares/containr):

``` r

# install.packages("pak")
pak::pak("erwinlares/containr")
```

## Usage

### Step 1 — Generate a Dockerfile

[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
requires an `renv.lock` in the current working directory. If you are
starting a new project, `toolero::init_project()` scaffolds a standard
folder structure and initializes `renv` for you. Once your project is
set up,
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
produces the lockfile that
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
reads.

``` r

library(containr)

# Generate a Dockerfile from the current project
generate_dockerfile(r_version = "4.4.0", output = ".")

# Use an RStudio Server image instead of plain R
generate_dockerfile(r_version = "4.4.0", r_mode = "rstudio", output = ".")

# Add extra system libraries not caught by auto-detection
generate_dockerfile(
  r_version       = "4.4.0",
  install_syslibs = c("libuv1-dev", "libwebp-dev"),
  output          = "."
)

# Guided generation with progress messages and annotated output
generate_dockerfile(
  r_version = "4.4.0",
  output    = ".",
  verbose   = TRUE,
  comments  = TRUE
)
```

### Step 2 — Build the image

``` r

# Build from the Dockerfile in the current directory
build_image(verbose = TRUE)

# Preview the build command without running it
build_image(dry_run = TRUE)
```

### Step 3 — Inspect local images

``` r

# Returns a data frame: repository, tag, image_id, created, size
imgs <- list_images()
```

Untagged images — those built without a `tag` argument — appear with
`<none>` in the `repository` and `tag` columns. The `image_id` column
contains the hash you pass to
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md).

### Step 4 — Push to the registry

``` r

# Push to the UW-Madison CHTC registry
push_image(
  image_id = imgs$image_id[1],
  netid    = "your.netid",
  project  = "container-registry",
  tag      = "1.0.0"
)

# Preview the tag and push commands without running them
push_image(
  image_id = imgs$image_id[1],
  netid    = "your.netid",
  project  = "container-registry",
  tag      = "1.0.0",
  dry_run  = TRUE
)

# Guided push with step-by-step explanations
push_image(
  image_id = imgs$image_id[1],
  netid    = "your.netid",
  project  = "container-registry",
  tag      = "1.0.0",
  verbose  = TRUE,
  comments = TRUE
)
```

Using explicit version tags (e.g. `"1.0.0"`) is recommended for
reproducibility — `"latest"` is overwritten on every push and makes it
harder to trace which image was used for a given analysis.

## Testing

`containr` includes functions that wrap system commands (`podman`,
`docker`). These cannot be tested end-to-end in a standard test suite
because they require a running container daemon, real images, and in the
case of
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
a live registry with valid credentials. The test suite addresses this
with a three-layer strategy.

**Layer 1 — Argument validation.** Tests that bad arguments error
correctly and required arguments are enforced. These are pure R checks
with no system dependencies and always run on every platform, including
CRAN.

**Layer 2 — Command construction.** Tests that the correct system
command is assembled from the supplied arguments. `dry_run = TRUE` is
the key mechanism — it causes the function to print the command that
would be executed without running it. `local_mocked_bindings()`
intercepts
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
so these tests run without any container tool installed. These always
run on every platform.

**Layer 3 — Integration.** Tests that call real system commands against
a live container environment. Guarded with
`skip_if_not(nchar(Sys.which("podman")) > 0)` so they only run when
`podman` is available on the PATH. These never run on CRAN or CI — they
are intended to be run locally before a release as part of the manual
pre-submission checklist.

## Citation

To cite `containr` in publications:

``` r

citation("containr")
```

## Related packages

`containr` is part of a family of R packages for reproducible research
workflows:

- [toolero](https://github.com/erwinlares/toolero) — scaffolds R
  projects, splits datasets for parallel processing, and provides
  utilities for reproducible data analysis workflows. A natural starting
  point before containerizing with `containr`.
- [curriculr](https://github.com/erwinlares/curriculr) — generates
  data-driven CVs from an Excel workbook using Quarto and Typst. No
  LaTeX required.

## License

Apache License (\>= 2) © Erwin Lares
