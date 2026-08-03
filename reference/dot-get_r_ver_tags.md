# Retrieve Docker tags for a Rocker image

Queries the Docker Hub API to retrieve all available tags for a
specified Rocker image. Supports user-friendly modes: `"base"`,
`"tidyverse"`, `"rstudio"`, `"verse"`, `"shiny_server"`, and
`"rstudio_shiny"`. Returns a structured list containing the image name,
tag vector, and source URL.

## Usage

``` r
.get_r_ver_tags(r_mode = "base", verbose = FALSE)
```

## Arguments

- r_mode:

  Character string. One of `"base"`, `"tidyverse"`, `"rstudio"`,
  `"verse"`, `"shiny_server"`, or `"rstudio_shiny"`. Determines which
  Rocker image to query. `"base"` maps to `"rocker/r-ver"`.
  `"rstudio_shiny"` maps to `"rocker/rstudio"`, since it's built by
  layering Shiny Server onto that image rather than a separate Docker
  Hub repository.

- verbose:

  Logical. If `TRUE`, prints progress messages during tag retrieval and
  pagination. Defaults to `FALSE`.

## Value

A named list with three elements: `image` (the full Docker image name),
`tags` (character vector of all available tags), and `source` (the base
URL of the Docker Hub API).
