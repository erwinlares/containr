# containr (development version)

# containr 0.1.3.9000

## New functions

* `build_image()` builds a container image from a `Dockerfile` using either
  `podman` or `docker`. Auto-detects which tool is available, preferring
  `podman`. Supports `dry_run = TRUE` to preview the build command without
  executing it. `verbose` and `comments` follow the same contract as
  `generate_dockerfile()`.

* `push_image()` tags a locally built container image with a full registry
  path and pushes it to a container registry in a single call, handling both
  the `podman tag` and `podman push` steps internally. Arguments: `image_id`,
  `netid`, `project`, `tag` (defaults to `"latest"`), `registry` (defaults to
  `"registry.doit.wisc.edu"`). Supports login verification, `dry_run = TRUE`,
  and guided output via `verbose` and `comments`.

* `list_images()` returns a data frame of container images in the local
  image store, as reported by `podman image ls` or `docker image ls`. Useful
  for finding the image ID to pass to `push_image()` after building an image
  with `build_image()`. Prints the data frame to the console and returns it
  invisibly.

* Two new internal helpers shared by `build_image()`, `push_image()`, and
  `list_images()`: `.resolve_tool()` auto-detects `podman` or `docker` on
  the PATH, and `.check_tool_responsive()` verifies the daemon is running
  before attempting any build, push, or list operation.

## Changes to `generate_dockerfile()`

* `generate_dockerfile()` refactored: `r_mode` validated before file and
  network operations, `dplyr` dependency removed, `expose_port` now warns
  when `r_mode` is not `"rstudio"`, build loop simplified, `invisible(NULL)`
  added to return value.

* `generate_dockerfile()` now requires an `renv.lock` file in the current
  working directory. Errors informatively if none is found, with instructions
  to run `renv::snapshot()`.

* New `auto_syslibs` argument (default `TRUE`) reads `renv.lock`, queries
  the Posit Package Manager sysreqs database via
  `remotes::system_requirements()`, and automatically includes the system
  libraries required by all packages in the lock file. Warns and continues
  without auto-detection if the lookup fails.

* New `install_syslibs` argument (default `NULL`) accepts a character vector
  of additional `apt` package names to install on top of the auto-detected
  set, e.g. `install_syslibs = c("libuv1-dev", "libwebp-dev")`.

* `curl` is now always installed as a baseline system package regardless of
  `auto_syslibs` or `install_syslibs`. It is required by `renv` for package
  downloads inside the container.

* **Breaking change:** the hardcoded system library list (`cmake`,
  `libcurl4-openssl-dev`, `libssl-dev`, etc.) has been removed. Libraries are
  now determined entirely by `auto_syslibs` and `install_syslibs`. The old
  `install_syslibs = TRUE` argument no longer works — pass a character vector
  of library names instead.

* `generate_dockerfile()` now calls `renv::status()` defensively and warns
  if the lock file appears to be out of sync with the project library.

* A success message now reports the path where the `Dockerfile` was written
  when `verbose = TRUE`.

## Tests and documentation

* Added `tests/testthat/test-generate-dockerfile-content.R` covering
  Dockerfile output content for all arguments.
* Added lifecycle and Codecov badges.
* Updated hex sticker and favicon.

## Dependency changes

* `httr2` added to `Imports`. Used by `.get_r_ver_tags()` for Docker Hub
  API calls.
* `httr` removed from `Imports`. All HTTP calls now use `httr2`.
* `remotes` added to `Imports`. Used by `.fetch_sysreqs()` to query system
  library requirements.
* `jsonlite` added to `Imports`. Used by `.read_renv_packages()` to parse
  `renv.lock`.
* `dplyr` removed from `Imports`. The `r_mode` lookup in
  `generate_dockerfile()` now uses a named vector instead of
  `dplyr::case_when()`.

## Internal changes

* `.get_r_ver_tags()` migrated from `httr` to `httr2`.
* New internal helpers `.read_renv_packages()` and `.fetch_sysreqs()` added
  in `R/sysreqs-helpers.R`.
* New internal helpers `.resolve_tool()` and `.check_tool_responsive()` added
  in `R/container-helpers.R`.


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

* Added `inst/CITATION` with DOI for proper academic citation via
  `citation("containr")`
* Added `inst/WORDLIST` for spell check consistency
* Added `Language: en-US` to `DESCRIPTION`
* Improved documentation and README
* Added rhub v2 GitHub Actions workflow for cross-platform checks


# containr 0.1.1


# containr 0.1.0

* Initial CRAN submission.
