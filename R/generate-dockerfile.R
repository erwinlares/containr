#' Generate a reproducible Dockerfile for an R project
#'
#' `generate_dockerfile()` inspects an R project's dependencies via an `renv`
#' lockfile and writes a ready-to-use `Dockerfile` to the specified output
#' directory. It supports multiple Rocker base images, optional system
#' libraries, Quarto installation, file copying, user creation, and inline
#' documentation comments.
#'
#' @param r_version A character string specifying the R version to use, e.g.
#'   `"4.3.0"`. Defaults to `"current"`, which resolves to the version of R
#'   running in the current session.
#' @param r_mode A character string selecting the Rocker base image. Inspired
#'   by the [Rocker Project](https://rocker-project.org/). One of `"base"` for
#'   plain R, `"tidyverse"` for R with the tidyverse, `"rstudio"` for RStudio
#'   Server, or `"tidystudio"` for tidyverse plus TeX Live and
#'   publishing-related packages. Defaults to `"base"`.
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
#' @param install_syslibs Logical. If `TRUE`, installs system libraries
#'   commonly required by R packages and needed for source compilation
#'   (e.g. `libcurl4-openssl-dev`, `libxml2-dev`). Defaults to `TRUE`.
#' @param comments Logical. If `TRUE`, annotates each Dockerfile instruction
#'   with an explanatory comment. Useful for learning or sharing. Defaults to
#'   `FALSE`.
#' @param verbose Logical. If `TRUE`, prints progress messages as each section
#'   of the Dockerfile is written. Defaults to `FALSE`.
#'
#' @return Called for its side effects. Writes a `Dockerfile` to `output`.
#'   Returns `invisible(NULL)`.
#' @export
#'
#' @examples
#' # Generate a minimal Dockerfile using a pinned R version
#' generate_dockerfile(r_version = "4.4.0", output = tempdir())
#'
#' # Pin a specific R version with the tidyverse image
#' generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse", output = tempdir())
#'
#' # Include a data file and annotate the Dockerfile with comments
#' \dontrun{
#' generate_dockerfile(
#'   r_version = "4.3.0",
#'   data_file = "data/penguins.csv",
#'   comments  = TRUE,
#'   output    = "."
#' )
#' }
#'
generate_dockerfile <- function(verbose = FALSE,
                                r_version = "current",
                                data_file = NULL,
                                code_file = NULL,
                                misc_file = NULL,
                                add_user = NULL,
                                home_dir = "/home",
                                install_quarto = FALSE,
                                expose_port = "8787",
                                r_mode = "base",
                                install_syslibs = TRUE,
                                comments = FALSE,
                                output = tempdir()) {

    # -- 1. Validate r_mode early -- before any file or network operations -----
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

    # -- 4. Resolve r_version --------------------------------------------------
    resolved_version <- if (r_version == "current") {
        as.character(getRversion())
    } else {
        r_version
    }

    if (!.r_ver_exists(resolved_version)) {
        cli::cli_abort(c(
            "Requested R version {.val {resolved_version}} does not exist.",
            "i" = "Check available tags at {.url https://rocker-project.org/images/versioned/r-ver}"
        ))
    }

    # -- 5. Build Dockerfile instruction strings -------------------------------
    image_prefix <- image_map[[r_mode]]

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
            instruction = if (install_syslibs) {
                glue::glue(
                    "RUN apt-get update && apt-get install -y \\\n",
                    "    cmake \\\n",
                    "    libcurl4-openssl-dev \\\n",
                    "    libssl-dev \\\n",
                    "    libxml2-dev \\\n",
                    "    libgit2-dev \\\n",
                    "    libfontconfig1-dev \\\n",
                    "    libfreetype6-dev \\\n",
                    "    libpng-dev \\\n",
                    "    libtiff5-dev \\\n",
                    "    libjpeg-dev \\\n",
                    "    wget \\\n",
                    "    gdebi-core \\\n",
                    "    libharfbuzz-dev \\\n",
                    "    libfribidi-dev \\\n",
                    "    && apt-get clean \\\n",
                    "    && rm -rf /var/lib/apt/lists/*"
                )
            } else {
                NULL
            },
            verbose_msg = "Install system libraries required for common R packages",
            comment     = "Update package lists and install system libraries needed for common R packages, then clean up to reduce image size"
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
            comment     = if (install_quarto) "Download and install the Quarto CLI for rendering .qmd files" else NULL
        ),
        workdir = list(
            instruction = glue::glue("WORKDIR {home_dir}"),
            verbose_msg = "Set working directory to {home_dir}",
            comment     = "Set the working directory inside the container"
        ),
        renv_lock = list(
            instruction = "COPY renv.lock /home/renv.lock",
            verbose_msg = "Copy renv.lock file",
            comment     = "Copy the renv lockfile from the host into the container"
        ),
        data = list(
            instruction = if (!is.null(data_file)) {
                purrr::map_chr(data_file, ~ glue::glue("COPY {.x} /home/data/{basename(.x)}"))
            } else {
                NULL
            },
            verbose_msg = "Copy data files into the container",
            comment     = if (!is.null(data_file)) "Optionally copy data files from the host into the container" else NULL
        ),
        code = list(
            instruction = if (!is.null(code_file)) {
                purrr::map_chr(code_file, ~ glue::glue("COPY {.x} /home/{basename(.x)}"))
            } else {
                NULL
            },
            verbose_msg = "Copy script files into the container",
            comment     = if (!is.null(code_file)) "Optionally copy script files from the host into the container" else NULL
        ),
        misc = list(
            instruction = if (!is.null(misc_file)) {
                purrr::map_chr(misc_file, ~ glue::glue("COPY {.x} /home/{basename(.x)}"))
            } else {
                NULL
            },
            verbose_msg = "Copy miscellaneous files into the container",
            comment     = if (!is.null(misc_file)) "Optionally copy additional files into the container" else NULL
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
            comment     = if (r_mode == "rstudio") "Expose port commonly used by RStudio Server" else NULL
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

    # -- 6. Write Dockerfile ---------------------------------------------------
    dockerfile_path <- file.path(output, "Dockerfile")

    # Write the first instruction fresh (no append) then append the rest
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

        # Comments follow immediately after the instruction they describe,
        # except for rstudio_hint which writes raw comment lines itself
        if (!is.null(block$comment) && comments) {
            readr::write_lines(paste0("# ", block$comment),
                               file   = dockerfile_path,
                               append = TRUE)
        }
    }

    invisible(NULL)
}
