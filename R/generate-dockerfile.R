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
#'   `"rstudio"`. Defaults to `"8787"`.
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
#'   Does not return a value.
#' @export
#'
#' @examples
#' # Generate a minimal Dockerfile using the current R version
#' generate_dockerfile(output = tempdir())
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
    # I want IDE to be base, tidyverse, rstudio, tidystudio (BOTH rstudio and tidyverse)
    # I found the tidystudio version of the image is fuzzier than the other

    # Start from the latest RStudio Server image with R pre-installed

    # validate the _file argument exist if there are different from NULL

    data_file <- .validate_file_arg("data_file", data_file)
    code_file <- .validate_file_arg("code_file", code_file)
    misc_file <- .validate_file_arg("misc_file", misc_file)
    dockerfile_path <- file.path(output, "Dockerfile")

    # Resolve "current" to actual R version
    resolved_version <- if (r_version == "current") as.character(getRversion()) else r_version

    # Ensure that the r_version argument is a supported version
    if (!.r_ver_exists(resolved_version)) {
        cli::cli_abort(c(
            "Requested R version {.val {resolved_version}} does not exist.",
            "i" = "Check available tags at {.url https://rocker-project.org/images/versioned/r-ver}"
        ))
    }

    # Map r_mode to appropriate Rocker image prefix
    image_prefix <- dplyr::case_when(
        r_mode == "base"       ~ "rocker/r-ver",
        r_mode == "tidyverse"  ~ "rocker/tidyverse",
        r_mode == "rstudio"    ~ "rocker/rstudio",
        r_mode == "tidystudio" ~ "rocker/verse",
        .default = NA
    )

    if (is.na(image_prefix)) {
        cli::cli_abort(c(
            "{.val {r_mode}} is not a valid {.arg r_mode}.",
            "i" = "Valid choices are {.val base}, {.val rstudio}, {.val tidyverse}, and {.val tidystudio}."
        ))
    }

    # Construct Docker base line
    base_line <- glue::glue("FROM {image_prefix}:{resolved_version}")

    non_interactive_line <- glue::glue("ENV DEBIAN_FRONTEND=noninteractive")

    # Set the working directory inside the container
    working_dir_line <- glue::glue("WORKDIR {home_dir}")

    # Install system libraries required for common R packages, Quarto rendering, and compilation from source

    system_lib_line <- if (install_syslibs) {
        glue::glue("RUN apt-get update && apt-get install -y \\
    cmake \\
    libcurl4-openssl-dev \\
    libssl-dev \\
    libxml2-dev \\
    libgit2-dev \\
    libfontconfig1-dev \\
    libfreetype6-dev \\
    libpng-dev \\
    libtiff5-dev \\
    libjpeg-dev \\
    wget \\
    gdebi-core \\
    libharfbuzz-dev \\
    libfribidi-dev \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*")
    } else {
        ""
    }

    # Download and install the Quarto CLI for rendering .qmd files
    quarto_install_line <- ifelse(install_quarto == TRUE, glue::glue("RUN wget -q https://quarto.org/download/latest/quarto-linux-amd64.deb \
    && gdebi --non-interactive quarto-linux-amd64.deb \
    && rm quarto-linux-amd64.deb"), "")

    # Copy the renv lockfile for reproducible R package environments
    renv_lock_line <- glue::glue("COPY renv.lock /home/renv.lock")

    # Copy the optional datafile used in the analysis

    data_line <- if (is.null(data_file) || length(data_file) == 0) {
        ""
    } else {
        purrr::map_chr(data_file, ~ glue::glue("COPY {.x} /home/data/{basename(.x)}"))
    }

    # Copy the optional code files (e.g., .qmd, .rmd, .R)

    code_line <- if (is.null(code_file) || length(code_file) == 0) {
        ""
    } else {
        purrr::map_chr(code_file, ~ glue::glue("COPY {.x} /home/{basename(.x)}"))
    }

    # Copy the optional miscellaneous files (e.g., images, bash scripts, etc)

    misc_line <- if (is.null(misc_file) || length(misc_file) == 0) {
        ""
    } else {
        purrr::map_chr(misc_file, ~ glue::glue("COPY {.x} /home/{basename(.x)}"))
    }

    # Copy the optional user line (e.g., report or documentation)

    user_line <- if (is.null(add_user) || length(add_user) == 0) {
        ""
    } else {
        purrr::map_chr(add_user, ~ glue::glue("RUN apt-get install -y sudo \\
&& useradd -m -d /home/{.x} -s /bin/bash {.x} \\
&& echo '{.x}:yourpassword' | chpasswd \\
&& echo '{.x} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \\
&& chown -R {.x}:{.x} /home/{.x}"))
    }

    # Expose the default port used by RStudio Server
    expose_line <- ifelse(r_mode == "rstudio", glue::glue("EXPOSE {expose_port}"), "")

    ##########################
    # Building the Dockerfile
    ##########################

    if (verbose) cli::cli_inform("Start from the Rocker project image")
    readr::write_lines(base_line, file = dockerfile_path)
    if (comments) {
        readr::write_lines("# Use the base image maintained by the Rocker project", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Prevent interactive prompts during package installation")
    readr::write_lines(non_interactive_line, file = dockerfile_path, append = TRUE)
    if (comments) {
        readr::write_lines("# Suppress interactive prompts during package installation", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Install system libraries required for common R packages")
    readr::write_lines(system_lib_line, file = dockerfile_path, append = TRUE)
    if (comments) {
        readr::write_lines("# Update package lists and install system libraries needed for common R packages, then clean up to reduce image size", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Create additional Linux user")
    readr::write_lines(user_line, file = dockerfile_path, append = TRUE)
    if (comments && !is.null(add_user)) {
        readr::write_lines("# Create the Linux user", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Install Quarto and Markdown support")
    readr::write_lines(quarto_install_line, file = dockerfile_path, append = TRUE)
    if (comments && install_quarto) {
        readr::write_lines("# Install required packages and libraries for Quarto and Rmarkdown", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Set working directory to {home_dir}")
    readr::write_lines(working_dir_line, file = dockerfile_path, append = TRUE)
    if (comments) {
        readr::write_lines("# Set the working directory inside the container", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Copy renv.lock files")
    readr::write_lines(renv_lock_line, file = dockerfile_path, append = TRUE)
    if (comments) {
        readr::write_lines("# Copy the renv lockfile from the host into the container", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("If required, copy data files from the host into the container")
    readr::write_lines(data_line, file = dockerfile_path, append = TRUE)
    if (comments && !is.null(data_file)) {
        readr::write_lines("# Optionally copy data files from the host into the container", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("If required, copy code files from the host into the container")
    readr::write_lines(code_line, file = dockerfile_path, append = TRUE)
    if (comments && !is.null(code_file)) {
        readr::write_lines("# Optionally copy script files from the host into the container", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("If required, copy miscellaneous files from the host into the container")
    readr::write_lines(misc_line, file = dockerfile_path, append = TRUE)
    if (comments && !is.null(misc_file)) {
        readr::write_lines("# Optionally copy additional files into the container", file = dockerfile_path, append = TRUE)
    }

    # Install the renv package from Posit's CRAN mirror & Restore the R package environment using the renv lockfile is tricky because there is more than two layers of quotations involved.

    if (verbose) cli::cli_inform("Installs renv and restores project library")
    readr::write_lines(
        readr::read_lines(system.file("extdata",
                                      "install_and_restore_packages.sh",
                                      package = "containr"
        )),
        file = dockerfile_path,
        append = TRUE
    )
    if (comments) {
        readr::write_lines("# Restore the R package environment as specified in renv.lock", file = dockerfile_path, append = TRUE)
    }

    if (verbose) cli::cli_inform("Expose port {expose_port} for the IDE")
    readr::write_lines(expose_line, file = dockerfile_path, append = TRUE)
    if (comments) {
        readr::write_lines("# Expose port 8787, commonly used by RStudio Server", file = dockerfile_path, append = TRUE)
    }

    if (comments && r_mode == "rstudio") {
        readr::write_lines(
            "# Run the container with: docker run --rm -ti -u root -e PASSWORD=yourpassword -p 8787:8787 yourimage",
            file = dockerfile_path,
            append = TRUE
        )
        readr::write_lines(
            "# Point your browser to localhost:8787 and log in with rstudio/yourpassword",
            file = dockerfile_path,
            append = TRUE
        )
    }
}
