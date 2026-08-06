# verify_all.ps1 — full verification of moon-sfv on every target.
#
# Runs, in order:
#   moon clean
#   moon fmt --check
#   moon check/build/test --target wasm-gc
#   moon check/build/test --target js
#   moon check/build/test --target native
#   python scripts/verify_httpwg_snapshot.py
#   moon package --list
#
# Any failing step prints the command and its output, then the script stops
# with exit code 1. Target availability is reported as-is; code is never
# modified to mask a missing toolchain.

$ErrorActionPreference = "Stop"
$moon = "D:\Moonbit\bin\moon.exe"
$project = Split-Path -Parent $PSScriptRoot
Set-Location $project

function Invoke-Step {
    param([string]$Label, [scriptblock]$Body)
    Write-Host ""
    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Body
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Label" -ForegroundColor Red
        exit 1
    }
}

Write-Host "moon-sfv full verification"
Write-Host "Project: $project"

Invoke-Step "moon clean" { & $moon clean }
Invoke-Step "moon fmt --check" { & $moon fmt --check }

foreach ($target in @("wasm-gc", "js", "native")) {
    Invoke-Step "moon check --target $target" { & $moon check --target $target }
    Invoke-Step "moon build --target $target" { & $moon build --target $target }
    Invoke-Step "moon test --target $target" { & $moon test --target $target }
}

Invoke-Step "verify_httpwg_snapshot.py" {
    & python scripts/verify_httpwg_snapshot.py
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Invoke-Step "moon package --list" { & $moon package --list }

Write-Host ""
Write-Host "All verification steps passed." -ForegroundColor Green
exit 0
