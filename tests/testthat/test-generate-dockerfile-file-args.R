# tests/testthat/test-generate-dockerfile-file-args.R

test_that("NULL file args are accepted (public API)", {
    expect_error(
        generate_dockerfile(data_file = NULL, code_file = NULL, misc_file = NULL),
        NA
    )
})

test_that("Existing files are accepted and Dockerfile is written", {
    skip_on_cran()
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    writeLines("x", "script.R")
    writeLines("a,b\n1,2", "data.csv")
    writeLines("notes", "notes.txt")

    expect_error(
        generate_dockerfile(
            code_file = "script.R",
            data_file = "data.csv",
            misc_file = "notes.txt",
            comments = TRUE,
            verbose = TRUE
        ),
        NA
    )
    expect_true(file.exists("Dockerfile"))
})

test_that("Nonexistent files error clearly (public API)", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    expect_error(generate_dockerfile(code_file = "nope.R"), "code_file.*does not exist")
    expect_error(generate_dockerfile(data_file = "missing.csv"), "data_file.*does not exist")
    expect_error(generate_dockerfile(misc_file = "ghost.txt"), "misc_file.*does not exist")
})

test_that("Directories are rejected for file args (public API)", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    dir.create("adir")
    expect_error(generate_dockerfile(code_file = "adir"), "code_file.*is a directory")
    expect_error(generate_dockerfile(data_file = "adir"), "data_file.*is a directory")
    expect_error(generate_dockerfile(misc_file = "adir"), "misc_file.*is a directory")
})

test_that("Non-character or length > 1 paths are rejected (public API)", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("ok", "one.R")
    writeLines("ok", "two.R")
    expect_error(generate_dockerfile(code_file = 123), "length-1 character path")
    expect_error(generate_dockerfile(code_file = c("one.R", "two.R")), "length-1 character path")
})
