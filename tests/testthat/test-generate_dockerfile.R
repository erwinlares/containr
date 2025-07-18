test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})

# test_that("Folder is a proper R project", {
#     expect_equal(any(grepl("\\.Rproj$", list.files(path = "."))), TRUE)
# })
#
# test_that("Project folder contains a .lock file managing package dependencies", {
#     expect_equal(file.exists("./renv.lock"), TRUE)
# })
