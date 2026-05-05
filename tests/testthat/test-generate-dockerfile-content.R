# tests/testthat/test-generate-dockerfile-content.R
#
# These tests assert on the *content* of the generated Dockerfile.
# Network calls to Docker Hub are eliminated by mocking .r_ver_exists()
# to return TRUE for any version string, keeping the suite fast and hermetic.

read_dockerfile <- function(dir) {
    readLines(file.path(dir, "Dockerfile"))
}

# ---------------------------------------------------------------------------
# FROM line
# ---------------------------------------------------------------------------

test_that("Dockerfile starts with FROM rocker/r-ver for r_mode = 'base'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "base", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/r-ver:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'tidyverse'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/tidyverse:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'rstudio'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/rstudio:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'tidystudio'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "tidystudio", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/verse:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line uses resolved current R version", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "current", output = tmp)
    lines     <- read_dockerfile(tmp)
    r_ver_str <- as.character(getRversion())
    expect_true(any(grepl(paste0("FROM rocker/r-ver:", r_ver_str), lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# Standard Dockerfile instructions
# ---------------------------------------------------------------------------

test_that("Dockerfile contains ENV DEBIAN_FRONTEND=noninteractive", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("ENV DEBIAN_FRONTEND=noninteractive", lines, fixed = TRUE)))
})

test_that("Dockerfile contains WORKDIR /home by default", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /home$", lines)))
})

test_that("Dockerfile WORKDIR reflects custom home_dir", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /workspace$", lines)))
})

test_that("Dockerfile contains COPY renv.lock line", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY renv\\.lock", lines)))
})

# ---------------------------------------------------------------------------
# System libraries
# ---------------------------------------------------------------------------

test_that("Dockerfile contains apt-get install block when install_syslibs = TRUE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", install_syslibs = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("apt-get install", lines, fixed = TRUE)))
})

test_that("Dockerfile omits apt-get install block when install_syslibs = FALSE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", install_syslibs = FALSE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("apt-get install", lines, fixed = TRUE)))
})

test_that("System lib block includes commonly required libraries", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", install_syslibs = TRUE, output = tmp)
    content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(content, "libcurl4-openssl-dev", fixed = TRUE)
    expect_match(content, "libxml2-dev",          fixed = TRUE)
    expect_match(content, "libssl-dev",            fixed = TRUE)
})

# ---------------------------------------------------------------------------
# Quarto installation
# ---------------------------------------------------------------------------

test_that("Dockerfile contains Quarto install when install_quarto = TRUE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", install_quarto = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("quarto-linux-amd64\\.deb", lines)))
})

test_that("Dockerfile omits Quarto install when install_quarto = FALSE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", install_quarto = FALSE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("quarto-linux-amd64\\.deb", lines)))
})

# ---------------------------------------------------------------------------
# EXPOSE port
# ---------------------------------------------------------------------------

test_that("Dockerfile contains EXPOSE 8787 when r_mode = 'rstudio'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 8787$", lines)))
})

test_that("Dockerfile omits EXPOSE when r_mode is not 'rstudio'", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "base", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("^EXPOSE", lines)))
})

test_that("Dockerfile EXPOSE line reflects custom expose_port", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio",
                        expose_port = "9090", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 9090$", lines)))
})

# ---------------------------------------------------------------------------
# Optional file COPY lines
# ---------------------------------------------------------------------------

test_that("Dockerfile contains COPY line for data_file", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("a,b", "data.csv")
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", data_file = "data.csv", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*data\\.csv.*/home/data/data\\.csv", lines)))
})

test_that("Dockerfile contains COPY line for code_file", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("x <- 1", "script.R")
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", code_file = "script.R", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*script\\.R.*/home/script\\.R", lines)))
})

test_that("Dockerfile contains COPY line for misc_file", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("notes", "notes.txt")
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", misc_file = "notes.txt", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*notes\\.txt.*/home/notes\\.txt", lines)))
})

test_that("Dockerfile omits COPY data line when data_file = NULL", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", data_file = NULL, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("/home/data/", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# User creation
# ---------------------------------------------------------------------------

test_that("Dockerfile contains useradd when add_user is supplied", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", add_user = "analyst", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("useradd.*analyst", lines)))
})

test_that("Dockerfile omits useradd when add_user = NULL", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", add_user = NULL, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("useradd", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# Comments
# ---------------------------------------------------------------------------

test_that("Dockerfile contains comment lines when comments = TRUE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", comments = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^#", lines)))
})

test_that("Dockerfile omits comment lines when comments = FALSE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", comments = FALSE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("^#", lines)))
})

test_that("rstudio comments include docker run instructions when comments = TRUE", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio",
                        comments = TRUE, output = tmp)
    content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(content, "docker run", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# verbose produces messages
# ---------------------------------------------------------------------------

test_that("verbose = TRUE produces messages", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    expect_message(
        generate_dockerfile(r_version = "4.3.0", verbose = TRUE, output = tmp)
    )
})

test_that("verbose = FALSE produces no messages", {
    tmp <- withr::local_tempdir()
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    expect_no_message(
        generate_dockerfile(r_version = "4.3.0", verbose = FALSE, output = tmp)
    )
})
