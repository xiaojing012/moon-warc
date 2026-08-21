# Changelog

All notable changes to moon-warc are recorded here. The project follows
a commit-by-feature discipline: every entry below is a real, pushed
commit whose full test suite passed on `wasm`, `wasm-gc`, `js` and `native`
before it was made.

## 0.1.0

First public Mooncakes release. The release contains 208 tests on each of the
four MoonBit targets and the following development commits (oldest first):

- **chore: initialize WARC core model and safe parsing foundations** —
  project skeleton: module metadata, license, core model
  (`WarcField`/`WarcRecord`), structured error model, resource
  limits, byte helpers and overflow-safe decimal parsing.
- **feat: parse WARC version lines and ordered record fields** —
  `WARC/1.1` version recognition; field-name token grammar with
  case-insensitive lookup; ordered named-field header parsing.
- **feat: parse Content-Length and frame binary-safe records** —
  mandatory Content-Length handling, duplicate detection, header +
  block + CRLF CRLF framing that never scans inside blocks.
- **feat: add record types and mandatory field helpers** — the eight
  standard WARC types plus record id, target URI, date and payload
  type accessors.
- **feat: parse complete WARC archives** — whole-archive buffered
  parsing with trailing-garbage diagnosis and archive-level limits.
- **feat: streaming WarcDecoder with chunking-independent results** —
  incremental `feed`/`finish` decoder whose output does not depend on
  chunk boundaries.
- **feat: record writer and builder with round-trip tests** —
  canonical serialization and a programmatic builder that rejects
  illegal headers before writing.
- **feat: semantic validator and labelled digest parsing** —
  specification validator (placement, value domains, duplicates) and
  the `algorithm:value` digest grammar.
- **feat: segmentation parsing and archive-level validation** —
  Segment-Number / Segment-Origin-ID / Segment-Total-Length with
  archive-level segment-group rules and record-id duplication checks.
- **feat: archive indexing, querying and aggregate statistics** —
  in-memory index by record id / target URI / type, plus
  `ArchiveStats` counts and date ranges.
- **feat: audit engine with advisory findings and truncation stress
  tests** — `FindingSeverity`/`WarcFinding` advisory audit, plus
  exhaustive truncation-point equivalence tests.
- **feat: CLI tool, examples and CI verification** — `cli/` command
  tool over a built-in demo archive, five runnable examples,
  `verify_all.ps1` one-shot verification and GitHub Actions CI.
