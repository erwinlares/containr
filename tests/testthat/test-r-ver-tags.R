test_that(".get_r_ver_tags rejects an invalid r_mode", {
    expect_error(containr:::.get_r_ver_tags(r_mode = "invalid"), "not a valid")
    expect_error(containr:::.get_r_ver_tags(r_mode = "shiny"),   "not a valid")
    expect_error(containr:::.get_r_ver_tags(r_mode = ""),        "not a valid")
})

test_that(".get_r_ver_tags returns a list with image, tags, and source", {
    mock_response <- list(
        results = list(
            list(name = "latest"),
            list(name = "devel"),
            list(name = "4.4.0")
        ),
        `next` = NULL
    )

    with_mocked_bindings(
        GET = function(url) structure(list(), class = "response"),
        status_code = function(res) 200L,
        content = function(res) mock_response,
        {
            out <- containr:::.get_r_ver_tags(r_mode = "base")

            expect_type(out, "list")
            expect_named(out, c("image", "tags", "source"))
            expect_equal(out$image, "rocker/r-ver")
            expect_contains(out$tags, c("latest", "devel", "4.4.0"))
            expect_type(out$source, "character")
        },
        .package = "httr"
    )
})

test_that(".get_r_ver_tags maps r_mode to the correct image name", {
    mock_response <- list(results = list(list(name = "4.4.0")), `next` = NULL)

    with_mocked_bindings(
        GET = function(url) structure(list(), class = "response"),
        status_code = function(res) 200L,
        content = function(res) mock_response,
        {
            expect_equal(containr:::.get_r_ver_tags("base")$image,       "rocker/r-ver")
            expect_equal(containr:::.get_r_ver_tags("rstudio")$image,    "rocker/rstudio")
            expect_equal(containr:::.get_r_ver_tags("tidyverse")$image,  "rocker/tidyverse")
            expect_equal(containr:::.get_r_ver_tags("tidystudio")$image, "rocker/verse")
        },
        .package = "httr"
    )
})

test_that(".get_r_ver_tags aborts on non-200 HTTP status", {
    with_mocked_bindings(
        GET = function(url) structure(list(), class = "response"),
        status_code = function(res) 429L,
        {
            expect_error(containr:::.get_r_ver_tags(), "Docker Hub API request failed")
        },
        .package = "httr"
    )
})
