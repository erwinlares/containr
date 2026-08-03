# containr (development version)

## Breaking changes

* `r_mode = "tidystudio"` has been removed. Renamed to `"verse"`, matching
  the Rocker project's own name for the underlying image (`rocker/verse`)
  -- `"studio"` was misleading, since RStudio Server is already present
  via `"tidyverse"` two modes earlier, and nothing in the old name hinted
  at the TeX Live installation that's the actual differentiator. No
  deprecation alias; regenerate any Dockerfile built with
  `r_mode = "tidystudio"` using `r_mode = "verse"` instead.

* The `tool` argument (a single tool name or `NULL` for auto-detect) on
  `build_image()`, `push_image()`, and `list_images()` is replaced by
  `tool_preference`, a non-empty character vector tried in order.
  Defaults to `c("podman", "docker")`, matching today's default behavior.
  A length-1 vector (e.g. `tool_preference = "docker"`) behaves like the
  old `tool = "docker"`; a longer vector lets you set a custom
  auto-detect order, e.g. `tool_preference = c("docker", "podman")`.
  `tool = NULL` had no direct equivalent kept -- passing `NULL` to
  `tool_preference` now errors, since the empty/auto-detect case is
  expressed by supplying more than one candidate instead.

* `push_image()`'s `netid` argument is renamed to `namespace`. `netid`
  only ever made sense for the default `"registry.doit.wisc.edu"`
  registry -- the same argument, and the same position in the assembled
  `{registry}/{namespace}/{project}:{tag}` path, is a GitHub username or
  organization for `ghcr.io`, or a Quay namespace for `quay.io`.
  `namespace` is the term those registries' own documentation uses for
  this segment, not a name `containr` invented. No alias kept; update
  `netid = ...` calls to `namespace = ...`.

## New features

* Two new `r_mode` values on `generate_dockerfile()`: `"shiny_server"`
  (`rocker/shiny`) for serving Shiny apps, and `"rstudio_shiny"`
  (`rocker/rstudio` with Shiny Server layered on top via Rocker's own
  `install_shiny_server.sh`) for RStudio Server and Shiny Server in the
  same image. Both require R >= 4.0.0 and error informatively otherwise
  -- `/rocker_scripts/` (which the Shiny Server install depends on) only
  exists in images built from the `rocker-versioned2` project, which
  covers R >= 4.0.0; older tags on the same Docker Hub repositories
  predate that entirely. `EXPOSE` now supports more than one port on a
  single line for `rstudio_shiny`, which exposes both `8787` and `3838`.
  `data_file`, `code_file`, and `misc_file` are copied to
  `/srv/shiny-server/` for these two modes, matching Shiny Server's own
  default app directory -- the four existing modes are unaffected,
  `COPY` destinations for those stay `/home/` exactly as before.
  `expose_port` remains an override for `"rstudio"` only; the two new
  modes expose fixed port(s) and ignore it, with a warning if supplied.

* `push_image()` now works against any OCI-compliant registry, not just
  the default `registry.doit.wisc.edu` -- tested against `ghcr.io` and
  `quay.io`. Login-check guidance (both the pre-push `comments` message
  and the not-logged-in error) is registry-aware: the default registry
  keeps its existing specific PAT-creation instructions, while any other
  registry gets generic guidance pointing at that registry's own
  documentation instead of DoIT-specific instructions that would be
  wrong for it.

* `containr` now ships a ready-to-use GitHub Actions template at
  `inst/templates/build-and-push.yaml`, for building and pushing your
  own project's image from CI rather than locally. Calls
  `build_image()`/`push_image()` directly (the same functions you'd run
  yourself, not a hand-written shell equivalent) on a GitHub-hosted
  runner, which is natively `x86_64` -- a direct fix, not a workaround,
  for QEMU emulation issues building `linux/amd64` images locally on
  Apple Silicon. See `README.md`'s "Building in CI" section.

## Bug fixes

* Fixed a bug where `push_image()`'s pre-push login check always failed
  under Docker regardless of whether the user was actually logged in.
  `<tool> login --get-login <registry>` is a Podman-only flag; running it
  under Docker always exits with a usage error (125), which is why
  `check_login = FALSE` was previously necessary as a Docker workaround.
  Podman keeps its native `--get-login` check; Docker (and, permissively,
  any other `tool_preference` value) now checks `~/.docker/config.json`
  directly for a cached credential, the same approach most CI tooling
  uses since Docker itself has no query subcommand for this. This is a
  best-effort local check either way -- it confirms a credential exists,
  not that it's still valid; an expired token can still fail at push
  time.

## Internal changes

* The three previously-independent, hand-maintained mappings of `r_mode`
  to image name (`generate_dockerfile()`), Docker Hub repo
  (`.get_r_ver_tags()`), and valid-values list (`.r_ver_exists()`) are
  now a single shared registry (`.r_mode_registry`). No user-facing
  effect beyond the `tidystudio` removal and the two new modes above.

* `tool_preference` is not validated against a fixed list of tool names
  -- any string on the system's PATH that responds to `<tool> info` is
  accepted. This is intentional: `tool_preference` should not need a
  companion validation update every time a new container tool gains
  support (Apptainer support is planned for a future release).
  Structural validation still applies -- `tool_preference` must be a
  non-empty character vector with no missing values. Error messages for
  an unrecognized tool that's installed but not responding fall back to
  generic guidance rather than Docker- or Podman-specific instructions
  that would be wrong for a different tool; `docker` and `podman` keep
  their existing specific guidance.

* Removed a redundant internal check: `build_image()`, `push_image()`,
  and `list_images()` each called `.check_tool_responsive()` immediately
  after `.resolve_tool()`, which already guarantees the resolved tool is
  responsive. No user-facing behavior change.

* Added integration tests (`CONTAINR_INTEGRATION_TESTS=true`) for
  `build_image()` and `push_image()`, backfilling the two that were
  previously only covered at the argument-validation and command-
  construction layers. `push_image()`'s integration test additionally
  requires `CONTAINR_TEST_NAMESPACE` and `CONTAINR_TEST_PROJECT` to be
  set, so it never pushes a test image to an unintended destination.
  These now run automatically in CI on every push/PR touching the
  relevant files, via a new `container-integration-tests.yaml` GitHub
  Actions workflow.

# containr 0.1.3.9000

## New functions

* `build_image()` builds a container image from a `Dockerfile` using either
  `podman` or `docker`. Auto-detects which tool is available, preferring
  `podman`. New `platform` argument defaults to `"linux/amd64"` for HPC/HTC
  cluster compatibility. When the target platform differs from the host
  architecture (e.g. building `linux/amd64` on Apple Silicon), the function
  automatically uses `docker buildx build` with `--load` for Docker, or
  passes `--platform` directly for Podman. A warning is emitted for
  cross-platform builds to alert the user about potential QEMU emulation
  issues. Supports `dry_run = TRUE` to preview the build command without
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

* **Breaking change:** `COPY` instructions generated by `data_file`,
  `code_file`, and `misc_file` now preserve the local directory structure
  inside the container under `/home/`. Previously, all files were flattened
  into `/home/data/` or `/home/` regardless of their source path. For
  example, `data_file = "data-raw/sample.csv"` now produces
  `COPY data-raw/sample.csv /home/data-raw/sample.csv` instead of
  `COPY data-raw/sample.csv /home/data/sample.csv`. This means R scripts
  inside the container can use the same relative paths they use locally.

* **Breaking change:** `COPY` source paths are now always written as relative
  to the build context (the current working directory). Previously, absolute
  paths could leak into the Dockerfile if `.validate_file_arg()` normalized
  them, causing `podman build` to fail with "no such file or directory."

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
  `install_syslibs = TRUE` argument no longer works -- pass a character vector
  of library names instead.

* `generate_dockerfile()` now calls `renv::status()` defensively and warns
  if the lock file appears to be out of sync with the project library.

* A success message now reports the path where the `Dockerfile` was written
  when `verbose = TRUE`.

## Tests and documentation

* Added `tests/testthat/test-generate-dockerfile-content.R` covering
  Dockerfile output content for all arguments.
* Updated tests to expect directory-preserving `COPY` destinations instead
  of the old flattened `/home/data/` pattern.
* Added lifecycle and Codecov badges.
* Updated hex sticker and favicon.
* Added tests for `build_image()` `platform` parameter: invalid platform
  validation, `--platform` flag inclusion/omission, `docker buildx` vs
  `docker build` selection, `--load` flag for cross-arch Docker builds,
  cross-compilation warning, and same-architecture no-warning behavior.
* `.validate_file_arg()` now returns paths relative to the working directory
  instead of absolute paths. Files outside the build context (including files
  on a different drive on Windows) produce an informative error. This fixes
  cross-drive build failures on Windows CI where `fs::path_rel()` could not
  compute a relative path

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

* Internal helpers renamed with a dot prefix: `get_r_ver_tags()` ->
  `.get_r_ver_tags()`, `r_ver_exists()` -> `.r_ver_exists()`, and
  `validate_file_arg()` -> `.validate_file_arg()`. These are not user-facing
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
