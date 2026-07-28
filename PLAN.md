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
- CRAN: yes (current released version `0.1.3`; `main` sits at dev version
  `0.1.3.9000` until the `containr-modes-0.2.0` branch below merges,
  targeting `0.2.0`)
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
submitr::htc_upload()           -- copy files to CHTC
submitr::htc_submit()           -- submit job
submitr::htc_status()           -- monitor job
submitr::htc_download()         -- retrieve results
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

## v0.2.0 -- full plan

**Branch:** `containr-modes-0.2.0`, created off `main` via the RStudio Git
pane or `gert::git_branch_create("containr-modes-0.2.0")`. `main` stays at
the released `0.1.3` state until Phase 7 is done and `devtools::check()` is
clean.

**Version:** `0.2.0.9000` -- a true minor bump (not `0.1.4.9000`, which
would read as a patch under semver), matching this section's name.

**Motivation:** started as one new `r_mode` value for the Longevity/
`encapsulr` project's `encapsulate()`. Grew, over the course of planning, to
two new modes (`shiny_server`, `rstudio_shiny`), a fix for a duplicated
mode-mapping problem those two modes exposed, and -- once the version was
already being bumped -- several other roadmap items that had been sitting
scoped-but-unstarted: registry support, Singularity/Apptainer, Layer 3
tests, and a GitHub Actions build workflow. Confirmed against a fresh clone
of the GitHub repo (`erwinlares/containr`, public) on 2026-07-27; every
file discussed in this plan matches what's on `main` exactly, so this is a
clean, known baseline to branch from.

Sequenced by dependency, not by request order -- each phase is meant to be
committable and testable on its own rather than one long-running diff.

---

### Phase 1 -- r_mode registry foundation

Three functions currently maintain independent, hand-written knowledge of
what `r_mode` values exist and what they mean:

- `image_map` in `generate-dockerfile.R` -- r_mode -> `FROM` image
- `valid_modes` in `r-ver-exists.R` -- r_mode -> allowed/not allowed
- `mode_map` in `get-r-ver-tags.R` -- r_mode -> Docker Hub repo suffix for
  tag-checking (confirmed by reading the file directly: `base = "r-ver"`,
  `rstudio = "rstudio"`, etc., feeding `paste0("rocker/", mode_map[[r_mode]])`)

None of these three currently know about ports, extra install steps, or
copy destinations either, which the two new modes both need. Rather than
add a fourth and fifth hand-maintained fact to three separate files,
Phase 1 introduces a single registry and repoints all three functions at
it -- but populated with **only the four existing modes**, so this phase
is a pure refactor with no behavior change, checkable against the existing
test suite before anything new is added.

**What each of the three functions currently does, precisely** (confirmed
by reading the source, not assumed): `image_map` (`generate-dockerfile.R`)
maps r_mode to the full Docker image name (`"rocker/r-ver"`) used in the
`FROM` line. `mode_map` (`get-r-ver-tags.R`) maps r_mode to the image-name
*suffix only* (`"r-ver"`), which the function prepends `"rocker/"` to
before querying Docker Hub. `valid_modes` (`r-ver-exists.R`) isn't a
mapping at all -- just a character vector of legal names used to validate
input before delegating to `.get_r_ver_tags()`. `.r_mode_registry` is the
one object that holds what the first two separately know, with the third
becoming simply `names(.r_mode_registry)`.

**Canonical order, confirmed:** `base, tidyverse, rstudio, verse,
shiny_server, rstudio_shiny` -- this is the order for the *complete*
registry (all six eventual entries), fixed now so it doesn't need
reordering later regardless of which phase each entry actually lands in.
Also resolves the wrinkle flagged earlier: today, `image_map` orders
`tidyverse` before `rstudio`, while `valid_modes` and `mode_map` both do
the reverse -- the three functions have never agreed with each other. This
order is now the single source of truth, and each function's `cli_abort()`
"valid choices are ..." / "must be one of ..." wording stays exactly as it
reads today; only the data source it pulls the name list from changes.

**`tidystudio` renamed to `verse` as part of this phase.** Checked what
`rocker/verse` actually contains before proposing this: it's
`rocker/tidyverse` (which is itself built on `rocker/rstudio`, so RStudio
Server is already present two modes earlier) plus full TeX Live -- *"a
large but not comprehensive LaTeX environment"* per the Rocker project's
own description, not the lightweight `tinytex` R package, and a genuinely
heavy image (~1.2-1.3GB compressed for current tags). `tidystudio`'s name
was misleading on both halves: `studio` implied it was the one adding
RStudio access, when `tidyverse` already has it; and nothing in the name
hinted at LaTeX, which is the actual differentiator. Decision: keep the
LaTeX-inclusive mode (Erwin's call -- "whoever needs it knows how heavy it
will make the container"), rename it to `verse` to match Rocker's own
name for the image, same pattern `shiny_server` already follows of
borrowing the upstream name directly rather than inventing a new one.

```r
.r_mode_registry <- list(
    base      = list(image = "rocker/r-ver",    tag_repo = "rocker/r-ver",
                      ports = NULL, extra_install = NULL, copy_root = "/home"),
    tidyverse = list(image = "rocker/tidyverse", tag_repo = "rocker/tidyverse",
                      ports = NULL, extra_install = NULL, copy_root = "/home"),
    rstudio   = list(image = "rocker/rstudio",   tag_repo = "rocker/rstudio",
                      ports = "8787", extra_install = NULL, copy_root = "/home"),
    verse     = list(image = "rocker/verse",     tag_repo = "rocker/verse",
                      ports = NULL, extra_install = NULL, copy_root = "/home")
    # shiny_server and rstudio_shiny entries land in Phase 2, in this
    # same order, appended after verse
)
```

Field names above are illustrative, not final. `generate_dockerfile()`
reads `image`/`ports`/`extra_install`/`copy_root`; `.r_ver_exists()` and
`.get_r_ver_tags()` read `tag_repo`; `names(.r_mode_registry)` becomes the
one legal-values list everywhere, so the `cli_abort()` "valid choices are
..." messages in all three files stay correct by construction rather than
by convention.

**Reversed -- clean drop, not deprecation.** `r_mode = "tidystudio"` is
removed outright in `0.2.0`, reported as a breaking change in `NEWS.md`.
Erwin's call, and I don't have a real objection to it: containr is still
`0.y.z` (pre-1.0), where semver's own convention is that anything may
change release to release without a deprecation cycle -- this isn't
reaching for an exception, it's the normal expectation at this stage.
Practically, the population affected is also narrower than "anyone who's
ever called `generate_dockerfile()`": `renv.lock`-pinned projects (the
workflow containr itself encourages) keep whatever containr version they
snapshotted, and a project's already-generated `Dockerfile` is a static
file -- the break only bites someone who upgrades containr *and*
regenerates a Dockerfile with the old mode name, which is a small,
specific overlap. Two follow-ups worth a mental note rather than blocking
this phase: check whether any Carpentries/BRUG workshop material
references `"tidystudio"` by name, and whether `README.md`'s
"When to use containr" prose needs a matching update -- neither affects
Phase 1's code, just worth not forgetting.

This also removes everything the deprecation design added: no resolver,
no alias table, no `lifecycle` dependency question. Back to the simpler
shape -- `.r_mode_registry`'s four keys (`base`, `tidyverse`, `rstudio`,
`verse`) *are* the valid-values list, full stop, and each of the three
consuming functions calls `names(.r_mode_registry)` directly rather than
through any translation layer.

**Confirmed: plain error, no special-casing.** `r_mode = "tidystudio"`
gets the same generic "not a valid r_mode, choices are: ..." message any
other invalid value would -- no `"did you mean 'verse'?"` hint. Keeps the
cut as clean as the rest of this decision; nothing in `.r_mode_registry`
or its consumers needs to know `"tidystudio"` ever existed.

**Files touched:** one new file (`R/r-mode-registry.R`, name open),
defining `.r_mode_registry` only -- no second object. Three modified
(`generate-dockerfile.R`, `r-ver-exists.R`, `get-r-ver-tags.R`), each
losing its local list/vector in favor of a lookup into the shared
registry. **Four test files need a one-word edit each**, back to what was
first identified two rounds ago, now confirmed as the actual plan rather
than superseded by the deprecation design:

- `test-generate-dockerfile-content.R` -- `"Dockerfile FROM line reflects
  r_mode = 'tidystudio'"` and its body's `r_mode = "tidystudio"`
- `test-r-ver-exists.R` -- `c("base", "rstudio", "tidyverse", "tidystudio")`
- `test-generate-dockerfile-file-args.R` -- same four-mode vector
- `test-r-ver-tags.R` -- `.get_r_ver_tags("tidystudio")$image` assertion

None deleted.

**Acceptance criteria -- all four must hold, not just "tests still pass":**

1. For each of the four existing `r_mode` values (three under their
   current names, `verse` under its new one), `generate_dockerfile()`
   writes the byte-identical `FROM` line it does today for the equivalent
   input. This is the one place a mapping bug would actually change what
   gets built, not just how the code is organized.
2. `.r_ver_exists()` / `.get_r_ver_tags()` resolve to the same Docker Hub
   repo for the same four modes -- version-checking behavior unchanged
   apart from the `verse` rename.
3. **Only the four `tidystudio` -> `verse` occurrences above change in
   `tests/testthat/` -- nothing else.** Confirmed by direct search that no
   existing test references `image_map`, `valid_modes`, or `mode_map` by
   name (they're function-local, never package-level bindings), so those
   three would need zero changes on their own. Any diff beyond the four
   listed above is a sign something else changed too.
4. A new `test-r-mode-registry.R` asserting the registry's structure
   directly (four entries, each with the expected `image`/`tag_repo`) --
   the one thing about this phase the existing suite can't verify, since
   it tests behavior through the public/internal functions, never the
   registry's shape itself.

---

### Phase 2 -- `shiny_server` and `rstudio_shiny`

Now two new entries in the registry rather than edits across three files:

```r
shiny_server  = list(image = "rocker/shiny",   tag_repo = "rocker/shiny",
                      ports = "3838", extra_install = NULL,
                      copy_root = "/srv/shiny-server"),
rstudio_shiny = list(image = "rocker/rstudio", tag_repo = "rocker/rstudio",
                      ports = c("8787", "3838"),
                      extra_install = "install_shiny_server.sh",
                      copy_root = "/srv/shiny-server")
```

`rstudio_shiny`'s `tag_repo` is deliberately `"rocker/rstudio"`, not a
`"rocker/rstudio_shiny"` that doesn't exist -- there's no separate Docker
Hub repo for the combo, since it's built by layering an install script
onto `rocker/rstudio`.

Changes to `generate_dockerfile()`:

- `EXPOSE` block emits one or more ports per `ports` (a single
  `EXPOSE 8787 3838` line for `rstudio_shiny`)
- new conditional RUN block for `extra_install`, structurally like the
  existing `install_quarto` block -- for `rstudio_shiny` this is
  `RUN /rocker_scripts/install_shiny_server.sh`, the Rocker project's own
  documented pattern for layering Shiny Server onto an RStudio image, with
  no manual `.deb` handling needed
- `data_file`/`code_file`/`misc_file` COPY destinations resolve from
  `copy_root` instead of the hardcoded `/home/{.x}` -- this also finally
  makes `home_dir` (which currently only drives `WORKDIR`) consistent with
  where files actually land
- new `comments`-only usage hint for `rstudio_shiny` (`docker run -p
  8787:8787 -p 3838:3838 ...`) alongside the existing `rstudio_hint` block

**App directory:** `/srv/shiny-server/` for both new modes, preserving
relative structure exactly the way `/home/` does today (`code_file =
"myapp/app.R"` -> `/srv/shiny-server/myapp/app.R`) -- this matches Shiny
Server's own default `site_dir /srv/shiny-server;` configuration, not a
convention containr is inventing.

**Open before this phase starts:** confirm `/rocker_scripts/
install_shiny_server.sh` is present across every R version
`r_ver_exists()` currently accepts, not just the newest tags -- a quick
smoke build, not an assumption.

**Also needed:** roxygen (`@param r_mode`, `@param expose_port`, at least
one new `@examples` block), `README.md` (new example(s) in "Core workflow
functions"), `NEWS.md` entry, and updates to
`test-generate-dockerfile-content.R`, `test-generate-dockerfile-file-args.R`,
`test-r-ver-exists.R`, and `test-r-ver-tags.R` (`FROM rocker/shiny` and
`RUN .../install_shiny_server.sh` assertions, port assertions per mode,
hint-block content, copy-root routing, valid-choices list).

**Sources consulted:** Shiny Server Pro Admin Guide (docs.posit.co/shiny-
server), rocker-versioned2 README and `install_shiny_server.sh`
(github.com/rocker-org/rocker-versioned2), rocker/shiny image description
(rocker-project.org).

---

### Phase 3 -- tool-resolution cleanup + Layer 3 test backfill

`.resolve_tool()`'s auto-detect path already falls through from Podman to
Docker correctly -- confirmed by reading `container-helpers.R` directly,
not just the roadmap's summary of it. `.check_tool_responsive()`'s own
docstring says as much: *"retained for backward compatibility... new code
should rely on `.resolve_tool()`, which incorporates responsiveness
checking into tool selection."* What's actually left is smaller than
originally scoped: `build_image()`, `push_image()`, and `list_images()`
all call `.resolve_tool(tool)` and then immediately call
`.check_tool_responsive(resolved_tool)` again, redundantly re-checking
something `.resolve_tool()` already guaranteed. Delete the redundant call
in all three files.

Alongside that, backfill the Layer 3 integration tests for `build_image()`
and `push_image()` that have been deferred since Session 2 -- against
today's surface, before Phases 4 and 5 add more of it. Same
`CONTAINR_INTEGRATION_TESTS` guard already used for `list_images()`'s
Layer 3 tests.

This is the cheapest, lowest-risk phase in the plan, and doubles as a
checkpoint that Phases 1-2 didn't disturb tool resolution anywhere.

---

### Phase 4 -- additional registry support (`ghcr.io`, `quay.io`)

Resolves open design question 2 (registry argument vs. separate
registry-specific functions).

Two concrete findings from reading `push-image.R` directly:

- **The login-check bug is real and precisely located.**
  `system2(resolved_tool, args = c("login", "--get-login", registry), ...)`
  -- `--get-login` is a Podman-only flag; under Docker this always
  misbehaves (exit code 125), which is why `check_login = FALSE` exists as
  a workaround today. Fix: parse `~/.docker/config.json` for the registry
  entry when the tool is Docker, or attempt a lightweight authenticated
  operation and catch the failure.
- **The destination-path shape already generalizes.**
  `destination <- glue::glue("{registry}/{netid}/{project}:{tag}")` is
  structurally the same three-segment pattern as `ghcr.io/OWNER/IMAGE:tag`
  or `quay.io/ORG/REPO:tag`. So this isn't a new assembly scheme -- it's
  the login-check fix above, plus deciding how `netid` gets generalized in
  name and docs (a GitHub username typed into an argument called `netid`
  reads oddly) without breaking existing CHTC callers.

**Open before this phase starts:** exact form of the `netid` generalization
-- rename with a backward-compatible alias, or keep the name and just
broaden the documentation? Also needs new Layer 3 coverage for the new
registries, likely mocked rather than hitting live `ghcr.io`/`quay.io` in
CI.

---

### Phase 5 -- Singularity / Apptainer support

**Stop and scope this one properly before writing anything** -- there's a
real fork hiding in "add Singularity support" that changes the size of the
work by roughly an order of magnitude depending on which side it lands on:

- **Pull/convert an existing OCI image** (`singularity build my.sif
  docker://registry/image:tag`, run *after* Phase 4 has something pushed)
  -- small, a new function layered on top of what already exists.
- **Native `.def` file generation** -- a second, parallel recipe format
  alongside `Dockerfile`, resolving open design question 3 (`format`
  argument on `generate_dockerfile()`). This duplicates a meaningful
  fraction of what `generate_dockerfile()` already does, in a different
  syntax, and is a substantially larger effort.

Once the model is decided, the entry point for the smaller option is
adding `"singularity"`/`"apptainer"` as valid `tool` values in
`.resolve_tool()`; for the larger option it's a `format` argument plus a
sibling code path to the existing `lines` list construction in
`generate_dockerfile()`.

---

### Phase 6 -- GitHub Actions workflow for image builds

Confirmed there's no existing workflow that builds or pushes container
images -- the four in `.github/workflows/` (`R-CMD-check.yaml`,
`pkgdown.yaml`, `test-coverage.yaml`, `rhub.yaml`) are all R-package
testing infrastructure, untouched by this phase. This is a clean net-new
`.github/workflows/` file.

Sequenced after Phases 4 and 5 so the workflow targets whatever tool/
registry surface actually exists by then, rather than being built against
CHTC-only and reworked twice. Solves the Apple Silicon QEMU problem from
Session 4 by running on a native `x86_64` GitHub-hosted runner.

Resolves open design question 4: does `build_image()` grow a
`github_actions = TRUE` mode that generates and triggers a workflow file,
or does the workflow live entirely as YAML calling the existing
`build_image()`/`push_image()` with the right arguments? Current guess is
the latter -- little or no R-code change, mostly new YAML -- but that's a
guess to confirm once this phase actually starts, not an assumption to
build on now.

---

### Phase 7 -- documentation and release pass

`README.md`, both vignettes (`containr-workflow.Rmd`, `why-containers.Rmd`),
a consolidated `NEWS.md` entry covering the whole `0.2.0` release, and
`inst/WORDLIST` additions (`shiny_server`, `ghcr`, `quay`, `Apptainer`,
`Singularity` will all trip `spelling::spell_check_package()` otherwise).
Then the standard release cycle: `devtools::document()` ->
`devtools::test()` -> `devtools::check()` -> `devtools::submit_cran()`,
followed by `usethis::use_github_release()` ->
`usethis::use_dev_version(push = TRUE)`.

---

### Deferred beyond v0.2.0

Two items from the original roadmap that weren't part of this round and
don't block anything above:

- **`containerize()` convenience wrapper** (open design question 1) --
  doesn't touch `r_mode` or anything else in this plan; fine to pick up
  independently whenever.
- **`.resolve_tool()` preference-order argument** (open design question 5)
  -- distinct from the Phase 3 cleanup; `tool_preference = c("podman",
  "docker")` as a configurable order rather than a hardcoded one. Small,
  but not requested this round.
