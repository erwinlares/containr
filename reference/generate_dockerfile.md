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
  RStudio Server, `"verse"` for tidyverse plus TeX Live and
  publishing-related packages, `"shiny_server"` for serving Shiny apps,
  or `"rstudio_shiny"` for RStudio Server with Shiny Server layered on
  top. Defaults to `"base"`.

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

  A character vector or `NULL`. Path(s) to data file(s) and/or
  directories to copy into the container – a single path, a vector of
  paths, or a directory (copied whole, with its contents) may all be
  mixed freely in the same vector. The local directory structure is
  preserved under `/home/` for `"base"`, `"tidyverse"`, `"rstudio"`, and
  `"verse"` (e.g. `"data-raw/sample.csv"` becomes
  `/home/data-raw/sample.csv`, and a directory `"data-raw/"` is copied
  to `/home/data-raw/` in full), or under `/srv/shiny-server/` for
  `"shiny_server"` and `"rstudio_shiny"`, matching Shiny Server's own
  default app directory. Every path must be inside the current working
  directory (the build context). Defaults to `NULL`.

- code_file:

  A character vector or `NULL`. Path(s) to script file(s) (e.g. `.R`,
  `.qmd`, `.rmd`) and/or directories to copy into the container – see
  `data_file` for vector and directory behavior. The local directory
  structure is preserved under the mode's copy root – see `data_file`.
  Every path must be inside the current working directory. Defaults to
  `NULL`.

- misc_file:

  A character vector or `NULL`. Path(s) to miscellaneous file(s) (e.g.
  images or shell scripts) and/or directories to copy into the container
  – see `data_file` for vector and directory behavior. The local
  directory structure is preserved under the mode's copy root – see
  `data_file`. Every path must be inside the current working directory.
  Defaults to `NULL`.

- add_user:

  A character string. Name of a Linux user to create inside the
  container with sudo access. Defaults to `NULL`.

- home_dir:

  A character string. The working directory set inside the container via
  `WORKDIR`. Does not affect where `data_file`, `code_file`, or
  `misc_file` are copied – see `data_file`. Defaults to `"/home"`.

- expose_port:

  A character string. Overrides the port exposed when `r_mode` is
  `"rstudio"`. Defaults to `"8787"`. Ignored for every other `r_mode` –
  `"shiny_server"` and `"rstudio_shiny"` expose their own fixed port(s)
  (`"3838"`, and `"8787"`/`"3838"` respectively), since a single
  override value can't address more than one port.

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

#' # Multiple scripts and a whole assets folder, copied in one call --
# data_file, code_file, and misc_file all accept vectors, and a directory
# is copied whole
generate_dockerfile(
  r_version = "4.3.0",
  code_file = c("R/prepare.R", "R/model.R"),
  misc_file = "assets/",
  output    = "."
)

# Serve a Shiny app -- files land under /srv/shiny-server/ automatically
generate_dockerfile(
  r_version = "4.3.0",
  r_mode    = "shiny_server",
  code_file = "app.R",
  output    = "."
)

# RStudio Server plus Shiny Server in the same image
generate_dockerfile(
  r_version = "4.3.0",
  r_mode    = "rstudio_shiny",
  code_file = "app.R",
  output    = "."
)
} # }
```
