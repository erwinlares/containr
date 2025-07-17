generate_dockerfile <- function(
        verbose = FALSE,
        r_version = "latest",
        data_file = NULL,
        code_file = NULL,
        home_dir = "/home",
        install_quarto = FALSE,
        expose_port = "8787",
        r_mode = "base",
        comments = FALSE){

#I want IDE to be base, tidyverse, rstudio, tidystudio (BOTH)
# I found the tidystudio version of the image is fuzzier than the other

    # Start from the latest RStudio Server image with R pre-installed

base_line <- case_when(
    r_mode == "base" ~ glue("FROM rocker/r-ver:{r_version}"),
    r_mode == "tidyverse" ~ glue("FROM rocker/tidyverse:{r_version}"),
    r_mode == "rstudio" ~ glue("FROM rocker/rstudio:{r_version}"),
    r_mode == "tidystudio" ~ glue("FROM rocker/verse:{r_version}"),
        is.na(r_mode) ~ "base",
    .default = "base")

# base_line <- glue("FROM rocker/rstudio:{r_version}")
# Prevent interactive prompts during package installation

non_interactive_line <- glue("ENV DEBIAN_FRONTEND=noninteractive")

# Set the working directory inside the container
working_dir_line <- glue("WORKDIR {home_dir}")

# Install system libraries required for common R packages and Quarto rendering
system_lib_line <- glue("RUN apt-get update && apt-get install -y \\
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
ifelse(install_quarto == TRUE, quarto_install_line <- glue("RUN wget -q https://quarto.org/download/latest/quarto-linux-amd64.deb \
    && gdebi --non-interactive quarto-linux-amd64.deb \
    && rm quarto-linux-amd64.deb"), quarto_install_line <- "")

# Copy the renv lockfile for reproducible R package environments
renv_lock_line <- glue("COPY renv.lock /home/renv.lock")

# Copy the dataset used in the analysis

data_line <- ifelse(is_null(data_file), "", glue("COPY {data_file} /home/data/{data_file}"))

# Copy the code files (e.g., report or documentation)
code_line <- ifelse(is_null(code_file), "", glue("COPY {code_file} /home/{code_file}"))

# Expose the default port used by RStudio Server
expose_line <- glue("EXPOSE {expose_port}")

##########################
# Building the Dockerfile
##########################

if(verbose == TRUE) {
    print("Start from the latest RStudio Server image with R pre-installed")
    Sys.sleep(0.5)}
readr::write_lines(base_line, file = "Dockerfile")
if(comments == TRUE) {
    readr::write_lines("# Use the latest base image maintained by the Rocker project", file = "Dockerfile", append = TRUE)}


if(verbose == TRUE) {
    print("Prevent interactive prompts during package installation")
    Sys.sleep(0.5)}
readr::write_lines(non_interactive_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Suppress interactive prompts during package installation", file = "Dockerfile", append = TRUE)}


if(verbose == TRUE) {
    print(glue("Set working directory to {home_dir}"))
    Sys.sleep(0.5)}
readr::write_lines(working_dir_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Set the working directory inside the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Install system libraries required for common R packages")
    Sys.sleep(0.5)}
readr::write_lines(system_lib_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {
    readr::write_lines("# Update package lists and install system libraries needed for common R packages, then clean up to reduce image size", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Install Quarto and Markdown support")
    Sys.sleep(0.5)}
readr::write_lines(quarto_install_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !quarto_install_line == "") {
    readr::write_lines("#Install required packages and libraries for Quarto and Rmarkdown", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("Copy renv.lock files")
    Sys.sleep(0.5)}
readr::write_lines(renv_lock_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {readr::write_lines("# Copy the renv lockfile from the host into the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("If required, copy data files from the host into the container")
    Sys.sleep(0.5)}
readr::write_lines(data_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !data_line == "" ) {readr::write_lines("# Optionally copy data files from the host into the container", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print("If required, copy code files from the host into the container")
    Sys.sleep(0.5)}
readr::write_lines(code_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE & !code_line == "") {readr::write_lines("# Optionally copy script files from the host into the container", file = "Dockerfile", append = TRUE)}

# Install the renv package from Posit's CRAN mirror & Restore the R package environment using the renv lockfile is tricky because there is more than two layers of quotations involved.

if(verbose == TRUE) {
    print("Installs renv and restores project library")
    Sys.sleep(0.5)}
readr::write_lines(read_lines("install_and_restore_packages.sh"), file = "Dockerfile",append = TRUE)
if(comments == TRUE) {readr::write_lines("# Restore the R package environment as specified in renv.lock", file = "Dockerfile", append = TRUE)}

if(verbose == TRUE) {
    print(glue("Expose port{expose_port} for the IDE"))
    Sys.sleep(0.5)}
readr::write_lines(expose_line, file = "Dockerfile", append = TRUE)
if(comments == TRUE) {readr::write_lines("# Expose port 8787, commonly used by RStudio Server", file = "Dockerfile", append = TRUE)}

if(comments == TRUE) {readr::write_lines("#Run the container with
# docker run --rm -ti -e PASSWORD=yourpassword -p 8787:8787 rocker/rstudio
#point your browser to localhost:8787
#Log in with user/password rstudio/yourpassword", file = "Dockerfile", append = TRUE)}

}


