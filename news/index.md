# Changelog

## containr 0.1.3

- Added `cli` to `Imports`; replaced all
  [`stop()`](https://rdrr.io/r/base/stop.html),
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html), and
  [`message()`](https://rdrr.io/r/base/message.html) calls with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  for richer, more consistent error and progress messages
- Renamed internal helpers with a dot prefix: `r_ver_exists()` -\>
  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md),
  `get_r_ver_tags()` -\>
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
- Renamed source files to hyphenated convention consistent with
  `toolero`
- Added `"tidystudio"` to the set of valid `r_mode` values recognized by
  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md)
  and
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md),
  consistent with
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
- Rewrote
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  roxygen documentation for consistency of style and completeness

## containr 0.1.2

CRAN release: 2026-04-07

- Added `inst/CITATION` with DOI for proper academic citation via
  `citation("containr")`
- Added `inst/WORDLIST` for spell check consistency
- Added `Language: en-US` to `DESCRIPTION`
- Improved documentation and README
- Added rhub v2 GitHub Actions workflow for cross-platform checks

## containr 0.1.1

CRAN release: 2025-09-24

## containr 0.1.0

- Initial CRAN submission.
