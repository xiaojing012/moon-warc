# One-shot verification of the whole repository.
#
# Runs, in order:
#   1. moon fmt --check  (style)
#   2. moon check        (type checking of every package)
#   3. moon test         (the full test matrix on all three targets)
#   4. moon run          (CLI and examples entry points)
#
# Any failure stops the script with a non-zero exit code.
#
# Usage: powershell -ExecutionPolicy Bypass -File verify_all.ps1
#        (or ./verify_all.ps1 from PowerShell)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "== moon fmt --check =="
moon fmt --check
if ($LASTEXITCODE -ne 0) {
  Write-Error "moon fmt --check failed (run 'moon fmt' to fix)"
  exit 1
}

Write-Host "== moon check =="
moon check
if ($LASTEXITCODE -ne 0) {
  Write-Error "moon check failed"
  exit 1
}

foreach ($target in @("wasm-gc", "js", "native")) {
  Write-Host "== moon test --target $target =="
  moon test --target $target
  if ($LASTEXITCODE -ne 0) {
    Write-Error "tests failed on target $target"
    exit 1
  }
}

Write-Host "== moon run cli =="
moon run cli version
if ($LASTEXITCODE -ne 0) { Write-Error "cli version failed"; exit 1 }
moon run cli stats
if ($LASTEXITCODE -ne 0) { Write-Error "cli stats failed"; exit 1 }
moon run cli query "http://example.org/a"
if ($LASTEXITCODE -ne 0) { Write-Error "cli query failed"; exit 1 }
moon run cli audit
if ($LASTEXITCODE -ne 0) { Write-Error "cli audit failed"; exit 1 }

Write-Host "== moon run examples =="
foreach ($demo in @("parse", "build", "validate", "index", "audit")) {
  moon run examples $demo
  if ($LASTEXITCODE -ne 0) { Write-Error "example $demo failed"; exit 1 }
}

Write-Host "All verifications passed."
