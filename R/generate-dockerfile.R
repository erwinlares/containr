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
#'   Server, or `"tidystudio"` for tidyverse plus TeX Live and
#'   publishing-related packages. Defaults to `"base"`.
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
#' @param data_file A character string. Path to an optional data file to copy
#'   into the container under `/home/data/`. Defaults to `NULL`.
#' @param code_file A character string. Path to an optional script file (e.g.
#'   `.R`, `.qmd`, `.rmd`) to copy into the container under `/home/`.
#'   Defaults to `NULL`.
#' @param misc_file A character string. Path to an optional miscellaneous file
#'   (e.g. an image or shell script) to copy into the container under
#'   `/home/`. Defaults to `NULL`.
#' @param add_user A character string. Name of a Linux user to create inside
#'   the container with sudo access. Defaults to `NULL`.
#' @param home_dir A character string. The working directory set inside the
#'   container via `WORKDIR`. Defaults to `"/home"`.
#' @param expose_port A character string. The port to expose when `r_mode` is
#'   `"rstudio"`. Defaults to `"8787"`. Ignored when `r_mode` is not
#'   `"rstudio"`.
#' @param install_quarto Logical. If `TRUE`, downloads and installs the Quarto
#'   CLI inside the container. Defaults to `FALSE`.
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
#' issued — run `renv::snapshot()` to update it before building the image.
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
#' # Include a data file and annotate the Dockerfile with comments
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   data_file = "data/penguins.csv",
#'   comments  = TRUE,
#'   output    = "."
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
                                comments        = FALSE,
                                verbose         = FALSE) {

    # -- 1. Validate r_mode early ----------------------------------------------
    image_map <- c(
        base       = "rocker/r-ver",
        tidyverse  = "rocker/tidyverse",
        rstudio    = "rocker/rstudio",
        tidystudio = "rocker/verse"
    )

    if (!r_mode %in% names(image_map)) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Valid choices are {.val {names(image_map)}}."
        ))
    }

    # -- 2. Warn if expose_port is customised but r_mode is not rstudio --------
    if (expose_port != "8787" && r_mode != "rstudio") {
        cli::cli_warn(c(
            "{.arg expose_port} is only used when {.arg r_mode} is {.val rstudio}.",
            "i" = "The supplied value {.val {expose_port}} will be ignored."
        ))
    }

    # -- 3. Validate file arguments --------------------------------------------
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

    # -- 7. Resolve system libraries -------------------------------------------
    # curl is always installed as a baseline — renv needs it for downloads
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
    image_prefix <- image_map[[r_mode]]

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
                    "RUN wget -q https://quarto.org/download/latest/quarto-linux-amd64.deb \\\n",
                    "    && gdebi --non-interactive quarto-linux-amd64.deb \\\n",
                    "    && rm quarto-linux-amd64.deb"
                )
            } else {
                NULL
            },
            verbose_msg = "Install Quarto CLI",
            comment     = if (install_quarto) {
                "Download and install the Quarto CLI for rendering .qmd files"
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
                purrr::map_chr(data_file, function(f) {
                    rel <- fs::path_rel(f, start = getwd())
                    glue::glue("COPY {rel} /home/{rel}")
                })
            } else {
                NULL
            },
            verbose_msg = "Copy data files into the container",
            comment     = if (!is.null(data_file)) {
                "Optionally copy data files from the host into the container"
            } else {
                NULL
            }
        ),
        code = list(
            instruction = if (!is.null(code_file)) {
                purrr::map_chr(code_file, function(f) {
                    rel <- fs::path_rel(f, start = getwd())
                    glue::glue("COPY {rel} /home/{rel}")
                })
            } else {
                NULL
            },
            verbose_msg = "Copy script files into the container",
            comment     = if (!is.null(code_file)) {
                "Optionally copy script files from the host into the container"
            } else {
                NULL
            }
        ),
        misc = list(
            instruction = if (!is.null(misc_file)) {
                purrr::map_chr(misc_file, function(f) {
                    rel <- fs::path_rel(f, start = getwd())
                    glue::glue("COPY {rel} /home/{rel}")
                })
            } else {
                NULL
            },
            verbose_msg = "Copy miscellaneous files into the container",
            comment     = if (!is.null(misc_file)) {
                "Optionally copy additional files into the container"
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
            instruction = if (r_mode == "rstudio") {
                glue::glue("EXPOSE {expose_port}")
            } else {
                NULL
            },
            verbose_msg = "Expose port for RStudio Server",
            comment     = if (r_mode == "rstudio") {
                "Expose port commonly used by RStudio Server"
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
