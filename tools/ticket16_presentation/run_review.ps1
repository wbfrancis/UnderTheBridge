param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe",
    [switch]$Capture
)

# Opens the dedicated ticket #16 presentation review scene. Use -Capture to
# write a PNG and exit instead of opening an interactive window.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Scene = "res://scenes/prototypes/ticket16_presentation_review.tscn"

if ($Capture) {
    $ArtifactDir = Join-Path $ProjectRoot "artifacts\ticket16_prototype"
    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
    $CapturePath = "res://artifacts/ticket16_prototype/review_scene.png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Ticket #16 review capture failed." }
    Write-Host "Ticket #16 review capture written to $ArtifactDir\review_scene.png"
} else {
    & $GodotBin --path $ProjectRoot --rendering-method gl_compatibility $Scene
    if ($LASTEXITCODE -ne 0) { throw "Ticket #16 review scene failed." }
}
