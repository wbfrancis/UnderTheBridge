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
    "--movement-scale=1" `
    "--movement-report=res://artifacts/movement_navigation/validation_1x.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $GodotBin --headless --fixed-fps=60 --path $ProjectRoot `
    "res://scenes/prototypes/ticket16_presentation_review.tscn" -- `
    "--stage=full_cast" `
    "--movement-scale=4" `
    "--movement-report=res://artifacts/movement_navigation/validation.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($Name in @("validation_1x.json", "validation.json")) {
    $ReportPath = Join-Path $ProjectRoot "artifacts/movement_navigation/$Name"
    $Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
    if (-not $Report.passed -or $Report.actor_count -ne 11) {
        throw "Movement navigation validation failed: $Name"
    }
}

Write-Host "Movement navigation validation passed at 1x and 4x for all 11 actors."
