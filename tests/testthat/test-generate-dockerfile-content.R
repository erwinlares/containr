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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "current", output = tmp)
    lines     <- read_dockerfile(tmp)
    r_ver_str <- as.character(getRversion())
    expect_true(any(grepl(paste0("FROM rocker/r-ver:", r_ver_str), lines, fixed = TRUE)))
})

test_that("generate_dockerfile() checks the R version against the resolved r_mode's own repository (C12)", {
    # .r_ver_exists()'s signature is function(version, r_mode = "base",
    # verbose = FALSE), but the call site previously never passed r_mode
    # through, so every mode's version was checked against rocker/r-ver
    # regardless of which image it would actually build FROM. A version
    # that exists in rocker/r-ver but not in, say, rocker/verse would pass
    # validation and only fail later, at the FROM instruction itself.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    captured_mode <- NULL
    local_mocked_bindings(
        `.r_ver_exists` = function(version, r_mode = "base", ...) {
            captured_mode <<- r_mode
            TRUE
        },
        .package = "containr"
    )

    generate_dockerfile(r_version = "4.3.0", r_mode = "verse", output = tmp)

    expect_equal(captured_mode, "verse")
})

test_that("the R-version-not-found error points at the resolved r_mode's own tag repository (C12)", {
    # Previously this error always pointed at rocker-project.org's r-ver
    # page even when the mode in question was, say, verse -- misleading
    # whenever the two repositories' available tags disagree.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`status`        = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(`.r_ver_exists` = function(...) FALSE, .package = "containr")

    tag_repo <- containr:::.r_mode_registry[["verse"]]$tag_repo

    expect_error(
        generate_dockerfile(r_version = "9.9.9", r_mode = "verse", output = tmp),
        tag_repo,
        fixed = TRUE
    )
})

# ---------------------------------------------------------------------------
# Standard Dockerfile instructions
# ---------------------------------------------------------------------------

test_that("Dockerfile contains ENV DEBIAN_FRONTEND=noninteractive", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("COPY renv\\.lock", lines)))
})

test_that("COPY renv.lock lands under custom home_dir, not a hardcoded /home (C10)", {
    # renv::restore() (in install_and_restore_packages.sh) resolves the
    # project from the working directory, which is home_dir, not from a
    # fixed location. COPY renv.lock /home/renv.lock only worked by
    # coincidence when home_dir was left at its own default of "/home";
    # passing home_dir = "/workspace" previously left the lockfile in
    # /home while the restore ran in /workspace and found nothing there.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^COPY renv\\.lock /workspace/renv\\.lock$", lines)))
    expect_false(any(grepl("/home/renv\\.lock", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# Path agreement across WORKDIR, COPY renv.lock, and copy_root (C22)
# ---------------------------------------------------------------------------
#
# Individually, one test asserts WORKDIR reflects home_dir, another asserts a
# COPY renv.lock line exists, and another asserts project files land under
# copy_root -- but nothing checked those results against each other, which
# is exactly how C10 stayed invisible: every individual assertion was true
# at once. This test parses one generated Dockerfile per r_mode and per
# home_dir and checks the relationships directly instead of re-deriving
# what each path "should" be.

test_that("renv.lock lands under WORKDIR and project files land under copy_root, for every r_mode and home_dir (C22)", {
    for (mode in names(containr:::.r_mode_registry)) {
        for (hd in c("/home", "/workspace")) {
            tmp <- withr::local_tempdir()
            writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
            withr::local_dir(tmp)
            local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
            local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
            local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

            writeLines("x", "script.R")

            generate_dockerfile(
                r_version = "4.3.0",
                r_mode    = mode,
                home_dir  = hd,
                code_file = "script.R",
                output    = tmp
            )
            lines <- read_dockerfile(tmp)
            info  <- paste("r_mode =", mode, "home_dir =", hd)

            workdir_line <- lines[grepl("^WORKDIR ", lines)]
            expect_length(workdir_line, 1)
            workdir <- sub("^WORKDIR ", "", workdir_line)
            expect_equal(workdir, hd, info = info)

            renv_copy_line <- lines[grepl("^COPY renv\\.lock ", lines)]
            expect_length(renv_copy_line, 1)
            renv_dest <- sub("^COPY renv\\.lock ", "", renv_copy_line)
            expect_equal(renv_dest, paste0(workdir, "/renv.lock"), info = info)

            # C24: NULL in the registry means "falls back to home_dir" --
            # resolve it the same way generate_dockerfile() itself does,
            # rather than asserting against the raw registry value.
            copy_root <- containr:::.r_mode_registry[[mode]]$copy_root
            if (is.null(copy_root)) copy_root <- hd
            script_copy_line  <- lines[grepl("^COPY script\\.R ", lines)]
            expect_length(script_copy_line, 1)
            script_dest <- sub("^COPY script\\.R ", "", script_copy_line)
            expect_true(startsWith(script_dest, paste0(copy_root, "/")), info = info)
        }
    }
})

# ---------------------------------------------------------------------------
# System libraries
# ---------------------------------------------------------------------------

test_that("Dockerfile contains apt-get install block when install_syslibs is supplied", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
# Empty renv.lock warning (C04)
# ---------------------------------------------------------------------------
#
# .read_renv_packages() returns character(0) for a renv.lock with no
# Packages recorded at all -- previously silent: .fetch_sysreqs()
# short-circuits on it, the image builds with only the baseline curl
# installed, and the build succeeds while the analysis inside it cannot
# run. generate_dockerfile() now warns whenever this happens, regardless
# of auto_syslibs, since an empty lockfile is a symptom of the project
# itself, not of skipping auto-detection.

test_that("generate_dockerfile() warns when renv.lock records no packages", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    expect_warning(
        generate_dockerfile(r_version = "4.3.0", output = tmp),
        "records no packages"
    )
})

test_that("generate_dockerfile() does not warn when renv.lock records packages", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    expect_no_warning(
        generate_dockerfile(r_version = "4.3.0", output = tmp)
    )
})

test_that("the empty-lockfile warning fires even when auto_syslibs = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    local_mocked_bindings(`status`        = function(...) list(synchronized = TRUE), .package = "renv")

    expect_warning(
        generate_dockerfile(r_version = "4.3.0", auto_syslibs = FALSE, output = tmp),
        "records no packages"
    )
})

test_that("the empty-lockfile warning mentions toolero as a runtime dependency", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    expect_warning(
        generate_dockerfile(r_version = "4.3.0", output = tmp),
        "toolero"
    )
})

# ---------------------------------------------------------------------------
# os_version derivation for sysreqs lookups (C14)
# ---------------------------------------------------------------------------
#
# .fetch_sysreqs() previously always received a hardcoded "22.04" default,
# regardless of r_version. generate_dockerfile() now derives os_version
# from the resolved r_version via the Rocker Project's own
# R-version-to-Ubuntu-release mapping, and passes it through explicitly,
# unless the caller overrides it with its own os_version argument.

test_that(".resolve_os_version() implements the Rocker Project's R-to-Ubuntu mapping", {
    expect_equal(containr:::.resolve_os_version("4.0.0"), "20.04")
    expect_equal(containr:::.resolve_os_version("4.1.3"), "20.04")
    expect_equal(containr:::.resolve_os_version("4.2.2"), "22.04")
    expect_equal(containr:::.resolve_os_version("4.3.3"), "22.04")
    expect_equal(containr:::.resolve_os_version("4.4.2"), "24.04")
    expect_equal(containr:::.resolve_os_version("4.4.5"), "24.04")
    # Just below each threshold still resolves to the previous release
    expect_equal(containr:::.resolve_os_version("4.2.1"), "20.04")
    expect_equal(containr:::.resolve_os_version("4.4.1"), "22.04")
    # latest/devel always track the newest known release
    expect_equal(containr:::.resolve_os_version("latest"), "24.04")
    expect_equal(containr:::.resolve_os_version("devel"), "24.04")
})

test_that("generate_dockerfile() derives os_version from r_version and passes it to .fetch_sysreqs()", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.4.5"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    local_mocked_bindings(`status`        = function(...) list(synchronized = TRUE), .package = "renv")

    captured_os_version <- NULL
    local_mocked_bindings(
        `.fetch_sysreqs` = function(packages, os_version = "22.04", ...) {
            captured_os_version <<- os_version
            character(0)
        },
        .package = "containr"
    )

    generate_dockerfile(r_version = "4.4.5", output = tmp)
    expect_equal(captured_os_version, "24.04")
})

test_that("generate_dockerfile()'s os_version argument overrides the derived value", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.4.5"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists` = function(...) TRUE, .package = "containr")
    local_mocked_bindings(`status`        = function(...) list(synchronized = TRUE), .package = "renv")

    captured_os_version <- NULL
    local_mocked_bindings(
        `.fetch_sysreqs` = function(packages, os_version = "22.04", ...) {
            captured_os_version <<- os_version
            character(0)
        },
        .package = "containr"
    )

    generate_dockerfile(r_version = "4.4.5", os_version = "23.10", output = tmp)
    expect_equal(captured_os_version, "23.10")
})

test_that("os_version is not derived or passed when auto_syslibs = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.4.5"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE, .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    local_mocked_bindings(
        `.fetch_sysreqs` = function(...) cli::cli_abort("should not be called"),
        .package = "containr"
    )

    expect_no_error(
        generate_dockerfile(r_version = "4.4.5", auto_syslibs = FALSE, output = tmp)
    )
})

# ---------------------------------------------------------------------------
# Quarto installation
# ---------------------------------------------------------------------------

test_that("Dockerfile contains Quarto install when install_quarto = TRUE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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

test_that("Quarto install uses curl and dpkg rather than wget and gdebi (C11)", {
    # Neither wget nor gdebi is present in rocker/r-ver, so install_quarto =
    # TRUE previously failed at build time on every r_mode unless something
    # in the lockfile happened to pull those two programs in as a side
    # effect. curl is already guaranteed present as a baseline syslib, so
    # the fetch step now uses curl -LO, and the install step uses dpkg -i
    # with an apt-get install -f fallback to resolve dependencies -- the
    # same two steps gdebi was a convenience wrapper for.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`      = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.get_quarto_version` = function(...) "1.5.57",    .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs`     = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`             = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", install_quarto = TRUE, output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^RUN curl -LO ", lines)))
    expect_true(any(grepl("dpkg -i quarto-1\\.5\\.57-linux-amd64\\.deb", lines)))
    expect_true(any(grepl("apt-get install -f", lines)))
    expect_false(any(grepl("wget", lines, fixed = TRUE)))
    expect_false(any(grepl("gdebi", lines, fixed = TRUE)))
})

test_that("Dockerfile omits Quarto install when install_quarto = FALSE", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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

test_that("expose_port warns even when explicitly set to the default value (C16)", {
    # The guard used to test expose_port != "8787", so explicitly passing
    # expose_port = "8787" under a non-rstudio r_mode -- an override that is
    # still ignored -- produced no warning at all. missing(expose_port) is
    # the honest test: it warns whenever an override was supplied, whatever
    # value it happens to be.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_warning(
        generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server",
                            expose_port = "8787", output = tmp),
        "only used when"
    )
})

test_that("expose_port does not warn when left at its default (not supplied)", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_no_warning(
        generate_dockerfile(r_version = "4.3.0", r_mode = "shiny_server", output = tmp)
    )
})

# ---------------------------------------------------------------------------
# extra_install (rstudio_shiny)
# ---------------------------------------------------------------------------

test_that("Dockerfile contains the Shiny Server install script for r_mode = 'rstudio_shiny'", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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

test_that("Dockerfile COPY destination tracks a custom home_dir for the four Phase 1 modes (C24)", {
    # Before C24, copy_root was hardcoded to the literal "/home" for base/
    # tidyverse/rstudio/verse, independent of home_dir. That only agreed
    # with home_dir's own default; passing home_dir = "/workspace"
    # previously left COPY destinations at /home while WORKDIR (and
    # therefore the running script) sat at /workspace. copy_root is now
    # NULL in the registry for these four modes, meaning "fall back to
    # home_dir", so the two now agree.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("a,b", "data.csv")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", data_file = "data.csv",
                        home_dir = "/workspace", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /workspace$", lines)))
    expect_true(any(grepl("COPY.*data\\.csv.*/workspace/.*data\\.csv", lines)))
    expect_false(any(grepl("/home/", lines, fixed = TRUE)))
})

test_that("Dockerfile COPY destination stays /home for the four Phase 1 modes when home_dir is left at its default", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    writeLines("a,b", "data.csv")
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(r_version = "4.3.0", data_file = "data.csv", output = tmp)
    lines <- read_dockerfile(tmp)
    expect_true(any(grepl("^WORKDIR /home$", lines)))
    expect_true(any(grepl("COPY.*data\\.csv.*/home/.*data\\.csv", lines)))
})

test_that("Dockerfile COPY destination is /srv/shiny-server for r_mode = 'shiny_server', ignoring home_dir", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"3.6.3"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.0.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.4.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"3.6.3"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
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
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    expect_no_message(
        generate_dockerfile(r_version = "4.3.0", verbose = FALSE, output = tmp)
    )
})

# ---------------------------------------------------------------------------
# Layer order (C13, tested per C21)
# ---------------------------------------------------------------------------
#
# renv_restore -- the single most expensive layer in the image -- used to sit
# below the data/code/misc COPY blocks, so editing one line of a project
# script invalidated Docker/Podman's cache for the COPY layer and, because
# renv_restore came after it, for the full package reinstall too. It's
# reordered now to sit immediately after renv_lock and before any project
# content is copied in, so an ordinary script edit only invalidates the COPY
# itself. Written as inequalities between block positions rather than as an
# expected full-file diff, so this survives future additions to the block
# list without needing to be rewritten (per the audit's own recommendation).

test_that("renv_restore runs right after renv_lock and before any project-content COPY, and syslibs before quarto", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`       = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.get_quarto_version` = function(...) "1.5.57",    .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs`      = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`              = function(...) list(synchronized = TRUE), .package = "renv")

    writeLines("x",   "script.R")
    writeLines("a,b", "data.csv")

    generate_dockerfile(
        r_version      = "4.3.0",
        code_file      = "script.R",
        data_file      = "data.csv",
        install_quarto = TRUE,
        output         = tmp
    )
    lines <- read_dockerfile(tmp)

    idx <- function(pattern) min(which(grepl(pattern, lines)))

    syslibs_idx      <- idx("^RUN apt-get update")
    quarto_idx       <- idx("QUARTO_VERSION")
    renv_lock_idx    <- idx("^COPY renv\\.lock ")
    renv_restore_idx <- idx("renv::restore\\(\\)")
    first_copy_idx   <- min(idx("^COPY script\\.R "), idx("^COPY data\\.csv "))

    expect_true(syslibs_idx      < quarto_idx)
    expect_true(renv_lock_idx    < renv_restore_idx)
    expect_true(renv_restore_idx < first_copy_idx)
})
