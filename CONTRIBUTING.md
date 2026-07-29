# Contributing to containr

Thank you for your interest in contributing to `containr`. This document
covers how to set up for development, how the test suite is organized, and
what to expect from the review process.

---

## Development setup

`containr` uses the standard R package development workflow:

```r
# Install development dependencies
install.packages(c("devtools", "testthat", "usethis"))

# Clone and open the project
usethis::create_from_github("erwinlares/containr")

# Run the standard loop
devtools::document()
devtools::test()
devtools::check()
```

---

## Testing

`containr` wraps system commands (`podman`, `docker`) that cannot be tested
end-to-end without a running container daemon, real images, and, for
`push_image()`, a live registry. The test suite addresses this with a
three-layer strategy.

**Layer 1 -- Argument validation.** Pure R checks that bad arguments error
correctly and required arguments are enforced. These tests run on every
platform, including CRAN, with no external dependencies.

**Layer 2 -- Command construction.** Tests that the correct system command is
assembled from the supplied arguments. `dry_run = TRUE` causes functions to
print the command without running it. Mocked bindings intercept internal
container checks so these tests can run without Podman or Docker installed.

**Layer 3 -- Integration.** Tests that call real system commands against a
live container environment. These tests are guarded behind an explicit opt-in
environment variable:

```r
Sys.setenv(CONTAINR_INTEGRATION_TESTS = "true")
devtools::test()
```

Integration tests never run automatically on CRAN or CI. They are intended
for local pre-release verification. Before running them, confirm that:

- Podman or Docker is installed and running;
- a valid `renv.lock` exists in the test project directory;
- you are authenticated with the container registry if testing `push_image()`
  (run `podman login registry.doit.wisc.edu` once beforehand).

`push_image()`'s Layer 3 test additionally requires two environment
variables naming a real destination to push a throwaway test image to --
this is deliberate, so the test never guesses at or pushes to a project it
wasn't explicitly told about:

```r
Sys.setenv(
    CONTAINR_INTEGRATION_TESTS = "true",
    CONTAINR_TEST_NETID        = "your.netid",
    CONTAINR_TEST_PROJECT      = "your-test-project"
)
devtools::test()
```

---

## Code style

- Exported functions: `snake_case`
- Internal helpers: `.dot_prefix()`
- File names: `kebab-case.R`
- cli for all user-facing messages -- no bare `message()`, `warning()`, or
  `stop()` calls in exported functions
- Double hyphens (`--`) in cli messages rather than em dashes

---

## Submitting changes

1. Fork the repository and create a branch from `main`.
2. Make your changes and add tests for any new behavior.
3. Run `devtools::check()` and confirm 0 errors, 0 warnings, 0 notes.
4. Open a pull request with a clear description of what changed and why.

For significant changes, open an issue first to discuss the approach before
writing code.

---

## Reporting issues

Use the [GitHub issue tracker](https://github.com/erwinlares/containr/issues).
Include a minimal reproducible example where possible, the output of
`sessionInfo()`, and the version of Podman or Docker you are using.
