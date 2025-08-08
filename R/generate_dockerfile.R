#' Generate a Dockerfile for your R project
#'
#' @param verbose logical (TRUE or FALSE). Should generate_dockerfile() print out progress? By default, it will silently create a Dockerfile
#' @param r_version a character string indicated a version of R, i.e., "4.3.0". By default, it will grab the latest version of R available
#' @param data_file a character string indicating an optional name of a data file to be copied into the container
#' @param code_file a character string indicating an optional name of a script file to be copied into the container
#' @param home_dir a character string specifying the home directory inside the container
#' @param install_quarto logical (TRUE or FALSE). If TRUE it will include supporting packages and system libraries to support Quarto and RMarkdown.
#' @param expose_port a character string indicating in which port will RStudio Server be accessible. It defaults to 8787
#' @param r_mode a character string. Inspired by the images in the Rocker Project. The options are "base" for base R, tidyverse, rstudio for RStudio Server, tidystudio which is tidyverse plus TeX Live and some publishing-related R packages
#'
#' @param comments a logical (TRUE or FALSE). If TRUE, the Dockerfile generated will include comments detailing what each line does. If FALSE, the Dockerfile will be bare with only commands.
#'
#' @param misc_file a character string indicating an optional name of miscellaneous files to be copied into the container
#'
#' @param add_user a character string indicating an optional name of a linux user to be created inside the container
#'
#' @return invisibly returns NULL. This function is called for its side effects and does not return a value.
#' @export
#' @examples
#' # Basic Usage
#' \dontrun{generate_dockerfile()}
#' # Specify a tidyverse ready image
#' \dontrun{generate_dockerfile(r_mode = "tidyverse")}
#' # Specify an image with R 4.2.0 installed
#' \dontrun{generate_dockerfile(r_version = "4.2.0")}
generate_dockerfile <- function(
        verbose = FALSE,
        r_version = "latest",
        data_file = NULL,
        code_file = NULL,
        misc_file = NULL,
        add_user = NULL,
        home_dir = "/home",
        install_quarto = FALSE,
        expose_port = "8787",
        r_mode = "base",
        comments = FALSE){

#I want IDE to be base, tidyverse, rstudio, tidystudio (BOTH rstudio and tidyverse)
# I found the tidystudio version of the image is fuzzier than the other

    # Start from the latest RStudio Server image with R pre-installed

base_line <- dplyr::case_when(
    r_mode == "base" ~ glue::glue("FROM rocker/r-ver:{r_version}"),
    r_mode == "tidyverse" ~ glue::glue("FROM rocker/tidyverse:{r_version}"),
    r_mode == "rstudio" ~ glue::glue("FROM rocker/rstudio:{r_version}"),
    r_mode == "tidystudio" ~ glue::glue("FROM rocker/verse:{r_version}"),
        is.na(r_mode) ~ "base",
    .default = "base")

# base_line <- glue::glue("FROM rocker/rstudio:{r_version}")
# Prevent interactive prompts during package installation

non_interactive_line <- glue::glue("ENV DEBIAN_FRONTEND=noninteractive")

# Set the working directory inside the container
working_dir_line <- glue::glue("WORKDIR {home_dir}")

# Install system libraries required for common R packages and Quarto rendering
system_lib_line <- glue::glue("RUN apt-get update && apt-get install -y \\
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
    purrr::map_chr(data_file, ~glue::glue("COPY {.x} /home/data/{basename(.x)}"))
}

# Copy the optional code files (e.g., .qmd, .rmd, .R)

code_line <- if (is.null(code_file) || length(code_file) == 0) {
    ""
} else {
    purrr::map_chr(data_file, ~glue::glue("COPY {.x} /home/{basename(.x)}"))
}

# Copy the optional miscellaneous files (e.g., images, bash scripts, etc)

misc_line <- if (is.null(misc_file) || length(misc_file) == 0) {
    ""
} else {
    purrr::map_chr(data_file, ~glue::glue("COPY {.x} /home/{basename(.x)}"))
}

# Copy the optional user line (e.g., report or documentation)

user_line <- if (is.null(add_user) || length(add_user) == 0) {
    ""
} else {
    purrr::map_chr(add_user, ~glue::glue("RUN apt-get install -y sudo \\
&& useradd -m -d /home/{.x} -s /bin/bash {.x} \\
&& echo '{.x}:yourpassword' | chpasswd \\
&& echo '{.x} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \\
&& chown -R {.x}:{.x} /home/{.x}"))
}


# Expose the default port used by RStudio Server
expose_line <- ifelse(r_mode == "studio", glue::glue("EXPOSE {expose_port}"), "")

##########################
# Building the Dockerfile
##########################

if(verbose == TRUE) {
    print("Start from the Rocker project image")
    Sys.sleep(0.5)}
readr::write_lines(base_line, file = "Dockerfile")
if(comments == TRUE) {
    readr::write_lines("# Use the base image maintained by the Rocker project", file = "Dockerfile", append = TRUE)}


if(verbose == TRUE) {
    print("Prevent interactive prompts during package installation")
    Sys.sleep(0.5)}
readr::write_lines(non_interactive_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Suppress interactive prompts during package installation", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Install system libraries required for common R packages")
    Sys.sleep(0.5)}
readr::write_lines(system_lib_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Update package lists and install system libraries needed for common R packages, then clean up to reduce image size", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Create additional Linux user")
    Sys.sleep(0.5)}
readr::write_lines(user_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !is.null(add_user)) {
    readr::write_lines("# Create the Linux user", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Install Quarto and Markdown support")
    Sys.sleep(0.5)}
readr::write_lines(quarto_install_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & quarto_install_line == TRUE) {
    readr::write_lines("#Install required packages and libraries for Quarto and Rmarkdown", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print(glue::glue("Set working directory to {home_dir}"))
    Sys.sleep(0.5)}
readr::write_lines(working_dir_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Set the working directory inside the container", file = "Dockerfile", append = TRUE)}


if(verbose == TRUE) {
    print("Copy renv.lock files")
    Sys.sleep(0.5)}
readr::write_lines(renv_lock_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {readr::write_lines("# Copy the renv lockfile from the host into the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("If required, copy data files from the host into the container")
    Sys.sleep(0.5)}
readr::write_lines(data_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !is.null(data_file) ) {readr::write_lines("# Optionally copy data files from the host into the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("If required, copy code files from the host into the container")
    Sys.sleep(0.5)}
readr::write_lines(code_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !is.null(code_line)) {readr::write_lines("# Optionally copy script files from the host into the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("If required, copy miscellaneous files from the host into the container")
    Sys.sleep(0.5)}
readr::write_lines(misc_file, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !is.null(misc_line)) {readr::write_lines("# Optionally copy additiional files into the container", file = "Dockerfile", append = TRUE)}

# Install the renv package from Posit's CRAN mirror & Restore the R package environment using the renv lockfile is tricky because there is more than two layers of quotations involved.

if(verbose == TRUE) {
    print("Installs renv and restores project library")
    Sys.sleep(0.5)}

readr::write_lines(readr::read_lines(system.file("install_and_restore_packages.sh", package = "containr")), file = "Dockerfile", append = TRUE)

# readr::write_lines(readr::read_lines("inst/install_and_restore_packages.sh"), file = "Dockerfile",append = TRUE)
if(comments == TRUE) {readr::write_lines("# Restore the R package environment as specified in renv.lock", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print(glue::glue("Expose port{expose_port} for the IDE"))
    Sys.sleep(0.5)}
readr::write_lines(expose_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {readr::write_lines("# Expose port 8787, commonly used by RStudio Server", file = "Dockerfile", append = TRUE)}

if(comments == TRUE & r_mode == "rstudio" ) {readr::write_lines(
"#Run the container with docker run --rm -ti -u root -e PASSWORD=yourpassword -p 8787:8787 yourimage point your browser to localhost:8787 Log in with user/password rstudio/yourpassword",
file = "Dockerfile",
append = TRUE)}

}


