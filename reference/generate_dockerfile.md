# Generate a reproducible Dockerfile for an R project

`generate_dockerfile()` inspects an R project's dependencies via an
`renv` lockfile and writes a ready-to-use `Dockerfile` to the specified
output directory. It supports multiple Rocker base images, automatic
system library detection, Quarto installation, file copying, user
creation, and inline documentation comments.

## Usage

``` r
generate_dockerfile(
  r_version = "current",
  r_mode = "base",
  auto_syslibs = TRUE,
  install_syslibs = NULL,
  output = ".",
  data_file = NULL,
  code_file = NULL,
  misc_file = NULL,
  add_user = NULL,
  home_dir = "/home",
  expose_port = "8787",
  install_quarto = FALSE,
  quarto_version = "latest",
  os_version = NULL,
  comments = FALSE,
  verbose = FALSE,
  config = NULL
)
```

## Arguments

- r_version:

  A character string specifying the R version to use, e.g. `"4.3.0"`.
  Defaults to `"current"`, which resolves to the version of R running in
  the current session.

- r_mode:

  A character string selecting the Rocker base image. Inspired by the
  [Rocker Project](https://rocker-project.org/). One of `"base"` for
  plain R, `"tidyverse"` for R with the tidyverse, `"rstudio"` for
  RStudio Server, `"verse"` for tidyverse plus TeX Live and
  publishing-related packages, `"shiny_server"` for serving Shiny apps,
  or `"rstudio_shiny"` for RStudio Server with Shiny Server layered on
  top. Defaults to `"base"`.

- auto_syslibs:

  Logical. If `TRUE` (the default), reads `renv.lock` from the current
  working directory, queries the Posit Package Manager sysreqs database
  via
  [`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html),
  and automatically includes the system libraries required by all
  packages in the lock file. Warns and continues without auto-detection
  if the lookup fails. Set to `FALSE` to skip auto-detection entirely.

- install_syslibs:

  A character vector or `NULL`. Additional system libraries to install
  beyond those auto-detected from `renv.lock`. Each element should be a
  valid `apt` package name, e.g. `c("libuv1-dev", "libwebp-dev")`.
  Defaults to `NULL`.

- output:

  A character string. Directory path where the `Dockerfile` will be
  written. Defaults to `"."`, the current working directory – the same
  directory
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  treats as the build context by default, so the two functions' defaults
  compose without either argument having to be supplied. A `Dockerfile`
  written somewhere else
  ([`tempdir()`](https://rdrr.io/r/base/tempfile.html), say) would have
  to be moved into the build context before
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  could find it, since the build context is always
  [`getwd()`](https://rdrr.io/r/base/getwd.html). `output` is created
  automatically, along with any missing parent directories, if it does
  not already exist.

- data_file:

  A character vector or `NULL`. Path(s) to data file(s) and/or
  directories to copy into the container – a single path, a vector of
  paths, or a directory (copied whole, with its contents) may all be
  mixed freely in the same vector. The local directory structure is
  preserved under `home_dir` for `"base"`, `"tidyverse"`, `"rstudio"`,
  and `"verse"` (e.g. with the default `home_dir = "/home"`,
  `"data-raw/sample.csv"` becomes `/home/data-raw/sample.csv`, and a
  directory `"data-raw/"` is copied to `/home/data-raw/` in full), or
  under `/srv/shiny-server/` for `"shiny_server"` and `"rstudio_shiny"`,
  matching Shiny Server's own default app directory regardless of
  `home_dir`. Every path must be inside the current working directory
  (the build context). Defaults to `NULL`.

- code_file:

  A character vector or `NULL`. Path(s) to script file(s) (e.g. `.R`,
  `.qmd`, `.rmd`) and/or directories to copy into the container – see
  `data_file` for vector and directory behavior. The local directory
  structure is preserved under the mode's copy root (`home_dir` for four
  of the six modes) – see `data_file`. Every path must be inside the
  current working directory. Defaults to `NULL`.

- misc_file:

  A character vector or `NULL`. Path(s) to miscellaneous file(s) (e.g.
  images, shell scripts, or branding assets) and/or directories to copy
  into the container – see `data_file` for vector and directory
  behavior. The local directory structure is preserved under the mode's
  copy root (`home_dir` for four of the six modes) – see `data_file`.
  Every path must be inside the current working directory. Defaults to
  `NULL`. If the project was scaffolded with `toolero::init_project()`
  using `branding = TRUE` or `branding = "uw-madison"`, the generated
  `.qmd` will reference `assets/styles.css`, `assets/header.html`, and
  `assets/footer.html` at render time. Those files must be present
  inside the container or Quarto will error on render. Pass
  `misc_file = "assets/"` to copy the entire branding folder in one
  step. Additional files and directories can be combined freely in the
  same vector, e.g. `misc_file = c("assets/", "extra-script.sh")`.

- add_user:

  A character string. Name of a Linux user to create inside the
  container with sudo access. Defaults to `NULL`.

- home_dir:

  A character string. The working directory set inside the container via
  `WORKDIR`. For `"base"`, `"tidyverse"`, `"rstudio"`, and `"verse"`,
  this is also where `data_file`, `code_file`, and `misc_file` are
  copied (C24) – there is nowhere else a script running from `WORKDIR`
  could resolve its relative paths against. `"shiny_server"` and
  `"rstudio_shiny"` are the exception: their copy destination is fixed
  at `/srv/shiny-server` regardless of `home_dir` – see `data_file`.
  Defaults to `"/home"`.

- expose_port:

  A character string. Overrides the port exposed when `r_mode` is
  `"rstudio"`. Defaults to `"8787"`. Ignored for every other `r_mode` –
  `"shiny_server"` and `"rstudio_shiny"` expose their own fixed port(s)
  (`"3838"`, and `"8787"`/`"3838"` respectively), since a single
  override value can't address more than one port.

- install_quarto:

  Logical. If `TRUE`, downloads and installs the Quarto CLI inside the
  container. Defaults to `FALSE`. See `quarto_version` to pin a specific
  release rather than always installing whatever is currently latest.

- quarto_version:

  Character string. Either `"latest"` (the default) or an explicit
  Quarto version, e.g. `"1.5.57"`. Ignored unless
  `install_quarto = TRUE`. When `"latest"`, the actual version is
  resolved at generation time via the Quarto releases API and recorded
  in the generated `Dockerfile` as `ENV QUARTO_VERSION=...`, so a later
  rebuild from the same `Dockerfile` reproduces the same Quarto version
  rather than whatever happens to be current at build time – consistent
  with how `r_version` and `renv.lock` are pinned elsewhere in the
  image. An explicit version is validated against the Quarto releases
  API and errors if no matching release exists.

- os_version:

  A character string or `NULL`. The Ubuntu version to query against when
  looking up system requirements for `auto_syslibs` (C14). When `NULL`
  (the default), it is derived from the resolved `r_version` via the
  Rocker Project's own R-version-to-Ubuntu-release mapping – see
  [`.resolve_os_version()`](https://erwinlares.github.io/containr/reference/dot-resolve_os_version.md)
  – rather than left at a single hardcoded value that only matched the
  Ubuntu release actually backing some R versions and not others.
  Supplying a value overrides the derivation entirely, for a project
  that needs to query against a different Ubuntu release than the one
  its `r_version` would normally resolve to. Ignored when
  `auto_syslibs = FALSE`, since no sysreqs lookup happens in that case.

- comments:

  Logical. If `TRUE`, annotates each Dockerfile instruction with an
  explanatory comment, written on the line above the instruction it
  describes. Useful for learning or sharing. Defaults to `FALSE`. Note
  (C15): this is the one `comments` argument in the family that writes
  into a generated file rather than printing to the console –
  [`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
  and
  [`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
  in this same package, and every `comments` argument in `submitr`, use
  it to print explanatory guidance to the console instead. Keep that
  distinction in mind when moving between these functions. The
  comment-then-instruction ordering matches `submitr`'s own generated
  `.sh` and `.sub` files (S09), so a reader moving between a generated
  Dockerfile and a submitr-generated script reads both the same way
  round: explanation first, instruction second.

- verbose:

  Logical. If `TRUE`, prints progress messages as each section of the
  Dockerfile is written. Defaults to `FALSE`.

- config:

  A character string. Path to a `_toolero.yml` project manifest, such as
  the one `toolero::init_project()` writes. When supplied, fills in
  `data_file`, `code_file`, and `misc_file` from the manifest's declared
  `folders:` – but only an argument left at its own `NULL` default. An
  argument you do supply always wins; `config` never overrides an
  explicit call. `code_file` is derived from the folder named by the
  manifest's `script_dir` convention (`"R"` by default) when that folder
  is present; `misc_file` is derived from `"assets"` when present, the
  branding folder `init_project(branding = ...)` creates; `data_file` is
  derived from `"data-raw"` when present, the folder this family's own
  documentation uses as the canonical home for input data – there is no
  dedicated manifest key naming it, so this one is `containr`'s own
  convention rather than something the file states explicitly. Reading
  `_toolero.yml` is not a dependency on `toolero`: the schema is the
  contract, and a manifest written by hand is as valid an input as one
  `init_project()` created. In `verbose` mode, reports which of
  `data_file`, `code_file`, and `misc_file` came from `config` rather
  than from the call, since a generated `Dockerfile` whose `COPY` lines
  came from somewhere invisible to the caller undermines the
  reproducibility this package exists to support. A `schema_version` the
  file does not declare is treated as schema `1`; any other declared
  value produces a warning, not an abort, and the file is still read on
  a best-effort basis either way. When supplied, `config` also adds a
  `RUN mkdir -p` instruction, right after `WORKDIR`, creating every
  folder the manifest's `folders:` declares under `home_dir` (C07) – so
  a script's first write into one of them (via `toolero::save_output()`,
  or a bare
  `ggsave()`/[`write.csv()`](https://rdrr.io/r/utils/write.table.html)
  call) does not fail the way it would on a fresh checkout with no
  `config` supplied. This is unconditional on which folders those are; a
  folder this version of `containr` has no other special meaning for is
  still created. Defaults to `NULL`, so nothing about this argument
  changes the behavior of a call that does not use it.

## Value

Called for its side effects. Writes a `Dockerfile` to `output`. Returns
`invisible(NULL)`.

## Prerequisites

`generate_dockerfile()` requires an `renv.lock` file in the current
working directory. Create one with
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
before calling this function. If the lock file is out of sync with your
project library, a warning is issued – run
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
to update it before building the image.

If the project uses Quarto with branding assets (i.e.
`toolero::create_qmd()` was called with `use_style = TRUE`), the
`assets/` folder must be copied into the container alongside the `.qmd`
file or Quarto will be unable to resolve the CSS and HTML includes at
render time. The simplest way to ensure this is to pass
`misc_file = "assets/"` – or `misc_file = c("assets/", other_files)` if
additional files are needed – when calling `generate_dockerfile()`. No
code change is required; `misc_file` already accepts directories and
copies them whole.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires renv.lock in the current working directory.
# Run renv::snapshot() first if you don't have one.

# Generate a minimal Dockerfile using a pinned R version. output defaults
# to ".", so this writes to the current working directory -- the same
# place build_image() looks by default.
generate_dockerfile(r_version = "4.4.0")

# Pin a specific R version with the tidyverse image
generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse")

# Add extra system libraries on top of auto-detected ones
generate_dockerfile(
  r_version       = "4.4.0",
  install_syslibs = c("libuv1-dev", "libwebp-dev"),
  output          = "."
)

# Include a data file -- directory structure is preserved in the container
generate_dockerfile(
  r_version = "4.3.0",
  data_file = "data-raw/penguins.csv",
  code_file = "analysis.R",
  comments  = TRUE,
  output    = "."
)

# Multiple scripts and a whole assets folder -- pass assets/ via misc_file
# so that branding files (styles.css, header.html, footer.html) are present
# inside the container when Quarto renders the .qmd
generate_dockerfile(
  r_version = "4.3.0",
  code_file = c("R/prepare.R", "R/model.R"),
  misc_file = "assets/",
  output    = "."
)

# Serve a Shiny app -- files land under /srv/shiny-server/ automatically
generate_dockerfile(
  r_version = "4.3.0",
  r_mode    = "shiny_server",
  code_file = "app.R",
  output    = "."
)

# RStudio Server plus Shiny Server in the same image
generate_dockerfile(
  r_version = "4.3.0",
  r_mode    = "rstudio_shiny",
  code_file = "app.R",
  output    = "."
)

# Install Quarto, pinned to a specific release rather than whatever is
# currently latest -- the resolved version is recorded as
# ENV QUARTO_VERSION in the generated Dockerfile either way
generate_dockerfile(
  r_version      = "4.3.0",
  install_quarto = TRUE,
  quarto_version = "1.5.57",
  output         = "."
)

# Fill in data_file, code_file, and misc_file from a toolero project
# manifest instead of retyping paths the project already declares
generate_dockerfile(
  r_version = "4.3.0",
  config    = "_toolero.yml",
  output    = "."
)
} # }
```
