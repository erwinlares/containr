## R CMD check results

0 errors | 0 warnings | 1 note

* checking for detritus in the temp directory: NOTE
  Found the following files/directories:
    'storage-run-754777108'

  This is a pre-existing directory created by Podman Desktop at system
  startup. It is present in tempdir() on this machine regardless of
  whether the package tests run. It does not appear on CRAN's check
  servers and is unrelated to the package.
