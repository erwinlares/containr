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
#' @param output A character string. Directory path where the `Dockerfile` will
#'   be written. Defaults to `tempdir()`.
#' @param data_file A character vector or `NULL`. Path(s) to data file(s)
#'   and/or directories to copy into the container -- a single path, a
#'   vector of paths, or a directory (copied whole, with its contents) may
#'   all be mixed freely in the same vector. The local directory structure
#'   is preserved under `/home/` for `"base"`, `"tidyverse"`, `"rstudio"`,
#'   and `"verse"` (e.g. `"data-raw/sample.csv"` becomes
#'   `/home/data-raw/sample.csv`, and a directory `"data-raw/"` is copied to
#'   `/home/data-raw/` in full), or under `/srv/shiny-server/` for
#'   `"shiny_server"` and `"rstudio_shiny"`, matching Shiny Server's own
#'   default app directory. Every path must be inside the current working
#'   directory (the build context). Defaults to `NULL`.
#' @param code_file A character vector or `NULL`. Path(s) to script file(s)
#'   (e.g. `.R`, `.qmd`, `.rmd`) and/or directories to copy into the
#'   container -- see `data_file` for vector and directory behavior. The
#'   local directory structure is preserved under the mode's copy root --
#'   see `data_file`. Every path must be inside the current working
#'   directory. Defaults to `NULL`.
#' @param misc_file A character vector or `NULL`. Path(s) to miscellaneous
#'   file(s) (e.g. images, shell scripts, or branding assets) and/or
#'   directories to copy into the container -- see `data_file` for vector
#'   and directory behavior. The local directory structure is preserved under
#'   the mode's copy root -- see `data_file`. Every path must be inside the
#'   current working directory. Defaults to `NULL`.
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
#'   container via `WORKDIR`. Does not affect where `data_file`, `code_file`,
#'   or `misc_file` are copied -- see `data_file`. Defaults to `"/home"`.
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
#' @param comments Logical. If `TRUE`, annotates each Dockerfile instruction
#'   with an explanatory comment. Useful for learning or sharing. Defaults to
#'   `FALSE`.
#' @param verbose Logical. If `TRUE`, prints progress messages as each section
#'   of the Dockerfile is written. Defaults to `FALSE`.
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
#' # Generate a minimal Dockerfile using a pinned R version
#' generate_dockerfile(r_version = "4.4.0", output = tempdir())
#'
#' # Pin a specific R version with the tidyverse image
#' generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse",
#'                     output = tempdir())
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
#' }
generate_dockerfile <- function(r_version       = "current",
                                r_mode          = "base",
                                auto_syslibs    = TRUE,
                                install_syslibs = NULL,
                                output          = tempdir(),
                                data_file       = NULL,
                                code_file       = NULL,
                                misc_file       = NULL,
                                add_user        = NULL,
                                home_dir        = "/home",
                                expose_port     = "8787",
                                install_quarto  = FALSE,
                                quarto_version  = "latest",
                                comments        = FALSE,
                                verbose         = FALSE) {

    # -- 1. Validate r_mode early ----------------------------------------------
    if (!r_mode %in% names(.r_mode_registry)) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Valid choices are {.val {names(.r_mode_registry)}}."
        ))
    }

    # -- 2. Warn if expose_port is customised but r_mode is not rstudio --------
    # shiny_server and rstudio_shiny expose fixed port(s) from the registry
    # (a single expose_port value can't address rstudio_shiny's two ports),
    # so the override remains rstudio-only.
    if (expose_port != "8787" && r_mode != "rstudio") {
        cli::cli_warn(c(
            "{.arg expose_port} is only used when {.arg r_mode} is {.val rstudio}.",
            "i" = "The supplied value {.val {expose_port}} will be ignored."
        ))
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

    if (!.r_ver_exists(resolved_version)) {
        cli::cli_abort(c(
            "Requested R version {.val {resolved_version}} does not exist.",
            "i" = "Check available tags at",
            " " = "  {.url https://rocker-project.org/images/versioned/r-ver}"
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

    if (auto_syslibs) {
        if (verbose) cli::cli_inform("Reading packages from {.file renv.lock}...")
        packages <- .read_renv_packages(lockfile)

        if (verbose) {
            cli::cli_inform(
                "Found {length(packages)} package{?s} in {.file renv.lock}."
            )
        }

        auto_detected <- .fetch_sysreqs(packages, verbose = verbose)
    }

    all_syslibs <- unique(c(baseline_syslibs, auto_detected, install_syslibs))

    if (verbose && length(all_syslibs) > 0) {
        cli::cli_inform(
            "Installing {length(all_syslibs)} system librar{?y/ies}."
        )
    }

    # -- 8. Build Dockerfile instruction strings -------------------------------
    image_prefix <- .r_mode_registry[[r_mode]]$image

    # copy_root: comes straight from the registry. "/home" for the four
    # Phase 1 modes (unrelated to home_dir -- COPY destinations for those
    # modes have always been the literal /home/, independent of WORKDIR,
    # and stay that way here). "/srv/shiny-server" for shiny_server and
    # rstudio_shiny, matching Shiny Server's own default app directory.
    copy_root <- .r_mode_registry[[r_mode]]$copy_root

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
            instruction = if (install_quarto) {
                glue::glue(
                    "ENV QUARTO_VERSION={resolved_quarto_version}\n",
                    "RUN wget -q https://github.com/quarto-dev/quarto-cli/releases/download/v{resolved_quarto_version}/quarto-{resolved_quarto_version}-linux-amd64.deb \\\n",
                    "    && gdebi --non-interactive quarto-{resolved_quarto_version}-linux-amd64.deb \\\n",
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
        renv_lock = list(
            instruction = "COPY renv.lock /home/renv.lock",
            verbose_msg = "Copy renv.lock file",
            comment     = "Copy the renv lockfile from the host into the container"
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
        renv_restore = list(
            instruction = readr::read_lines(
                system.file("extdata", "install_and_restore_packages.sh",
                            package = "containr")
            ),
            verbose_msg = "Install renv and restore project library",
            comment     = "Restore the R package environment as specified in renv.lock"
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
    dockerfile_path <- file.path(output, "Dockerfile")
    first <- TRUE

    for (block in lines) {
        if (is.null(block$instruction)) next

        if (!is.null(block$verbose_msg) && verbose) {
            cli::cli_inform(block$verbose_msg)
        }

        readr::write_lines(block$instruction,
                           file   = dockerfile_path,
                           append = !first)
        first <- FALSE

        if (!is.null(block$comment) && comments) {
            readr::write_lines(paste0("# ", block$comment),
                               file   = dockerfile_path,
                               append = TRUE)
        }
    }

    if (verbose) {
        cli::cli_alert_success(
            "Dockerfile written to {.path {dockerfile_path}}"
        )
    }

    invisible(NULL)
}
