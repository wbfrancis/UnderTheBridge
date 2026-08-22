param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\full_integration"
$ProfileDir = Join-Path $ProjectRoot ".godot\full_integration_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }

$Scene = "res://scenes/slices/full_integration_slice.tscn"
$Stages = @("all_four_routes", "success", "failed_operation", "defeat", "readable_info")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/full_integration/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/full_integration/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=all_four_routes" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }
$Validation = Get-Content (Join-Path $ProjectRoot "artifacts\full_integration\validation.json") -Raw | ConvertFrom-Json
if (-not $Validation.passed) { throw "Full integration validation checks reported a failure." }

Write-Host "Full integration evidence written to $ArtifactDir"
