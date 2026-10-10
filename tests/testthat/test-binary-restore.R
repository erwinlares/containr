# tests/testthat/test-binary-restore.R
#
# generate_dockerfile(binary_packages = ) and its helpers. The external
# dependencies are mocked the same way as in test-generate-dockerfile-
# content.R: no Docker Hub, no sysreqs API, no renv::status().

write_lock <- function(dir, r_version) {
    writeLines(
        sprintf('{"R":{"Version":"%s"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', r_version),
        file.path(dir, "renv.lock")
    )
}

generate_for_test <- function(tmp, detected = character(0), ...) {
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,          .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) detected,      .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
    generate_dockerfile(output = tmp, ...)
    readLines(file.path(tmp, "Dockerfile"))
}


# -- the default is a binary restore --------------------------------------------

test_that("the default restore step uses the Linux binary repository for the image's Ubuntu", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, r_version = "4.6.1")

    expect_true(any(grepl("install.packages('renv', repos = 'https://packagemanager.posit.co/cran/__linux__/noble/latest')", lines, fixed = TRUE)))
    expect_true(any(grepl("renv::restore(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/noble/latest'))", lines, fixed = TRUE)))
    expect_false(any(grepl('RUN R -e "renv::restore()"', lines, fixed = TRUE)))
})

test_that("binary_packages = FALSE keeps the source restore", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, r_version = "4.6.1", binary_packages = FALSE)

    expect_true(any(grepl("renv::restore()", lines, fixed = TRUE)))
    expect_false(any(grepl("__linux__", lines, fixed = TRUE)))
})

test_that("the codename follows r_version, so an older R gets an older codename", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.3.0")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, r_version = "4.3.0")

    expect_true(any(grepl("__linux__/jammy/latest", lines, fixed = TRUE)))
})

test_that("an os_version override steers the sysreqs lookup, never the binary repository", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    asked <- NULL
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE, .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(packages, os_version, ...) {
        asked <<- os_version
        character(0)
    }, .package = "containr")
    local_mocked_bindings(`status` = function(...) list(synchronized = TRUE), .package = "renv")

    generate_dockerfile(r_version = "4.6.1", os_version = "22.04", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))

    expect_equal(asked, "22.04")
    expect_true(any(grepl("__linux__/noble/latest", lines, fixed = TRUE)))
    expect_false(any(grepl("__linux__/jammy", lines, fixed = TRUE)))
})

test_that("ppm_snapshot picks a dated snapshot", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, r_version = "4.6.1", ppm_snapshot = "2026-10-07")

    expect_true(any(grepl("__linux__/noble/2026-10-07'", lines, fixed = TRUE)))
})

test_that("comments = TRUE describes the binary restore", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, r_version = "4.6.1", comments = TRUE)

    expect_true(any(grepl("precompiled Linux binaries", lines, fixed = TRUE)))
})

test_that("the detected system libraries stay in the image with binary_packages = TRUE", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    lines <- generate_for_test(tmp, detected = c("libfreetype6-dev", "libwebp-dev"),
                               r_version = "4.6.1")

    expect_true(any(grepl("libfreetype6-dev", lines, fixed = TRUE)))
    expect_true(any(grepl("libwebp-dev", lines, fixed = TRUE)))
})


# -- an Ubuntu release with no binary repository ----------------------------------

test_that("a release with no known codename warns and keeps the source restore", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    local_mocked_bindings(`.resolve_os_version` = function(...) "18.04", .package = "containr")

    expect_warning(
        lines <- generate_for_test(tmp, r_version = "4.6.1"),
        "No Posit Package Manager binary repository"
    )
    expect_true(any(grepl("renv::restore()", lines, fixed = TRUE)))
    expect_false(any(grepl("__linux__", lines, fixed = TRUE)))
})


# -- arguments and helpers ---------------------------------------------------------

test_that("invalid binary-restore arguments abort before anything is written", {
    expect_error(generate_dockerfile(binary_packages = NA), "binary_packages")
    expect_error(generate_dockerfile(binary_packages = "yes"), "binary_packages")
    expect_error(generate_dockerfile(ppm_snapshot = "yesterday"), "ppm_snapshot")
    expect_error(generate_dockerfile(ppm_snapshot = c("latest", "latest")), "ppm_snapshot")
})

test_that(".os_codename() maps the Rocker Ubuntu releases and returns NA for others", {
    expect_equal(containr:::.os_codename("20.04"), "focal")
    expect_equal(containr:::.os_codename("22.04"), "jammy")
    expect_equal(containr:::.os_codename("24.04"), "noble")
    expect_true(is.na(containr:::.os_codename("26.04")))
})

test_that(".binary_restore_instructions() returns the two RUN lines, or NULL without a codename", {
    expect_equal(
        containr:::.binary_restore_instructions("24.04", "2026-10-07"),
        c("RUN R -e \"install.packages('renv', repos = 'https://packagemanager.posit.co/cran/__linux__/noble/2026-10-07')\"",
          "RUN R -e \"renv::restore(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/noble/2026-10-07'))\"")
    )
    expect_null(containr:::.binary_restore_instructions("26.04"))
})


# -- the verbose breakdown of system libraries ------------------------------------

test_that("verbose mode breaks the system libraries down by where they came from", {
    tmp <- withr::local_tempdir()
    write_lock(tmp, "4.6.1")
    withr::local_dir(tmp)

    msgs <- testthat::capture_messages(
        generate_for_test(tmp, detected = "libpng-dev", r_version = "4.6.1",
                          install_syslibs = "libwebp-dev", verbose = TRUE)
    )
    txt <- paste(msgs, collapse = "\n")

    expect_match(txt, "1 baseline, 1 detected from", fixed = FALSE)
    expect_match(txt, "1 added through", fixed = FALSE)
})
