# containr 0.1.3

### Changes

* Internal helpers renamed with a dot prefix: `get_r_ver_tags()` →
  `.get_r_ver_tags()`, `r_ver_exists()` → `.r_ver_exists()`, and
  `validate_file_arg()` → `.validate_file_arg()`. These are not user-facing
  but the change enforces the package convention for internal functions.
* `tidystudio` added as a valid `r_mode` in `generate_dockerfile()`,
  `.get_r_ver_tags()`, and `.r_ver_exists()`. Maps to `rocker/verse`.

### Bug fixes

* `generate_dockerfile()`: replaced `stop()` and `print()` / `Sys.sleep()`
  calls with `cli::cli_abort()` and `cli::cli_inform()` throughout for
  consistent, styled error and progress messages.
* `generate_dockerfile()`: fixed `comments` condition for Quarto block from
  `quarto_install_line == TRUE` to `install_quarto`.
* `generate_dockerfile()`: fixed `comments` conditions for `code_file` and
  `misc_file` blocks to check the correct variables.
* `generate_dockerfile()`: RStudio run instructions split into two cleaner
  comment lines.
* `.get_r_ver_tags()`: replaced `stopifnot()` with `cli::cli_abort()` and
  `message()` with `cli::cli_inform()`. Removed bare `return()` from final
  list expression.
* `.r_ver_exists()`: replaced `stop()` with `cli::cli_abort()` and
  `message()` with `cli::cli_inform()`.
* `.validate_file_arg()`: replaced `stop()` with `cli::cli_abort()`.

# containr 0.1.2

* Added `inst/CITATION` with DOI for proper academic citation via `citation("containr")`
* Added `inst/WORDLIST` for spell check consistency
* Added `Language: en-US` to `DESCRIPTION`
* Improved documentation and README
* Added rhub v2 GitHub Actions workflow for cross-platform checks

# containr 0.1.1

# containr 0.1.0

* Initial CRAN submission.
