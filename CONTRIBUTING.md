# Contributing

Thanks for your interest in moon-warc. This is a small, focused
library; contributions that fit its scope are welcome.

## Toolchain

- MoonBit 0.1.20260819 or later.
- Windows: `powershell -ExecutionPolicy Bypass -File verify_all.ps1`.
  If `moon` is not on `PATH`, pass `-Moon <path-to-moon.exe>`.
- Linux/macOS: run the same strict steps by hand (`moon fmt --check`,
  `moon info`, `moon check --target all --deny-warn`,
  `moon build --target all`, `moon test --target all --deny-warn`).

## Development rules

1. **One commit per feature.** Each commit must pass the full test
   matrix on all four targets before it is pushed. No empty commits,
   no rebasing/squashing of published history, no backdating.
2. **Tests with every feature.** The matching `*_test.mbt` grows with
   the module; behavioural changes update tests in the same commit.
3. **Match the surrounding style.** MoonBit formatting (`moon fmt`),
   `///|` doc comments on public items, lowercase file-scoped helper
   names, and the error conventions in `error.mbt`.
4. **Honour the invariants in `docs/security.md`.** In particular:
   record delimiting stays Content-Length-only, and
   WARC-Target-URI is never treated as a file-system path.
5. **Keep the specification map honest.** Update
   `docs/specification-map.md` whenever a clause's implementation
   status changes.

## Reporting issues

- Bugs: include the smallest WARC input that reproduces the problem
  and the structured error it produces.
- Security: report privately to the repository owner first; do not
  open a public issue for a suspected vulnerability.

## Pull requests

- Branch from `main`, keep commits reviewable, describe what changed
  and why in the PR body.
- CI runs fmt/check/tests on every PR; a red PR is not merged.
- New public API needs a rationale: moon-warc prefers a small surface
  that matches ISO 28500:2017 clause by clause.
