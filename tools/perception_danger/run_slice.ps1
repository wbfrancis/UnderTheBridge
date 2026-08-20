param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\perception_danger"
$ProfileDir = Join-Path $ProjectRoot ".godot\perception_danger_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }

$Scene = "res://scenes/slices/perception_danger_slice.tscn"
$Stages = @("line_of_sight", "room_hearing", "unattended_body", "companion", "debug_trace")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/perception_danger/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/perception_danger/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=debug_trace" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }
$Validation = Get-Content (Join-Path $ProjectRoot "artifacts\perception_danger\validation.json") -Raw | ConvertFrom-Json
if (-not $Validation.passed) { throw "Perception & Danger validation checks reported a failure." }

Write-Host "Perception & Danger evidence written to $ArtifactDir"
