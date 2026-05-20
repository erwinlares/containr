# Internal wrapper for Sys.which()

.sys_which adds Sys.which() inside containr's namespace so that
local_mock_bindings() can be used

## Usage

``` r
.sys_which(tool)
```
