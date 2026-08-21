# Limitations

This is version 0.1.0. The following areas are deliberately out of
scope for this version; each one is listed with the reason and the
workaround where one exists.

## No file-system I/O

The MoonBit core library in use has no file I/O package. The library
itself takes `Bytes` in memory, which is the streaming-friendly
design; the `cli/` tool therefore operates on a built-in demo archive
instead of reading files. Workaround: feed bytes into `parse_archive`
or `WarcDecoder` from the host language's own I/O layer (for example
when calling the wasm-gc build from JavaScript or a native build from
C).

## No digest verification

The core library has no SHA-1/SHA-256. `digest.mbt` implements the
`algorithm:value` labelled-digest *grammar* and the validator checks
that syntax; actual hash verification of blocks is not performed.
Workaround: compute the digest in the host language and compare it
against `WARC-Block-Digest`.

## HTTP payloads are opaque bytes

WARC response/resource blocks usually wrap an HTTP exchange, but this
library treats blocks as arbitrary binary and performs no HTTP
parsing. WARC records therefore parse even when the embedded HTTP is
malformed, which matches the WARC 1.1 requirement that records are
delimited by Content-Length alone.

## No compression handling

WARC does not standardise payload compression. gzip (or any other
codec) handling of blocks is left to consumers; the library neither
detects nor inflates compressed blocks.

## No CDX/CDXJ/WACZ tooling

Derived index formats and the WACZ packaging format are out of scope
for this version. `index.mbt` provides in-memory WARC queries instead.

## No network access

The library never fetches URLs; `WARC-Target-URI` is data, not an
instruction to fetch.

## MoonBit-specific notes

- `WARC-Date` timestamps without a timezone offset are rejected as
  non-UTC (specification-compliant), even though some archives in the
  wild contain them.
- The CLI and examples need `moon run <package>`; standalone binaries
  require the MoonBit toolchain on the host.
