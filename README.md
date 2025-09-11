
<!-- README.md is generated from README.Rmd. Please edit that file -->

# containr

<!-- badges: start -->

[![R-CMD-check](https://github.com/erwinlares/containr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/erwinlares/containr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of containr is to help automate the process of containerizing R
projects. Its core function, generate_dockerfile(), analyzes an R
project’s environment and dependencies—via renv::renv.lock—and generates
a ready-to-use Dockerfile that encapsulates the computational setup. The
package is designed to assist researchers in building portable and
consistent workflows, ensuring that analyses can be reliably shared,
archived, and rerun across systems.

## Installation

You can install the development version of containr from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("erwinlares/containr")
```

Examples

Below are some common ways you can use generate_dockerfile():

``` r
library(containr)

# Generate a Dockerfile with the latest R version and renv.lock dependencies
generate_dockerfile()

# Specify a particular R version
generate_dockerfile(r_version = "4.3.0")

# Use an RStudio Server image
generate_dockerfile(r_mode = "rstudio")

# Print progress messages during generation
generate_dockerfile(verbose = TRUE)
#> [1] "Start from the Rocker project image"
#> [1] "Prevent interactive prompts during package installation"
#> [1] "Install system libraries required for common R packages"
#> [1] "Create additional Linux user"
#> [1] "Install Quarto and Markdown support"
#> Set working directory to /home
#> [1] "Copy renv.lock files"
#> [1] "If required, copy data files from the host into the container"
#> [1] "If required, copy code files from the host into the container"
#> [1] "If required, copy miscellaneous files from the host into the container"
#> [1] "Installs renv and restores project library"
#> Expose port8787 for the IDE

# Add explanatory comments to the generated Dockerfile
generate_dockerfile(comments = TRUE)
```
