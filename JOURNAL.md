# containr Development Journal

------------------------------------------------------------------------

## Session 1 — pre-2026-05

### Initial development

`containr` was developed as a companion to `toolero` with a single
initial focus: generating reproducible Dockerfiles from R project
environments. The core function
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
reads an `renv.lock` file and writes a ready-to-use `Dockerfile`
targeting the Rocker project base images.

The package was submitted to and accepted by CRAN at `v0.1.0`, then
updated through `v0.1.3` with internal refactoring, CLI improvements,
and the addition of the `tidystudio` r_mode.

------------------------------------------------------------------------

## Session 2 — 2026-05-07

### What we set out to do

This session extended containr from a Dockerfile generator into a full
container workflow toolkit. The goal was to give researchers everything
they need to go from a `Dockerfile` to a pushed image without leaving R.

Three new exported functions were added:
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md),
and
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md).
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
was substantially refactored. The package was brought to a clean
`R CMD check` with 0 errors, 0 warnings, 0 notes, and all three GitHub
Actions workflows passing.

------------------------------------------------------------------------

### New functions

**[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)**
— wraps `podman build` or `docker build`. Auto-detects the container
tool, validates the Dockerfile exists, checks the daemon is responsive,
and supports `dry_run = TRUE` for previewing the command. No `output`
argument — images always land in the container tool’s local store, not
on the filesystem.

**[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)**
— wraps `podman image ls` or `docker image ls`. Returns a data frame
with columns `repository`, `tag`, `image_id`, `created`, `size`. Prints
to the console and returns invisibly. The format string uses Go template
syntax via [`shQuote()`](https://rdrr.io/r/base/shQuote.html) for
reliable column splitting across shell environments.

**[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)**
— handles both `podman tag` and `podman push` in a single call.
Arguments: `image_id`, `netid`, `project`, `tag` (default `"latest"`),
`registry` (default `"registry.doit.wisc.edu"`). Warns when
`tag = "latest"`. Checks login status via `podman login --get-login`
before attempting the push. The success message fires unconditionally
after a successful push.

**Internal helpers** —
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
in `R/container-helpers.R` are shared by all three functions. Both are
mocked in Layer 2 tests to keep the test suite independent of the host
environment.

------------------------------------------------------------------------

### Changes to `generate_dockerfile()`

The function was substantially refactored:

- **`renv.lock` now required** — errors informatively if not found, with
  instructions to run
  [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html).
  This was the most significant breaking change.
- **`auto_syslibs = TRUE`** — new argument. Reads `renv.lock`, queries
  [`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
  against the Posit Package Manager sysreqs database, and auto-installs
  the required system libraries. Replaces the old hardcoded library
  list.
- **`install_syslibs = NULL`** — changed from boolean to character
  vector. `install_syslibs = TRUE` no longer works. Pass a character
  vector of `apt` package names instead.
- **`curl` baseline** — always installed regardless of other arguments.
  Required by `renv` for package downloads inside the container.
- **[`renv::status()`](https://rstudio.github.io/renv/reference/status.html)
  check** — called defensively before generating. Warns if the lockfile
  is out of sync but does not block.
- **Success message** — `cli_alert_success()` now reports the Dockerfile
  path when `verbose = TRUE`.
- **`dplyr` removed** — `r_mode` lookup uses a named vector instead of
  `dplyr::case_when()`.

------------------------------------------------------------------------

### Dependency changes

- `httr` removed from `Imports`
- `httr2` added to `Imports` — used by
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
  for Docker Hub API
- `remotes` added to `Imports` — used by
  [`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
- `jsonlite` added to `Imports` — used by
  [`.read_renv_packages()`](https://erwinlares.github.io/containr/reference/dot-read_renv_packages.md)
- `dplyr` removed from `Imports`
- `fs` and `lifecycle` removed from `Imports` (were unused stale
  entries)
- `renv.lock` added to git for CI reproducibility

------------------------------------------------------------------------

### Testing

The three-layer testing strategy was formalized and documented in
`on-testing.md`:

- **Layer 1** — argument validation, always runs
- **Layer 2** — command construction via `dry_run = TRUE` and
  `local_mocked_bindings()`, always runs
- **Layer 3** — integration tests against real Podman, guarded behind
  `CONTAINR_INTEGRATION_TESTS=true`

The `CONTAINR_INTEGRATION_TESTS` environment variable guard was chosen
over `skip_on_cran()` because `devtools::check()` sets `NOT_CRAN=true`,
making `skip_on_cran()` ineffective for controlling whether tests run
during `devtools::check()`.

All tests that call
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
write a minimal `renv.lock` fixture and use
[`withr::local_dir()`](https://withr.r-lib.org/reference/with_dir.html)
to change the working directory, satisfying the lockfile requirement
without touching the project’s real `renv.lock`.

**Test counts after this session:** 138 passing, 0 failing, 0 warnings.

------------------------------------------------------------------------

### CI fixes

- `RENV_CONFIG_AUTOLOADER_ENABLED: "false"` added to the test-coverage
  workflow. Without this, `covr::package_coverage()` sources `.Rprofile`
  which activates `renv`’s library isolation, overriding the packages
  installed by `r-lib/actions/setup-r-dependencies`. All three CI
  workflows (`R-CMD-check`, `pkgdown`, `test-coverage`) now pass
  cleanly.

------------------------------------------------------------------------

### Open questions carried forward

- Layer 3 tests for
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  and
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  are not yet written. They require a running daemon, a real image, and
  for
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
  valid registry credentials. Deferred to a future session.
- `containerize()` — a convenience wrapper around
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md) +
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  — is on the roadmap but not yet drafted.

------------------------------------------------------------------------

## Session 3 — 2026-05-13

### What we set out to do

This session fixed two related bugs in
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
that surfaced during an end-to-end test of the notebook-to-cluster
pipeline. The first build attempt failed because absolute file paths
leaked into the generated Dockerfile’s `COPY` instructions. Fixing that
revealed a second issue: the `COPY` destinations flattened the local
directory structure, so a file at `data-raw/sample.csv` ended up at
`/home/data/sample.csv` instead of `/home/data-raw/sample.csv`.

Both issues were fixed together.

------------------------------------------------------------------------

### Changes to `generate_dockerfile()`

**Directory-preserving `COPY` instructions** — the three `COPY` blocks
(`data_file`, `code_file`, `misc_file`) now preserve the local directory
structure inside the container under `/home/`. Previously, `data_file`
paths were flattened into `/home/data/` (using
[`basename()`](https://rdrr.io/r/base/basename.html)) and `code_file` /
`misc_file` paths were flattened into `/home/`. The new behavior mirrors
the source path on both sides of the `COPY` instruction:

``` dockerfile
# Before (broken)
COPY /Users/lares/Desktop/project/data-raw/sample.csv /home/data/sample.csv

# After (fixed)
COPY data-raw/sample.csv /home/data-raw/sample.csv
```

This means R scripts inside the container can use the same relative
paths they use locally, which is the whole point of containerizing a
project without rewriting its file references.

**Relative source paths** — `COPY` source paths are now computed via
`fs::path_rel(f, start = getwd())` so that absolute paths from
[`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md)
are converted to paths relative to the build context before being
written to the Dockerfile. This fixes the `podman build` error “no such
file or directory” that occurred when the Dockerfile contained absolute
paths pointing outside the build context.

The implementation replaces `basename(.x)` with
[`fs::path_rel()`](https://fs.r-lib.org/reference/path_math.html) in all
three
[`purrr::map_chr()`](https://purrr.tidyverse.org/reference/map.html)
blocks:

``` r

purrr::map_chr(data_file, function(f) {
    rel <- fs::path_rel(f, start = getwd())
    glue::glue("COPY {rel} /home/{rel}")
})
```

------------------------------------------------------------------------

### Testing

Updated `test-generate-dockerfile-content.R` to expect the new
directory-preserving `COPY` destinations instead of the old flattened
`/home/data/` pattern. The test at line 266 was the only failure after
the code change.

**Test counts after this session:** 132 passing, 0 failing, 0 warnings,
3 skipped (Layer 3 integration tests).

------------------------------------------------------------------------

### Documentation

- Updated `@param` roxygen2 docs for `data_file`, `code_file`, and
  `misc_file` to describe the directory-preserving behavior.
- Updated README to explain the new `COPY` behavior and show examples
  with `data_file` and `code_file` arguments.
- Updated NEWS.md with two breaking change entries.

------------------------------------------------------------------------

### Open questions carried forward

- Layer 3 integration tests for
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  and
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  are still not written (carried from Session 2).
- `containerize()` convenience wrapper still on the roadmap (carried
  from Session 2).
- [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md)
  could be updated to return relative paths directly, consolidating the
  [`fs::path_rel()`](https://fs.r-lib.org/reference/path_math.html)
  conversion into one place instead of three. Deferred — the current
  approach works and the duplication is minimal.
