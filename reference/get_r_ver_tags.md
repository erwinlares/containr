# Retrieve Docker tags for a Rocker image

Queries the Docker Hub API to retrieve all available tags for a
specified Rocker image. Supports user-friendly modes: `"base"`,
`"rstudio"`, and `"tidyverse"`. Returns a structured list containing the
image name, tag vector, and source URL.

## Usage

``` r
get_r_ver_tags(r_mode = "base", verbose = FALSE)
```

## Arguments

- r_mode:

  Character string. One of `"base"`, `"rstudio"`, or `"tidyverse"`.
  Determines which Rocker image to query. `"base"` maps to
  `"rocker/r-ver"`.

- verbose:

  Logical. If `TRUE`, prints progress messages during tag retrieval and
  pagination.

## Value

A named list with the following elements:

- image:

  Character string. The full Docker image name, e.g. `"rocker/r-ver"`.

- tags:

  Character vector. All available tags for the specified image, e.g.
  `c("latest", "devel", "4.4", "4.4.3", ...)`.

- source:

  Character string. The base URL of the Docker Hub API used to retrieve
  the tags.
