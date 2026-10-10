# Fetch system requirements for a set of R packages

Uses
[`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
to retrieve Ubuntu/Debian `apt` package names required by a set of R
packages. Returns a deduplicated character vector of bare `apt` package
names suitable for passing to `apt-get install`. Warns and returns an
empty character vector if the lookup fails.

## Usage

``` r
.fetch_sysreqs(
  packages,
  os_version = "22.04",
  verbose = FALSE,
  chunk_size = 50L
)
```

## Arguments

- packages:

  A character vector of R package names.

- os_version:

  A character string. The Ubuntu version to query against. Defaults to
  `"22.04"` when this function is called directly.
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  never relies on that default (C14): it always passes an explicit
  `os_version`, derived from the resolved `r_version` via
  [`.resolve_os_version()`](https://erwinlares.github.io/containr/reference/dot-resolve_os_version.md)
  unless its own `os_version` argument overrides that derivation, since
  a single hardcoded value here only matched the Ubuntu release actually
  backing some R versions and not others.

- verbose:

  Logical. If `TRUE`, prints progress messages and the per-package
  report.

- chunk_size:

  A positive integer. The most packages sent to
  [`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
  in one request, a guard against very long request URLs for large
  lockfiles. Defaults to `50L`.

## Value

A deduplicated character vector of `apt` package names.

## Details

[`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
validates the Ubuntu release against a fixed internal list (remotes
2.5.0 stops at `"22.04"`), so asking about a newer release, such as the
`"24.04"` that backs R 4.4.2 and later, is rejected before any lookup
happens. When that happens, the error message itself names the releases
`remotes` accepts, so this function reads that list, picks the newest
accepted release that is not newer than the one requested, and repeats
the lookup against it, with a message saying so. Nothing about the
accepted releases is hardcoded here, which means that once `remotes`
learns about a newer release the fallback simply stops being needed. A
failure that is not a rejected release, a network error for instance, is
never retried.

With `verbose = TRUE`, the function also reports which package asked for
which library, by looking each package up on its own (see
[`.report_sysreqs_sources()`](https://erwinlares.github.io/containr/reference/dot-report_sysreqs_sources.md)).
The report never changes the returned value.
