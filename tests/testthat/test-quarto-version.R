test_that(".get_quarto_version rejects non-character input", {
    expect_error(containr:::.get_quarto_version(123),           "single character string")
    expect_error(containr:::.get_quarto_version(TRUE),          "single character string")
    expect_error(containr:::.get_quarto_version(NA_character_), "single character string")
})

test_that(".get_quarto_version rejects length > 1 version vectors", {
    expect_error(
        containr:::.get_quarto_version(c("1.5.57", "1.6.39")),
        "single character string"
    )
})

test_that(".get_quarto_version resolves 'latest' by querying the releases API", {
    mock_body <- list(tag_name = "v1.5.57")
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform    = function(...) fake_resp,
        resp_status    = function(...) 200L,
        resp_body_json = function(...) mock_body,
        {
            out <- containr:::.get_quarto_version("latest")
            expect_equal(out, "1.5.57")
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version strips the leading 'v' from the resolved tag", {
    mock_body <- list(tag_name = "v1.6.39")
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform    = function(...) fake_resp,
        resp_status    = function(...) 200L,
        resp_body_json = function(...) mock_body,
        {
            expect_false(grepl("^v", containr:::.get_quarto_version("latest")))
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version aborts on non-200 status while resolving 'latest'", {
    fake_resp <- structure(
        list(status_code = 429L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 429L,
        {
            expect_error(
                containr:::.get_quarto_version("latest"),
                "Quarto releases API request failed"
            )
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version rejects malformed explicit version strings", {
    expect_error(containr:::.get_quarto_version("v1.5.57"),  "not a valid Quarto version format")
    expect_error(containr:::.get_quarto_version("1.5"),      "not a valid Quarto version format")
    expect_error(containr:::.get_quarto_version("latest2"),  "not a valid Quarto version format")
    expect_error(containr:::.get_quarto_version("quarto"),   "not a valid Quarto version format")
})

test_that(".get_quarto_version accepts a well-formed explicit version that exists", {
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 200L,
        {
            expect_equal(containr:::.get_quarto_version("1.5.57"), "1.5.57")
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version accepts a pre-release suffix", {
    fake_resp <- structure(
        list(status_code = 200L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 200L,
        {
            expect_equal(containr:::.get_quarto_version("1.7.1-beta"), "1.7.1-beta")
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version aborts with a clear message when the release does not exist", {
    fake_resp <- structure(
        list(status_code = 404L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 404L,
        {
            expect_error(
                containr:::.get_quarto_version("9.9.9"),
                "was not found"
            )
        },
        .package = "httr2"
    )
})

test_that(".get_quarto_version aborts on other non-200 statuses for an explicit version", {
    fake_resp <- structure(
        list(status_code = 500L, headers = list(), body = raw(0)),
        class = "httr2_response"
    )

    with_mocked_bindings(
        req_perform = function(...) fake_resp,
        resp_status = function(...) 500L,
        {
            expect_error(
                containr:::.get_quarto_version("1.5.57"),
                "Quarto releases API request failed"
            )
        },
        .package = "httr2"
    )
})
