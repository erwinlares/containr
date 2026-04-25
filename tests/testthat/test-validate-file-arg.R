test_that(".validate_file_arg returns NULL for NULL input", {
    expect_null(containr:::.validate_file_arg("code_file", NULL))
    expect_null(containr:::.validate_file_arg("data_file", NULL))
    expect_null(containr:::.validate_file_arg("misc_file", NULL))
})

test_that(".validate_file_arg accepts an existing file and returns a normalized path", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    writeLines("x", "ok.R")
    out <- containr:::.validate_file_arg("code_file", "ok.R")

    expect_type(out, "character")
    expect_length(out, 1L)
    expect_true(file.exists(out))
})

test_that(".validate_file_arg rejects non-character input", {
    expect_error(containr:::.validate_file_arg("code_file", 123),       "length-1 character path")
    expect_error(containr:::.validate_file_arg("code_file", TRUE),      "length-1 character path")
    expect_error(containr:::.validate_file_arg("code_file", list("a")), "length-1 character path")
})

test_that(".validate_file_arg rejects length > 1 character vectors", {
    expect_error(
        containr:::.validate_file_arg("code_file", c("a.R", "b.R")),
        "length-1 character path"
    )
})

test_that(".validate_file_arg rejects NA", {
    expect_error(containr:::.validate_file_arg("code_file", NA_character_), "length-1 character path")
})

test_that(".validate_file_arg rejects a nonexistent file", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(containr:::.validate_file_arg("code_file", "nope.R"),      "does not exist")
    expect_error(containr:::.validate_file_arg("data_file", "missing.csv"),  "does not exist")
    expect_error(containr:::.validate_file_arg("misc_file", "ghost.txt"),    "does not exist")
})

test_that(".validate_file_arg rejects a directory", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    dir.create("adir")

    expect_error(containr:::.validate_file_arg("code_file", "adir"), "is a directory")
    expect_error(containr:::.validate_file_arg("data_file", "adir"), "is a directory")
    expect_error(containr:::.validate_file_arg("misc_file", "adir"), "is a directory")
})

test_that(".validate_file_arg error messages include the argument name", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(containr:::.validate_file_arg("data_file", "missing.csv"), "data_file")
    expect_error(containr:::.validate_file_arg("misc_file", "ghost.txt"),   "misc_file")
})
