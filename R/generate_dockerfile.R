#' Generate a reproducible Dockerfile for R projects
#'
#' Creates a customizable Dockerfile tailored to R-based workflows, supporting multiple Rocker images (base R, tidyverse, RStudio Server, and publishing-ready configurations). The function allows inclusion of data, code, and miscellaneous files, sets up system libraries, optionally installs Quarto, and configures user access. It supports verbose output and inline comments for transparency and educational use. Designed to streamline containerization for reproducible research and deployment.
#'
#' @param verbose logical (TRUE or FALSE). Should generate_dockerfile() print out progress? By default, it will silently create a Dockerfile
#' @param r_version a character string indicated a version of R, i.e., "4.3.0". By default, it will grab the version of R from the current session
#' @param data_file a character string indicating an optional name of a data file to be copied into the container
#' @param code_file a character string indicating an optional name of a script file to be copied into the container
#' @param home_dir a character string specifying the home directory inside the container
#' @param install_quarto logical (TRUE or FALSE). If TRUE it will include supporting packages and system libraries to support Quarto and RMarkdown.
#' @param expose_port a character string indicating in which port will RStudio Server be accessible. It defaults to 8787
#' @param r_mode a character string. Inspired by the images in the Rocker Project. The options are "base" for base R, "tidyverse", "rstudio" for RStudio Server, and "tidystudio" which is tidyverse plus TeX Live and some publishing-related R packages
#'
#' @param comments logical (TRUE or FALSE). If TRUE, the Dockerfile generated will include comments detailing what each line does. If FALSE, the Dockerfile will be bare with only commands.
#'
#' @param misc_file a character string indicating an optional name of miscellaneous files to be copied into the container
#'
#' @param add_user a character string indicating an optional name of a linux user to be created inside the container
#'
#' @param install_syslibs logical. If TRUE, includes system libraries commonly required by R packages and tools for source compilation.
#'
#' @return invisibly returns NULL. This function is called for its side effects and does not return a value.
#' @export
#' @examples
#' # Basic Usage
#'
#' # Specify an image with R 4.2.0 installed
#'
#' generate_dockerfile(r_version = "4.3.0")
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
                                comments = FALSE) {
    # I want IDE to be base, tidyverse, rstudio, tidystudio (BOTH rstudio and tidyverse)
    # I found the tidystudio version of the image is fuzzier than the other

    # Start from the latest RStudio Server image with R pre-installed

    # validate the _file argument exist if there are different from NULL

    data_file <- .validate_file_arg("data_file", data_file)
    code_file <- .validate_file_arg("code_file", code_file)
    misc_file <- .validate_file_arg("misc_file", misc_file)

    # Resolve "current" to actual R version
    resolved_version <- if (r_version == "current") as.character(getRversion()) else r_version

    # Ensure that the r_version argument is a supported version
    if (!r_ver_exists(resolved_version)) stop("Requested R version does not exist. Check https://rocker-project.org/images/versioned/r-ver")

    # Map r_mode to appropriate Rocker image prefix
    image_prefix <- dplyr::case_when(
        r_mode == "base" ~ "rocker/r-ver",
        r_mode == "tidyverse" ~ "rocker/tidyverse",
        r_mode == "rstudio" ~ "rocker/rstudio",
        r_mode == "tidystudio" ~ "rocker/verse",
        .default = NA
    )

    if (is.na(image_prefix)) stop("Invalid r_mode. Valid choices are 'base', 'rstudio, 'tidyverse', and 'tidystudio'")

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

    if (verbose == TRUE) {
        print("Start from the Rocker project image")
        Sys.sleep(0.5)
    }
    readr::write_lines(base_line, file = "Dockerfile")
    if (comments == TRUE) {
        readr::write_lines("# Use the base image maintained by the Rocker project", file = "Dockerfile", append = TRUE)
    }


    if (verbose == TRUE) {
        print("Prevent interactive prompts during package installation")
        Sys.sleep(0.5)
    }
    readr::write_lines(non_interactive_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE) {
        readr::write_lines("# Suppress interactive prompts during package installation", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("Install system libraries required for common R packages")
        Sys.sleep(0.5)
    }
    readr::write_lines(system_lib_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE) {
        readr::write_lines("# Update package lists and install system libraries needed for common R packages, then clean up to reduce image size", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("Create additional Linux user")
        Sys.sleep(0.5)
    }
    readr::write_lines(user_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE & !is.null(add_user)) {
        readr::write_lines("# Create the Linux user", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("Install Quarto and Markdown support")
        Sys.sleep(0.5)
    }
    readr::write_lines(quarto_install_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE & quarto_install_line == TRUE) {
        readr::write_lines("#Install required packages and libraries for Quarto and Rmarkdown", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print(glue::glue("Set working directory to {home_dir}"))
        Sys.sleep(0.5)
    }
    readr::write_lines(working_dir_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE) {
        readr::write_lines("# Set the working directory inside the container", file = "Dockerfile", append = TRUE)
    }


    if (verbose == TRUE) {
        print("Copy renv.lock files")
        Sys.sleep(0.5)
    }
    readr::write_lines(renv_lock_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE) {
        readr::write_lines("# Copy the renv lockfile from the host into the container", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("If required, copy data files from the host into the container")
        Sys.sleep(0.5)
    }
    readr::write_lines(data_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE & !is.null(data_file)) {
        readr::write_lines("# Optionally copy data files from the host into the container", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("If required, copy code files from the host into the container")
        Sys.sleep(0.5)
    }
    readr::write_lines(code_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE & !is.null(code_line)) {
        readr::write_lines("# Optionally copy script files from the host into the container", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print("If required, copy miscellaneous files from the host into the container")
        Sys.sleep(0.5)
    }
    readr::write_lines(misc_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE & !is.null(misc_line)) {
        readr::write_lines("# Optionally copy additiional files into the container", file = "Dockerfile", append = TRUE)
    }

    # Install the renv package from Posit's CRAN mirror & Restore the R package environment using the renv lockfile is tricky because there is more than two layers of quotations involved.

    if (verbose == TRUE) {
        print("Installs renv and restores project library")
        Sys.sleep(0.5)
    }


    readr::write_lines(
        readr::read_lines(system.file("extdata",
            "install_and_restore_packages.sh",
            package = "containr"
        )),
        file = "Dockerfile",
        append = TRUE
    )


    if (comments == TRUE) {
        readr::write_lines("# Restore the R package environment as specified in renv.lock", file = "Dockerfile", append = TRUE)
    }

    if (verbose == TRUE) {
        print(glue::glue("Expose port{expose_port} for the IDE"))
        Sys.sleep(0.5)
    }
    readr::write_lines(expose_line, file = "Dockerfile", append = TRUE)
    if (comments == TRUE) {
        readr::write_lines("# Expose port 8787, commonly used by RStudio Server", file = "Dockerfile", append = TRUE)
    }

    if (comments == TRUE & r_mode == "rstudio") {
        readr::write_lines(
            "#Run the container with docker run --rm -ti -u root -e PASSWORD=yourpassword -p 8787:8787 yourimage point your browser to localhost:8787 Log in with user/password rstudio/yourpassword",
            file = "Dockerfile",
            append = TRUE
        )
    }
}
