# containr — Package Development Plan

## What is containr?

`containr` helps researchers containerize their R projects. It generates a
`Dockerfile` from a project's `renv.lock`, builds a container image, and
pushes it to a registry — so analyses can be reliably shared, archived, and
rerun across systems without worrying about software versions or system
configuration.

The package is explicitly scoped to containerization. Job submission,
scheduling, and results retrieval belong in `submitr`.

---

## Package identity

- Name: containr
- CRAN: yes (current version `0.1.3`, dev version `0.1.3.9000`)
- License: Apache 2.0
- Registry target: UW-Madison CHTC (`registry.doit.wisc.edu`) by default
- Container tool: `podman` preferred, `docker` supported

---

## Relationship to sibling packages

```
toolero     -- research workflow toolkit (CRAN)
containr    -- containerization toolkit (CRAN, dev)
curriculr   -- CV generation toolkit (CRAN pending)
submitr     -- HTC job submission toolkit (in development)
```

The full workflow:

```
toolero::init_project()         -- scaffold project
renv::snapshot()                -- capture dependencies
containr::generate_dockerfile() -- generate Dockerfile
containr::build_image()         -- build container image
containr::list_images()         -- inspect local images
containr::push_image()          -- push to registry
submitr::htc_gen_submit()       -- generate .sub file
submitr::htc_gen_executable()   -- generate .sh file
submitr::htc_stage()            -- copy files to CHTC
submitr::htc_submit()           -- submit job
submitr::htc_status()           -- monitor job
submitr::htc_fetch_results()    -- retrieve results
```

---

## Completed

### `generate_dockerfile()`

Generates a ready-to-use `Dockerfile` from a project's `renv.lock`.

Key features:
- `auto_syslibs = TRUE` — auto-detects required system libraries via
  `remotes::system_requirements()`
- `install_syslibs = NULL` — accepts character vector of extra `apt` packages
- `curl` always installed as baseline for `renv` downloads
- `renv.lock` required — errors informatively if not found
- `renv::status()` check — warns if lockfile is out of sync
- Supports `r_mode`: `"base"`, `"tidyverse"`, `"rstudio"`, `"tidystudio"`
- `verbose`, `comments`, `dry_run` follow package-wide conventions

### `build_image()`

Builds a container image from a `Dockerfile` using `podman` or `docker`.
Auto-detects tool, validates Dockerfile, checks daemon responsiveness.
`platform` defaults to `"linux/amd64"` for HPC/HTC cluster compatibility.
Automatically uses `docker buildx build` with `--load` for cross-platform
Docker builds. Warns when the target platform differs from the host
architecture. Supports `dry_run = TRUE`, `verbose`, `comments`.

### `list_images()`

Returns a data frame of locally stored container images. Columns:
`repository`, `tag`, `image_id`, `created`, `size`. Prints and returns
invisibly. Uses Go template format string via `shQuote()` for reliable
output parsing.

### `push_image()`

Tags and pushes a local image to a container registry in a single call.
Arguments: `image_id`, `netid`, `project`, `tag`, `registry`,
`check_login`, `dry_run`, `verbose`, `comments`. Warns on `tag = "latest"`.
Checks login status before pushing. Unconditional success message on
completion.

---

## Source file organization

```
R/
+-- containr-package.R      # package sentinel
+-- generate-dockerfile.R   # generate_dockerfile()
+-- build-image.R           # build_image()
+-- list-images.R           # list_images()
+-- push-image.R            # push_image()
+-- container-helpers.R     # .resolve_tool(), .check_tool_responsive()
+-- sysreqs-helpers.R       # .read_renv_packages(), .fetch_sysreqs()
+-- get-r-ver-tags.R        # .get_r_ver_tags()
+-- r-ver-exists.R          # .r_ver_exists()
+-- validate-args.R         # .validate_file_arg()

inst/extdata/
+-- install_and_restore_packages.sh   # renv restore script for Dockerfile

tests/testthat/
+-- test-generate-dockerfile-content.R
+-- test-generate-dockerfile-file-args.R
+-- test-project-prereqs.R
+-- test-r-ver-tags.R
+-- test-r-ver-exists.R
+-- test-validate-file-arg.R
+-- test-container-workflow.R
```

---

## Testing strategy

See `on-testing.md` for the full three-layer strategy. Summary:

| Layer | What it tests | Guard | Runs on CI |
|-------|--------------|-------|-----------|
| 1 | Argument validation | none | Yes |
| 2 | Command construction | `dry_run`, mocks | Yes |
| 3 | End-to-end execution | `CONTAINR_INTEGRATION_TESTS=true` | No |

To run Layer 3 tests locally before a release:

```r
Sys.setenv(CONTAINR_INTEGRATION_TESTS = "true")
devtools::test()
Sys.unsetenv("CONTAINR_INTEGRATION_TESTS")
```

---

## v0.2.0 roadmap

### `containerize()` — convenience wrapper

A single function that calls `build_image()` then `push_image()` in sequence.
Intended for researchers who want the full build-and-push workflow in one
call after the first time setup.

```r
containerize(
    image_id = NULL,   # if NULL, uses most recently built image
    netid    = NULL,
    project  = NULL,
    tag      = "latest",
    registry = "registry.doit.wisc.edu",
    ...
)
```

### GitHub Actions workflow for image builds

Apple Silicon users cannot reliably build `linux/amd64` images locally due
to QEMU emulation failures. A GitHub Actions workflow running on `x86_64`
runners would build and push images natively. Could be triggered manually
via `workflow_dispatch` or automatically on tagged releases. Scoped but not
yet implemented.

### Layer 3 tests for `build_image()` and `push_image()`

Deferred from the current session. Require a running daemon and valid
registry credentials. Will follow the same `CONTAINR_INTEGRATION_TESTS`
guard as the `list_images()` Layer 3 tests.

### Additional registry support

`ghcr.io` (GitHub Container Registry) and `quay.io` as alternatives to
`registry.doit.wisc.edu`. Will require updating `push_image()` to accept
different authentication patterns.

### Singularity / Apptainer support

HPC environments (including some CHTC configurations) use Singularity or
Apptainer rather than Podman/Docker. Adding these as valid `tool` values in
`.resolve_tool()` is the entry point. Scoped for a future release alongside
`submitr`'s HPC support.

---

## Open design questions

1. Should `containerize()` accept an `image_id` or always use the most
   recently built image? The latter is more convenient but less explicit.

2. Should `push_image()` eventually support `ghcr.io` and `quay.io` via
   a `registry` argument, or should separate registry-specific functions
   be added?

3. When Singularity/Apptainer support arrives, should `generate_dockerfile()`
   gain a `format` argument to produce `.def` files instead of `Dockerfile`?

4. Should `build_image()` offer a `github_actions = TRUE` mode that
   generates and triggers a workflow file instead of building locally?
   Or should the workflow be a separate function entirely?
