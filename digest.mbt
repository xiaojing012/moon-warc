// Labelled digest values (ISO 28500:2017 clauses 5.8-5.9).
//
// WARC-Payload-Digest and WARC-Block-Digest carry an algorithm label
// (a token, conventionally `sha1`) followed by a colon and an encoded
// digest. This module parses that `algorithm:value` envelope and
// checks the value against the base-encoding alphabets. It does not
// compute digests: the MoonBit core library ships no hash primitive,
// so digest verification is deferred and documented in the
// limitations.

///|
/// A parsed labelled digest such as `sha1:B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR`.
pub struct WarcDigest {
  algorithm : String
  value : String
}

///|
/// Construct a labelled digest from its parts.
pub fn WarcDigest::new(algorithm : String, value : String) -> WarcDigest {
  { algorithm, value }
}

///|
/// The algorithm label (e.g. `sha1`).
pub fn WarcDigest::algorithm(self : WarcDigest) -> String {
  self.algorithm
}

///|
/// The encoded digest value.
pub fn WarcDigest::value(self : WarcDigest) -> String {
  self.value
}

///|
/// The canonical `algorithm:value` rendering.
pub fn WarcDigest::to_string(self : WarcDigest) -> String {
  "\{self.algorithm}:\{self.value}"
}

///|
/// A structured invalid-digest error.
fn bad_digest(record_index : Int64, context : String) -> WarcError {
  WarcError::new(
    WarcErrorStage::Digest,
    WarcErrorKind::InvalidDigest,
    0L,
    record_index,
    context,
  )
}

///|
/// True when the byte may appear in an encoded digest value: ASCII
/// letters and digits plus `+`, `/`, `=`, `-` and `_` cover the
/// base16/base32/base64 alphabets.
fn is_digest_byte(b : Byte) -> Bool {
  if is_digit(b) {
    return true
  }
  if (b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z') {
    return true
  }
  b == b'+' || b == b'/' || b == b'=' || b == b'-' || b == b'_'
}

///|
/// Parse a `algorithm:value` digest field value.
///
/// The algorithm must be a legal token, the separator a single colon,
/// and the value non-empty and made only of base-encoding alphabet
/// characters.
pub fn parse_digest(
  text : String,
  record_index : Int64,
) -> Result[WarcDigest, WarcError] {
  let data = @utf8.encode(text)
  let len = data.length()
  // Locate the first colon: it must be present and not the last byte.
  let mut colon = -1
  for i = 0; i < len; i = i + 1 {
    if data[i] == b':' {
      colon = i
      break
    }
  }
  if colon <= 0 {
    return Err(
      bad_digest(record_index, "digest must be written as algorithm:value"),
    )
  }
  if colon == len - 1 {
    return Err(bad_digest(record_index, "digest value must not be empty"))
  }
  if !valid_field_name(data, 0, colon) {
    return Err(
      bad_digest(record_index, "digest algorithm is not a legal token"),
    )
  }
  for i = colon + 1; i < len; i = i + 1 {
    if !is_digest_byte(data[i]) {
      return Err(
        bad_digest(
          record_index, "digest value contains characters outside the base-encoding alphabets",
        ),
      )
    }
  }
  let algorithm = @utf8.decode(data.view(start=0, end=colon)) catch {
    _ =>
      return Err(
        bad_digest(record_index, "digest algorithm is not valid UTF-8"),
      )
  }
  let value = @utf8.decode(data.view(start=colon + 1, end=len)) catch {
    _ => return Err(bad_digest(record_index, "digest value is not valid UTF-8"))
  }
  Ok(WarcDigest::new(algorithm, value))
}
