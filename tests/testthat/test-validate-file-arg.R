test_that(".validate_file_arg returns NULL for NULL", {
    expect_null(containr:::.validate_file_arg("code_file", NULL))
})

test_that(".validate_file_arg accepts an existing file and normalizes the path", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    writeLines("x", "ok.R")
    out <- containr:::.validate_file_arg("code_file", "ok.R")

    expect_true(is.character(out))
    expect_equal(length(out), 1L)
    expect_true(file.exists(out))
})

test_that(".validate_file_arg rejects invalid inputs", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    dir.create("adir")

    # wrong type / length
    expect_error(containr:::.validate_file_arg("code_file", 123), "length-1 character path")
    expect_error(containr:::.validate_file_arg("code_file", c("a", "b")), "length-1 character path")

    # nonexistent file
    expect_error(containr:::.validate_file_arg("code_file", "nope.R"), "does not exist")

    # directory instead of file
    expect_error(containr:::.validate_file_arg("code_file", "adir"), "is a directory")
})
