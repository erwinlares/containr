test_that(".validate_file_arg returns NULL for NULL input", {
    expect_null(containr:::.validate_file_arg("code_file", NULL))
    expect_null(containr:::.validate_file_arg("data_file", NULL))
    expect_null(containr:::.validate_file_arg("misc_file", NULL))
})

test_that(".validate_file_arg accepts a single existing file and returns a normalized path", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    writeLines("x", "ok.R")
    out <- containr:::.validate_file_arg("code_file", "ok.R")

    expect_type(out, "character")
    expect_length(out, 1L)
    expect_true(file.exists(out))
})

test_that(".validate_file_arg accepts a character vector of files and preserves order", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    writeLines("x", "one.R")
    writeLines("y", "two.R")
    out <- containr:::.validate_file_arg("code_file", c("one.R", "two.R"))

    expect_type(out, "character")
    expect_length(out, 2L)
    expect_equal(out, c("one.R", "two.R"))
    expect_true(all(file.exists(out)))
})

test_that(".validate_file_arg accepts a directory and returns its relative path", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    dir.create("assets")
    writeLines("x", file.path("assets", "logo.png"))

    out <- containr:::.validate_file_arg("misc_file", "assets")

    expect_type(out, "character")
    expect_length(out, 1L)
    expect_true(dir.exists(out))
})

test_that(".validate_file_arg accepts a vector mixing files and a directory", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    dir.create("assets")
    writeLines("x", "script.R")

    out <- containr:::.validate_file_arg("misc_file", c("script.R", "assets"))

    expect_length(out, 2L)
    expect_equal(out, c("script.R", "assets"))
})

test_that(".validate_file_arg rejects non-character input", {
    expect_error(containr:::.validate_file_arg("code_file", 123),       "character vector of paths")
    expect_error(containr:::.validate_file_arg("code_file", TRUE),      "character vector of paths")
    expect_error(containr:::.validate_file_arg("code_file", list("a")), "character vector of paths")
})

test_that(".validate_file_arg rejects a zero-length character vector", {
    expect_error(containr:::.validate_file_arg("code_file", character(0)), "character vector of paths")
})

test_that(".validate_file_arg rejects NA anywhere in the vector", {
    expect_error(containr:::.validate_file_arg("code_file", NA_character_), "character vector of paths")

    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("x", "ok.R")
    expect_error(
        containr:::.validate_file_arg("code_file", c("ok.R", NA_character_)),
        "character vector of paths"
    )
})

test_that(".validate_file_arg rejects a nonexistent file", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(containr:::.validate_file_arg("code_file", "nope.R"),      "does not exist")
    expect_error(containr:::.validate_file_arg("data_file", "missing.csv"), "does not exist")
    expect_error(containr:::.validate_file_arg("misc_file", "ghost.txt"),   "does not exist")
})

test_that(".validate_file_arg rejects a vector if any element does not exist", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("x", "ok.R")

    expect_error(
        containr:::.validate_file_arg("code_file", c("ok.R", "nope.R")),
        "does not exist"
    )
})

test_that(".validate_file_arg error messages include the argument name", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(containr:::.validate_file_arg("data_file", "missing.csv"), "data_file")
    expect_error(containr:::.validate_file_arg("misc_file", "ghost.txt"),   "misc_file")
})
