#' Generate a reproducible Dockerfile for an R project
#'
#' `generate_dockerfile()` inspects an R project's dependencies via an `renv`
#' lockfile and writes a ready-to-use `Dockerfile` to the specified output
#' directory. It supports multiple Rocker base images, automatic system
#' library detection, Quarto installation, file copying, user creation, and
#' inline documentation comments.
#'
#' @param r_version A character string specifying the R version to use, e.g.
#'   `"4.3.0"`. Defaults to `"current"`, which resolves to the version of R
#'   running in the current session.
#' @param r_mode A character string selecting the Rocker base image. Inspired
#'   by the [Rocker Project](https://rocker-project.org/). One of `"base"` for
#'   plain R, `"tidyverse"` for R with the tidyverse, `"rstudio"` for RStudio
#'   Server, `"verse"` for tidyverse plus TeX Live and publishing-related
#'   packages, `"shiny_server"` for serving Shiny apps, or `"rstudio_shiny"`
#'   for RStudio Server with Shiny Server layered on top. Defaults to
#'   `"base"`.
#' @param auto_syslibs Logical. If `TRUE` (the default), reads `renv.lock`
#'   from the current working directory, queries the Posit Package Manager
#'   sysreqs database via `remotes::system_requirements()`, and automatically
#'   includes the system libraries required by all packages in the lock file.
#'   Warns and continues without auto-detection if the lookup fails. Set to
#'   `FALSE` to skip auto-detection entirely.
#' @param install_syslibs A character vector or `NULL`. Additional system
#'   libraries to install beyond those auto-detected from `renv.lock`. Each
#'   element should be a valid `apt` package name, e.g.
#'   `c("libuv1-dev", "libwebp-dev")`. Defaults to `NULL`.
#' @param output A character string. Directory path where the `Dockerfile`
#'   will be written. Defaults to `"."`, the current working directory --
#'   the same directory `build_image()` treats as the build context by
#'   default, so the two functions' defaults compose without either
#'   argument having to be supplied. A `Dockerfile` written somewhere else
#'   (`tempdir()`, say) would have to be moved into the build context before
#'   `build_image()` could find it, since the build context is always
#'   `getwd()`. `output` is created automatically, along with any missing
#'   parent directories, if it does not already exist.
#' @param data_file A character vector or `NULL`. Path(s) to data file(s)
#'   and/or directories to copy into the container -- a single path, a
#'   vector of paths, or a directory (copied whole, with its contents) may
#'   all be mixed freely in the same vector. The local directory structure
#'   is preserved under `home_dir` for `"base"`, `"tidyverse"`, `"rstudio"`,
#'   and `"verse"` (e.g. with the default `home_dir = "/home"`,
#'   `"data-raw/sample.csv"` becomes `/home/data-raw/sample.csv`, and a
#'   directory `"data-raw/"` is copied to `/home/data-raw/` in full), or
#'   under `/srv/shiny-server/` for `"shiny_server"` and `"rstudio_shiny"`,
#'   matching Shiny Server's own default app directory regardless of
#'   `home_dir`. Every path must be inside the current working directory
#'   (the build context). Defaults to `NULL`.
#' @param code_file A character vector or `NULL`. Path(s) to script file(s)
#'   (e.g. `.R`, `.qmd`, `.rmd`) and/or directories to copy into the
#'   container -- see `data_file` for vector and directory behavior. The
#'   local directory structure is preserved under the mode's copy root
#'   (`home_dir` for four of the six modes) -- see `data_file`. Every path
#'   must be inside the current working directory. Defaults to `NULL`.
#' @param misc_file A character vector or `NULL`. Path(s) to miscellaneous
#'   file(s) (e.g. images, shell scripts, or branding assets) and/or
#'   directories to copy into the container -- see `data_file` for vector
#'   and directory behavior. The local directory structure is preserved
#'   under the mode's copy root (`home_dir` for four of the six modes) --
#'   see `data_file`. Every path must be inside the current working
#'   directory. Defaults to `NULL`.
#'   If the project was scaffolded with [toolero::init_project()] using
#'   `branding = TRUE` or `branding = "uw-madison"`, the generated `.qmd`
#'   will reference `assets/styles.css`, `assets/header.html`, and
#'   `assets/footer.html` at render time. Those files must be present inside
#'   the container or Quarto will error on render. Pass
#'   `misc_file = "assets/"` to copy the entire branding folder in one step.
#'   Additional files and directories can be combined freely in the same
#'   vector, e.g. `misc_file = c("assets/", "extra-script.sh")`.
#' @param add_user A character string. Name of a Linux user to create inside
#'   the container with sudo access. Defaults to `NULL`.
#' @param home_dir A character string. The working directory set inside the
#'   container via `WORKDIR`. For `"base"`, `"tidyverse"`, `"rstudio"`, and
#'   `"verse"`, this is also where `data_file`, `code_file`, and `misc_file`
#'   are copied (C24) -- there is nowhere else a script running from
#'   `WORKDIR` could resolve its relative paths against. `"shiny_server"`
#'   and `"rstudio_shiny"` are the exception: their copy destination is
#'   fixed at `/srv/shiny-server` regardless of `home_dir` -- see
#'   `data_file`. Defaults to `"/home"`.
#' @param expose_port A character string. Overrides the port exposed when
#'   `r_mode` is `"rstudio"`. Defaults to `"8787"`. Ignored for every other
#'   `r_mode` -- `"shiny_server"` and `"rstudio_shiny"` expose their own
#'   fixed port(s) (`"3838"`, and `"8787"`/`"3838"` respectively), since a
#'   single override value can't address more than one port.
#' @param install_quarto Logical. If `TRUE`, downloads and installs the Quarto
#'   CLI inside the container. Defaults to `FALSE`. See `quarto_version` to
#'   pin a specific release rather than always installing whatever is
#'   currently latest.
#' @param quarto_version Character string. Either `"latest"` (the default) or
#'   an explicit Quarto version, e.g. `"1.5.57"`. Ignored unless
#'   `install_quarto = TRUE`. When `"latest"`, the actual version is resolved
#'   at generation time via the Quarto releases API and recorded in the
#'   generated `Dockerfile` as `ENV QUARTO_VERSION=...`, so a later rebuild
#'   from the same `Dockerfile` reproduces the same Quarto version rather
#'   than whatever happens to be current at build time -- consistent with
#'   how `r_version` and `renv.lock` are pinned elsewhere in the image. An
#'   explicit version is validated against the Quarto releases API and
#'   errors if no matching release exists.
#' @param os_version A character string or `NULL`. The Ubuntu version to
#'   query against when looking up system requirements for `auto_syslibs`
#'   (C14). When `NULL` (the default), it is derived from the resolved
#'   `r_version` via the Rocker Project's own R-version-to-Ubuntu-release
#'   mapping -- see `.resolve_os_version()` -- rather than left at a single
#'   hardcoded value that only matched the Ubuntu release actually backing
#'   some R versions and not others. Supplying a value overrides the
#'   derivation entirely, for a project that needs to query against a
#'   different Ubuntu release than the one its `r_version` would normally
#'   resolve to. Ignored when `auto_syslibs = FALSE`, since no sysreqs
#'   lookup happens in that case.
#' @param comments Logical. If `TRUE`, annotates each Dockerfile instruction
#'   with an explanatory comment, written on the line above the instruction
#'   it describes. Useful for learning or sharing. Defaults to `FALSE`.
#'   Note (C15): this is the one `comments` argument in the family that
#'   writes into a generated file rather than printing to the console --
#'   [build_image()] and [push_image()] in this same package, and every
#'   `comments` argument in `submitr`, use it to print explanatory guidance
#'   to the console instead. Keep that distinction in mind when moving
#'   between these functions. The comment-then-instruction ordering matches
#'   `submitr`'s own generated `.sh` and `.sub` files (S09), so a reader
#'   moving between a generated Dockerfile and a submitr-generated script
#'   reads both the same way round: explanation first, instruction second.
#' @param verbose Logical. If `TRUE`, prints progress messages as each section
#'   of the Dockerfile is written. Defaults to `FALSE`.
#' @param config A character string. Path to a `_toolero.yml` project
#'   manifest, such as the one [toolero::init_project()] writes. When
#'   supplied, fills in `data_file`, `code_file`, and `misc_file` from the
#'   manifest's declared `folders:` -- but only an argument left at its own
#'   `NULL` default. An argument you do supply always wins; `config` never
#'   overrides an explicit call. `code_file` is derived from the folder
#'   named by the manifest's `script_dir` convention (`"R"` by default) when
#'   that folder is present; `misc_file` is derived from `"assets"` when
#'   present, the branding folder `init_project(branding = ...)` creates;
#'   `data_file` is derived from `"data-raw"` when present, the folder this
#'   family's own documentation uses as the canonical home for input data --
#'   there is no dedicated manifest key naming it, so this one is
#'   `containr`'s own convention rather than something the file states
#'   explicitly. Reading `_toolero.yml` is not a dependency on `toolero`: the
#'   schema is the contract, and a manifest written by hand is as valid an
#'   input as one `init_project()` created. In `verbose` mode, reports which
#'   of `data_file`, `code_file`, and `misc_file` came from `config` rather
#'   than from the call, since a generated `Dockerfile` whose `COPY` lines
#'   came from somewhere invisible to the caller undermines the
#'   reproducibility this package exists to support. A `schema_version` the
#'   file does not declare is treated as schema `1`; any other declared
#'   value produces a warning, not an abort, and the file is still read on a
#'   best-effort basis either way. When supplied, `config` also adds a
#'   `RUN mkdir -p` instruction, right after `WORKDIR`, creating every
#'   folder the manifest's `folders:` declares under `home_dir` (C07) --
#'   so a script's first write into one of them (via
#'   `toolero::save_output()`, or a bare `ggsave()`/`write.csv()` call)
#'   does not fail the way it would on a fresh checkout with no `config`
#'   supplied. This is unconditional on which folders those are; a folder
#'   this version of `containr` has no other special meaning for is still
#'   created. Defaults to `NULL`, so nothing about this argument changes
#'   the behavior of a call that does not use it.
#'
#' @return Called for its side effects. Writes a `Dockerfile` to `output`.
#'   Returns `invisible(NULL)`.
#'
#' @section Prerequisites:
#' `generate_dockerfile()` requires an `renv.lock` file in the current working
#' directory. Create one with `renv::snapshot()` before calling this function.
#' If the lock file is out of sync with your project library, a warning is
#' issued -- run `renv::snapshot()` to update it before building the image.
#'
#' If the project uses Quarto with branding assets (i.e. [toolero::create_qmd()]
#' was called with `use_style = TRUE`), the `assets/` folder must be copied
#' into the container alongside the `.qmd` file or Quarto will be unable to
#' resolve the CSS and HTML includes at render time. The simplest way to
#' ensure this is to pass `misc_file = "assets/"` -- or
#' `misc_file = c("assets/", other_files)` if additional files are needed --
#' when calling `generate_dockerfile()`. No code change is required;
#' `misc_file` already accepts directories and copies them whole.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Requires renv.lock in the current working directory.
#' # Run renv::snapshot() first if you don't have one.
#'
#' # Generate a minimal Dockerfile using a pinned R version. output defaults
#' # to ".", so this writes to the current working directory -- the same
#' # place build_image() looks by default.
#' generate_dockerfile(r_version = "4.4.0")
#'
#' # Pin a specific R version with the tidyverse image
#' generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse")
#'
#' # Add extra system libraries on top of auto-detected ones
#' generate_dockerfile(
#'   r_version       = "4.4.0",
#'   install_syslibs = c("libuv1-dev", "libwebp-dev"),
#'   output          = "."
#' )
#'
#' # Include a data file -- directory structure is preserved in the container
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   data_file = "data-raw/penguins.csv",
#'   code_file = "analysis.R",
#'   comments  = TRUE,
#'   output    = "."
#' )
#'
#' # Multiple scripts and a whole assets folder -- pass assets/ via misc_file
#' # so that branding files (styles.css, header.html, footer.html) are present
#' # inside the container when Quarto renders the .qmd
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   code_file = c("R/prepare.R", "R/model.R"),
#'   misc_file = "assets/",
#'   output    = "."
#' )
#'
#' # Serve a Shiny app -- files land under /srv/shiny-server/ automatically
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   r_mode    = "shiny_server",
#'   code_file = "app.R",
#'   output    = "."
#' )
#'
#' # RStudio Server plus Shiny Server in the same image
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   r_mode    = "rstudio_shiny",
#'   code_file = "app.R",
#'   output    = "."
#' )
#'
#' # Install Quarto, pinned to a specific release rather than whatever is
#' # currently latest -- the resolved version is recorded as
#' # ENV QUARTO_VERSION in the generated Dockerfile either way
#' generate_dockerfile(
#'   r_version      = "4.3.0",
#'   install_quarto = TRUE,
#'   quarto_version = "1.5.57",
#'   output         = "."
#' )
#'
#' # Fill in data_file, code_file, and misc_file from a toolero project
#' # manifest instead of retyping paths the project already declares
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   config    = "_toolero.yml",
#'   output    = "."
#' )
#' }
generate_dockerfile <- function(r_version       = "current",
                                r_mode          = "base",
                                auto_syslibs    = TRUE,
                                install_syslibs = NULL,
                                output          = ".",
                                data_file       = NULL,
                                code_file       = NULL,
                                misc_file       = NULL,
                                add_user        = NULL,
                                home_dir        = "/home",
                                expose_port     = "8787",
                                install_quarto  = FALSE,
                                quarto_version  = "latest",
                                os_version      = NULL,
                                comments        = FALSE,
                                verbose         = FALSE,
                                config          = NULL) {

    # -- 1. Validate r_mode early ----------------------------------------------
    if (!r_mode %in% names(.r_mode_registry)) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Valid choices are {.val {names(.r_mode_registry)}}."
        ))
    }

    # -- 2. Warn if expose_port is supplied but r_mode is not rstudio ----------
    # shiny_server and rstudio_shiny expose fixed port(s) from the registry
    # (a single expose_port value can't address rstudio_shiny's two ports),
    # so the override remains rstudio-only. Testing missing(expose_port)
    # rather than expose_port != "8787" means the warning is about whether an
    # override was supplied at all, not about what value it happens to be --
    # explicitly passing expose_port = "8787" under a non-rstudio r_mode is
    # still an override that gets ignored, and deserves the same warning as
    # any other value would.
    if (!missing(expose_port) && r_mode != "rstudio") {
        cli::cli_warn(c(
            "{.arg expose_port} is only used when {.arg r_mode} is {.val rstudio}.",
            "i" = "The supplied value {.val {expose_port}} will be ignored."
        ))
    }

    # -- 2b. Fill in file arguments from a toolero project manifest, if -------
    # config was supplied. Only ever fills an argument the caller left at
    # its own NULL default -- an explicit data_file/code_file/misc_file
    # always wins, so config never changes the behavior of a call that
    # also states its own file arguments. Must run before file argument
    # validation below, since a config-derived path is validated exactly
    # like one the caller typed.
    # config_folders backs the C07 mkdir block below: every folder in
    # _toolero.yml, verbatim, only when config was actually supplied. Left
    # empty otherwise, matching the audit's "do nothing" answer for a call
    # that has not asked for the config-derived behavior.
    config_folders <- character(0)

    if (!is.null(config)) {
        from_config <- .resolve_config_file_args(config)

        data_file <- .apply_config_default(
            data_file, from_config$data_file, "data_file", config, verbose
        )
        code_file <- .apply_config_default(
            code_file, from_config$code_file, "code_file", config, verbose
        )
        misc_file <- .apply_config_default(
            misc_file, from_config$misc_file, "misc_file", config, verbose
        )
        config_folders <- from_config$folders
    }

    # -- 3. Validate file arguments --------------------------------------------
    # .validate_file_arg() returns paths relative to getwd() (the build
    # context). Files outside the build context error immediately.
    data_file <- .validate_file_arg("data_file", data_file)
    code_file <- .validate_file_arg("code_file", code_file)
    misc_file <- .validate_file_arg("misc_file", misc_file)

    # -- 4. Validate renv.lock exists ------------------------------------------
    lockfile <- file.path(getwd(), "renv.lock")

    if (!file.exists(lockfile)) {
        cli::cli_abort(c(
            "{.file renv.lock} not found in {.path {getwd()}}.",
            "i" = "Run {.code renv::snapshot()} to generate one before",
            " " = "  calling {.fn generate_dockerfile}."
        ))
    }

    # -- 4b. Warn on an empty lockfile (C04) ------------------------------------
    # .read_renv_packages() returns character(0) for a renv.lock with no
    # Packages recorded at all -- previously silent: .fetch_sysreqs()
    # short-circuits on an empty package vector, the image builds with only
    # the baseline curl installed, and the build succeeds while the
    # analysis inside it cannot run. Checked here regardless of
    # auto_syslibs, since an empty lockfile is a symptom of the project
    # itself (renv::snapshot() never run, or run before any packages were
    # loaded), not something skipping auto-detection should hide.
    lockfile_packages <- .read_renv_packages(lockfile)

    if (length(lockfile_packages) == 0L) {
        cli::cli_warn(c(
            "{.file renv.lock} records no packages.",
            "i" = "The generated image will have no R packages installed",
            " " = "  beyond what the base image already provides.",
            "i" = "Run {.code renv::snapshot()} after loading the packages",
            " " = "  your analysis uses -- including {.pkg toolero} itself",
            " " = "  if the containerized script calls",
            " " = "  {.code toolero::save_output()} or",
            " " = "  {.code toolero::resolve_input_path()}, since those make",
            " " = "  toolero a runtime dependency of the analysis, not just",
            " " = "  a development convenience."
        ))
    }

    # -- 5. Check renv status --------------------------------------------------
    if (verbose) cli::cli_inform("Checking renv status...")

    status_ok <- tryCatch({
        status <- renv::status(project = getwd())
        isTRUE(status$synchronized)
    }, error = function(e) {
        TRUE  # if status() errors, don't block the user
    })

    if (!status_ok) {
        cli::cli_warn(c(
            "{.file renv.lock} may be out of sync with your project library.",
            "i" = "Run {.code renv::snapshot()} to update it before building",
            " " = "  the image to ensure the container matches your environment."
        ))
    }

    # -- 6. Resolve r_version --------------------------------------------------
    resolved_version <- if (r_version == "current") {
        as.character(getRversion())
    } else {
        r_version
    }

    # r_mode is passed through so the version is checked against the tag
    # repository the resolved r_mode will actually build FROM (tag_repo), not
    # always against rocker/r-ver -- a version can exist in one and not the
    # other, and previously that mismatch would only surface later, at the
    # FROM instruction, rather than here.
    if (!.r_ver_exists(resolved_version, r_mode = r_mode)) {
        tag_repo <- .r_mode_registry[[r_mode]]$tag_repo
        cli::cli_abort(c(
            "Requested R version {.val {resolved_version}} does not exist",
            " " = "for {.arg r_mode} {.val {r_mode}}.",
            "i" = "Check available tags at",
            " " = "  {.url https://rocker-project.org/images/versioned/{tag_repo}}"
        ))
    }

    # -- 6b. Enforce r_mode's minimum R version, if any ------------------------
    # /rocker_scripts/ (and install_shiny_server.sh inside it) only exists in
    # images built from the rocker-versioned2 repository, which covers
    # R >= 4.0.0. Older tags on the same Docker Hub repos (R <= 3.6.3) are
    # carried over from the predecessor rocker-versioned repo and predate
    # rocker_scripts entirely -- confirmed against rocker-versioned2's own
    # README, not assumed.
    #
    # resolved_version can be "latest", "devel", a bare "4", or carry a
    # CUDA/Ubuntu suffix (e.g. "4.4.0-cuda12.2-ubuntu22.04") -- none of which
    # package_version() accepts directly. .extract_r_version_prefix() pulls
    # the leading X[.Y[.Z]] numeric portion and pads it to three components;
    # NA for "latest"/"devel", both of which always resolve to the current
    # rocker-versioned2 lineage and so are exempt from the comparison.
    min_r_version  <- .r_mode_registry[[r_mode]]$min_r_version
    version_prefix <- .extract_r_version_prefix(resolved_version)

    if (!is.null(min_r_version) && !is.na(version_prefix) &&
        package_version(version_prefix) < package_version(min_r_version)) {
        cli::cli_abort(c(
            "{.val {r_mode}} requires R {.val {min_r_version}} or later.",
            "i" = "{.val {resolved_version}} predates the rocker-versioned2 image",
            " " = "  lineage that {.file /rocker_scripts/} ships in."
        ))
    }

    # -- 6c. Resolve quarto_version, if installing Quarto -----------------------
    # Every other layer in this image is pinned deliberately (r_version,
    # renv.lock); resolving "latest" to a concrete version here -- rather
    # than leaving /download/latest/ in the generated RUN instruction --
    # closes what was previously the one unpinned layer. Skipped entirely
    # when install_quarto = FALSE, so no network call is made unless Quarto
    # is actually being installed.
    resolved_quarto_version <- if (install_quarto) {
        .get_quarto_version(quarto_version, verbose = verbose)
    } else {
        NULL
    }

    # -- 7. Resolve system libraries -------------------------------------------
    # curl is always installed as a baseline -- renv needs it for downloads
    # inside the container regardless of what packages are in renv.lock.
    baseline_syslibs <- c("curl")

    auto_detected <- character(0)

    # os_version (C14): derived from the resolved R version via the Rocker
    # Project's own R-version-to-Ubuntu-release mapping unless the caller
    # overrides it. .fetch_sysreqs() previously defaulted to a hardcoded
    # "22.04" regardless of r_version, which only matched the Ubuntu
    # release actually backing R 4.2.2-4.3.3.
    resolved_os_version <- if (!is.null(os_version)) {
        os_version
    } else {
        .resolve_os_version(resolved_version)
    }

    if (auto_syslibs) {
        # Already read above (C04), so this reuses lockfile_packages rather
        # than parsing renv.lock a second time.
        packages <- lockfile_packages

        if (verbose) {
            cli::cli_inform(
                "Found {length(packages)} package{?s} in {.file renv.lock}."
            )
        }

        if (verbose) {
            cli::cli_inform(
                "Querying system requirements against Ubuntu {resolved_os_version}..."
            )
        }

        auto_detected <- .fetch_sysreqs(packages, os_version = resolved_os_version, verbose = verbose)
    }

    all_syslibs <- unique(c(baseline_syslibs, auto_detected, install_syslibs))

    if (verbose && length(all_syslibs) > 0) {
        cli::cli_inform(
            "Installing {length(all_syslibs)} system librar{?y/ies}."
        )
    }

    # -- 8. Build Dockerfile instruction strings -------------------------------
    image_prefix <- .r_mode_registry[[r_mode]]$image

    # copy_root (C24): NULL in the registry for the four Phase 1 modes,
    # meaning "track home_dir" -- those modes copy data_file/code_file/
    # misc_file to wherever WORKDIR points, since that's where a script
    # actually runs and where its relative paths resolve. Falling back to
    # home_dir here, rather than hardcoding "/home" as before, is what
    # makes home_dir = "/workspace" actually relocate the COPY
    # destinations along with WORKDIR instead of splitting them across two
    # different directories. "/srv/shiny-server" for shiny_server and
    # rstudio_shiny is left untouched -- Shiny Server's app directory is a
    # fixed system location, not something that should ever track
    # home_dir.
    copy_root <- .r_mode_registry[[r_mode]]$copy_root
    if (is.null(copy_root)) copy_root <- home_dir

    # ports: rstudio keeps the user-overridable expose_port for backward
    # compatibility. Every other mode with ports uses the registry's fixed
    # value(s) -- see the expose_port docs for why those aren't overridable.
    mode_ports <- if (r_mode == "rstudio") {
        expose_port
    } else {
        .r_mode_registry[[r_mode]]$ports
    }

    extra_install_script <- .r_mode_registry[[r_mode]]$extra_install

    syslibs_instruction <- if (length(all_syslibs) > 0) {
        lib_lines <- paste(
            paste0("    ", all_syslibs, " \\"),
            collapse = "\n"
        )
        paste0(
            "RUN apt-get update && apt-get install -y \\\n",
            lib_lines, "\n",
            "    && apt-get clean \\\n",
            "    && rm -rf /var/lib/apt/lists/*"
        )
    } else {
        NULL
    }

    lines <- list(
        base = list(
            instruction = glue::glue("FROM {image_prefix}:{resolved_version}"),
            verbose_msg = "Start from the Rocker project image",
            comment     = "Use the base image maintained by the Rocker project"
        ),
        non_interactive = list(
            instruction = "ENV DEBIAN_FRONTEND=noninteractive",
            verbose_msg = "Prevent interactive prompts during package installation",
            comment     = "Suppress interactive prompts during package installation"
        ),
        syslibs = list(
            instruction = syslibs_instruction,
            verbose_msg = "Install system libraries",
            comment     = if (!is.null(syslibs_instruction)) {
                "Install system libraries required by R packages in renv.lock"
            } else {
                NULL
            }
        ),
        user = list(
            instruction = if (!is.null(add_user)) {
                purrr::map_chr(add_user, ~ glue::glue(
                    "RUN apt-get install -y sudo \\\n",
                    "&& useradd -m -d /home/{.x} -s /bin/bash {.x} \\\n",
                    "&& echo '{.x}:yourpassword' | chpasswd \\\n",
                    "&& echo '{.x} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \\\n",
                    "&& chown -R {.x}:{.x} /home/{.x}"
                ))
            } else {
                NULL
            },
            verbose_msg = "Create additional Linux user",
            comment     = if (!is.null(add_user)) "Create the Linux user" else NULL
        ),
        quarto = list(
            # Neither wget nor gdebi is present in rocker/r-ver, so the
            # previous wget + gdebi incantation failed at build time on every
            # r_mode unless something in the lockfile happened to pull those
            # two programs in as a side effect. curl is already installed
            # unconditionally as a baseline syslib (see step 7), so this uses
            # curl -LO to fetch the .deb and dpkg -i / apt-get install -f to
            # install it -- the same two steps gdebi was a convenience
            # wrapper for -- rather than adding wget and gdebi-core as two
            # more packages to the image.
            instruction = if (install_quarto) {
                glue::glue(
                    "ENV QUARTO_VERSION={resolved_quarto_version}\n",
                    "RUN curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v{resolved_quarto_version}/quarto-{resolved_quarto_version}-linux-amd64.deb \\\n",
                    "    && (dpkg -i quarto-{resolved_quarto_version}-linux-amd64.deb || apt-get install -f -y) \\\n",
                    "    && rm quarto-{resolved_quarto_version}-linux-amd64.deb"
                )
            } else {
                NULL
            },
            verbose_msg = "Install Quarto CLI",
            comment     = if (install_quarto) {
                glue::glue("Download and install Quarto {resolved_quarto_version} for rendering .qmd files")
            } else {
                NULL
            }
        ),
        extra_install = list(
            instruction = if (!is.null(extra_install_script)) {
                glue::glue("RUN /rocker_scripts/{extra_install_script}")
            } else {
                NULL
            },
            verbose_msg = if (!is.null(extra_install_script)) {
                glue::glue("Running {extra_install_script}")
            } else {
                NULL
            },
            comment     = if (!is.null(extra_install_script)) {
                "Layer additional software onto the base image via Rocker's own install script"
            } else {
                NULL
            }
        ),
        workdir = list(
            instruction = glue::glue("WORKDIR {home_dir}"),
            verbose_msg = glue::glue("Set working directory to {home_dir}"),
            comment     = "Set the working directory inside the container"
        ),
        # mkdir (C07): the third of three answers the audit considered --
        # do nothing (safe but silent), unconditionally mkdir a toolero-
        # specific output/figures + output/tables (cheap but bakes in a
        # convention containr does not own), or derive it from folders: in
        # _toolero.yml only when config was actually supplied. This is
        # that third answer: every folder the manifest declares is created
        # under home_dir, right after WORKDIR, so a script's first write
        # into any of them -- via toolero::save_output() or a bare
        # ggsave()/write.csv() call -- lands somewhere that already
        # exists, the same way it does on the laptop where those folders
        # were created by toolero::init_project(). A call that never
        # passes config sees no new instruction here at all.
        mkdir = list(
            instruction = if (length(config_folders) > 0) {
                glue::glue(
                    "RUN mkdir -p {paste(file.path(home_dir, config_folders), collapse = ' ')}"
                )
            } else {
                NULL
            },
            verbose_msg = if (length(config_folders) > 0) {
                "Create project folders declared in config"
            } else {
                NULL
            },
            comment     = if (length(config_folders) > 0) {
                "Create the folders config declares, so a script's first write into any of them does not fail"
            } else {
                NULL
            }
        ),
        renv_lock = list(
            # home_dir, not copy_root: the lockfile isn't project content
            # (copy_root's job), it's the input to a restore that runs
            # wherever WORKDIR points. The image's later
            # `RUN R -e "renv::restore()"` resolves the project from the
            # working directory, which is home_dir, so a lockfile hardcoded
            # to /home/renv.lock only worked by coincidence when home_dir
            # was left at its own default of "/home" -- pass
            # home_dir = "/workspace" and restore() finds no lockfile there.
            instruction = glue::glue("COPY renv.lock {home_dir}/renv.lock"),
            verbose_msg = "Copy renv.lock file",
            comment     = "Copy the renv lockfile from the host into the container"
        ),
        # renv_restore runs immediately after renv_lock and before the
        # data/code/misc COPY blocks (C13). Podman and Docker invalidate a
        # layer's cache, and every layer after it, the moment anything
        # earlier in the Dockerfile changes -- including the COPY blocks'
        # own file contents, which is exactly what changes on every
        # ordinary edit to a script. With the restore ordered after those
        # COPY blocks, editing one line of analysis.R invalidated the cache
        # for the COPY itself and, because renv_restore came after it, for
        # the single most expensive layer in the image too: every package
        # reinstalled from source on every rebuild. renv_restore only
        # depends on renv.lock, which is already in place by this point, so
        # moving it here lets an ordinary script edit invalidate just the
        # COPY and restore-of-nothing-new layers below it, while the
        # package installation layer stays cached. See C21's test for the
        # ordering this depends on.
        renv_restore = list(
            # C23, verified: this script calls renv::restore() with no
            # subsequent renv::activate(), so no .Rprofile or
            # renv/activate.R is ever written -- a later, independent R
            # session (a further RUN layer, or `docker run <image>
            # Rscript ...`) has no automatic way to rediscover a
            # project-isolated library. That would ordinarily mean the
            # restored packages are invisible outside the one RUN step
            # that installed them. It doesn't happen here, because
            # Rocker's own r-ver family pre-wires renv's library path so
            # a project's restore resolves directly into
            # /usr/local/lib/R/site-library -- already on every R
            # session's default .libPaths() -- rather than an isolated
            # per-project renv/library/<platform>/<r-version>/ subfolder.
            # Confirmed 2026-09 with `docker run --rm <image> R -e
            # 'find.package("<a lockfile-only package>")'`, which
            # resolved under site-library, not under a hidden renv/
            # directory. No change needed; recorded here so nobody has
            # to re-derive this from scratch.
            instruction = readr::read_lines(
                system.file("extdata", "install_and_restore_packages.sh",
                            package = "containr")
            ),
            verbose_msg = "Install renv and restore project library",
            comment     = "Restore the R package environment as specified in renv.lock"
        ),
        data = list(
            instruction = if (!is.null(data_file)) {
                purrr::map_chr(data_file,
                               ~ glue::glue("COPY {.x} {copy_root}/{.x}"))
            } else {
                NULL
            },
            verbose_msg = "Copy data files into the container",
            comment     = if (!is.null(data_file)) {
                glue::glue("Copy data files -- directory structure preserved under {copy_root}/")
            } else {
                NULL
            }
        ),
        code = list(
            instruction = if (!is.null(code_file)) {
                purrr::map_chr(code_file,
                               ~ glue::glue("COPY {.x} {copy_root}/{.x}"))
            } else {
                NULL
            },
            verbose_msg = "Copy script files into the container",
            comment     = if (!is.null(code_file)) {
                glue::glue("Copy script files -- directory structure preserved under {copy_root}/")
            } else {
                NULL
            }
        ),
        misc = list(
            instruction = if (!is.null(misc_file)) {
                purrr::map_chr(misc_file,
                               ~ glue::glue("COPY {.x} {copy_root}/{.x}"))
            } else {
                NULL
            },
            verbose_msg = "Copy miscellaneous files into the container",
            comment     = if (!is.null(misc_file)) {
                glue::glue("Copy additional files -- directory structure preserved under {copy_root}/")
            } else {
                NULL
            }
        ),
        expose = list(
            instruction = if (!is.null(mode_ports)) {
                glue::glue("EXPOSE {paste(mode_ports, collapse = ' ')}")
            } else {
                NULL
            },
            verbose_msg = if (!is.null(mode_ports)) "Expose port(s) for the container" else NULL,
            comment     = if (!is.null(mode_ports)) {
                "Expose the port(s) used by RStudio Server and/or Shiny Server"
            } else {
                NULL
            }
        ),
        rstudio_hint = list(
            instruction = if (r_mode == "rstudio" && comments) {
                c(
                    "# Run the container with: docker run --rm -ti -u root -e PASSWORD=yourpassword -p 8787:8787 yourimage",
                    "# Point your browser to localhost:8787 and log in with rstudio/yourpassword"
                )
            } else {
                NULL
            },
            verbose_msg = NULL,
            comment     = NULL
        ),
        shiny_server_hint = list(
            instruction = if (r_mode == "shiny_server" && comments) {
                c(
                    "# Run the container with: docker run --rm -ti -p 3838:3838 yourimage",
                    "# Point your browser to localhost:3838"
                )
            } else {
                NULL
            },
            verbose_msg = NULL,
            comment     = NULL
        ),
        rstudio_shiny_hint = list(
            instruction = if (r_mode == "rstudio_shiny" && comments) {
                c(
                    "# Run the container with: docker run --rm -ti -u root -e PASSWORD=yourpassword -p 8787:8787 -p 3838:3838 yourimage",
                    "# Point your browser to localhost:8787 (RStudio) or localhost:3838 (Shiny apps)"
                )
            } else {
                NULL
            },
            verbose_msg = NULL,
            comment     = NULL
        )
    )

    # -- 9. Write Dockerfile ---------------------------------------------------
    # output may not already exist -- nothing upstream creates it, and
    # neither file.path() nor readr::write_lines() do either, so a
    # nonexistent output directory previously surfaced as a raw
    # file-connection error rather than a sentence naming the problem.
    # fs::dir_create() is idempotent: it creates output and any missing
    # parent directories, and does nothing if output is already there.
    fs::dir_create(output)

    dockerfile_path <- file.path(output, "Dockerfile")
    first <- TRUE

    for (block in lines) {
        if (is.null(block$instruction)) next

        if (!is.null(block$verbose_msg) && verbose) {
            cli::cli_inform(block$verbose_msg)
        }

        # Comment before instruction (S09): matches submitr's own write
        # loops in htc_gen_submit() and htc_gen_executable(), so a reader
        # moving between a generated Dockerfile and a submitr-generated
        # script reads both the same way round -- explanation first,
        # instruction second.
        if (!is.null(block$comment) && comments) {
            readr::write_lines(paste0("# ", block$comment),
                               file   = dockerfile_path,
                               append = !first)
            first <- FALSE
        }

        readr::write_lines(block$instruction,
                           file   = dockerfile_path,
                           append = !first)
        first <- FALSE
    }

    if (verbose) {
        cli::cli_alert_success(
            "Dockerfile written to {.path {dockerfile_path}}"
        )
    }

    invisible(NULL)
}


# -- Helpers backing the config argument (C01) --------------------------------
#
# Reading _toolero.yml is not a dependency on toolero: the schema is the
# contract (schema_version, folders:, conventions:), and a project that
# writes the file by hand is as valid an input as one init_project() wrote.
# containr therefore parses the YAML itself with yaml::read_yaml() rather
# than calling any toolero-internal function.
#
# Deliberately additive only: nothing here ever overrides a file argument
# the caller supplied, and nothing about generate_dockerfile()'s behavior
# changes for a call that does not pass config. Silent defaulting based on
# whether a file happens to exist is how you get bug reports nobody can
# reproduce.


#' Resolve file arguments from a toolero project manifest
#'
#' Internal helper backing [generate_dockerfile()]'s `config` argument.
#' Parses `_toolero.yml` and returns the file arguments it can derive from
#' the manifest's declared `folders:` -- one element per argument the file
#' has an opinion about, `NULL` for one it does not. Never validates that
#' the derived paths actually exist on disk; a stale or hand-edited
#' manifest surfaces as the same "does not exist" error from
#' `.validate_file_arg()` that a caller's own typo would, rather than a
#' separate failure mode here.
#'
#' @param config Character. Path to a `_toolero.yml` file.
#'
#' @return A named list with elements `data_file`, `code_file`, and
#'   `misc_file`, each a single character string or `NULL`; and `folders`,
#'   a character vector of every folder the manifest declares (possibly
#'   empty), for deriving the `mkdir -p` block (C07).
#'
#' @keywords internal
.resolve_config_file_args <- function(config) {

    if (!is.character(config) || length(config) != 1L || is.na(config)) {
        cli::cli_abort(c(
            "{.arg config} must be a single character string.",
            "x" = "Received {.obj_type_friendly {config}} of length {length(config)}."
        ))
    }

    if (!fs::file_exists(config)) {
        cli::cli_abort(c(
            "{.arg config} file not found at {.file {config}}.",
            "i" = "Pass the path to a {.file _toolero.yml} written by
                   {.code toolero::init_project()} or
                   {.code toolero::generate_project_config()}."
        ))
    }

    parsed <- yaml::read_yaml(config)

    # -- schema version --------------------------------------------------
    # containr currently understands schema 1 only. A file with no
    # schema_version is treated as schema 1, matching toolero's own
    # reader, so a manifest written before the field existed still works.
    # Anything else is read anyway: a config this version of containr
    # cannot fully understand is still more useful consulted than ignored,
    # and the file arguments it can derive (plain folder names) are
    # unlikely to change shape even if the schema grows new keys.
    supported_schema <- 1L
    declared_schema  <- parsed[["schema_version"]]

    if (!is.null(declared_schema)) {
        declared_numeric <- suppressWarnings(as.integer(declared_schema))

        if (is.na(declared_numeric) || declared_numeric != supported_schema) {
            cli::cli_warn(c(
                "!" = "{.file {config}} declares {.field schema_version}
                       {.val {declared_schema}}, which this version of
                       {.pkg containr} does not recognize.",
                "i" = "Reading it anyway. This version of {.pkg containr}
                       understands schema {.val {supported_schema}}."
            ))
        }
    }

    # -- folders and conventions ------------------------------------------
    # A missing folders: entry is not an error here the way it is for
    # toolero's own check_project() -- a manifest containr can't derive
    # anything useful from just means config contributes nothing, and the
    # call proceeds as if it had not been supplied.
    folders <- parsed[["folders"]]
    folders <- if (is.null(folders)) character(0) else as.character(folders)

    conventions <- parsed[["conventions"]]
    script_dir  <- NULL
    if (is.list(conventions)) {
        script_dir <- conventions[["script_dir"]]
    }
    if (is.null(script_dir) || !nzchar(script_dir)) {
        script_dir <- "R"
    }

    list(
        # No dedicated conventions: key names the input-data folder, unlike
        # script_dir -- "data-raw" here is containr's own convention,
        # matching how this family's own documentation uses it everywhere
        # else, not something _toolero.yml states explicitly.
        data_file = if ("data-raw" %in% folders) "data-raw" else NULL,
        code_file = if (script_dir %in% folders) script_dir else NULL,
        misc_file = if ("assets" %in% folders) "assets" else NULL,
        # C07: every folder the manifest declares, verbatim, regardless of
        # whether containr recognizes it as data-raw/script_dir/assets --
        # used to derive the mkdir -p block below, so a folder this version
        # of containr has no special meaning for (a future convention, or a
        # user's own addition to folders:) still gets created instead of
        # silently failing the first time a script writes into it.
        folders = folders
    )
}


#' Apply one config-derived file argument default
#'
#' Internal helper used by [generate_dockerfile()]. Returns `current`
#' unchanged whenever the caller already supplied it, or whenever `config`
#' had no opinion about this argument. Only when both are true -- the
#' caller left it `NULL` and `config` derived a value -- does `derived`
#' take effect, and, in `verbose` mode, get reported as having come from
#' `config` rather than from the call.
#'
#' @param current The argument's current value (from the call).
#' @param derived The value [.resolve_config_file_args()] derived for it,
#'   or `NULL`.
#' @param arg_name Character. The argument's name, for the `verbose` message.
#' @param config Character. Path to the config file, for the `verbose`
#'   message.
#' @param verbose Logical. Whether to report the substitution.
#'
#' @return `current`, or `derived` when it applies.
#'
#' @keywords internal
.apply_config_default <- function(current, derived, arg_name, config, verbose) {

    if (!is.null(current) || is.null(derived)) {
        return(current)
    }

    if (verbose) {
        cli::cli_inform(
            "{.arg {arg_name}} not supplied -- using {.val {derived}} from {.file {config}}."
        )
    }

    derived
}
