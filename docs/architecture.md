# Architecture

This document describes the module layout of moon-warc, the data flow
through the pipeline and the design decisions that shape the code.

## Module layout

The library is one MoonBit package. Each source file covers one
cohesive slice of the WARC 1.1 model:

| File | Responsibility |
| --- | --- |
| `version.mbt` | WARC version line recognition |
| `model.mbt` | Core model: `WarcField`, `WarcRecord`, version and MIME constants |
| `field.mbt` | Field-name token rules and case-insensitive lookup |
| `header.mbt` | Header-region parsing: version line + ordered named fields |
| `scanner.mbt` | Shared byte scanning helpers over header text |
| `framing.mbt` | Record framing: header, block, CRLF CRLF trailer |
| `content_length.mbt` | Content-Length extraction, deduplication, octet arithmetic |
| `decimal.mbt` | Overflow-safe decimal parsing |
| `date.mbt` | W3CDTF timestamps (WARC-Date grammar and accessors) |
| `uri.mbt` | `<uri>` form handling (never a file-system path) |
| `record.mbt` | Record-level accessors: record id, target URI, WARC-Type, date |
| `archive.mbt` | Whole-archive buffered parsing with limits |
| `decoder.mbt` | Incremental streaming decoder (feed/finish) |
| `writer.mbt` | Canonical serialization of a parsed record |
| `builder.mbt` | Programmatic record construction with build-time checks |
| `limits.mbt` | Resource limits (record count, block bytes, field count) |
| `error.mbt` | Structured error model: stage + kind + offsets + message |
| `digest.mbt` | Labelled digest parsing (`algorithm:value` grammar) |
| `validator.mbt` | Semantic validation: placement, value domains, archive-level rules |
| `segment.mbt` | Segmentation field parsing and segment-group validation |
| `index.mbt` | In-memory index: record id / target URI / type → indices |
| `stats.mbt` | Archive statistics: counts, bytes, type histogram, date range |
| `audit.mbt` | Advisory audit engine (`FindingSeverity`, `WarcFinding`) |
| `bytes.mbt` | Small byte helpers used across the pipeline |

Every module has a matching `*_test.mbt`; `truncation_test.mbt`
exercises cross-module behaviour (buffered parser vs streaming decoder).

The `cli/` and `examples/` directories are separate executable
packages that consume the library the same way an external user would
(through the `@warc` package alias), which keeps the library's public
surface honest.

## Data flow

```
bytes ──► parse_archive ──► WarcArchive ──► validate_archive ──► Array[WarcError]
   │            │                  │
   │            │                  ├─► WarcIndex::build ──► queries
   │            │                  ├─► archive_stats ──► ArchiveStats
   │            │                  └─► audit_archive ──► Array[WarcFinding]
   │            └── WarcDecoder::feed/finish (streaming, same records)
   │
   └── WarcBuilder::build ──► WarcRecord ──► to_bytes (round-trip)
```

- **Parsing** produces an immutable `WarcArchive` of `WarcRecord`s;
  field order and original spelling are preserved.
- **Validation, indexing, statistics and auditing** are separate
  passes over a parsed archive, so partial or unknown data can still
  be inspected.
- **Building** constructs records programmatically; Content-Length is
  generated from the block, and illegal header values are rejected
  before serialization.
- **Errors** are structured: every `WarcError` carries a stage
  (lexical / framing / record / archive / builder / validator ...),
  a kind (machine-readable code), byte offsets and a message.

## Design decisions

1. **Content-Length is the only record delimiter.** The block is
   delimited exclusively by the declared Content-Length; the parser
   never scans for `WARC/1.1` or any other terminator inside a block.
   This is what makes blocks binary-safe (see `docs/security.md`).

2. **Unknown data is preserved, not rejected.** Unknown WARC-Type
   values and unknown fields parse fine; the validator skips
   type-dependent placement checks for unknown types (clause 5.5) but
   still checks value domains. Rejection only happens for framing and
   limit violations.

3. **Layered strictness.** The parser enforces framing, limits and
   Content-Length integrity. The validator enforces semantic rules
   (placement, value domains, segmentation, duplicate record ids).
   The audit engine only *advises* (missing digests, dangling
   references, empty payload blocks). Callers choose the layer.

4. **No hidden I/O.** The library performs no file-system, network or
   clock access. All input arrives as `Bytes`; the CLI is built on a
   fixed in-memory demo archive (see `docs/limitations.md`).

5. **Deterministic writer.** Serialization re-emits the parsed record
   in canonical form with generated Content-Length, so parse →
   write → parse is a stable identity.

6. **Resource limits everywhere.** Record count, block size and field
   count are bounded by `Limits`, enforced identically by the
   buffered parser and the streaming decoder, before allocation
   decisions are made.
