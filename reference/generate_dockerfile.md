# Generate a reproducible Dockerfile for R projects

Creates a customizable Dockerfile tailored to R-based workflows,
supporting multiple Rocker images (base R, tidyverse, RStudio Server,
and publishing-ready configurations). The function allows inclusion of
data, code, and miscellaneous files, sets up system libraries,
optionally installs Quarto, and configures user access. It supports
verbose output and inline comments for transparency and educational use.
Designed to streamline containerization for reproducible research and
deployment.

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

  logical (TRUE or FALSE). Should generate_dockerfile() print out
  progress? By default, it will silently create a Dockerfile

- r_version:

  a character string indicated a version of R, i.e., "4.3.0". By
  default, it will grab the version of R from the current session

- data_file:

  a character string indicating an optional name of a data file to be
  copied into the container

- code_file:

  a character string indicating an optional name of a script file to be
  copied into the container

- misc_file:

  a character string indicating an optional name of miscellaneous files
  to be copied into the container

- add_user:

  a character string indicating an optional name of a linux user to be
  created inside the container

- home_dir:

  a character string specifying the home directory inside the container

- install_quarto:

  logical (TRUE or FALSE). If TRUE it will include supporting packages
  and system libraries to support Quarto and RMarkdown.

- expose_port:

  a character string indicating in which port will RStudio Server be
  accessible. It defaults to 8787

- r_mode:

  a character string. Inspired by the images in the Rocker Project. The
  options are "base" for base R, "tidyverse", "rstudio" for RStudio
  Server, and "tidystudio" which is tidyverse plus TeX Live and some
  publishing-related R packages

- install_syslibs:

  logical. If TRUE, includes system libraries commonly required by R
  packages and tools for source compilation.

- comments:

  logical (TRUE or FALSE). If TRUE, the Dockerfile generated will
  include comments detailing what each line does. If FALSE, the
  Dockerfile will be bare with only commands.

- output:

  Character. Directory path to write the Dockerfile. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

## Value

writes a Dockerfile to the specified output directory.

## Examples

``` r
# Basic Usage

# Specify an image with R 4.2.0 installed

generate_dockerfile(r_version = "4.3.0")
```
