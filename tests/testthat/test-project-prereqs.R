test_that("A directory with a .Rproj file is recognised as an R project", {
    tmp <- withr::local_tempdir()
    writeLines("", file.path(tmp, "example.Rproj"))

    has_rproj <- any(grepl("\\.Rproj$", list.files(tmp, all.files = TRUE)))
    expect_true(has_rproj)
})

test_that("A directory without a .Rproj file is not recognised as an R project", {
    tmp <- withr::local_tempdir()

    has_rproj <- any(grepl("\\.Rproj$", list.files(tmp, all.files = TRUE)))
    expect_false(has_rproj)
})

test_that("A directory with renv.lock satisfies the lock file prerequisite", {
    tmp <- withr::local_tempdir()
    writeLines("{}", file.path(tmp, "renv.lock"))

    expect_true(file.exists(file.path(tmp, "renv.lock")))
})

test_that("A directory without renv.lock fails the lock file prerequisite", {
    tmp <- withr::local_tempdir()

    expect_false(file.exists(file.path(tmp, "renv.lock")))
})

test_that("generate_dockerfile() writes renv.lock COPY line into Dockerfile", {
    tmp <- withr::local_tempdir()

    generate_dockerfile(r_version = "4.3.0", output = tmp)

    dockerfile <- readLines(file.path(tmp, "Dockerfile"))
    expect_true(any(grepl("COPY renv\\.lock", dockerfile)))
})
