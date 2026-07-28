# containr Development Journal

---

## Session 1 — pre-2026-05

### Initial development

`containr` was developed as a companion to `toolero` with a single initial
focus: generating reproducible Dockerfiles from R project environments. The
core function `generate_dockerfile()` reads an `renv.lock` file and writes a
ready-to-use `Dockerfile` targeting the Rocker project base images.

The package was submitted to and accepted by CRAN at `v0.1.0`, then updated
through `v0.1.3` with internal refactoring, CLI improvements, and the
addition of the `tidystudio` r_mode.

---

## Session 2 — 2026-05-07

### What we set out to do

This session extended containr from a Dockerfile generator into a full
container workflow toolkit. The goal was to give researchers everything they
need to go from a `Dockerfile` to a pushed image without leaving R.

Three new exported functions were added: `build_image()`, `list_images()`,
and `push_image()`. `generate_dockerfile()` was substantially refactored.
The package was brought to a clean `R CMD check` with 0 errors, 0 warnings,
0 notes, and all three GitHub Actions workflows passing.

---

### New functions

**`build_image()`** — wraps `podman build` or `docker build`. Auto-detects
the container tool, validates the Dockerfile exists, checks the daemon is
responsive, and supports `dry_run = TRUE` for previewing the command. No
`output` argument — images always land in the container tool's local store,
not on the filesystem.

**`list_images()`** — wraps `podman image ls` or `docker image ls`. Returns
a data frame with columns `repository`, `tag`, `image_id`, `created`, `size`.
Prints to the console and returns invisibly. The format string uses Go
template syntax via `shQuote()` for reliable column splitting across shell
environments.

**`push_image()`** — handles both `podman tag` and `podman push` in a single
call. Arguments: `image_id`, `netid`, `project`, `tag` (default `"latest"`),
`registry` (default `"registry.doit.wisc.edu"`). Warns when `tag = "latest"`.
Checks login status via `podman login --get-login` before attempting the
push. The success message fires unconditionally after a successful push.

**Internal helpers** — `.resolve_tool()` and `.check_tool_responsive()` in
`R/container-helpers.R` are shared by all three functions. Both are mocked
in Layer 2 tests to keep the test suite independent of the host environment.

---

### Changes to `generate_dockerfile()`

The function was substantially refactored:

- **`renv.lock` now required** — errors informatively if not found, with
  instructions to run `renv::snapshot()`. This was the most significant
  breaking change.
- **`auto_syslibs = TRUE`** — new argument. Reads `renv.lock`, queries
  `remotes::system_requirements()` against the Posit Package Manager sysreqs
  database, and auto-installs the required system libraries. Replaces the
  old hardcoded library list.
- **`install_syslibs = NULL`** — changed from boolean to character vector.
  `install_syslibs = TRUE` no longer works. Pass a character vector of `apt`
  package names instead.
- **`curl` baseline** — always installed regardless of other arguments.
  Required by `renv` for package downloads inside the container.
- **`renv::status()` check** — called defensively before generating. Warns
  if the lockfile is out of sync but does not block.
- **Success message** — `cli_alert_success()` now reports the Dockerfile path
  when `verbose = TRUE`.
- **`dplyr` removed** — `r_mode` lookup uses a named vector instead of
  `dplyr::case_when()`.

---

### Dependency changes

- `httr` removed from `Imports`
- `httr2` added to `Imports` — used by `.get_r_ver_tags()` for Docker Hub API
- `remotes` added to `Imports` — used by `.fetch_sysreqs()`
- `jsonlite` added to `Imports` — used by `.read_renv_packages()`
- `dplyr` removed from `Imports`
- `fs` and `lifecycle` removed from `Imports` (were unused stale entries)
- `renv.lock` added to git for CI reproducibility

---

### Testing

The three-layer testing strategy was formalized and documented in
`on-testing.md`:

- **Layer 1** — argument validation, always runs
- **Layer 2** — command construction via `dry_run = TRUE` and
  `local_mocked_bindings()`, always runs
- **Layer 3** — integration tests against real Podman, guarded behind
  `CONTAINR_INTEGRATION_TESTS=true`

The `CONTAINR_INTEGRATION_TESTS` environment variable guard was chosen over
`skip_on_cran()` because `devtools::check()` sets `NOT_CRAN=true`, making
`skip_on_cran()` ineffective for controlling whether tests run during
`devtools::check()`.

All tests that call `generate_dockerfile()` write a minimal `renv.lock`
fixture and use `withr::local_dir()` to change the working directory,
satisfying the lockfile requirement without touching the project's real
`renv.lock`.

**Test counts after this session:** 138 passing, 0 failing, 0 warnings.

---

### CI fixes

- `RENV_CONFIG_AUTOLOADER_ENABLED: "false"` added to the test-coverage
  workflow. Without this, `covr::package_coverage()` sources `.Rprofile`
  which activates `renv`'s library isolation, overriding the packages
  installed by `r-lib/actions/setup-r-dependencies`. All three CI workflows
  (`R-CMD-check`, `pkgdown`, `test-coverage`) now pass cleanly.

---

### Open questions carried forward

- Layer 3 tests for `build_image()` and `push_image()` are not yet written.
  They require a running daemon, a real image, and for `push_image()`, valid
  registry credentials. Deferred to a future session.
- `containerize()` — a convenience wrapper around `build_image()` +
  `push_image()` — is on the roadmap but not yet drafted.

---

## Session 3 — 2026-05-13

### What we set out to do

This session fixed two related bugs in `generate_dockerfile()` that surfaced
during an end-to-end test of the notebook-to-cluster pipeline. The first
build attempt failed because absolute file paths leaked into the generated
Dockerfile's `COPY` instructions. Fixing that revealed a second issue: the
`COPY` destinations flattened the local directory structure, so a file at
`data-raw/sample.csv` ended up at `/home/data/sample.csv` instead of
`/home/data-raw/sample.csv`.

Both issues were fixed together.

---

### Changes to `generate_dockerfile()`

**Directory-preserving `COPY` instructions** — the three `COPY` blocks
(`data_file`, `code_file`, `misc_file`) now preserve the local directory
structure inside the container under `/home/`. Previously, `data_file` paths
were flattened into `/home/data/` (using `basename()`) and `code_file` /
`misc_file` paths were flattened into `/home/`. The new behavior mirrors the
source path on both sides of the `COPY` instruction:

```dockerfile
# Before (broken)
COPY /Users/lares/Desktop/project/data-raw/sample.csv /home/data/sample.csv

# After (fixed)
COPY data-raw/sample.csv /home/data-raw/sample.csv
```

This means R scripts inside the container can use the same relative paths
they use locally, which is the whole point of containerizing a project
without rewriting its file references.

**Relative source paths** — `COPY` source paths are now computed via
`fs::path_rel(f, start = getwd())` so that absolute paths from
`.validate_file_arg()` are converted to paths relative to the build context
before being written to the Dockerfile. This fixes the `podman build` error
"no such file or directory" that occurred when the Dockerfile contained
absolute paths pointing outside the build context.

The implementation replaces `basename(.x)` with `fs::path_rel()` in all
three `purrr::map_chr()` blocks:

```r
purrr::map_chr(data_file, function(f) {
    rel <- fs::path_rel(f, start = getwd())
    glue::glue("COPY {rel} /home/{rel}")
})
```

---

### Testing

Updated `test-generate-dockerfile-content.R` to expect the new
directory-preserving `COPY` destinations instead of the old flattened
`/home/data/` pattern. The test at line 266 was the only failure after
the code change.

**Test counts after this session:** 132 passing, 0 failing, 0 warnings,
3 skipped (Layer 3 integration tests).

---

### Documentation

- Updated `@param` roxygen2 docs for `data_file`, `code_file`, and
  `misc_file` to describe the directory-preserving behavior.
- Updated README to explain the new `COPY` behavior and show examples with
  `data_file` and `code_file` arguments.
- Updated NEWS.md with two breaking change entries.

---

### Open questions carried forward

### Open questions carried forward

- Layer 3 integration tests for `build_image()` and `push_image()` are
  still not written (carried from Session 2).
- `containerize()` convenience wrapper still on the roadmap (carried from
  Session 2).

---

## Session 4 — 2026-05-14

### What we set out to do

This session added cross-platform build support to `build_image()`. The
immediate trigger was an end-to-end test of the notebook-to-cluster pipeline:
the container image built on an Apple Silicon Mac was `arm64`, which CHTC's
`x86_64` execute nodes rejected with "Image Architecture arm64 not compatible
with this machine." Building with `--platform linux/amd64` via Podman failed
due to QEMU emulation segfaults. Docker Desktop's `buildx` handled the
cross-platform build successfully.

### Changes to `build_image()`

**New `platform` parameter** — defaults to `"linux/amd64"` since HPC/HTC
clusters are almost universally `x86_64`. Also accepts `"linux/arm64"` or
`NULL` (build for the host architecture). Invalid values error with the
valid options listed.

**Automatic `buildx` selection** — when the resolved tool is `docker` and
the target platform differs from the host architecture, `build_image()`
automatically uses `docker buildx build` with `--load` instead of plain
`docker build`. The `--load` flag is required for `buildx` to store the
image in the local image store. For Podman, `--platform` is passed directly
to `podman build` since Podman handles it natively.

**Cross-compilation warning** — when the target platform differs from the
host (detected via `Sys.info()[["machine"]]`), a `cli::cli_warn()` fires
explaining that emulation may be slow or unstable and suggesting Docker
Desktop or a native x86_64 build as alternatives.

### Changes to `.validate_file_arg()`

Resolved the deferred item from Session 3. `.validate_file_arg()` now
returns paths relative to the working directory instead of absolute paths.
Both the file path and `getwd()` are normalized before computing the
relative path. Files outside the build context (including cross-drive paths
on Windows) produce an informative error. This consolidates the
`fs::path_rel()` conversion into one place and removes the three duplicate
calls from `generate_dockerfile()`.

The COPY blocks in `generate_dockerfile()` are now simple
`glue::glue("COPY {.x} /home/{.x}")` since `.validate_file_arg()` guarantees
the input is already relative.

### Testing

Added new tests in `test-container-workflow.R`:

- Invalid platform validation
- `--platform` flag inclusion and omission
- `docker buildx build` vs `docker build` selection based on architecture
- `--load` flag for cross-architecture Docker builds
- Cross-compilation warning fires when architectures differ
- No warning for same-architecture builds
- Existing tests wrapped with `suppressWarnings()` where the default
  `platform = "linux/amd64"` triggers the cross-compilation warning on
  `arm64` test hosts

Added build-context boundary test in `test-generate-dockerfile-content.R`:
files outside the working directory now error instead of producing a broken
Dockerfile.

### Open questions carried forward

- Layer 3 integration tests for `build_image()` and `push_image()` are
  still not written (carried from Session 2).
- `containerize()` convenience wrapper still on the roadmap (carried from
  Session 2).
- GitHub Actions workflow for building and pushing images on x86_64 runners
  is scoped but not yet implemented. This would eliminate QEMU emulation
  entirely for Apple Silicon users.

---

## Session 5 — 2026-07-27 (planning only, no code written)

### What we set out to do

This session added `shiny_server` as a valid choice for the `r_mode`
argument of `generate_dockerfile()`, motivated by the Longevity/`encapsulr`
project's `encapsulate()`, which needs to containerize Shiny-based artifacts
rather than only RStudio-based ones. No code was written this session --
the goal was to map out what changes the addition touches and to surface
design decisions that should be made before implementation starts.

### Where the change lives

Confirmed by reading `R/generate-dockerfile.R` alongside
`container-helpers.R`, `sysreqs-helpers.R`, `validate-args.R`, and
`build-image.R`: every `r_mode`-dependent branch (`image_map`, the
`expose_port` default/warning, the `EXPOSE` instruction, and the
`comments`-only usage hint) lives in `generate-dockerfile.R` alone. The
other four source files have no `r_mode` references and are out of scope
for this feature.

### Design questions surfaced, not yet resolved

Two questions turned out to be more than defaulting details and were added
to `PLAN.md`'s open design questions list (items 6 and 7):

- Whether `code_file` should auto-route to `/srv/shiny-server/` for
  `shiny_server` mode, stay under the existing (currently hardcoded)
  `/home/` destination with the convention documented instead, or become
  configurable via a new `app_dir` argument. This also surfaced an
  existing inconsistency worth noting on its own: `home_dir` only drives
  `WORKDIR` today -- the `COPY` destinations for `data_file` / `code_file`
  / `misc_file` are hardcoded to `/home/{.x}` rather than
  `{home_dir}/{.x}`.
- Whether `expose_port`'s default should become mode-aware (`NULL`,
  resolved internally via a small port map keyed by `r_mode`) now that two
  modes need different default ports (`8787` for `rstudio`, `3838` for
  `shiny_server`), or whether the caller stays responsible for passing the
  right port.

A third, lower-stakes question (item 8 in `PLAN.md`) is which dev-version
bump scheme to use: `0.1.4.9000` (minor-feature bump) or `0.1.3.9001`
(incremental bump within the current dev cycle).

### Scope grew mid-session: `rstudio_shiny` joins `shiny_server`

Erwin's answer to the port question introduced a second new mode --
running RStudio Server and Shiny Server together, not just Shiny Server
alone. Checked the Shiny Server Pro Admin Guide and the rocker-versioned2
README/install scripts before proposing a design, rather than guessing:

- Shiny Server's own default `shiny-server.conf` hosts the whole directory
  tree at `site_dir /srv/shiny-server;`. This resolves open question 6:
  `data_file` / `code_file` / `misc_file` should auto-route to
  `/srv/shiny-server/` for `shiny_server` and `rstudio_shiny`, preserving
  relative structure the same way `/home/` does today. Surfaced a related,
  pre-existing inconsistency worth fixing at the same time: `home_dir`
  only drives `WORKDIR` today, not the `COPY` destinations, which are
  hardcoded to `/home/{.x}`.
- rocker-versioned2 documents the supported way to combine the two:
  `FROM rocker/rstudio:4.0.0` followed by
  `RUN /rocker_scripts/install_shiny_server.sh`. The script already ships
  inside `rocker/rstudio` images, so `rstudio_shiny` needs no manual
  `.deb` handling -- just a new kind of block in `generate_dockerfile()`
  (an appended RUN instruction, structurally like the existing
  `install_quarto` block) rather than a second `image_map` entry.
- Both RStudio Server and Shiny Server can run in the same container on
  their own ports simultaneously (`-p 8787:8787 -p 3838:3838`), confirmed
  by multiple real-world Dockerfiles using this exact pattern. Resolves
  open question 7: `expose_port` becomes mode-aware via a `port_map`
  rather than a single literal default.

### Open questions carried forward

- Whether `/rocker_scripts/install_shiny_server.sh` is present across
  every R version `r_ver_exists()` currently accepts, or only the newest
  tags -- needs a smoke build before implementation, not an assumption.
- The `copy_root` / `home_dir` fix (question 6a) is scoped but not yet
  designed in detail.
- Layer 3 integration tests for `build_image()` and `push_image()` are
  still not written (carried from Session 2).
- `containerize()` convenience wrapper still on the roadmap (carried from
  Session 2).

### Scope finalized: full v0.2.0, seven phases

Asked what files I needed to see next; rather than requesting them one at
a time, tried cloning the public GitHub repo directly
(`git clone https://github.com/erwinlares/containr.git`) since
`github.com`/`codeload.github.com` are already in the allowed network
domains. It worked, and gave access to everything not yet uploaded:
`get-r-ver-tags.R`, `push-image.R`, `list-images.R`,
`.github/workflows/*.yaml`, the full `tests/testthat/` suite,
`on-testing.md`, and `NEWS.md`. Diffed every previously-uploaded file
against this clone -- all identical, confirming `main` is exactly the
baseline this whole conversation has been reasoning about.

Three findings from reading the newly-available files directly, rather
than continuing to reason from `PLAN.md`'s summaries of them:

- **`get-r-ver-tags.R` confirmed the third r_mode mapping.** Its own
  `mode_map` (`base = "r-ver"`, `rstudio = "rstudio"`, etc.) builds the
  Docker Hub API URL independently of `image_map` and `valid_modes`. This
  is what motivated folding a registry-consolidation phase into the
  release rather than adding `shiny_server`/`rstudio_shiny` to three lists
  by hand.
- **The `.check_tool_responsive()` redundancy is in three call sites, not
  one.** `build_image()`, `push_image()`, and `list_images()` all call
  `.resolve_tool()` and then immediately re-check responsiveness on the
  result, which `.resolve_tool()` already guaranteed.
- **`push_image()`'s login check and destination-path logic**, read
  directly: the `--get-login` flag bug is exactly where `PLAN.md` said,
  and the `"{registry}/{netid}/{project}:{tag}"` destination shape turns
  out to already generalize to `ghcr.io`/`quay.io`'s path structure --
  the registry-support work is smaller than it looked, mostly the
  login-check fix plus renaming/documenting `netid` more generally.

Erwin then asked to tackle the full remaining roadmap in this same
release -- GitHub Actions image builds, Singularity/Apptainer support,
the deferred Layer 3 tests, and additional registry support -- rather
than treating `shiny_server`/`rstudio_shiny` as a standalone patch.
Confirmed `0.2.0.9000` as the version target (a genuine minor bump,
correcting the earlier `0.1.4.9000` mislabel) and worked out a
dependency-ordered, seven-phase plan, written up in full in `PLAN.md`:

1. r_mode registry foundation (pure refactor, no new modes yet)
2. `shiny_server` and `rstudio_shiny`
3. tool-resolution cleanup + Layer 3 backfill for today's surface
4. additional registry support (`ghcr.io`, `quay.io`)
5. Singularity/Apptainer support
6. GitHub Actions workflow for image builds
7. documentation and release pass

Recommended a single long-lived branch, `containr-modes-0.2.0`, off
`main`, created via the RStudio Git pane or `gert::git_branch_create()`
rather than the command line, given Erwin's stated RStudio-centric
workflow. `main` stays at the released `0.1.3` state until Phase 7 lands
and `devtools::check()` is clean.

### Open questions carried forward (this round)

- Phase 2: whether `/rocker_scripts/install_shiny_server.sh` is present
  across every R version `r_ver_exists()` accepts -- smoke build needed.
- Phase 4: exact form of the `netid` -> more general argument name
  transition.
- Phase 5: pull/convert an existing OCI image vs. native `.def` file
  generation -- needs a decision before any code gets written, since it
  changes the size of the phase by roughly an order of magnitude.
- Phase 6: whether `build_image()` needs a `github_actions = TRUE` mode or
  the workflow can be pure YAML calling existing exported functions --
  current guess is the latter, unconfirmed.
- `containerize()` and a `.resolve_tool()` preference-order argument
  remain explicitly deferred beyond this release.

### Branch confirmed live; `tidystudio` renamed to `verse`; backward-compatibility assessment corrected

Erwin confirmed `containr-modes-0.2.0` is already created and pushed to
GitHub (visible in the repo's branch switcher) -- corrected the branch
name everywhere in this document and `PLAN.md`: it's `containr-modes-
0.2.0` (matching the package name), not `container-modes-0.2.0` (the
English word), which is what had been written since the name was first
proposed. Confirmed we're not pulling that branch here; work happens
locally in RStudio, with Erwin handling push/pull.

Raised whether `tidystudio` (mapped to `rocker/verse`) was worth keeping,
given curriculr's move to Typst removed the original motivation for a
LaTeX-inclusive image, and the name itself is arguably wrong on both
halves -- checked directly rather than assuming: `rocker/tidyverse` is
built on `rocker/rstudio`, so RStudio Server is already present two modes
earlier, meaning `tidystudio`'s "studio" half was never a unique
contribution; `rocker/verse` adds full TeX Live (~1.2-1.3GB image), not
the lightweight `tinytex` package, so "tinytex" would have been an
inaccurate name too had it been chosen. Erwin's decision: keep the
LaTeX-inclusive mode -- *"whoever needs it knows how heavy it will make
the container"* -- and rename it to `verse`, matching Rocker's own name
for the image (same pattern `shiny_server` already follows).

This renames one of Phase 1's four r_mode values, which is a real
exception to last round's "Phase 1 is fully backward compatible"
assessment -- `r_mode = "tidystudio"` works on `0.1.3` and will error
after this phase ships. Flagged as a `NEWS.md`-worthy breaking change and
raised, not yet decided, whether `"tidystudio"` should be accepted as a
deprecated alias for one release or hard-removed immediately. Also
confirmed by direct search that four test files reference `"tidystudio"`
by name (`test-generate-dockerfile-content.R`, `test-r-ver-exists.R`,
`test-generate-dockerfile-file-args.R`, `test-r-ver-tags.R`) and will need
a one-word edit each -- corrected Phase 1's "zero test diff" acceptance
criterion to scope that claim to everything *except* these four expected
edits, rather than overclaiming a fully silent refactor.

`shiny_server` and `rstudio_shiny` reconfirmed as the Phase 2 names.

### Open questions carried forward (this round)

- Hard rename `tidystudio` -> `verse`, or accept the old name as a
  deprecated, warning alias for one release first?
- Erwin's most recent message wrote `shiny-server` (hyphen) once, after
  confirming `shiny_server` (underscore) the round before -- flagged as
  almost certainly a typo rather than a deliberate change, pending
  confirmation, since a real change would need updating six-plus places
  across `PLAN.md` where the underscore form is already written down.

### `tidystudio` -> `verse`: deprecate, don't hard-remove

Erwin's call: deprecate rather than hard-remove -- "it's a small fraction
of the potential users and it clears a naming mistake." Reworked Phase 1's
plan in `PLAN.md` accordingly: `r_mode = "tidystudio"` keeps working,
resolving to the same `verse` entry, with a deprecation warning pointing
at the new name. Design lands the alias table and the resolver
(`.resolve_r_mode()`, tentative name) in the same new file as the
registry itself, rather than duplicating the check in each of the three
consuming functions -- continues the phase's own point, which is to stop
tripling r_mode knowledge across files.

Worked out the test-impact consequence of deprecation vs. hard rename:
under deprecation, the four existing `"tidystudio"` test call sites
identified last round turn out to need **zero edits** -- every assertion
they make still holds, since the deprecated alias still resolves and
still doesn't error. What's actually needed is new coverage instead:
direct tests for `r_mode = "verse"` (nothing exercises the new name today)
and a test that the deprecation warning itself fires. This reverses last
round's claim that four test files would need one-word edits -- worth
noting as a case where reasoning through the *shape* of a decision
(deprecate vs. hard-remove) changed the actual downstream file-impact
answer, not just the user-facing behavior.

Flagged `lifecycle::deprecate_warn()` as the likely mechanism (one new
`Imports` entry) versus a hand-rolled `cli::cli_warn()` matching the
package's existing style -- not yet decided.

`rstudio_shiny` reconfirmed (Erwin: "good call. it is rstudio_shiny"),
closing out the `shiny-server`/`shiny_server` typo question from last
round's message.

### Reversed: clean drop instead of deprecation

Erwin's reaction to the deprecation design: "it actually sounds more
cumbersome than it needs to be" -- switched to fully dropping
`tidystudio`, reported as a breaking change, no alias, no warning cycle.
Asked directly whether there were objections; answer was no real one --
containr is still `0.y.z`, and semver's own convention at that stage is
that anything may change without a deprecation cycle, so this isn't an
exception to normal practice, it's the normal case. Noted two small,
non-blocking follow-ups: check whether Carpentries/BRUG workshop material
references `"tidystudio"` by name, and whether `README.md` needs a
matching update -- neither affects Phase 1's code.

This unwinds everything the deprecation design added to `PLAN.md`: no
`.resolve_r_mode()` resolver, no alias table, no `lifecycle` dependency
question. Back to the simpler shape from two rounds ago -- the registry's
four keys *are* the valid-values list, and the four `"tidystudio"` test
call sites go back to needing a one-word edit each, which is now the
confirmed plan rather than a superseded finding.

Left one small, optional question open rather than deciding it: whether
`generate_dockerfile(r_mode = "tidystudio")` should get a plain
"not a valid r_mode" error like any other typo, or a `"did you mean
'verse'?"`-style hint specific to that one input. Cheap either way, not a
reintroduction of the complexity just removed, but still a piece of
special-casing worth a direct yes/no.
