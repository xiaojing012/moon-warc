# WARC 1.1 Specification Map

The authoritative source for this project's behavior is the WARC 1.1
specification (ISO 28500:2017), maintained publicly by the IIPC at
https://iipc.github.io/warc-specifications/specifications/warc-format/warc-1.1/

This table maps specification clauses to their implementation and tests.
It is updated as implementation proceeds; entries marked *planned* are
not yet implemented.

| Spec clause | Requirement | Implementation | Tests |
| --- | --- | --- | --- |
| 4, `warc-record` ABNF | `header CRLF block CRLF CRLF` framing; version line first | `version.mbt`, `framing.mbt` | `version_test.mbt`, `framing_test.mbt` |
| 4, archive structure | One or more records back to back; trailing bytes that cannot form a complete record are diagnosed; archive-level size and record-count limits | `archive.mbt` | `archive_test.mbt` |
| 4, archive structure (streaming) | Chunking-independent incremental decoding; the block boundary comes from Content-Length only and is never scanned | `decoder.mbt` | `decoder_test.mbt` |
| 4, archive structure (writing) | Canonical record serialization; Content-Length generated from the block and always consistent with it | `writer.mbt`, `builder.mbt` | `writer_test.mbt` |
| 4, `named-field` ABNF | `field-name ":" [ field-value ]`, token names, UTF-8 values, continuation lines | `field.mbt`, `header.mbt` | `fields_test.mbt`, `headers_test.mbt` |
| 4, grammar notes | Field names case-insensitive; unknown fields ignored; LWS before values; CRLF line endings; binary-safe block framing via Content-Length only | `field.mbt`, `header.mbt`, `scanner.mbt`, `framing.mbt` | `fields_test.mbt`, `headers_test.mbt`, `scanner_test.mbt`, `framing_test.mbt` |
| 5.1, named fields | WARC fields shall not repeat except WARC-Concurrent-To | `validator.mbt` | `validator_test.mbt` |
| 5.2, WARC-Record-ID (mandatory) | Legal URI, written `<uri>`, no internal whitespace | `record.mbt`, `uri.mbt` | `record_test.mbt`, `uri_test.mbt` |
| 5.3, Content-Length (mandatory) | `1*DIGIT` octet count; `0` for no block; overflow-safe; not repeatable | `decimal.mbt`, `content_length.mbt` | `decimal_test.mbt`, `content_length_test.mbt` |
| 5.4, WARC-Date (mandatory) | W3CDTF UTC timestamp; fractional seconds 1..9 digits; multiple granularities | `date.mbt`, `record.mbt` | `date_test.mbt`, `record_test.mbt` |
| 5.5, WARC-Type (mandatory) | Eight standard types; unknown types skipped by readers | `record.mbt`, `validator.mbt` | `record_test.mbt`, `validator_test.mbt` |
| 5.6, Content-Type | MIME type of block; recommended for non-empty blocks except continuation | advisory `missing-content-type` finding in `audit.mbt` | `audit_test.mbt` |
| 5.7, WARC-Concurrent-To | Repeatable; forbidden in warcinfo/conversion/continuation | `validator.mbt` | `validator_test.mbt` |
| 5.8 / 5.9, digests | `algorithm:value` labelled digest (token syntax) | `digest.mbt`, `validator.mbt` | `digest_test.mbt`, `validator_test.mbt` |
| 5.10, WARC-IP-Address | IPv4/IPv6 forms; forbidden in warcinfo/conversion/continuation | `validator.mbt` | `validator_test.mbt` |
| 5.11-5.13, WARC-Refers-To(-Target-URI/-Date) | URI forms; type-restricted use | `validator.mbt` | `validator_test.mbt` |
| 5.14, WARC-Target-URI | Required on response/resource/request/revisit/conversion/continuation; forbidden on warcinfo | `<uri>` parsing: `record.mbt`, `uri.mbt`; type placement: `validator.mbt` | `record_test.mbt`, `uri_test.mbt`, `validator_test.mbt` |
| 5.15, WARC-Truncated | `length`/`time`/`disconnect`/`unspecified` reason tokens | `validator.mbt` | `validator_test.mbt` |
| 5.16, WARC-Warcinfo-ID | URI form; allowed on all types except warcinfo | `validator.mbt` | `validator_test.mbt` |
| 5.17, WARC-Filename | warcinfo only | `validator.mbt` | `validator_test.mbt` |
| 5.18, WARC-Profile | URI; mandatory on revisit | `validator.mbt` | `validator_test.mbt` |
| 5.19, WARC-Identified-Payload-Type | MIME type; payload records only | `validator.mbt` | `validator_test.mbt` |
| 5.20-5.22, segmentation fields | Segment-Number / Segment-Origin-ID / Segment-Total-Length placement | `segment.mbt`, `validator.mbt` | `segment_test.mbt` |
| 6, record types | warcinfo / response / resource / request / metadata / revisit / conversion / continuation | `record.mbt` | `record_test.mbt` |
| 6.6 revisit | WARC-Profile mandatory; two standard profiles; payload-digest rules | `validator.mbt` | `validator_test.mbt` |
| 7, record segmentation | First segment keeps type + number 1; continuations carry origin id, increasing number; last carries total length | `segment.mbt`, `validator.mbt` | `segment_test.mbt` |
| 8, MIME types | `application/warc`, `application/warc-fields` | constants in `model.mbt` (`WARC_MIME_TYPE`, `WARC_FIELDS_MIME_TYPE`) | `model_test.mbt` |

## Scope boundaries

- Compression (`.warc.gz`) is outside the core parser: callers
  decompress first, then feed the uncompressed byte stream.
- HTTP message payloads inside response/request records are treated as
  opaque bytes; no HTTP parser is included.
- No network access, no path extraction, no CDX/CDXJ/WACZ formats.
