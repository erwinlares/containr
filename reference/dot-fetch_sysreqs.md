# Fetch system requirements for a set of R packages

Uses
[`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
to retrieve Ubuntu/Debian `apt` package names required by a set of R
packages. Returns a deduplicated character vector of bare `apt` package
names suitable for passing to `apt-get install`. Warns and returns an
empty character vector if the lookup fails.

## Usage

``` r
.fetch_sysreqs(packages, os_version = "22.04", verbose = FALSE)
```

## Arguments

- packages:

  A character vector of R package names.

- os_version:

  A character string. The Ubuntu version to query against. Defaults to
  `"22.04"` to match the Rocker base image.

- verbose:

  Logical. If `TRUE`, prints progress messages.

## Value

A deduplicated character vector of `apt` package names.
