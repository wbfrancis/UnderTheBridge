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

foreach ($Scale in @(1, 4)) {
    $Report = "validation_${Scale}x.json"
    & $GodotBin --headless --fixed-fps=60 --path $ProjectRoot `
        "res://scenes/prototypes/ticket16_presentation_review.tscn" -- `
        "--stage=full_cast" `
        "--movement-scale=$Scale" `
        "--command-report=res://artifacts/smart_object_commands/$Report"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $ReportPath = Join-Path $ProjectRoot "artifacts/smart_object_commands/$Report"
    $Parsed = Get-Content $ReportPath -Raw | ConvertFrom-Json
    if (-not $Parsed.passed -or $Parsed.step_count -ne 7) {
        throw "Smart-object command validation failed at ${Scale}x."
    }
}

Write-Host "Smart-object command validation passed at 1x and 4x for all seven steps."
