# Changelog

## containr 0.1.3

CRAN release: 2026-04-26

#### Changes

- Internal helpers renamed with a dot prefix: `get_r_ver_tags()` →
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md),
  `r_ver_exists()` →
  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md),
  and `validate_file_arg()` →
  [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md).
  These are not user-facing but the change enforces the package
  convention for internal functions.
- `tidystudio` added as a valid `r_mode` in
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md),
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md),
  and
  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md).
  Maps to `rocker/verse`.

#### Bug fixes

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):
  replaced [`stop()`](https://rdrr.io/r/base/stop.html) and
  [`print()`](https://rdrr.io/r/base/print.html) /
  [`Sys.sleep()`](https://rdrr.io/r/base/Sys.sleep.html) calls with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  throughout for consistent, styled error and progress messages.
- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):
  fixed `comments` condition for Quarto block from
  `quarto_install_line == TRUE` to `install_quarto`.
- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):
  fixed `comments` conditions for `code_file` and `misc_file` blocks to
  check the correct variables.
- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):
  RStudio run instructions split into two cleaner comment lines.
- [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md):
  replaced [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and [`message()`](https://rdrr.io/r/base/message.html) with
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).
  Removed bare [`return()`](https://rdrr.io/r/base/function.html) from
  final list expression.
- [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md):
  replaced [`stop()`](https://rdrr.io/r/base/stop.html) with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and [`message()`](https://rdrr.io/r/base/message.html) with
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html).
- [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md):
  replaced [`stop()`](https://rdrr.io/r/base/stop.html) with
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html).

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
