param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "../..")).Path

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $GodotBin = "godot"
}

& (Join-Path $ProjectRoot "tools/test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $GodotBin --headless --fixed-fps=60 --path $ProjectRoot `
    "res://scenes/prototypes/ticket16_presentation_review.tscn" -- `
    "--stage=full_cast" `
    "--movement-report=res://artifacts/movement_navigation/validation.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ReportPath = Join-Path $ProjectRoot "artifacts/movement_navigation/validation.json"
$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
if (-not $Report.passed) {
    throw "Movement navigation validation failed."
}

Write-Host "Movement navigation validation passed."
