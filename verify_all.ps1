# One-shot verification of the whole repository.
#
# Runs, in order:
#   1. moon fmt --check  (style)
#   2. moon info         (public interface generation)
#   3. moon check/build  (strict checks on all four targets)
#   4. moon test         (the full four-target test matrix)
#   5. moon run          (CLI and examples entry points)
#   6. moon package      (publishable package contents)
#
# Any failure stops the script with a non-zero exit code.
#
# Usage: powershell -ExecutionPolicy Bypass -File verify_all.ps1
#        ./verify_all.ps1 -Moon D:\Moonbit\bin\moon.exe

param(
  [string]$Moon = "moon"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "== moon fmt --check =="
& $Moon fmt --check
if ($LASTEXITCODE -ne 0) {
  Write-Error "moon fmt --check failed (run 'moon fmt' to fix)"
  exit 1
}

Write-Host "== moon info =="
& $Moon info
if ($LASTEXITCODE -ne 0) {
  Write-Error "moon info failed"
  exit 1
}

Write-Host "== moon check --target all --deny-warn =="
& $Moon check --target all --deny-warn
if ($LASTEXITCODE -ne 0) {
  Write-Error "strict four-target check failed"
  exit 1
}

Write-Host "== moon build --target all =="
& $Moon build --target all
if ($LASTEXITCODE -ne 0) {
  Write-Error "four-target build failed"
  exit 1
}

Write-Host "== moon test --target all --deny-warn =="
& $Moon test --target all --deny-warn
if ($LASTEXITCODE -ne 0) {
  Write-Error "strict four-target tests failed"
  exit 1
}

Write-Host "== moon run cli =="
& $Moon run cli version
if ($LASTEXITCODE -ne 0) { Write-Error "cli version failed"; exit 1 }
& $Moon run cli stats
if ($LASTEXITCODE -ne 0) { Write-Error "cli stats failed"; exit 1 }
& $Moon run cli query "http://example.org/a"
if ($LASTEXITCODE -ne 0) { Write-Error "cli query failed"; exit 1 }
& $Moon run cli audit
if ($LASTEXITCODE -ne 0) { Write-Error "cli audit failed"; exit 1 }

Write-Host "== moon run examples =="
foreach ($demo in @("parse", "build", "validate", "index", "audit")) {
  & $Moon run examples $demo
  if ($LASTEXITCODE -ne 0) { Write-Error "example $demo failed"; exit 1 }
}

Write-Host "== moon package --list =="
& $Moon package --list
if ($LASTEXITCODE -ne 0) {
  Write-Error "package validation failed"
  exit 1
}

Write-Host "All verifications passed."
