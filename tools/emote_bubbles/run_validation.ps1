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
    "--emote-report=res://artifacts/emote_bubbles/validation.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ReportPath = Join-Path $ProjectRoot "artifacts/emote_bubbles/validation.json"
$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
if (-not $Report.passed -or $Report.check_count -ne 9) {
    throw "Emote Bubble overlay validation failed."
}

Write-Host "Emote Bubble overlay validation passed all nine checks."
