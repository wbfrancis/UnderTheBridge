param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\personal_suspicion"
$ProfileDir = Join-Path $ProjectRoot ".godot\personal_suspicion_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

& (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }

$Scene = "res://scenes/slices/personal_suspicion_slice.tscn"
$Stages = @("independent", "soft_recovery", "hard_evidence", "max_drunk", "maximum_selection")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/personal_suspicion/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

$ReportPath = "res://artifacts/personal_suspicion/validation.json"
& $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=maximum_selection" "--report=$ReportPath"
if ($LASTEXITCODE -ne 0) { throw "Validation report failed." }
$Validation = Get-Content (Join-Path $ProjectRoot "artifacts\personal_suspicion\validation.json") -Raw | ConvertFrom-Json
if (-not $Validation.passed) { throw "Personal Suspicion validation checks reported a failure." }

Write-Host "Personal Suspicion evidence written to $ArtifactDir"
