test_that("NULL file args are accepted and Dockerfile is written", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    expect_no_error(
        generate_dockerfile(
            r_version = "4.3.0",
            data_file = NULL, code_file = NULL, misc_file = NULL,
            output    = tmp
        )
    )
    expect_true(file.exists(file.path(tmp, "Dockerfile")))
})

test_that("Dockerfile is written to the specified output directory", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    generate_dockerfile(r_version = "4.3.0", output = tmp)

    expect_true(file.exists(file.path(tmp, "Dockerfile")))
})

test_that("Valid file args are accepted and Dockerfile is written", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    writeLines("x",      "script.R")
    writeLines("a,b",    "data.csv")
    writeLines("notes",  "notes.txt")

    expect_no_error(
        generate_dockerfile(
            r_version = "4.3.0",
            code_file = "script.R",
            data_file = "data.csv",
            misc_file = "notes.txt",
            output    = tmp
        )
    )
})

test_that("comments = TRUE and verbose = TRUE produce no errors", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    writeLines("x", "script.R")

    expect_no_error(
        generate_dockerfile(
            r_version = "4.3.0",
            code_file = "script.R",
            comments  = TRUE,
            verbose   = TRUE,
            output    = tmp
        )
    )
})

test_that("Nonexistent file args error with the argument name and 'does not exist'", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = "nope.R",      output = tmp), "code_file")
    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = "nope.R",      output = tmp), "does not exist")
    expect_error(generate_dockerfile(r_version = "4.3.0", data_file = "missing.csv", output = tmp), "data_file")
    expect_error(generate_dockerfile(r_version = "4.3.0", data_file = "missing.csv", output = tmp), "does not exist")
    expect_error(generate_dockerfile(r_version = "4.3.0", misc_file = "ghost.txt",   output = tmp), "misc_file")
    expect_error(generate_dockerfile(r_version = "4.3.0", misc_file = "ghost.txt",   output = tmp), "does not exist")
})

test_that("Directory supplied as file arg errors with the argument name and 'is a directory'", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    dir.create("adir")

    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = "adir", output = tmp), "code_file")
    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = "adir", output = tmp), "is a directory")
    expect_error(generate_dockerfile(r_version = "4.3.0", data_file = "adir", output = tmp), "data_file")
    expect_error(generate_dockerfile(r_version = "4.3.0", misc_file = "adir", output = tmp), "misc_file")
})

test_that("Non-character or length > 1 file args error with 'length-1 character path'", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines("ok", "one.R")
    writeLines("ok", "two.R")

    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = 123,              output = tmp), "length-1 character path")
    expect_error(generate_dockerfile(r_version = "4.3.0", code_file = c("one.R","two.R"), output = tmp), "length-1 character path")
    expect_error(generate_dockerfile(r_version = "4.3.0", data_file = TRUE,              output = tmp), "length-1 character path")
})

test_that("Invalid r_mode errors before any file or network operations", {
    tmp <- withr::local_tempdir()

    expect_error(
        generate_dockerfile(r_version = "4.3.0", r_mode = "shiny", output = tmp),
        "not a valid"
    )
    # Dockerfile must not have been created
    expect_false(file.exists(file.path(tmp, "Dockerfile")))
})

test_that("All valid r_mode values are accepted", {
    for (mode in names(containr:::.r_mode_registry)) {
        tmp <- withr::local_tempdir()
        writeLines('{"R":{"Version":"4.3.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
        withr::local_dir(tmp)
        local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
        local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
        local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")
        expect_error(
            generate_dockerfile(r_version = "4.3.0", r_mode = mode, output = tmp),
            NA,
            info = paste("r_mode =", mode)
        )
    }
})
