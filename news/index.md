# Changelog

## containr 0.2.0.9000

### Breaking changes

- `r_mode = "tidystudio"` has been removed. Renamed to `"verse"`,
  matching the Rocker project’s own name for the underlying image
  (`rocker/verse`) – `"studio"` was misleading, since RStudio Server is
  already present via `"tidyverse"` two modes earlier, and nothing in
  the old name hinted at the TeX Live installation that’s the actual
  differentiator. No deprecation alias; regenerate any Dockerfile built
  with `r_mode = "tidystudio"` using `r_mode = "verse"` instead.

- The `tool` argument (a single tool name or `NULL` for auto-detect) on
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
  and
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
  is replaced by `tool_preference`, a non-empty character vector tried
  in order. Defaults to `c("podman", "docker")`, matching today’s
  default behavior. A length-1 vector
  (e.g. `tool_preference = "docker"`) behaves like the old
  `tool = "docker"`; a longer vector lets you set a custom auto-detect
  order, e.g. `tool_preference = c("docker", "podman")`. `tool = NULL`
  had no direct equivalent kept – passing `NULL` to `tool_preference`
  now errors, since the empty/auto-detect case is expressed by supplying
  more than one candidate instead.

- [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)‘s
  `netid` argument is renamed to `namespace`. `netid` only ever made
  sense for the default `"registry.doit.wisc.edu"` registry – the same
  argument, and the same position in the assembled
  `{registry}/{namespace}/{project}:{tag}` path, is a GitHub username or
  organization for `ghcr.io`, or a Quay namespace for `quay.io`.
  `namespace` is the term those registries’ own documentation uses for
  this segment, not a name `containr` invented. No alias kept; update
  `netid = ...` calls to `namespace = ...`.

### New features

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  gains a `config` argument: the path to a `_toolero.yml` project
  manifest, such as the one `toolero::init_project()` writes. When
  supplied, it fills in `data_file`, `code_file`, and `misc_file` from
  the manifest’s declared `folders:` – but only an argument the call
  left at its own `NULL` default. An explicit
  `data_file`/`code_file`/`misc_file` always wins, so passing `config`
  never changes the behavior of a call that already states its own file
  arguments. `code_file` is derived from the folder named by the
  manifest’s `script_dir` convention (`"R"` when the manifest does not
  say otherwise); `misc_file` is derived from `"assets"` when present,
  the branding folder `init_project(branding = ...)` creates;
  `data_file` is derived from `"data-raw"` when present. In `verbose`
  mode,
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  reports which of the three arguments came from `config` rather than
  from the call. A `schema_version` the file does not declare is treated
  as schema `1`; any other declared value warns rather than aborts, and
  the file is still read on a best-effort basis either way. Reading
  `_toolero.yml` is not a dependency on `toolero`: the schema is the
  contract, and a manifest written by hand is as valid an input as one
  `init_project()` created (#C01).

- When `config` is supplied,
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now also adds a `RUN mkdir -p` instruction, right after `WORKDIR`,
  creating every folder the manifest’s `folders:` declares under
  `home_dir`. Previously the generated image had no `output/` directory
  (or any other project folder) at all: a script calling
  `toolero::save_output()` was safe, because that function creates
  parents recursively, but a bare `ggsave("output/figures/x.png")`
  failed inside the container exactly as it would on an execute node
  with no `output/` yet created. A call that never passes `config` sees
  no new instruction (#C07).

- Two new `r_mode` values on
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):
  `"shiny_server"` (`rocker/shiny`) for serving Shiny apps, and
  `"rstudio_shiny"` (`rocker/rstudio` with Shiny Server layered on top
  via Rocker’s own `install_shiny_server.sh`) for RStudio Server and
  Shiny Server in the same image. Both require R \>= 4.0.0 and error
  informatively otherwise – `/rocker_scripts/` (which the Shiny Server
  install depends on) only exists in images built from the
  `rocker-versioned2` project, which covers R \>= 4.0.0; older tags on
  the same Docker Hub repositories predate that entirely. `EXPOSE` now
  supports more than one port on a single line for `rstudio_shiny`,
  which exposes both `8787` and `3838`. `data_file`, `code_file`, and
  `misc_file` are copied to `/srv/shiny-server/` for these two modes,
  matching Shiny Server’s own default app directory – the four existing
  modes are unaffected, still copying to `home_dir` as before (see the
  `copy_root`/`home_dir` fix below, \#C24, for a related correction to
  exactly how that tracking works). `expose_port` remains an override
  for `"rstudio"` only; the two new modes expose fixed port(s) and
  ignore it, with a warning if supplied.

- [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  now works against any OCI-compliant registry, not just the default
  `registry.doit.wisc.edu` – tested against `ghcr.io` and `quay.io`.
  Login-check guidance (both the pre-push `comments` message and the
  not-logged-in error) is registry-aware: the default registry keeps its
  existing specific PAT-creation instructions, while any other registry
  gets generic guidance pointing at that registry’s own documentation
  instead of DoIT-specific instructions that would be wrong for it.

- `containr` now ships a ready-to-use GitHub Actions template at
  `inst/templates/build-and-push.yaml`, for building and pushing your
  own project’s image from CI rather than locally. Calls
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)/[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  directly (the same functions you’d run yourself, not a hand-written
  shell equivalent) on a GitHub-hosted runner, which is natively
  `x86_64` – a direct fix, not a workaround, for QEMU emulation issues
  building `linux/amd64` images locally on Apple Silicon. See
  `README.md`’s “Building in CI” section.

- `data_file`, `code_file`, and `misc_file` on
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now accept a character vector of paths, not just a single path, and a
  path may point to a directory, copied whole rather than one file at a
  time. `code_file = c("R/prepare.R", "R/model.R")` and
  `misc_file = "assets/"` both work in a single call now; previously
  each argument accepted exactly one file path and rejected directories
  outright. Fully backward-compatible – a length-1 character path
  behaves exactly as before. The `COPY`-instruction generation already
  built its output via
  [`purrr::map_chr()`](https://purrr.tidyverse.org/reference/map.html)
  over these arguments, so this change is contained to
  [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md).

- New `quarto_version` argument on
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md),
  defaulting to `"latest"` for full backward compatibility. Quarto
  installation (`install_quarto = TRUE`) previously always pulled from
  `quarto.org/download/latest/`, the one unpinned layer in an otherwise
  deliberately pinned image (`r_version`, `renv.lock`). `"latest"` is
  now resolved to a concrete version at generation time via the Quarto
  releases API and installed from a versioned GitHub release URL
  instead; an explicit version (e.g. `"1.5.57"`) is validated against
  that same API and errors if no matching release exists. Either way,
  the resolved version is recorded in the generated `Dockerfile` as
  `ENV QUARTO_VERSION=...`, recoverable from a running container without
  the original `Dockerfile` on hand. New internal helper
  [`.get_quarto_version()`](https://erwinlares.github.io/containr/reference/dot-get_quarto_version.md)
  in `R/get-quarto-version.R`.

- New `os_version` argument on
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md),
  defaulting to `NULL`. When `NULL`, the Ubuntu version queried for
  system requirements (`auto_syslibs`) is now derived from the resolved
  `r_version` via the Rocker Project’s own R-version-to-Ubuntu-release
  mapping (20.04 for R 4.0.0-4.1.3, 22.04 for R 4.2.2-4.3.3, 24.04 for R
  4.4.2 and later, confirmed directly against rocker-project.org and the
  rocker-versioned2 wiki) rather than a single hardcoded default.
  Supplying `os_version` overrides the derivation entirely, for a
  project that needs to query against a different Ubuntu release than
  the one its `r_version` would normally resolve to. New internal helper
  [`.resolve_os_version()`](https://erwinlares.github.io/containr/reference/dot-resolve_os_version.md)
  in `R/r-mode-registry.R` (#C14).

### Bug fixes

- The generated `Dockerfile` now restores the `renv` project library
  immediately after copying `renv.lock`, before any of the `data_file`,
  `code_file`, or `misc_file` content is copied in. Previously the three
  `COPY` blocks for project content sat above the restore step, so
  editing a single line of an analysis script invalidated
  Docker/Podman’s build cache for that `COPY` layer and, because the
  restore came after it, for the single most expensive layer in the
  image too – every package reinstalled from source on every rebuild,
  contrary to what the README says about later builds being faster. The
  restore only depends on `renv.lock`, already in place earlier in the
  file, so nothing about moving it changes what gets installed.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now copies `renv.lock` to `{home_dir}/renv.lock` instead of a
  hardcoded `/home/renv.lock`. The image’s install script runs
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  with no explicit project, which resolves the project from the working
  directory – i.e. wherever `WORKDIR` (`home_dir`) points. The hardcoded
  destination only worked by coincidence when `home_dir` was left at its
  own default of `"/home"`; passing `home_dir = "/workspace"` left the
  lockfile somewhere
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  never looked.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)’s
  `copy_root` (the destination for `data_file`, `code_file`, and
  `misc_file`) was hardcoded to the literal `"/home"` for `"base"`,
  `"tidyverse"`, `"rstudio"`, and `"verse"`, independent of `home_dir` –
  the same class of bug as the `renv.lock` fix above, in the same corner
  of the file. That agreed with `home_dir`’s own default and silently
  disagreed the moment `home_dir` was set to anything else: `COPY`
  destinations stayed at `/home` while `WORKDIR`, and the script that
  actually ran, moved to wherever `home_dir` pointed. `copy_root` is now
  `NULL` in the mode registry for those four modes, meaning “fall back
  to `home_dir`”, so the two now always agree. `"shiny_server"` and
  `"rstudio_shiny"` are unaffected – their copy destination is still the
  fixed `/srv/shiny-server` regardless of `home_dir` (#C24).

- `generate_dockerfile(install_quarto = TRUE)` now fetches and installs
  Quarto with `curl -LO` and `dpkg -i` (falling back to
  `apt-get install -f` to resolve dependencies) instead of `wget` and
  `gdebi`. Neither `wget` nor `gdebi` is present in `rocker/r-ver`, so
  `install_quarto = TRUE` previously failed at build time on every
  `r_mode` unless something in the lockfile happened to pull those two
  programs in as a side effect. `curl` is already installed
  unconditionally as a baseline system library, so the new approach adds
  no packages to the image.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now validates the requested R version against the tag repository the
  resolved `r_mode` will actually build `FROM`, instead of always
  checking it against `rocker/r-ver`. A version that exists in
  `rocker/r-ver` but not in, say, `rocker/verse` previously passed
  validation and only failed later, at the `FROM` instruction itself;
  the “version does not exist” error now also points at the right
  repository’s page instead of always linking to `rocker/r-ver`’s.

- `expose_port`’s “only used when `r_mode` is `rstudio`” warning is now
  based on whether the argument was supplied at all
  (`missing(expose_port)`), not on whether its value differs from the
  default. Previously, explicitly passing `expose_port = "8787"` under a
  non-rstudio `r_mode` produced no warning even though the value is
  still ignored there.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now creates `output`, including any missing parent directories, if it
  does not already exist. Previously, a nonexistent `output` directory
  surfaced as a raw file-connection error from
  [`readr::write_lines()`](https://readr.tidyverse.org/reference/read_lines.html)
  rather than an informative message.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)’s
  `output` argument now defaults to `"."`, the current working
  directory, instead of
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). The old default
  meant
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  and
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  – whose `dockerfile` argument is always resolved against
  [`getwd()`](https://rdrr.io/r/base/getwd.html) – pointed at two
  different places by default, so calling both with no arguments, the
  most natural thing a new user does, failed on the second call with a
  file it could not find. The two defaults now compose without either
  argument having to be supplied.

- Fixed a bug where
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
  pre-push login check always failed under Docker regardless of whether
  the user was actually logged in. `<tool> login --get-login <registry>`
  is a Podman-only flag; running it under Docker always exits with a
  usage error (125), which is why `check_login = FALSE` was previously
  necessary as a Docker workaround. Podman keeps its native
  `--get-login` check; Docker (and, permissively, any other
  `tool_preference` value) now checks `~/.docker/config.json` directly
  for a cached credential, the same approach most CI tooling uses since
  Docker itself has no query subcommand for this. This is a best-effort
  local check either way – it confirms a credential exists, not that
  it’s still valid; an expired token can still fail at push time.

- [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
  called `print(parsed)` unconditionally before returning
  `invisible(parsed)`, so `imgs <- list_images()` printed a data frame
  as a side effect of assignment. Printing is now gated behind
  `verbose`, matching every other user-facing message in the package:
  `imgs <- list_images()` assigns quietly, and
  `list_images(verbose = TRUE)` prints (#C17).

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now warns when `renv.lock` records no packages at all, regardless of
  `auto_syslibs`. Previously this was silent:
  [`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
  short-circuits on an empty package vector, the image builds with only
  the baseline `curl` installed, and the build succeeds while the
  analysis inside it cannot run (#C04).

### Documentation

- [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
  `project` argument was documented as “the GitLab project name that
  hosts the container registry,” with its own examples using
  `project = "container-registry"` as if that’s a single shared project
  set up to host the registry generally. The README, and every one of
  its own examples, use `project = "my-analysis"` and produce
  `registry.doit.wisc.edu/erwin.lares/my-analysis:1.0.0` – the project
  *is* the image. Fixed the roxygen, the missing-argument error message,
  and every example in `push-image.R`, plus the
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  example embedded in
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
  own docs, to say so and use `project = "my-analysis"` throughout
  (#C18).

- `comments` means something different depending on which function
  you’re looking at:
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)’s
  `comments` argument writes annotations into the generated
  `Dockerfile`, while
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
  and
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
  `comments` arguments print explanatory guidance to the console
  instead, matching how `comments` is used across `submitr`’s own
  functions. A roxygen note on all three arguments now states this
  directly rather than renaming anything (#C15).

- “Before you start” in the README now says the lockfile has to record
  the analysis’s own packages, and `toolero` itself if the containerized
  script calls `toolero::save_output()` or
  `toolero::resolve_input_path()` – those functions make `toolero` a
  runtime dependency of the analysis, not just a development convenience
  (#C04).

- The README’s
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  section now notes that `embed-resources: true` in `toolero`’s Quarto
  templates reduces, but does not eliminate, the need to remember
  `misc_file = "assets/"` – a self-contained `.html` still requires
  `assets/styles.css`, `assets/header.html`, and `assets/footer.html` to
  be present at render time (#C06). The same section’s description of
  where `data_file`, `code_file`, and `misc_file` land was also updated
  to say `home_dir` rather than a hardcoded `/home/`, reflecting the
  `copy_root` fix above (#C24).

### Internal changes

- The three previously-independent, hand-maintained mappings of `r_mode`
  to image name
  ([`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)),
  Docker Hub repo
  ([`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)),
  and valid-values list
  ([`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md))
  are now a single shared registry (`.r_mode_registry`). No user-facing
  effect beyond the `tidystudio` removal and the two new modes above.

- `tool_preference` is not validated against a fixed list of tool names
  – any string on the system’s PATH that responds to `<tool> info` is
  accepted. This is intentional: `tool_preference` should not need a
  companion validation update every time a new container tool gains
  support (Apptainer support is planned for a future release).
  Structural validation still applies – `tool_preference` must be a
  non-empty character vector with no missing values. Error messages for
  an unrecognized tool that’s installed but not responding fall back to
  generic guidance rather than Docker- or Podman-specific instructions
  that would be wrong for a different tool; `docker` and `podman` keep
  their existing specific guidance.

- Removed a redundant internal check:
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
  and
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
  each called
  [`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
  immediately after
  [`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md),
  which already guarantees the resolved tool is responsive. No
  user-facing behavior change.

- Added integration tests (`CONTAINR_INTEGRATION_TESTS=true`) for
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  and
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
  backfilling the two that were previously only covered at the
  argument-validation and command- construction layers.
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
  integration test additionally requires `CONTAINR_TEST_NAMESPACE` and
  `CONTAINR_TEST_PROJECT` to be set, so it never pushes a test image to
  an unintended destination. These now run automatically in CI on every
  push/PR touching the relevant files, via a new
  `container-integration-tests.yaml` GitHub Actions workflow.

### Testing

- Added `tests/testthat/test-readme-workflow.R`, which extracts the
  actual
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  call from the README’s “A first workflow” section, runs it exactly as
  printed, and confirms the resulting `Dockerfile` pins the requested R
  version and copies in the referenced files. The other three steps in
  that workflow
  ([`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md),
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md))
  need a live container engine and registry and can’t run in CI, but
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  needs nothing but a lockfile in a temporary directory, and it’s the
  step everything else depends on. This test reads the README rather
  than holding a copy of its example, so the two can’t quietly drift
  apart, and skips (rather than fails) when `README.md` isn’t on disk,
  such as from a built tarball (#C20).

- Added a test that generates a Dockerfile for every `r_mode` crossed
  with both `"/home"` and `"/workspace"` `home_dir` values, parses the
  actual `WORKDIR` and `COPY` lines out of the result, and asserts that
  `renv.lock` lands under `WORKDIR` and that project files land under
  the mode’s `copy_root`. Previously each of those facts was tested in
  isolation, which is exactly how \#C10 stayed invisible: every
  individual assertion was true at once. Updated for the `copy_root` fix
  (#C24) to resolve a `NULL` registry value against `home_dir` rather
  than asserting the old hardcoded behavior.

- Added a test asserting the position of instructions relative to each
  other (`syslibs` before `quarto`, `renv_lock` before the restore step,
  the restore step before the first `COPY` of project content) rather
  than comparing against a fixed expected `Dockerfile`, so it survives
  future additions to the instruction list without needing to be
  rewritten (#C21).

- Added tests for the `copy_root`/`home_dir` fix (#C24): `COPY`
  destinations track a custom `home_dir` for the four Phase 1 modes, and
  still default to `/home` when `home_dir` is left at its own default.

- Added tests for the `config`-derived `mkdir -p` block (#C07): every
  declared folder appears in one `RUN mkdir -p` line positioned after
  `WORKDIR`, the destinations track a custom `home_dir`, the line is
  absent when `config` is not supplied or declares no folders, and a
  folder `containr` has no other special meaning for (neither
  `data-raw`, `script_dir`, nor `assets`) is still included.

- Added
  [`.resolve_os_version()`](https://erwinlares.github.io/containr/reference/dot-resolve_os_version.md)
  unit tests covering each Ubuntu-version threshold and its boundary,
  plus `"latest"`/`"devel"`. Added tests asserting
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  derives `os_version` and passes it to
  [`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md),
  that an explicit `os_version` overrides the derivation, and that
  neither derivation nor the sysreqs call happens when
  `auto_syslibs = FALSE` (#C14).

- Added tests asserting
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
  does not print when `verbose = FALSE` (the default), does print when
  `verbose = TRUE`, and returns the correct data frame either way
  (#C17).

- Added tests asserting the empty-lockfile warning fires (and mentions
  `toolero`), fires even when `auto_syslibs = FALSE`, and does not fire
  when `renv.lock` records at least one package (#C04). Every existing
  test’s `renv.lock` fixture now records a dummy package (previously an
  empty `"Packages":{}`), so this new warning does not fire incidentally
  across the rest of the suite.

## containr 0.1.3.9000

### New functions

- [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  builds a container image from a `Dockerfile` using either `podman` or
  `docker`. Auto-detects which tool is available, preferring `podman`.
  New `platform` argument defaults to `"linux/amd64"` for HPC/HTC
  cluster compatibility. When the target platform differs from the host
  architecture (e.g. building `linux/amd64` on Apple Silicon), the
  function automatically uses `docker buildx build` with `--load` for
  Docker, or passes `--platform` directly for Podman. A warning is
  emitted for cross-platform builds to alert the user about potential
  QEMU emulation issues. Supports `dry_run = TRUE` to preview the build
  command without executing it. `verbose` and `comments` follow the same
  contract as
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md).

- [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  tags a locally built container image with a full registry path and
  pushes it to a container registry in a single call, handling both the
  `podman tag` and `podman push` steps internally. Arguments:
  `image_id`, `netid`, `project`, `tag` (defaults to `"latest"`),
  `registry` (defaults to `"registry.doit.wisc.edu"`). Supports login
  verification, `dry_run = TRUE`, and guided output via `verbose` and
  `comments`.

- [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
  returns a data frame of container images in the local image store, as
  reported by `podman image ls` or `docker image ls`. Useful for finding
  the image ID to pass to
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  after building an image with
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md).
  Prints the data frame to the console and returns it invisibly.

- Two new internal helpers shared by
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
  and
  [`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md):
  [`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
  auto-detects `podman` or `docker` on the PATH, and
  [`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
  verifies the daemon is running before attempting any build, push, or
  list operation.

### Changes to `generate_dockerfile()`

- **Breaking change:** `COPY` instructions generated by `data_file`,
  `code_file`, and `misc_file` now preserve the local directory
  structure inside the container under `/home/`. Previously, all files
  were flattened into `/home/data/` or `/home/` regardless of their
  source path. For example, `data_file = "data-raw/sample.csv"` now
  produces `COPY data-raw/sample.csv /home/data-raw/sample.csv` instead
  of `COPY data-raw/sample.csv /home/data/sample.csv`. This means R
  scripts inside the container can use the same relative paths they use
  locally.

- **Breaking change:** `COPY` source paths are now always written as
  relative to the build context (the current working directory).
  Previously, absolute paths could leak into the Dockerfile if
  [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md)
  normalized them, causing `podman build` to fail with “no such file or
  directory.”

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  refactored: `r_mode` validated before file and network operations,
  `dplyr` dependency removed, `expose_port` now warns when `r_mode` is
  not `"rstudio"`, build loop simplified, `invisible(NULL)` added to
  return value.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now requires an `renv.lock` file in the current working directory.
  Errors informatively if none is found, with instructions to run
  [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html).

- New `auto_syslibs` argument (default `TRUE`) reads `renv.lock`,
  queries the Posit Package Manager sysreqs database via
  [`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html),
  and automatically includes the system libraries required by all
  packages in the lock file. Warns and continues without auto-detection
  if the lookup fails.

- New `install_syslibs` argument (default `NULL`) accepts a character
  vector of additional `apt` package names to install on top of the
  auto-detected set,
  e.g. `install_syslibs = c("libuv1-dev", "libwebp-dev")`.

- `curl` is now always installed as a baseline system package regardless
  of `auto_syslibs` or `install_syslibs`. It is required by `renv` for
  package downloads inside the container.

- **Breaking change:** the hardcoded system library list (`cmake`,
  `libcurl4-openssl-dev`, `libssl-dev`, etc.) has been removed.
  Libraries are now determined entirely by `auto_syslibs` and
  `install_syslibs`. The old `install_syslibs = TRUE` argument no longer
  works – pass a character vector of library names instead.

- [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now calls
  [`renv::status()`](https://rstudio.github.io/renv/reference/status.html)
  defensively and warns if the lock file appears to be out of sync with
  the project library.

- A success message now reports the path where the `Dockerfile` was
  written when `verbose = TRUE`.

### Tests and documentation

- Added `tests/testthat/test-generate-dockerfile-content.R` covering
  Dockerfile output content for all arguments.
- Updated tests to expect directory-preserving `COPY` destinations
  instead of the old flattened `/home/data/` pattern.
- Added lifecycle and Codecov badges.
- Updated hex sticker and favicon.
- Added tests for
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  `platform` parameter: invalid platform validation, `--platform` flag
  inclusion/omission, `docker buildx` vs `docker build` selection,
  `--load` flag for cross-arch Docker builds, cross-compilation warning,
  and same-architecture no-warning behavior.
- [`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md)
  now returns paths relative to the working directory instead of
  absolute paths. Files outside the build context (including files on a
  different drive on Windows) produce an informative error. This fixes
  cross-drive build failures on Windows CI where
  [`fs::path_rel()`](https://fs.r-lib.org/reference/path_math.html)
  could not compute a relative path

### Dependency changes

- `httr2` added to `Imports`. Used by
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
  for Docker Hub API calls.
- `httr` removed from `Imports`. All HTTP calls now use `httr2`.
- `remotes` added to `Imports`. Used by
  [`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
  to query system library requirements.
- `jsonlite` added to `Imports`. Used by
  [`.read_renv_packages()`](https://erwinlares.github.io/containr/reference/dot-read_renv_packages.md)
  to parse `renv.lock`.
- `dplyr` removed from `Imports`. The `r_mode` lookup in
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
  now uses a named vector instead of `dplyr::case_when()`.

### Internal changes

- [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
  migrated from `httr` to `httr2`.
- New internal helpers
  [`.read_renv_packages()`](https://erwinlares.github.io/containr/reference/dot-read_renv_packages.md)
  and
  [`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
  added in `R/sysreqs-helpers.R`.
- New internal helpers
  [`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
  and
  [`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
  added in `R/container-helpers.R`.

## containr 0.1.3

CRAN release: 2026-04-26

#### Changes

- Internal helpers renamed with a dot prefix: `get_r_ver_tags()` -\>
  [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md),
  `r_ver_exists()` -\>
  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md),
  and `validate_file_arg()` -\>
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
