# Generate a reproducible Dockerfile for an R project

`generate_dockerfile()` inspects an R project's dependencies via an
`renv` lockfile and writes a ready-to-use `Dockerfile` to the specified
output directory. It supports multiple Rocker base images, optional
system libraries, Quarto installation, file copying, user creation, and
inline documentation comments.

## Usage

``` r
generate_dockerfile(
  verbose = FALSE,
  r_version = "current",
  data_file = NULL,
  code_file = NULL,
  misc_file = NULL,
  add_user = NULL,
  home_dir = "/home",
  install_quarto = FALSE,
  expose_port = "8787",
  r_mode = "base",
  install_syslibs = TRUE,
  comments = FALSE,
  output = tempdir()
)
```

## Arguments

- verbose:

  Logical. If `TRUE`, prints progress messages as each section of the
  Dockerfile is written. Defaults to `FALSE`.

- r_version:

  A character string specifying the R version to use, e.g. `"4.3.0"`.
  Defaults to `"current"`, which resolves to the version of R running in
  the current session.

- data_file:

  A character string. Path to an optional data file to copy into the
  container under `/home/data/`. Defaults to `NULL`.

- code_file:

  A character string. Path to an optional script file (e.g. `.R`,
  `.qmd`, `.rmd`) to copy into the container under `/home/`. Defaults to
  `NULL`.

- misc_file:

  A character string. Path to an optional miscellaneous file (e.g. an
  image or shell script) to copy into the container under `/home/`.
  Defaults to `NULL`.

- add_user:

  A character string. Name of a Linux user to create inside the
  container with sudo access. Defaults to `NULL`.

- home_dir:

  A character string. The working directory set inside the container via
  `WORKDIR`. Defaults to `"/home"`.

- install_quarto:

  Logical. If `TRUE`, downloads and installs the Quarto CLI inside the
  container. Defaults to `FALSE`.

- expose_port:

  A character string. The port to expose when `r_mode` is `"rstudio"`.
  Defaults to `"8787"`.

- r_mode:

  A character string selecting the Rocker base image. Inspired by the
  [Rocker Project](https://rocker-project.org/). One of `"base"` for
  plain R, `"tidyverse"` for R with the tidyverse, `"rstudio"` for
  RStudio Server, or `"tidystudio"` for tidyverse plus TeX Live and
  publishing-related packages. Defaults to `"base"`.

- install_syslibs:

  Logical. If `TRUE`, installs system libraries commonly required by R
  packages and needed for source compilation (e.g.
  `libcurl4-openssl-dev`, `libxml2-dev`). Defaults to `TRUE`.

- comments:

  Logical. If `TRUE`, annotates each Dockerfile instruction with an
  explanatory comment. Useful for learning or sharing. Defaults to
  `FALSE`.

- output:

  A character string. Directory path where the `Dockerfile` will be
  written. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

## Value

Called for its side effects. Writes a `Dockerfile` to `output`. Does not
return a value.

## Examples

``` r
# Generate a minimal Dockerfile using a pinned R version
generate_dockerfile(r_version = "4.4.0", output = tempdir())

# Pin a specific R version with the tidyverse image
generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse", output = tempdir())

# Include a data file and annotate the Dockerfile with comments
if (FALSE) { # \dontrun{
generate_dockerfile(
  r_version = "4.3.0",
  data_file = "data/penguins.csv",
  comments  = TRUE,
  output    = "."
)
} # }
```
