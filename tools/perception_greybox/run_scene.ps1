param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

# Windows runner for the perception greybox 3-D view. Captures one PNG per
# scenario stage. Open the scene with F6 in Godot for the interactive version.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ArtifactDir = Join-Path $ProjectRoot "artifacts\perception_greybox"
$ProfileDir = Join-Path $ProjectRoot ".godot\perception_greybox_profile"
$env:APPDATA = Join-Path $ProfileDir "Roaming"
$env:LOCALAPPDATA = Join-Path $ProfileDir "Local"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

$Scene = "res://scenes/prototypes/perception_greybox.tscn"
$Stages = @("line_of_sight", "room_hearing", "unattended_body", "companion", "debug_trace")
foreach ($Stage in $Stages) {
    $CapturePath = "res://artifacts/perception_greybox/${Stage}.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for stage $Stage." }
}

Write-Host "Perception greybox captures written to $ArtifactDir"
