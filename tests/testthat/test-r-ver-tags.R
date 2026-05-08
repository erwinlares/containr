test_that(".get_r_ver_tags rejects an invalid r_mode", {
    expect_error(containr:::.get_r_ver_tags(r_mode = "invalid"), "not a valid")
    expect_error(containr:::.get_r_ver_tags(r_mode = "shiny"),   "not a valid")
    expect_error(containr:::.get_r_ver_tags(r_mode = ""),        "not a valid")
})

test_that(".get_r_ver_tags returns a list with image, tags, and source", {
    mock_body <- list(
        results = list(
            list(name = "latest"),
            list(name = "devel"),
            list(name = "4.4.0")
        ),
        `next` = NULL
    )
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform    = function(...) fake_resp,
        resp_status    = function(...) 200L,
        resp_body_json = function(...) mock_body,
        {
            out <- containr:::.get_r_ver_tags(r_mode = "base")

            expect_type(out, "list")
            expect_named(out, c("image", "tags", "source"))
            expect_equal(out$image, "rocker/r-ver")
            expect_contains(out$tags, c("latest", "devel", "4.4.0"))
            expect_type(out$source, "character")
        },
        .package = "httr2"
    )
})

test_that(".get_r_ver_tags maps r_mode to the correct image name", {
    mock_body <- list(results = list(list(name = "4.4.0")), `next` = NULL)
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform    = function(...) fake_resp,
        resp_status    = function(...) 200L,
        resp_body_json = function(...) mock_body,
        {
            expect_equal(containr:::.get_r_ver_tags("base")$image,       "rocker/r-ver")
            expect_equal(containr:::.get_r_ver_tags("rstudio")$image,    "rocker/rstudio")
            expect_equal(containr:::.get_r_ver_tags("tidyverse")$image,  "rocker/tidyverse")
            expect_equal(containr:::.get_r_ver_tags("tidystudio")$image, "rocker/verse")
        },
        .package = "httr2"
    )
})

test_that(".get_r_ver_tags aborts on non-200 HTTP status", {
    # Mock httr2::req_perform to return a fake response with status 429
    fake_resp <- structure(
        list(status_code = 429L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )
    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 429L,
        {
            expect_error(containr:::.get_r_ver_tags(), "Docker Hub API request failed")
        },
        .package = "httr2"
    )
})
