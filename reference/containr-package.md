# containr: Containerize Your 'R' Project

Provides tools for containerizing 'R' projects. Reads an 'renv' lock
file, generates a ready-to-use 'Dockerfile', builds the container image,
and pushes it to a registry. Generated 'COPY' instructions preserve the
local directory structure inside the container. Cross-platform builds
are supported via 'Docker' buildx for targeting 'linux/amd64' from ARM
hosts. Designed to help researchers build portable, reproducible
workflows that can be reliably shared, archived, and rerun across
systems. See R Core Team (2025) <https://www.R-project.org/>, Ushey et
al. (2025) <https://CRAN.R-project.org/package=renv>, and Docker Inc.
(2025) <https://www.docker.com/>.

## See also

Useful links:

- <https://github.com/erwinlares/containr>

- <https://erwinlares.github.io/containr/>

- Report bugs at <https://github.com/erwinlares/containr/issues>

## Author

**Maintainer**: Erwin Lares <erwin.lares@wisc.edu>
([ORCID](https://orcid.org/0000-0002-3284-828X))

Authors:

- Erwin Lares <erwin.lares@wisc.edu>
  ([ORCID](https://orcid.org/0000-0002-3284-828X))
