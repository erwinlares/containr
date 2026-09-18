# Apply one config-derived file argument default

Internal helper used by
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md).
Returns `current` unchanged whenever the caller already supplied it, or
whenever `config` had no opinion about this argument. Only when both are
true – the caller left it `NULL` and `config` derived a value – does
`derived` take effect, and, in `verbose` mode, get reported as having
come from `config` rather than from the call.

## Usage

``` r
.apply_config_default(current, derived, arg_name, config, verbose)
```

## Arguments

- current:

  The argument's current value (from the call).

- derived:

  The value
  [`.resolve_config_file_args()`](https://erwinlares.github.io/containr/reference/dot-resolve_config_file_args.md)
  derived for it, or `NULL`.

- arg_name:

  Character. The argument's name, for the `verbose` message.

- config:

  Character. Path to the config file, for the `verbose` message.

- verbose:

  Logical. Whether to report the substitution.

## Value

`current`, or `derived` when it applies.
