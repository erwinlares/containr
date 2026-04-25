# Check if a specific Rocker image tag exists

Validates the format of a version string and checks whether it exists
among the available tags for a specified Rocker image on Docker Hub.
Supports semantic versioning, CUDA variants, and Ubuntu suffixes.

## Usage

``` r
.r_ver_exists(version, r_mode = "base", verbose = FALSE)
```

## Arguments

- version:

  Character string. The tag to check for existence, e.g. `"4.4.0"`,
  `"devel"`, or `"4.4.0-cuda12.2-ubuntu22.04"`. Must match semantic
  versioning or be one of `"latest"`, `"devel"`.

- r_mode:

  Character string. One of `"base"`, `"rstudio"`, or `"tidyverse"`.
  Determines which Rocker image to query.

- verbose:

  Logical. If `TRUE`, prints messages indicating whether the version was
  found.

## Value

Logical. `TRUE` if the specified version tag exists for the given Rocker
image; otherwise `FALSE`.
