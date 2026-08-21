param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\knockout_drag"
$ProfileDir = Join-Path $ProjectRoot ".godot\knockout_drag_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }

$Scene = "res://scenes/slices/knockout_drag_slice.tscn"
$Stages = @("windup_commitment", "witness_split", "drag_occupies", "drop_restarts", "intake_capture")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/knockout_drag/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/knockout_drag/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=windup_commitment" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }
$Validation = Get-Content (Join-Path $ProjectRoot "artifacts\knockout_drag\validation.json") -Raw | ConvertFrom-Json
if (-not $Validation.passed) { throw "Knockout & Drag validation checks reported a failure." }

Write-Host "Knockout & Drag evidence written to $ArtifactDir"
