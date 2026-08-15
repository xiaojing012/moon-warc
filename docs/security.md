# Security Notes

WARC files are untrusted input: they come from crawls of the open web,
from third-party archives and from migration pipelines. The following
invariants are design requirements, not incidental behaviour.

## Block boundaries come from Content-Length only

The parser **never** scans block contents for `WARC/1.1`, `\r\n\r\n`
or any other terminator to find the end of a block. A block is exactly
the number of octets declared by Content-Length, which is parsed with
overflow-safe decimal arithmetic (`decimal.mbt`) and checked against
resource limits before any block bytes are consumed.

This means a malicious record whose block contains a fake
`WARC/1.1\r\n...` header cannot desynchronise the parser: the fake
line is block content, not a record boundary. `truncation_test.mbt`
asserts this explicitly for every truncation point.

## Header values are data, never code or paths

- **WARC-Target-URI is never treated as a file-system path.** The
  library never joins, opens, creates or deletes anything from a
  target URI. `uri.mbt` only performs grammar checks, and the index
  compares URIs as opaque strings.
- Field names are validated against the token grammar
  (`valid_field_name`) before being used for anything; values are
  plain strings.
- The builder rejects CR/LF in field values at build time, so a
  caller-supplied value can never inject a header line.

## Resource limits

`Limits` bounds record count, block size and field count. The same
limits are enforced by `parse_archive` and `WarcDecoder` **before**
allocating or copying, and both read only the octets the declared
framing requires. This bounds memory growth on hostile input.

## No ambient capabilities

The library performs no file-system, network or subprocess access and
reads no environment or clock. A caller that exposes the library to
untrusted archives does not thereby expose the host to anything beyond
CPU and memory use, both of which are limit-bounded.

## Scope

moon-warc is a parsing and analysis library. It does not authenticate
archives (digest *syntax* is checked; digest *verification* would
require a hash implementation, which this version does not include —
see `docs/limitations.md`), nor does it sandbox or de-compress
content blocks. Consumers that un-gzip or render archived payloads
must treat them as untrusted content.

Security issues should be reported privately to the repository owner;
see `CONTRIBUTING.md`.
