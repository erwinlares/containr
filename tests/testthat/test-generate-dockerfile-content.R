# tests/testthat/test-generate-dockerfile-content.R
#
# These tests assert on the *content* of the generated Dockerfile.
# Two sources of external dependencies are eliminated via mocking:
#   1. Docker Hub version checks -- .r_ver_exists() always returns TRUE
#   2. sysreqs API calls -- .fetch_sysreqs() always returns character(0)
#   3. renv::status() -- always returns a synchronized status
# Each test also writes a minimal renv.lock to its temp directory and
# changes the working directory there, satisfying the renv.lock requirement
# added in v0.1.3.9000.

read_dockerfile <- function(dir) {
    readLines(file.path(dir, "Dockerfile"))
}

# ---------------------------------------------------------------------------
# FROM line
# ---------------------------------------------------------------------------

test_that("Dockerfile starts with FROM rocker/r-ver for r_mode = 'base'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "base", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/r-ver:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'tidyverse'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "tidyverse", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/tidyverse:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'rstudio'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/rstudio:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'verse'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "verse", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/verse:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'shiny_server'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^FROM rocker/shiny:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line reflects r_mode = 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio_shiny", output = tmp)
    lines <- read_dockerfile(tmp)
    # rstudio_shiny is layered on rocker/rstudio, not a separate image
    expect_true(any(grepl("^FROM rocker/rstudio:4\\.3\\.0", lines)))
})

test_that("Dockerfile FROM line uses resolved current R version", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("ENV DEBIAN_FRONTEND=noninteractive", lines, fixed = TRUE)))
})

test_that("Dockerfile contains WORKDIR /home by default", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /home$", lines)))
})

test_that("Dockerfile WORKDIR reflects custom home_dir", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /workspace$", lines)))
})

test_that("Dockerfile contains COPY renv.lock line", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY renv\\.lock", lines)))
})

# ---------------------------------------------------------------------------
# System libraries
# ---------------------------------------------------------------------------

test_that("Dockerfile contains apt-get install block when install_syslibs is supplied", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", install_syslibs = "libxml2-dev", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("apt-get install", lines, fixed = TRUE)))
    expect_true(any(grepl("libxml2-dev", lines, fixed = TRUE)))
})

test_that("Dockerfile installs only baseline curl when install_syslibs = NULL", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", install_syslibs = NULL, output = tmp)
    # curl is on its own line inside the multi-line RUN block -- search full content
    dockerfile_content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(dockerfile_content, "apt-get install", fixed = TRUE)
    expect_match(dockerfile_content, "curl",            fixed = TRUE)
})

test_that("System lib block includes user-supplied libraries", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0",
                        install_syslibs = c("libcurl4-openssl-dev", "libxml2-dev", "libssl-dev"),
                        output = tmp)
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`      = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.get_quarto_version` = function(...) "1.5.57",    .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs`     = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`             = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", install_quarto = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("ENV QUARTO_VERSION=1\\.5\\.57", lines)))
    expect_true(any(grepl("quarto-cli/releases/download/v1\\.5\\.57/quarto-1\\.5\\.57-linux-amd64\\.deb", lines)))
})

test_that("Dockerfile omits Quarto install when install_quarto = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", install_quarto = FALSE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("QUARTO_VERSION", lines)))
    expect_false(any(grepl("quarto-cli/releases", lines)))
})

test_that("generate_dockerfile() passes quarto_version through to .get_quarto_version()", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    captured <- NULL
    local_mocked_bindings(
        `.get_quarto_version` = function(quarto_version, ...) {
            captured <<- quarto_version
            "1.6.39"
        },
        .package = "containr"
    )

    generate_dockerfile(r_version = "4.3.0", install_quarto = TRUE,
                        quarto_version = "1.6.39", output = tmp)

    expect_equal(captured, "1.6.39")
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("ENV QUARTO_VERSION=1\\.6\\.39", lines)))
})

test_that(".get_quarto_version() is not called when install_quarto = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(
        `.get_quarto_version` = function(...) cli::cli_abort("should not be called"),
        .package = "containr"
    )

    expect_no_error(
        generate_dockerfile(r_version = "4.3.0", install_quarto = FALSE, output = tmp)
    )
})

# ---------------------------------------------------------------------------
# EXPOSE port
# ---------------------------------------------------------------------------

test_that("Dockerfile contains EXPOSE 8787 when r_mode = 'rstudio'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 8787$", lines)))
})

test_that("Dockerfile omits EXPOSE when r_mode is not 'rstudio'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "base", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("^EXPOSE", lines)))
})

test_that("Dockerfile EXPOSE line reflects custom expose_port", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio",
                        expose_port = "9090", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 9090$", lines)))
})

test_that("Dockerfile contains EXPOSE 3838 when r_mode = 'shiny_server'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 3838$", lines)))
})

test_that("Dockerfile contains EXPOSE 8787 3838 when r_mode = 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio_shiny", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 8787 3838$", lines)))
})

test_that("expose_port override is ignored for shiny_server and rstudio_shiny", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_warning(
        generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server",
                            expose_port = "9090", output = tmp),
        "only used when"
    )
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^EXPOSE 3838$", lines)))
    expect_false(any(grepl("9090", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# extra_install (rstudio_shiny)
# ---------------------------------------------------------------------------

test_that("Dockerfile contains the Shiny Server install script for r_mode = 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio_shiny", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^RUN /rocker_scripts/install_shiny_server\\.sh$", lines)))
})

test_that("Dockerfile omits the Shiny Server install script for modes other than 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    for (mode in c("base", "rstudio", "shiny_server")) {
        generate_dockerfile(r_version = "4.3.0", r_mode = mode, output = tmp)
        lines <- read_dockerfile(tmp)
        expect_false(any(grepl("install_shiny_server\\.sh", lines)), info = paste("mode =", mode))
    }
})

# ---------------------------------------------------------------------------
# copy_root routing (shiny_server / rstudio_shiny)
# ---------------------------------------------------------------------------

test_that("Dockerfile COPY destination stays /home for the four Phase 1 modes even with a custom home_dir", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("a,b", "data.csv")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", data_file = "data.csv",
                        home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    # home_dir only drives WORKDIR -- COPY destination stays /home/, unchanged
    expect_true(any(grepl("^WORKDIR /workspace$", lines)))
    expect_true(any(grepl("COPY.*data\\.csv.*/home/.*data\\.csv", lines)))
})

test_that("Dockerfile COPY destination is /srv/shiny-server for r_mode = 'shiny_server', ignoring home_dir", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("shiny::shinyApp(ui = fluidPage(), server = function(input, output) {})", "app.R")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server",
                        code_file = "app.R", home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*app\\.R.*/srv/shiny-server/.*app\\.R", lines)))
})

test_that("Dockerfile COPY destination is /srv/shiny-server for r_mode = 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("shiny::shinyApp(ui = fluidPage(), server = function(input, output) {})", "app.R")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio_shiny",
                        code_file = "app.R", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*app\\.R.*/srv/shiny-server/.*app\\.R", lines)))
})

# ---------------------------------------------------------------------------
# Optional file COPY lines
# ---------------------------------------------------------------------------

test_that("Dockerfile contains COPY line for data_file", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("a,b", "data.csv")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", data_file = "data.csv", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*data\\.csv.*/home/.*data\\.csv", lines)))
})

test_that("Dockerfile contains COPY line for code_file", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("x <- 1", "script.R")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", code_file = "script.R", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*script\\.R.*/home/script\\.R", lines)))
})

test_that("Dockerfile contains COPY line for misc_file", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("notes", "notes.txt")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", misc_file = "notes.txt", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY.*notes\\.txt.*/home/notes\\.txt", lines)))
})

test_that("Dockerfile omits COPY data line when data_file = NULL", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", data_file = NULL, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("/home/data/", lines, fixed = TRUE)))
})

test_that("validate_file_arg errors when file is outside build context", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    outside <- withr::local_tempdir()
    writeLines("data", file.path(outside, "outside.csv"))
    expect_error(
        .validate_file_arg("data_file", file.path(outside, "outside.csv")),
        "outside the build context"
    )
})

# ---------------------------------------------------------------------------
# User creation
# ---------------------------------------------------------------------------

test_that("Dockerfile contains useradd when add_user is supplied", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", add_user = "analyst", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("useradd.*analyst", lines)))
})

test_that("Dockerfile omits useradd when add_user = NULL", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", add_user = NULL, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("useradd", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# Comments
# ---------------------------------------------------------------------------

test_that("Dockerfile contains comment lines when comments = TRUE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", comments = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^#", lines)))
})

test_that("Dockerfile omits comment lines when comments = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", comments = FALSE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_false(any(grepl("^#", lines)))
})

test_that("rstudio comments include docker run instructions when comments = TRUE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio",
                        comments = TRUE, output = tmp)
    content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(content, "docker run", fixed = TRUE)
})

test_that("shiny_server comments include docker run instructions when comments = TRUE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server",
                        comments = TRUE, output = tmp)
    content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(content, "-p 3838:3838", fixed = TRUE)
})

test_that("rstudio_shiny comments include both ports in the docker run instructions when comments = TRUE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", r_mode = "rstudio_shiny",
                        comments = TRUE, output = tmp)
    content <- paste(read_dockerfile(tmp), collapse = "\n")
    expect_match(content, "-p 8787:8787", fixed = TRUE)
    expect_match(content, "-p 3838:3838", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# Minimum R version for shiny_server / rstudio_shiny
# ---------------------------------------------------------------------------

test_that("generate_dockerfile errors for shiny_server/rstudio_shiny below R 4.0.0", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"3.6.3"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    for (mode in c("shiny_server", "rstudio_shiny")) {
        expect_error(
            generate_dockerfile(r_version = "3.6.3", r_mode = mode, output = tmp),
            "requires R",
            info = paste("r_mode =", mode)
        )
    }
})

test_that("generate_dockerfile succeeds for shiny_server/rstudio_shiny at exactly R 4.0.0", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.0.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    for (mode in c("shiny_server", "rstudio_shiny")) {
        expect_error(
            generate_dockerfile(r_version = "4.0.0", r_mode = mode, output = tmp),
            NA,
            info = paste("r_mode =", mode)
        )
    }
})

test_that("generate_dockerfile succeeds for shiny_server/rstudio_shiny with r_version = 'devel'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.4.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    for (mode in c("shiny_server", "rstudio_shiny")) {
        expect_error(
            generate_dockerfile(r_version = "devel", r_mode = mode, output = tmp),
            NA,
            info = paste("r_mode =", mode)
        )
    }
})

test_that("min_r_version does not affect the four Phase 1 modes at R 3.6.3", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"3.6.3"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    for (mode in c("base", "tidyverse", "rstudio", "verse")) {
        expect_error(
            generate_dockerfile(r_version = "3.6.3", r_mode = mode, output = tmp),
            NA,
            info = paste("r_mode =", mode)
        )
    }
})

# ---------------------------------------------------------------------------
# verbose produces messages
# ---------------------------------------------------------------------------

test_that("verbose = TRUE produces messages", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_message(
        generate_dockerfile(r_version = "4.3.0", verbose = TRUE, output = tmp)
    )
})

test_that("verbose = FALSE produces no messages", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_no_message(
        generate_dockerfile(r_version = "4.3.0", verbose = FALSE, output = tmp)
    )
})
