# containr 0.1.3

* Added `cli` to `Imports`; replaced all `stop()`, `stopifnot()`, and
  `message()` calls with `cli::cli_abort()` and `cli::cli_inform()` for
  richer, more consistent error and progress messages
* Renamed internal helpers with a dot prefix: `r_ver_exists()` ->
  `.r_ver_exists()`, `get_r_ver_tags()` -> `.get_r_ver_tags()`
* Renamed source files to hyphenated convention consistent with `toolero`
* Added `"tidystudio"` to the set of valid `r_mode` values recognized by
  `.r_ver_exists()` and `.get_r_ver_tags()`, consistent with
  `generate_dockerfile()`
* Rewrote `generate_dockerfile()` roxygen documentation for consistency
  of style and completeness

# containr 0.1.2

* Added `inst/CITATION` with DOI for proper academic citation via `citation("containr")`
* Added `inst/WORDLIST` for spell check consistency
* Added `Language: en-US` to `DESCRIPTION`
* Improved documentation and README
* Added rhub v2 GitHub Actions workflow for cross-platform checks

# containr 0.1.1

# containr 0.1.0

* Initial CRAN submission.
