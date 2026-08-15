# Reproducibility

Everything in this repository is reproducible from source with a
single pinned toolchain and no network access at build time.

## Toolchain

- **MoonBit 0.1.20260713** (the `moon` CLI; module format `moon.mod` /
  `moon.pkg`).
- Dependencies: `moonbitlang/core` only (buffer, debug, encoding/utf8,
  env) — resolved by the toolchain, no third-party packages.
- No build-time code generation, no vendored data, no native
  subprocesses.

## Build and test

From the repository root:

```
moon fmt --check   # style
moon check         # type checking of every package
moon test --target wasm-gc
moon test --target js
moon test --target native
```

The whole verification, including the CLI and example entry points, is
a single script:

```
powershell -ExecutionPolicy Bypass -File verify_all.ps1
```

`.github/workflows/ci.yml` performs the same checks on every push to
`main` and every pull request (format, type check, three-target test
matrix, CLI and examples smoke runs).

## Determinism notes

- The library reads no clock, no environment and no filesystem;
  serialization output depends only on the parsed bytes.
- The CLI and examples operate on a fixed in-memory demo archive, so
  their output is byte-for-byte deterministic.
- The test suite uses fixed timestamps and fixed record ids; no test
  depends on execution order, wall time or locale.

## Reproducing a specific release

1. Check out the tag or commit.
2. Install MoonBit 0.1.20260713.
3. Run `verify_all.ps1` (or the CI steps above by hand).

Expected result: all checks pass and 208 tests pass on each target.
