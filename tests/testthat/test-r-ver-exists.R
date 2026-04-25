test_that(".r_ver_exists rejects an invalid r_mode", {
    expect_error(containr:::.r_ver_exists("4.3.0", r_mode = "invalid"),    "not a valid")
    expect_error(containr:::.r_ver_exists("4.3.0", r_mode = "shiny"),      "not a valid")
    expect_error(containr:::.r_ver_exists("4.3.0", r_mode = ""),           "not a valid")
})

test_that(".r_ver_exists accepts all four valid r_mode values", {
    mock_tags <- list(image = "rocker/r-ver", tags = c("4.3.0"), source = "https://hub.docker.com/v2/repositories")

    with_mocked_bindings(
        `.get_r_ver_tags` = function(...) mock_tags,
        {
            for (mode in c("base", "rstudio", "tidyverse", "tidystudio")) {
                expect_error(
                    containr:::.r_ver_exists("4.3.0", r_mode = mode),
                    NA,
                    info = paste("r_mode =", mode)
                )
            }
        },
        .package = "containr"
    )
})

test_that(".r_ver_exists rejects non-character version input", {
    expect_error(containr:::.r_ver_exists(430),           "single character string")
    expect_error(containr:::.r_ver_exists(TRUE),          "single character string")
    expect_error(containr:::.r_ver_exists(NA_character_), "single character string")
})

test_that(".r_ver_exists rejects length > 1 version vectors", {
    expect_error(
        containr:::.r_ver_exists(c("4.3.0", "4.4.0")),
        "single character string"
    )
})

test_that(".r_ver_exists rejects malformed version strings", {
    expect_error(containr:::.r_ver_exists("R-4.3.0"),   "not a valid version format")
    expect_error(containr:::.r_ver_exists("4.3.0.1.2"), "not a valid version format")
    expect_error(containr:::.r_ver_exists("four"),      "not a valid version format")
    expect_error(containr:::.r_ver_exists("4.3.0 "),   "not a valid version format")
})

test_that(".r_ver_exists accepts well-formed version strings without error (format only)", {
    # These pass format validation — network call is skipped via mocking
    mock_tags <- list(image = "rocker/r-ver", tags = c("4.3.0", "latest", "devel"), source = "https://hub.docker.com/v2/repositories")

    with_mocked_bindings(
        `.get_r_ver_tags` = function(...) mock_tags,
        {
            expect_true(containr:::.r_ver_exists("4.3.0"))
            expect_true(containr:::.r_ver_exists("latest"))
            expect_true(containr:::.r_ver_exists("devel"))
            expect_false(containr:::.r_ver_exists("9.9.9"))
        },
        .package = "containr"
    )
})

test_that(".r_ver_exists accepts CUDA and Ubuntu variant tags", {
    mock_tags <- list(
        image  = "rocker/r-ver",
        tags   = c("4.4.0-cuda12.2", "4.4.0-cuda12.2-ubuntu22.04", "4.4.0-ubuntu22.04"),
        source = "https://hub.docker.com/v2/repositories"
    )

    with_mocked_bindings(
        `.get_r_ver_tags` = function(...) mock_tags,
        {
            expect_true(containr:::.r_ver_exists("4.4.0-cuda12.2"))
            expect_true(containr:::.r_ver_exists("4.4.0-cuda12.2-ubuntu22.04"))
            expect_true(containr:::.r_ver_exists("4.4.0-ubuntu22.04"))
        },
        .package = "containr"
    )
})
