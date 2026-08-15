param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\ordinary_arrival_group"
$ProfileDir = Join-Path $ProjectRoot ".godot\ordinary_visit_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Focused tests failed." }

$Scene = "res://scenes/slices/ordinary_visit_slice.tscn"
$Stages = @("served", "bathroom", "debug", "departed")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/ordinary_arrival_group/ordinary_${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/ordinary_arrival_group/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=departed" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }

Write-Host "Ordinary Arrival Group evidence written to $ArtifactDir"
