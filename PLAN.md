# containr — Package Development Plan

## What is containr?

`containr` helps researchers containerize their R projects. It generates
a `Dockerfile` from a project’s `renv.lock`, builds a container image,
and pushes it to a registry — so analyses can be reliably shared,
archived, and rerun across systems without worrying about software
versions or system configuration.

The package is explicitly scoped to containerization. Job submission,
scheduling, and results retrieval belong in `submitr`.

------------------------------------------------------------------------

## Package identity

- Name: containr
- CRAN: yes (current released version `0.1.3`; `main` sits at dev
  version `0.1.3.9000` until the `containr-modes-0.2.0` branch below
  merges, targeting `0.2.0`)
- License: Apache 2.0
- Registry target: UW-Madison DoIT’s GitLab Container Registry
  (`registry.doit.wisc.edu`) by default – the only registry
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  currently supports. containr’s role ends at the push; CHTC pulls from
  this registry independently, later, when a submitted job runs – it has
  no direct relationship to containr.
- Container tool: `podman` preferred, `docker` supported

------------------------------------------------------------------------

## Relationship to sibling packages

    toolero     -- research workflow toolkit (CRAN 0.4.0, dev)
    containr    -- containerization toolkit (CRAN 0.1.3, dev)
    curriculr   -- CV generation toolkit (CRAN 0.3.0, dev)
    submitr     -- HTC job submission toolkit (CRAN 0.1.0, dev)

The full workflow:

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

------------------------------------------------------------------------

## Completed

### `generate_dockerfile()`

Generates a ready-to-use `Dockerfile` from a project’s `renv.lock`.

Key features: - `auto_syslibs = TRUE` — auto-detects required system
libraries via
[`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html) -
`install_syslibs = NULL` — accepts character vector of extra `apt`
packages - `curl` always installed as baseline for `renv` downloads -
`renv.lock` required — errors informatively if not found -
[`renv::status()`](https://rstudio.github.io/renv/reference/status.html)
check — warns if lockfile is out of sync - Supports `r_mode`: `"base"`,
`"tidyverse"`, `"rstudio"`, `"tidystudio"` - `verbose`, `comments`,
`dry_run` follow package-wide conventions

### `build_image()`

Builds a container image from a `Dockerfile` using `podman` or `docker`.
Auto-detects tool, validates Dockerfile, checks daemon responsiveness.
`platform` defaults to `"linux/amd64"` for HPC/HTC cluster
compatibility. Automatically uses `docker buildx build` with `--load`
for cross-platform Docker builds. Warns when the target platform differs
from the host architecture. Supports `dry_run = TRUE`, `verbose`,
`comments`.

### `list_images()`

Returns a data frame of locally stored container images. Columns:
`repository`, `tag`, `image_id`, `created`, `size`. Prints and returns
invisibly. Uses Go template format string via
[`shQuote()`](https://rdrr.io/r/base/shQuote.html) for reliable output
parsing.

### `push_image()`

Tags and pushes a local image to a container registry in a single call.
Arguments: `image_id`, `netid`, `project`, `tag`, `registry`,
`check_login`, `dry_run`, `verbose`, `comments`. Warns on
`tag = "latest"`. Checks login status before pushing. Unconditional
success message on completion.

------------------------------------------------------------------------

## Source file organization

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

------------------------------------------------------------------------

## Testing strategy

See `on-testing.md` for the full three-layer strategy. Summary:

| Layer | What it tests        | Guard                             | Runs on CI |
|-------|----------------------|-----------------------------------|------------|
| 1     | Argument validation  | none                              | Yes        |
| 2     | Command construction | `dry_run`, mocks                  | Yes        |
| 3     | End-to-end execution | `CONTAINR_INTEGRATION_TESTS=true` | No         |

To run Layer 3 tests locally before a release:

``` r

Sys.setenv(CONTAINR_INTEGRATION_TESTS = "true")
devtools::test()
Sys.unsetenv("CONTAINR_INTEGRATION_TESTS")
```

------------------------------------------------------------------------

## v0.2.0 – full plan

**Branch:** `containr-modes-0.2.0`, created off `main` via the RStudio
Git pane or `gert::git_branch_create("containr-modes-0.2.0")`. `main`
stays at the released `0.1.3` state until Phase 6 is done and
`devtools::check()` is clean.

**Version:** `0.2.0.9000` – a true minor bump (not `0.1.4.9000`, which
would read as a patch under semver), matching this section’s name.

**Motivation:** started as one new `r_mode` value for the Longevity/
`encapsulr` project’s `encapsulate()`. Grew, over the course of
planning, to two new modes (`shiny_server`, `rstudio_shiny`), a fix for
a duplicated mode-mapping problem those two modes exposed, and – once
the version was already being bumped – several other roadmap items that
had been sitting scoped-but-unstarted: registry support, Layer 3 tests,
and a GitHub Actions build workflow. Apptainer support was scoped
alongside these too, but ultimately deferred to `0.3.0` – see below.
Confirmed against a fresh clone of the GitHub repo
(`erwinlares/containr`, public) on 2026-07-27; every file discussed in
this plan matches what’s on `main` exactly, so this is a clean, known
baseline to branch from.

Sequenced by dependency, not by request order – each phase is meant to
be committable and testable on its own rather than one long-running
diff.

------------------------------------------------------------------------

### Phase 1 – r_mode registry foundation

Three functions currently maintain independent, hand-written knowledge
of what `r_mode` values exist and what they mean:

- `image_map` in `generate-dockerfile.R` – r_mode -\> `FROM` image
- `valid_modes` in `r-ver-exists.R` – r_mode -\> allowed/not allowed
- `mode_map` in `get-r-ver-tags.R` – r_mode -\> Docker Hub repo suffix
  for tag-checking (confirmed by reading the file directly:
  `base = "r-ver"`, `rstudio = "rstudio"`, etc., feeding
  `paste0("rocker/", mode_map[[r_mode]])`)

None of these three currently know about ports, extra install steps, or
copy destinations either, which the two new modes both need. Rather than
add a fourth and fifth hand-maintained fact to three separate files,
Phase 1 introduces a single registry and repoints all three functions at
it – but populated with **only the four existing modes**, so this phase
is a pure refactor with no behavior change, checkable against the
existing test suite before anything new is added.

**What each of the three functions currently does, precisely**
(confirmed by reading the source, not assumed): `image_map`
(`generate-dockerfile.R`) maps r_mode to the full Docker image name
(`"rocker/r-ver"`) used in the `FROM` line. `mode_map`
(`get-r-ver-tags.R`) maps r_mode to the image-name *suffix only*
(`"r-ver"`), which the function prepends `"rocker/"` to before querying
Docker Hub. `valid_modes` (`r-ver-exists.R`) isn’t a mapping at all –
just a character vector of legal names used to validate input before
delegating to
[`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md).
`.r_mode_registry` is the one object that holds what the first two
separately know, with the third becoming simply
`names(.r_mode_registry)`.

**Canonical order, confirmed:**
`base, tidyverse, rstudio, verse, shiny_server, rstudio_shiny` – this is
the order for the *complete* registry (all six eventual entries), fixed
now so it doesn’t need reordering later regardless of which phase each
entry actually lands in. Also resolves the wrinkle flagged earlier:
today, `image_map` orders `tidyverse` before `rstudio`, while
`valid_modes` and `mode_map` both do the reverse – the three functions
have never agreed with each other. This order is now the single source
of truth, and each function’s `cli_abort()` “valid choices are …” /
“must be one of …” wording stays exactly as it reads today; only the
data source it pulls the name list from changes.

**`tidystudio` renamed to `verse` as part of this phase.** Checked what
`rocker/verse` actually contains before proposing this: it’s
`rocker/tidyverse` (which is itself built on `rocker/rstudio`, so
RStudio Server is already present two modes earlier) plus full TeX Live
– *“a large but not comprehensive LaTeX environment”* per the Rocker
project’s own description, not the lightweight `tinytex` R package, and
a genuinely heavy image (~1.2-1.3GB compressed for current tags).
`tidystudio`’s name was misleading on both halves: `studio` implied it
was the one adding RStudio access, when `tidyverse` already has it; and
nothing in the name hinted at LaTeX, which is the actual differentiator.
Decision: keep the LaTeX-inclusive mode (Erwin’s call – “whoever needs
it knows how heavy it will make the container”), rename it to `verse` to
match Rocker’s own name for the image, same pattern `shiny_server`
already follows of borrowing the upstream name directly rather than
inventing a new one.

``` r

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

Field names above are illustrative, not final.
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
reads `image`/`ports`/`extra_install`/`copy_root`;
[`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md)
and
[`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
read `tag_repo`; `names(.r_mode_registry)` becomes the one legal-values
list everywhere, so the `cli_abort()` “valid choices are …” messages in
all three files stay correct by construction rather than by convention.

**Reversed – clean drop, not deprecation.** `r_mode = "tidystudio"` is
removed outright in `0.2.0`, reported as a breaking change in `NEWS.md`.
Erwin’s call, and I don’t have a real objection to it: containr is still
`0.y.z` (pre-1.0), where semver’s own convention is that anything may
change release to release without a deprecation cycle – this isn’t
reaching for an exception, it’s the normal expectation at this stage.
Practically, the population affected is also narrower than “anyone who’s
ever called
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)”:
`renv.lock`-pinned projects (the workflow containr itself encourages)
keep whatever containr version they snapshotted, and a project’s
already-generated `Dockerfile` is a static file – the break only bites
someone who upgrades containr *and* regenerates a Dockerfile with the
old mode name, which is a small, specific overlap. Two follow-ups worth
a mental note rather than blocking this phase: check whether any
Carpentries/BRUG workshop material references `"tidystudio"` by name,
and whether `README.md`’s “When to use containr” prose needs a matching
update – neither affects Phase 1’s code, just worth not forgetting.

This also removes everything the deprecation design added: no resolver,
no alias table, no `lifecycle` dependency question. Back to the simpler
shape – `.r_mode_registry`’s four keys (`base`, `tidyverse`, `rstudio`,
`verse`) *are* the valid-values list, full stop, and each of the three
consuming functions calls `names(.r_mode_registry)` directly rather than
through any translation layer.

**Confirmed: plain error, no special-casing.** `r_mode = "tidystudio"`
gets the same generic “not a valid r_mode, choices are: …” message any
other invalid value would – no `"did you mean 'verse'?"` hint. Keeps the
cut as clean as the rest of this decision; nothing in `.r_mode_registry`
or its consumers needs to know `"tidystudio"` ever existed.

**Files touched:** one new file (`R/r-mode-registry.R`, name open),
defining `.r_mode_registry` only – no second object. Three modified
(`generate-dockerfile.R`, `r-ver-exists.R`, `get-r-ver-tags.R`), each
losing its local list/vector in favor of a lookup into the shared
registry. **Four test files need a one-word edit each**, back to what
was first identified two rounds ago, now confirmed as the actual plan
rather than superseded by the deprecation design:

- `test-generate-dockerfile-content.R` –
  `"Dockerfile FROM line reflects r_mode = 'tidystudio'"` and its body’s
  `r_mode = "tidystudio"`
- `test-r-ver-exists.R` –
  `c("base", "rstudio", "tidyverse", "tidystudio")`
- `test-generate-dockerfile-file-args.R` – same four-mode vector
- `test-r-ver-tags.R` – `.get_r_ver_tags("tidystudio")$image` assertion

None deleted.

**Acceptance criteria – all four must hold, not just “tests still
pass”:**

1.  For each of the four existing `r_mode` values (three under their
    current names, `verse` under its new one),
    [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
    writes the byte-identical `FROM` line it does today for the
    equivalent input. This is the one place a mapping bug would actually
    change what gets built, not just how the code is organized.
2.  [`.r_ver_exists()`](https://erwinlares.github.io/containr/reference/dot-r_ver_exists.md)
    /
    [`.get_r_ver_tags()`](https://erwinlares.github.io/containr/reference/dot-get_r_ver_tags.md)
    resolve to the same Docker Hub repo for the same four modes –
    version-checking behavior unchanged apart from the `verse` rename.
3.  **Only the four `tidystudio` -\> `verse` occurrences above change in
    `tests/testthat/` – nothing else.** Confirmed by direct search that
    no existing test references `image_map`, `valid_modes`, or
    `mode_map` by name (they’re function-local, never package-level
    bindings), so those three would need zero changes on their own. Any
    diff beyond the four listed above is a sign something else changed
    too.
4.  A new `test-r-mode-registry.R` asserting the registry’s structure
    directly (four entries, each with the expected `image`/`tag_repo`) –
    the one thing about this phase the existing suite can’t verify,
    since it tests behavior through the public/internal functions, never
    the registry’s shape itself.

------------------------------------------------------------------------

### Phase 2 – `shiny_server` and `rstudio_shiny`

**Status: implemented and verified (Session 6).** Registry entries,
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
changes, the `min_r_version` floor check (R \>= 4.0.0 for
`shiny_server`/`rstudio_shiny`, since `/rocker_scripts/` only exists in
`rocker-versioned2`-lineage images), and test coverage are all in place
on `containr-modes-0.2.0`. Actually run this time, not just
syntax-checked: `devtools::test()` – 237 passed, 0 failed, 3 skipped
(Layer 3, correctly guarded). `devtools::check()` – 0 errors; the 1
WARNING (locale) and 1 NOTE (no CRAN access) are both artifacts of the
sandbox this ran in, not real issues. `inst/WORDLIST` gained several
pre-existing gaps this surfaced (`DOI`, `Sys`, `URI`, `amd64`,
`containr's`, `macOS`, `repo`, `sys`, `v2`, `x86`) plus `versioned2` for
this phase’s own docs. Worth Erwin re-running
`document()`/`test()`/`check()` locally regardless, since this sandbox’s
R toolchain (installed via `apt-get`, not CRAN) may not exactly match
his.

**Decided in Session 6: `copy_root` is not coupled to `home_dir`.** An
initial pass made the four Phase 1 modes’ `copy_root` follow `home_dir`
(fixing a latent inconsistency where `home_dir` drove `WORKDIR` but
never `COPY`). Erwin rejected this as scope creep unrelated to shiny
mode support and asked to keep `/home` and `home_dir` exactly as they
are today, routing Shiny Server’s files to `/srv/shiny-server` only
because that’s where Shiny Server’s own docs place them. Reverted –
`copy_root` is `.r_mode_registry[[r_mode]]$copy_root` with no `home_dir`
involvement for any mode, keeping Phase 1’s byte-identical guarantee
intact into Phase 2.

Now two new entries in the registry rather than edits across three
files:

``` r
shiny_server  = list(image = "rocker/shiny",   tag_repo = "rocker/shiny",
                      ports = "3838", extra_install = NULL,
                      copy_root = "/srv/shiny-server",
                      min_r_version = "4.0.0"),
rstudio_shiny = list(image = "rocker/rstudio", tag_repo = "rocker/rstudio",
                      ports = c("8787", "3838"),
                      extra_install = "install_shiny_server.sh",
                      copy_root = "/srv/shiny-server",
                      min_r_version = "4.0.0")
```

`min_r_version` guards both new modes against R \< 4.0.0 –
`/rocker_scripts/` (and `install_shiny_server.sh` inside it) only exists
in images built from `rocker-versioned2`, which covers R \>= 4.0.0 only;
older tags on the same Docker Hub repos predate that entirely (confirmed
against `rocker-versioned2`’s own README).
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
checks this right after resolving `r_version`, via a new
[`.extract_r_version_prefix()`](https://erwinlares.github.io/containr/reference/dot-extract_r_version_prefix.md)
helper that handles the non-numeric shapes `resolved_version` can take
(`"latest"`, `"devel"`, CUDA/Ubuntu-suffixed strings) before comparing.

`rstudio_shiny`’s `tag_repo` is deliberately `"rocker/rstudio"`, not a
`"rocker/rstudio_shiny"` that doesn’t exist – there’s no separate Docker
Hub repo for the combo, since it’s built by layering an install script
onto `rocker/rstudio`.

Changes to
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md):

- `EXPOSE` block emits one or more ports per `ports` (a single
  `EXPOSE 8787 3838` line for `rstudio_shiny`)
- new conditional RUN block for `extra_install`, structurally like the
  existing `install_quarto` block – for `rstudio_shiny` this is
  `RUN /rocker_scripts/install_shiny_server.sh`, the Rocker project’s
  own documented pattern for layering Shiny Server onto an RStudio
  image, with no manual `.deb` handling needed
- `data_file`/`code_file`/`misc_file` COPY destinations resolve from
  `copy_root` instead of the hardcoded `/home/{.x}` – this also finally
  makes `home_dir` (which currently only drives `WORKDIR`) consistent
  with where files actually land
- new `comments`-only usage hint for `rstudio_shiny`
  (`docker run -p 8787:8787 -p 3838:3838 ...`) alongside the existing
  `rstudio_hint` block

**App directory:** `/srv/shiny-server/` for both new modes, preserving
relative structure exactly the way `/home/` does today
(`code_file = "myapp/app.R"` -\> `/srv/shiny-server/myapp/app.R`) – this
matches Shiny Server’s own default `site_dir /srv/shiny-server;`
configuration, not a convention containr is inventing.

**Open before this phase starts:** confirm
`/rocker_scripts/ install_shiny_server.sh` is present across every R
version `r_ver_exists()` currently accepts, not just the newest tags – a
quick smoke build, not an assumption.

**Also needed:** roxygen (`@param r_mode`, `@param expose_port`, at
least one new `@examples` block), `README.md` (new example(s) in “Core
workflow functions”), `NEWS.md` entry, and updates to
`test-generate-dockerfile-content.R`,
`test-generate-dockerfile-file-args.R`, `test-r-ver-exists.R`, and
`test-r-ver-tags.R` (`FROM rocker/shiny` and
`RUN .../install_shiny_server.sh` assertions, port assertions per mode,
hint-block content, copy-root routing, valid-choices list).

**Sources consulted:** Shiny Server Pro Admin Guide
(docs.posit.co/shiny- server), rocker-versioned2 README and
`install_shiny_server.sh` (github.com/rocker-org/rocker-versioned2),
rocker/shiny image description (rocker-project.org).

------------------------------------------------------------------------

### Phase 3 – tool-resolution cleanup + Layer 3 test backfill

**Status: implemented and verified.** Erwin ran `devtools::test()` and
`devtools::check()` clean on this branch (0 errors, 0 warnings, 0 notes)
after the `tool_preference` redesign and its test coverage landed. Grew
to include the `tool_preference` redesign (open design question 5,
originally deferred beyond v0.2.0 – see below) once Erwin asked to
tackle it in the same sitting as the Phase 3 cleanup, since both touch
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
directly.

[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)’s
auto-detect path already falls through from Podman to Docker correctly –
confirmed by reading `container-helpers.R` directly, not just the
roadmap’s summary of it.
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)’s
own docstring says as much: *“retained for backward compatibility… new
code should rely on
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md),
which incorporates responsiveness checking into tool selection.”* What’s
actually left is smaller than originally scoped:
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
all call `.resolve_tool(tool)` and then immediately call
`.check_tool_responsive(resolved_tool)` again, redundantly re-checking
something
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
already guaranteed. Delete the redundant call in all three files.

Alongside that, backfill the Layer 3 integration tests for
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
and
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
that have been deferred since Session 2 – against today’s surface,
before Phases 4 and 5 add more of it. Same `CONTAINR_INTEGRATION_TESTS`
guard already used for
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
Layer 3 tests.

This is the cheapest, lowest-risk phase in the plan, and doubles as a
checkpoint that Phases 1-2 didn’t disturb tool resolution anywhere.

**`tool_preference` redesign, folded in from the deferred item below.**
`.resolve_tool(tool = NULL)` (single explicit tool, or `NULL` for
hardcoded Podman-then-Docker auto-detect) is replaced by
`.resolve_tool(tool_preference = c("podman", "docker"))` – a non-empty
character vector, tried in order. Length 1 behaves like the old explicit
`tool` argument; length \> 1 is the auto-detect path, now walking
whatever order is supplied instead of a hardcoded `valid_tools`.
`tool = NULL` has no direct equivalent kept: passing `NULL` to
`tool_preference` now fails structural validation (must be non-empty
character, no `NA`) rather than meaning “auto-detect,” since auto-detect
is now expressed by supplying more than one candidate instead of by the
sentinel value `NULL`. Confirmed as an acceptable breaking change under
the same reasoning as `tidystudio` – `containr` is still `0.y.z`.

**Confirmed permissive rather than validated against a fixed tool list**
(Erwin’s call, looking ahead to eventual Apptainer support – deferred to
`0.3.0`, see below): `tool_preference` accepts any string, so adding
`"apptainer"` support later needs no matching validation change here.
The tradeoff:
[`match.arg()`](https://rdrr.io/r/base/match.arg.html)-style rejection
of typos is gone, replaced by the same “not installed” error a
correctly-spelled-but-absent tool would get. Structural validation (must
be a non-empty character vector, no missing values) stays, since that’s
a contract violation rather than a judgment call about which tool names
are legitimate.

**Error messages generalized, not just validation.** A new shared
[`.abort_tool_not_responsive()`](https://erwinlares.github.io/containr/reference/dot-abort_tool_not_responsive.md)
helper keeps Docker’s and Podman’s existing specific troubleshooting
text, and falls back to generic guidance (*“Start the `<tool>` daemon or
service and try again”*) for any other tool name – avoids handing out
Docker-specific `systemctl` instructions for a tool that isn’t Docker,
which permissive validation would otherwise risk doing silently.

**Also renamed:** `tool` -\> `tool_preference` on
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
themselves (not just
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)),
passed straight through. Updated `README.md` and `containr-workflow.Rmd`
where they showed `tool = "docker"` as a usage example – these were left
broken by the rename otherwise, not deferred to Phase 6 like the rest of
the documentation pass.

**Layer 3 backfill, as implemented:**
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
builds a real, tiny `alpine` image (not an R image – these tests
exercise
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
own mechanics, already-covered R install path stays with
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)’s
tests) and cleans it up via
[`on.exit()`](https://rdrr.io/r/base/on.exit.html).
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
test additionally requires two new environment variables,
`CONTAINR_TEST_NETID` and `CONTAINR_TEST_PROJECT`, rather than
hardcoding a destination – pushing to a guessed-at or
documentation-placeholder project (`erwin.lares`/`container-registry`)
risked the test silently landing somewhere it wasn’t actually told to
go. Documented in `on-testing.md` and `CONTRIBUTING.md`.

------------------------------------------------------------------------

### Phase 4 – additional registry support (`ghcr.io`, `quay.io`)

**Status: implemented and verified.** Closing commit
(`fix!: close out Phase 4`) fixed a
`local_mocked_bindings(.package = "jsonlite")` test-mocking issue that
surfaced during Erwin’s first `devtools::check()` run – see
`JOURNAL.md`’s Session 6 entry for the full debugging story, since it
took several rounds to isolate. Confirmed clean afterward: plain
`devtools::check()` (no `NOT_CRAN` override), 0 errors, 0 warnings, 0
notes. `diagrams.qmd` was also brought fully current as part of closing
this phase out – every diagram now reflects `tool_preference`, the
`namespace` rename,
[`.is_logged_in()`](https://erwinlares.github.io/containr/reference/dot-is_logged_in.md)’s
replacement of the raw `--get-login` call, and the current
13-helper/17-function call graph, plus a fix for diagrams rendering with
illegibly dark backgrounds in some renders.

Resolves open design question 2 (registry argument vs. separate
registry-specific functions).

Two concrete findings from reading `push-image.R` directly:

- **The login-check bug is real and precisely located.**
  `system2(resolved_tool, args = c("login", "--get-login", registry), ...)`
  – `--get-login` is a Podman-only flag; under Docker this always
  misbehaves (exit code 125), which is why `check_login = FALSE` exists
  as a workaround today.
- **The destination-path shape already generalizes.**
  `destination <- glue::glue("{registry}/{netid}/{project}:{tag}")` is
  structurally the same three-segment pattern as
  `ghcr.io/OWNER/IMAGE:tag` or `quay.io/ORG/REPO:tag` – confirmed
  against both registries’ actual docs, not assumed. So this isn’t a new
  assembly scheme – it’s the login-check fix, plus the `netid` naming
  decision.

**`netid` -\> `namespace`, no alias.** Settled after weighing two
options: rename with a `lifecycle`-backed deprecation alias, or keep
`netid` and just broaden the documentation. Went with a clean rename,
consistent with `tidystudio` -\> `verse` and `tool` -\>
`tool_preference` earlier this release – same reasoning each time:
`containr` is still `0.y.z`, and a `lifecycle` dependency for one
argument on one function would be the first time this release added that
machinery, for something less central than either of those two prior
renames. `namespace` specifically (not, say, `account` or `owner`)
because it’s the term `ghcr.io`’s own docs use for this exact path
segment (“Replace NAMESPACE with the name of the personal account or
organization…”), not a name containr invented. Also updated
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
tagging-convention docs and examples, and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
cross-referencing example, since both used `<netid>` as illustrative
text even though neither function has a `netid` argument of its own. The
`CONTAINR_TEST_NETID` env var Phase 3 introduced for
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
Layer 3 test was renamed to `CONTAINR_TEST_NAMESPACE` for the same
reason – it was brand new that same session, so there was no real-world
usage to preserve compatibility with.

**Login-check fix, as implemented.** New `.is_logged_in(tool, registry)`
in `container-helpers.R`: Podman keeps its native `--get-login` flag;
Docker (and, permissively, any other `tool_preference` value, matching
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)’s
own permissiveness) falls back to a new
[`.docker_config_has_auth()`](https://erwinlares.github.io/containr/reference/dot-docker_config_has_auth.md)
helper that reads `~/.docker/config.json` directly and checks for a
matching key under `auths` – the standard way tooling checks this, since
Docker has no query subcommand for “am I logged in to X.” Confirmed this
works correctly even when a per-registry `credHelpers` entry is
configured, since `docker login` still writes a marker entry under
`auths` in that case. Acknowledged, not silently glossed over: this
can’t detect a login set up entirely through a global `credsStore` (as
opposed to a per-registry `credHelpers` entry), since Docker defers
entirely to the external store for those without writing anything to
`auths` – a narrow, documented gap. `jsonlite` was already a declared
dependency (used elsewhere in the package), so no new dependency was
needed for the config-file parsing.

**Login guidance generalized alongside the fix, not just the check.**
The pre-push `comments` message and the not-logged-in error both branch
on whether `registry` is the known default: `registry.doit.wisc.edu`
keeps its existing specific PAT-creation instructions (NetID, PAT
scopes, the DoIT auth guide URL); any other registry gets generic
guidance pointing at that registry’s own documentation instead of
DoIT-specific instructions that would be wrong for it. New
`.registry_pat_guidance` lookup in `push-image.R`, mirroring
[`.abort_tool_not_responsive()`](https://erwinlares.github.io/containr/reference/dot-abort_tool_not_responsive.md)’s
known-tool/ generic-fallback pattern from Phase 3.

**Test coverage gap closed.** Before this phase, every existing
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
test used `check_login = FALSE` to bypass the login check entirely –
meaning the `--get-login` bug itself had zero test coverage, at any
layer, before it was ever fixed. Added direct unit tests for
[`.docker_config_has_auth()`](https://erwinlares.github.io/containr/reference/dot-docker_config_has_auth.md)
and
[`.is_logged_in()`](https://erwinlares.github.io/containr/reference/dot-is_logged_in.md),
plus
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)-level
tests exercising `check_login = TRUE` against both the known-registry
and generic-registry guidance branches.

**Also fixed in passing:** a pre-existing typo in
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
top-level roxygen description (“The format for the is
registry.doit.wisc.edu/…”) – likely a leftover from an earlier edit,
unrelated to this phase’s actual scope but caught while touching the
same lines.

**Flagged during this phase, resolved shortly after:** `diagrams.qmd`
(the internal component-diagram reference doc) was found to be stale in
several ways beyond the `netid` rename caught and fixed here – it still
showed `.resolve_tool(tool)` (pre-`tool_preference`), a
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
call Phase 3 removed, and the `--get-login` call this phase just
replaced, including a “known gaps” table that actually predicted this
exact bug and the missing test coverage before either was fixed. Flagged
as a substantial standalone task rather than folded into this rename in
passing – and then done as its own pass shortly after, alongside a fix
for diagrams rendering with illegibly dark backgrounds in some renders.
Both are complete; `diagrams.qmd` reflects the source accurately as of
Phase 4’s completion.

New Layer 3 coverage for `ghcr.io`/`quay.io` themselves (as opposed to
the generalized login-check logic, which is covered) is still open –
`PLAN.md`’s original note about mocking rather than hitting live
registries in CI still applies, and no such tests were added this phase.

------------------------------------------------------------------------

### Phase 5 – GitHub Actions workflow for image builds

**Status: implemented and verified (Session 7).** Triggered manually via
a pull request (`pull_request` was already a configured trigger, and
GitHub’s Actions UI won’t offer `workflow_dispatch` for a workflow that
doesn’t yet exist on the default branch – opening a PR from
`containr-modes-0.2.0` sidesteps that without needing to merge
anything). Checked the actual logs, not just the green checkmark: Podman
resolved cleanly (`arch: amd64`, `rootless: true`, no errors),
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
Layer 3 tests ran real `podman build`/`image ls` commands (visible
`COMMIT containr-test-build-image:...` / `Successfully tagged` lines,
not skips), and
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
Layer 3 test correctly skipped exactly as designed
(`Reason: Set CONTAINR_TEST_NAMESPACE and CONTAINR_TEST_PROJECT...`)
rather than either running unintentionally or failing.
`failed: 0 errors: 0` across the whole suite. The one thing flagged as
genuinely unverified after implementation – whether Podman would
actually work cleanly on GitHub’s runner – is now confirmed, not
assumed.

**Renumbered from Phase 6.** Apptainer support (previously this
section’s Phase 5) is deferred beyond `0.2.0` entirely – see
`## Deferred beyond v0.2.0` below for the full reasoning and everything
scoped so far. This phase now runs directly after Phase 4 rather than
waiting on a Phase 5 that won’t exist in this release.

Confirmed there’s no existing workflow that builds or pushes container
images – the four in `.github/workflows/` (`R-CMD-check.yaml`,
`pkgdown.yaml`, `test-coverage.yaml`, `rhub.yaml`) are all R-package
testing infrastructure, untouched by this phase.

**Resolved open design question 4, which turned out to have two
genuinely different answers hiding inside it, not one.** Discussed
explicitly with Erwin before writing anything:

- **Path A – a CI workflow that runs `containr`’s own Layer 3
  integration tests** (the ones Phase 3 added, gated behind
  `CONTAINR_INTEGRATION_TESTS=true`, which had never run anywhere except
  manually on a developer’s own machine). Lives in `containr`’s own
  `.github/workflows/`. Closes a real, existing coverage gap.
- **Path B – a template workflow for `containr` users’ own projects**,
  directly solving the actual Session 4 QEMU incident (build natively on
  a GitHub-hosted `x86_64` runner instead of cross-compiling from Apple
  Silicon). Three nested sub-decisions of its own (plain shell commands
  vs. calling
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)/[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  via R; docs-only vs. a shipped `inst/templates/` file vs. a new
  exported `use_github_actions_workflow()`-style function) –
  underspecified enough, and different enough in shape from Path A, that
  it deserves its own scoping pass rather than being decided in passing
  here.

**Decided: Path A now, Path B deferred to Phase 6 (the docs pass) or its
own pass** – reasoning being that Path B is fundamentally a
documentation-shaped feature (teaching users a workflow) regardless of
which of its three sub-options it lands on, and a template built on top
of never-automated-in-CI build/push logic is building confidence on an
unverified foundation. Closing Path A’s gap first, while still in active
development where a caught regression costs minutes rather than becoming
a researcher’s support issue after `0.2.0` ships, is the better
ordering.

**Path A, as implemented:** new
`.github/workflows/ container-integration-tests.yaml`. Installs Podman
on `ubuntu-latest` (natively `x86_64`, so
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
tests never hit the Session 4 QEMU problem – there’s no architecture
mismatch to cross-compile for), sets `CONTAINR_INTEGRATION_TESTS=true`,
and runs `devtools::test()`. Triggered on push/PR to `main`/`master`,
path-filtered to only the files that actually matter for this
(`build-image.R`, `push-image.R`, `list-images.R`,
`container-helpers.R`, `test-container-workflow.R`, the workflow file
itself), plus `workflow_dispatch` for manual runs.
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)’s
and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
Layer 3 tests both run this way, since both only need Podman locally, no
external credentials.

**[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
Layer 3 test deliberately does not run here.** It additionally requires
`CONTAINR_TEST_NAMESPACE` and `CONTAINR_TEST_PROJECT` (from Phase 3),
which this workflow intentionally leaves unset – that test needs a live
registry login and pushes a real, if throwaway, image to a real
destination on every run. That’s a separate operational decision (a real
credential sitting in this repo’s GitHub secrets, a live external side
effect on every push) from the build-only coverage this phase adds, and
wasn’t bundled in by default.

**A real bug caught before it shipped, not assumed away:**
`devtools::test()` does **not** exit non-zero on test failure by itself
– verified this directly in a throwaway package with a deliberately
failing test before writing the workflow’s actual test-running step,
since a CI job that silently reports green regardless of test outcome
would have defeated the entire point of Path A. Fixed by explicitly
checking `as.data.frame(results)$failed`/`$error` and calling
`quit(status = 1)` if either is nonzero – verified both directions (a
failing test now exits 1, a passing suite still exits 0) before
considering this done.

**Not independently verified:** whether `apt-get install podman` on
GitHub’s `ubuntu-latest` runner actually produces a working rootless
Podman without additional configuration. This is a reasonable, common
pattern, but wasn’t (and can’t be, from this environment) confirmed by
actually triggering the workflow on GitHub’s own infrastructure – that’s
the real verification step still outstanding, on Erwin’s side.

------------------------------------------------------------------------

### Phase 6 – documentation and release pass

`README.md`, both vignettes (`containr-workflow.Rmd`,
`why-containers.Rmd`), a consolidated `NEWS.md` entry covering the whole
`0.2.0` release, and `inst/WORDLIST` additions (`shiny_server`, `ghcr`,
`quay` will all trip
[`spelling::spell_check_package()`](https://docs.ropensci.org/spelling//reference/spell_check_package.html)
otherwise – `Apptainer`/`Singularity` dropped from this list along with
the rest of that work, now deferred to `0.3.0`; see below). Then the
standard release cycle: `devtools::document()` -\> `devtools::test()`
-\> `devtools::check()` -\> `devtools::submit_cran()`, followed by
`usethis::use_github_release()` -\>
`usethis::use_dev_version(push = TRUE)`.

**“Path B” – decided and implemented (Session 8).** A GitHub Actions
template for `containr` *users’* own projects, directly solving the
Session 4 QEMU incident by building on a native `x86_64` GitHub-hosted
runner instead of cross-compiling locally. Both of the sub-questions
this was left with at the end of Phase 5 are now resolved:

1.  **R-based, not plain shell commands.** Erwin’s own framing was the
    deciding argument: `containr`’s whole design premise is that a
    researcher never has to leave R to containerize their work – a
    shell-based template would be the one place in the entire
    user-facing surface that broke that promise, at exactly the moment
    (debugging CI) a researcher is least equipped to troubleshoot YAML
    and shell instead of R. Calling
    [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)/[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
    directly from the template also means it inherits any future fix to
    those functions automatically, rather than a hand-written shell
    equivalent quietly drifting out of sync as `containr` changes – a
    real correctness risk given this project’s reproducibility goal.
2.  **Shipped template file, not docs-only or a new function –
    `use_github_actions_workflow()`-style function explicitly flagged
    for `0.3.0`, not left as a vague “maybe someday.”** A template users
    copy manually gets real, correct value in front of them without the
    added scope and testing burden a new exported function would add
    this close to release. Recorded here explicitly, alongside the
    already-deferred Apptainer work, so it doesn’t quietly vanish from
    the roadmap the way “deferred” items can when they only exist in
    someone’s head.

**Assumes the user’s `Dockerfile` is already built and committed** –
this template does not call
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
to regenerate it from `renv.lock`. If dependencies change, the user
re-runs
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
locally and commits the result, the same way they would for any other
generated file. This was a deliberate scoping choice (Erwin’s call) to
keep the template’s job narrow – build and push what’s already there,
not also own regeneration.

**As implemented:** `inst/templates/build-and-push.yaml`, following R
package convention for shipping non-R auxiliary files (alongside
`inst/extdata/install_and_restore_packages.sh`, `inst/CITATION`). Runs
on `ubuntu-latest` (native `x86_64`, same reasoning as Phase 5’s own
workflow – no QEMU emulation possible when host and target architecture
match), installs Podman and `containr` from CRAN, logs in via a
`podman login` step reading two repository secrets
(`REGISTRY_USERNAME`/`REGISTRY_PASSWORD`, generic enough to work for
`registry.doit.wisc.edu`, `ghcr.io`, or `quay.io` – login mechanics
don’t differ by registry), then calls
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
followed by
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)/[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
– the exact idiom already documented in
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)’s
own `@section Finding your image ID:`, not a new pattern invented for
this template. Tags the pushed image with `github.sha` rather than
`"latest"`, matching
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)’s
own warning about that default. Four `env:` values (`REGISTRY`,
`NAMESPACE`, `PROJECT`, plus the `Dockerfile` path in the trigger’s
`paths:` filter) are the only things a user needs to customize, called
out explicitly in both the file’s own header comment and inline
`# CUSTOMIZE` markers.

**Not yet done:** documenting this template in the vignette (the
“docs-only” delivery option that was considered and set aside in favor
of a shipped file is still the right *complement* to a shipped file, not
an alternative to it – a template with nowhere pointing to it is hard to
discover). Folds into this phase’s existing vignette work rather than
being a separate task.

------------------------------------------------------------------------

### Deferred beyond v0.2.0

Three items from the original roadmap that aren’t part of this round and
don’t block anything above:

- **`containerize()` convenience wrapper** (open design question 1) –
  doesn’t touch `r_mode` or anything else in this plan; fine to pick up
  independently whenever.
- **Apptainer support** (previously Phase 5) – see below. Targeting
  `0.3.0`, not `0.2.1`: this is a genuine new capability, not a
  backward-compatible fix, so it warrants a real minor bump under the
  same semver reasoning that put the current release at `0.2.0` rather
  than `0.1.4` in the first place.
- **A `use_github_actions_workflow()`-style function** (Erwin’s call,
  Session 8), wrapping `inst/templates/build-and-push.yaml`’s manual
  copy step the way `usethis::use_github_action()` does for its own
  templates. `0.2.0` ships the shipped-template version of “Path B” (see
  Phase 6); this is the natural next increment on top of it, not a
  replacement – targeting `0.3.0` alongside Apptainer support, same
  semver reasoning.

[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)’s
preference-order argument (open design question 5), previously listed
here, is no longer deferred – implemented as part of Phase 3 above,
since Erwin asked to tackle it alongside the Phase 3 cleanup rather than
hold it for later.

------------------------------------------------------------------------

### Apptainer support (deferred to `0.3.0`)

**Deferred, not abandoned.** Decided against building this now for two
reasons. First, Erwin wants to read more before committing to a design.
Second, and more concretely: CHTC operates a genuinely separate HPC
cluster (SLURM-based, `spark-login.chtc.wisc.edu`) distinct from the HTC
pool `submitr` currently targets (its own function names –
`htc_gen_submit()`, `htc_submit()` – are HTCondor-specific, the HTC
pool’s scheduler). Docker/Podman aren’t available on SLURM-based HPC
clusters generally – confirmed across multiple institutions’ own docs
(Michigan, Utah, Harvard, several DoD HPC centers), not assumed from one
source – so Apptainer is effectively required there, not just an option.
Apptainer is *also* usable on CHTC’s HTC pool via HTCondor’s container
universe, but Docker already works fine there today, which is exactly
what `containr` already supports. Net effect: building Apptainer
generation now would produce a feature `submitr` has no pipeline to
actually consume, since it doesn’t submit to the SLURM cluster at all
yet.

**Terminology decision: `containr` will say “Apptainer,” not
“Singularity,” throughout.** Matches CHTC’s own current documentation,
which consistently leads with “Apptainer” and treats Singularity as the
superseded name (*“HTCondor supports the use of Apptainer (formerly
known as Singularity)”*) – Singularity is now Sylabs’ commercial
SingularityCE, Apptainer is the open Linux Foundation-governed fork.
Briefly considered “Singularity” instead (Erwin’s first instinct, on the
reasoning that it’s still the more widely-recognized umbrella term
across the broader HPC world, and some other institutions’ docs do still
lead with it) but reversed after double-checking against CHTC
specifically – “Apptainer” is more current for the actual target
platform, which is the reasoning that should win. Logged here so a
future session doesn’t re-litigate a decision that’s already settled
either direction.

**Three open questions, not one – confirmed against CHTC’s and OSPool’s
own documentation rather than assumed from the tool’s general
reputation. Numbering kept as originally scoped, since (3) is now
answered:**

1.  **Where does the build actually happen?** CHTC’s own guidance for
    converting a Docker image to a `.sif` file doesn’t run locally –
    it’s an *interactive HTCondor job*, submitted via `condor_submit -i`
    against a `build.sub` file, run on CHTC’s own infrastructure. A
    local `apptainer build my.sif docker://...` wrapper (mirroring
    [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
    small effort) only serves someone who has Apptainer installed on
    their own machine – true for some HPC/Linux-workstation users, not
    the typical CHTC-via-laptop researcher this package otherwise
    targets. Generating the CHTC-side submit file instead is a
    different, more integration-heavy shape of feature, and arguably
    edges into `submitr`’s territory (job submission) rather than
    staying inside `containr`’s own scope (containerization) – and would
    need `submitr` to support the HPC/SLURM cluster at all first, which
    it doesn’t yet. **Still open.**
2.  **Pull/convert vs. native `.def` generation** – the fork this
    section originally flagged, now sharper given (1). Pull/convert
    (whichever shape (1) resolves to) stays small. Native `.def` file
    generation is a second, parallel recipe format alongside
    `Dockerfile` – resolving open design question 3 (a `format` argument
    on
    [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md))
    – and duplicates a meaningful fraction of what
    [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
    already does, in a different syntax. Substantially larger regardless
    of how (1) resolves. **Still open.**
3.  **If native `.def` generation happens, which base images? –
    decided.** Follow OSG’s guidance:
    `hub.opensciencegrid.org/htc/{debian,rocky, ubuntu}`, not `rocker/*`
    (Erwin’s call). This doesn’t force a break with `.r_mode_registry`
    if that path is ever built, since Apptainer’s `Bootstrap: docker`
    directive can still pull Rocker images directly the same way
    `docker pull`/`podman pull` do – but the deliberate choice here is
    the OSG-recommended bases specifically, likely better-tuned for
    CHTC/OSPool, accepting a second base-image mapping alongside
    `.r_mode_registry` as the cost.

Once (1) and (2) are decided, the entry point for the smaller shape is
adding `"apptainer"` as a candidate in `tool_preference`’s default –
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
itself needs no change, since it already accepts any tool name (Phase
3’s `tool_preference` redesign was deliberately permissive with exactly
this in mind); for native `.def` generation it’s a `format` argument
plus a sibling code path to the existing `lines` list construction in
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md).

**Sources consulted:** HTCondor’s own Apptainer/Singularity support docs
(htcondor.readthedocs.io), CHTC’s Apptainer-in-HTC-jobs,
Docker-to-Apptainer-conversion, and HPC-cluster-overview guides
(chtc.cs.wisc.edu), and OSPool’s container-building documentation
(portal.osg-htc.org) – all fetched directly, not recalled from general
knowledge of the tool.
