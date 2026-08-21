param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\capture_chain"
$ProfileDir = Join-Path $ProjectRoot ".godot\capture_chain_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }

$Scene = "res://scenes/slices/capture_chain_slice.tscn"
$Stages = @("trapdoor_capture", "seated_witness", "missing_investigation", "escape_intercept", "front_exit_defeat")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/capture_chain/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/capture_chain/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=trapdoor_capture" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }
$Validation = Get-Content (Join-Path $ProjectRoot "artifacts\capture_chain\validation.json") -Raw | ConvertFrom-Json
if (-not $Validation.passed) { throw "Capture-chain validation checks reported a failure." }

Write-Host "Capture-chain evidence written to $ArtifactDir"
