# Testing

Every module has a matching black-box test file in the same package.
The suite is run identically on all four MoonBit targets.

## Test matrix

| Test file | Count | Focus |
| --- | ---: | --- |
| `headers_test.mbt` | 17 | header-region edge cases |
| `record_test.mbt` | 16 | record accessors, record id / target URI / type / date |
| `validator_test.mbt` | 14 | placement, value domains, duplicate fields, archive rules |
| `archive_test.mbt` | 13 | buffered whole-archive parsing, trailing garbage |
| `decimal_test.mbt` | 13 | overflow-safe decimal parsing |
| `writer_test.mbt` | 13 | canonical serialization, round-trips |
| `decoder_test.mbt` | 12 | streaming feed/finish across chunk boundaries |
| `framing_test.mbt` | 12 | record framing, binary-safe blocks |
| `date_test.mbt` | 11 | W3CDTF grammar and accessors |
| `bytes_test.mbt` | 11 | shared byte helpers |
| `content_length_test.mbt` | 9 | Content-Length framing and limits |
| `fields_test.mbt` | 9 | field tokens, case-insensitive lookup |
| `scanner_test.mbt` | 8 | line/header scanning helpers |
| `index_test.mbt` | 7 | index build and queries |
| `error_test.mbt` | 6 | error stage/kind codes and rendering |
| `audit_test.mbt` | 6 | advisory findings |
| `segment_test.mbt` | 6 | segmentation parsing, group rules |
| `uri_test.mbt` | 5 | `<uri>` grammar |
| `model_test.mbt` | 5 | core model and constants |
| `limits_test.mbt` | 4 | resource limits |
| `digest_test.mbt` | 3 | labelled digest grammar |
| `version_test.mbt` | 5 | version line recognition |
| `truncation_test.mbt` | 3 | cross-module stress/property tests |

**Total: 208 tests** on each of `wasm`, `wasm-gc`, `js` and `native`.

## Cross-module stress tests

`truncation_test.mbt` holds the tests that deliberately cross module
boundaries:

- **Every truncation point** of a three-record archive (including a
  binary block containing a fake `WARC/1.1` line) must be handled by
  the streaming decoder exactly as the buffered parser handles it:
  both succeed, or both fail — never a silent partial success.
- **32 × 256-octet archive** parsed whole and fed byte-by-byte into
  the decoder; both paths must emit identical records.
- **Tight limits** (4 records / 32-octet blocks) must trip identically
  in the buffered parser and the streaming decoder.

## Running the tests

```
moon test --target all --deny-warn
```

or run everything (formatting, interface generation, strict four-target checks,
CLI and examples) with `verify_all.ps1`. CI runs the same steps on
every push (`.github/workflows/ci.yml`).
