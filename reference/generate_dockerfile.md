# Generate a reproducible Dockerfile for an R project

`generate_dockerfile()` inspects an R project's dependencies via an
`renv` lockfile and writes a ready-to-use `Dockerfile` to the specified
output directory. It supports multiple Rocker base images, automatic
system library detection, Quarto installation, file copying, user
creation, and inline documentation comments.

## Usage

``` r
generate_dockerfile(
  r_version = "current",
  r_mode = "base",
  auto_syslibs = TRUE,
  install_syslibs = NULL,
  output = tempdir(),
  data_file = NULL,
  code_file = NULL,
  misc_file = NULL,
  add_user = NULL,
  home_dir = "/home",
  expose_port = "8787",
  install_quarto = FALSE,
  comments = FALSE,
  verbose = FALSE
)
```

## Arguments

- r_version:

  A character string specifying the R version to use, e.g. `"4.3.0"`.
  Defaults to `"current"`, which resolves to the version of R running in
  the current session.

- r_mode:

  A character string selecting the Rocker base image. Inspired by the
  [Rocker Project](https://rocker-project.org/). One of `"base"` for
  plain R, `"tidyverse"` for R with the tidyverse, `"rstudio"` for
  RStudio Server, or `"tidystudio"` for tidyverse plus TeX Live and
  publishing-related packages. Defaults to `"base"`.

- auto_syslibs:

  Logical. If `TRUE` (the default), reads `renv.lock` from the current
  working directory, queries the Posit Package Manager sysreqs database
  via
  [`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html),
  and automatically includes the system libraries required by all
  packages in the lock file. Warns and continues without auto-detection
  if the lookup fails. Set to `FALSE` to skip auto-detection entirely.

- install_syslibs:

  A character vector or `NULL`. Additional system libraries to install
  beyond those auto-detected from `renv.lock`. Each element should be a
  valid `apt` package name, e.g. `c("libuv1-dev", "libwebp-dev")`.
  Defaults to `NULL`.

- output:

  A character string. Directory path where the `Dockerfile` will be
  written. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- data_file:

  A character string or `NULL`. Path to a data file to copy into the
  container. The local directory structure is preserved under `/home/` –
  e.g. `"data-raw/sample.csv"` becomes `/home/data-raw/sample.csv`
  inside the container. The file must be inside the current working
  directory (the build context). Defaults to `NULL`.

- code_file:

  A character string or `NULL`. Path to a script file (e.g. `.R`,
  `.qmd`, `.rmd`) to copy into the container. The local directory
  structure is preserved under `/home/`. The file must be inside the
  current working directory. Defaults to `NULL`.

- misc_file:

  A character string or `NULL`. Path to a miscellaneous file (e.g. an
  image or shell script) to copy into the container. The local directory
  structure is preserved under `/home/`. The file must be inside the
  current working directory. Defaults to `NULL`.

- add_user:

  A character string. Name of a Linux user to create inside the
  container with sudo access. Defaults to `NULL`.

- home_dir:

  A character string. The working directory set inside the container via
  `WORKDIR`. Defaults to `"/home"`.

- expose_port:

  A character string. The port to expose when `r_mode` is `"rstudio"`.
  Defaults to `"8787"`. Ignored when `r_mode` is not `"rstudio"`.

- install_quarto:

  Logical. If `TRUE`, downloads and installs the Quarto CLI inside the
  container. Defaults to `FALSE`.

- comments:

  Logical. If `TRUE`, annotates each Dockerfile instruction with an
  explanatory comment. Useful for learning or sharing. Defaults to
  `FALSE`.

- verbose:

  Logical. If `TRUE`, prints progress messages as each section of the
  Dockerfile is written. Defaults to `FALSE`.

## Value

Called for its side effects. Writes a `Dockerfile` to `output`. Returns
`invisible(NULL)`.

## Prerequisites

`generate_dockerfile()` requires an `renv.lock` file in the current
working directory. Create one with
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
before calling this function. If the lock file is out of sync with your
project library, a warning is issued – run
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
to update it before building the image.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires renv.lock in the current working directory.
# Run renv::snapshot() first if you don't have one.

# Generate a minimal Dockerfile using a pinned R version
generate_dockerfile(r_version = "4.4.0", output = tempdir())

# Pin a specific R version with the tidyverse image
generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse",
                    output = tempdir())

# Add extra system libraries on top of auto-detected ones
generate_dockerfile(
  r_version       = "4.4.0",
  install_syslibs = c("libuv1-dev", "libwebp-dev"),
  output          = "."
)

# Include a data file -- directory structure is preserved in the container
generate_dockerfile(
  r_version = "4.3.0",
  data_file = "data-raw/penguins.csv",
  code_file = "analysis.R",
  comments  = TRUE,
  output    = "."
)
} # }
```
