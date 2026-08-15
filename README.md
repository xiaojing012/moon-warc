# moon-warc

A streaming WARC 1.1 (ISO 28500) parser, writer, validator, indexer and
audit toolkit for MoonBit.

- **Module:** `xiaojing012/moon-warc`
- **Version:** 0.1.0-dev
- **Repository:** https://github.com/xiaojing012/moon-warc
- **Applicant / Maintainer:** 宋晓静 / xiaojing012
- **Mooncakes:** not published yet

## Overview

WARC (Web ARChive) is the ISO-standard container format (ISO 28500:2017)
used by web archives, crawlers and digital-preservation systems to store
billions of harvested resources. A WARC file concatenates any number of
WARC records; each record carries a set of named fields plus an
arbitrary binary content block.

moon-warc implements the record framing and semantic layer of WARC 1.1
in pure MoonBit: binary-safe record framing, ordered named fields,
buffered and incremental streaming parsing, deterministic writing,
semantic validation, segmentation support, in-memory indexing, and an
advisory audit engine — with structured errors, resource limits and
cross-target tests along the way.

## Why WARC

- **Web archive interoperability** — read and write the format used by
  the Internet Archive, national libraries and Common Crawl;
- **Binary-safe streaming** — blocks are arbitrary bytes; parsing never
  depends on scanning for version strings;
- **Archival data processing** — record framing, validation, querying
  and statistics for offline analysis pipelines;
- **Reproducible data pipelines** — a deterministic writer/builder with
  no hidden clock or network access;
- **MoonBit ecosystem infrastructure** — a foundation for crawler
  storage layers, migration tools and archive inspection utilities.

## Record Structure

```
warc-record  = header CRLF block CRLF CRLF
header       = version warc-fields
version      = "WARC/1.1" CRLF
warc-fields  = *named-field CRLF
block        = *OCTET
```

## CLI and Examples

A small command-line entry point (`cli/`) operates on a built-in demo
archive (this build has no file-system I/O):

```
moon run cli help
moon run cli parse | validate | inspect | stats | audit
moon run cli query http://example.org/a
moon run cli build
```

Runnable examples (`examples/`) demonstrate each slice of the library:

```
moon run examples parse | build | validate | index | audit
```

## Development Status

Development version 0.1.0-dev. The complete record model, framing,
buffered parser, streaming decoder, writer/builder, semantic validator,
segmentation, indexing and statistics, and the audit engine are
implemented and covered by 207 tests on all three MoonBit targets
(wasm-gc, js, native); see `docs/` for the specification map,
architecture notes, limitations and the reproducibility guide.
`verify_all.ps1` runs the whole verification in one go.

## License

Apache License 2.0. See `LICENSE`.
