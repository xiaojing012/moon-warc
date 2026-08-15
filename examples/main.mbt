// Example dispatcher.
//
// Run with: moon run examples <name>
//   parse | build | validate | index | audit

///|
/// Dispatch on argv[1] (defaults to "parse").
fn main {
  let argv = @env.args()
  let name = if argv.length() > 1 { argv[1] } else { "parse" }
  match name {
    "parse" => demo_parse()
    "build" => demo_build()
    "validate" => demo_validate()
    "index" => demo_index()
    "audit" => demo_audit()
    _ => println("examples: parse | build | validate | index | audit")
  }
}
