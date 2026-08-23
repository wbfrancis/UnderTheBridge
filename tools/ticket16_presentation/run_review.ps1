param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe",
    [switch]$Capture,
    [switch]$Validate
)

# Opens the dedicated ticket #16 presentation review scene. Use -Capture for four
# focused PNGs and a report. Use -Validate to run the lean suite first.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Scene = "res://scenes/prototypes/ticket16_presentation_review.tscn"

if ($Capture -or $Validate) {
    $ArtifactDir = Join-Path $ProjectRoot "artifacts\ticket16_presentation"
    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
    if ($Validate) {
        & (Join-Path $ProjectRoot "tools\test_headless.ps1") -GodotBin $GodotBin
        if ($LASTEXITCODE -ne 0) { throw "Lean tests failed." }
    }
    $Stages = @("full_cast", "service_wing", "front_exit", "cultist_states")
    foreach ($Stage in $Stages) {
        $CapturePath = "res://artifacts/ticket16_presentation/${Stage}.png"
        & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- "--stage=$Stage" "--capture=$CapturePath"
        if ($LASTEXITCODE -ne 0) { throw "Ticket #16 capture failed for stage $Stage." }
    }
    $ReportPath = "res://artifacts/ticket16_presentation/validation.json"
    & $GodotBin --headless --path $ProjectRoot $Scene -- "--stage=full_cast" "--report=$ReportPath"
    if ($LASTEXITCODE -ne 0) { throw "Ticket #16 validation report failed." }
    $Validation = Get-Content (Join-Path $ArtifactDir "validation.json") -Raw | ConvertFrom-Json
    if (-not $Validation.passed) { throw "Ticket #16 presentation validation reported a failure." }
    Write-Host "Ticket #16 presentation evidence written to $ArtifactDir"
} else {
    & $GodotBin --path $ProjectRoot --rendering-method gl_compatibility $Scene
    if ($LASTEXITCODE -ne 0) { throw "Ticket #16 review scene failed." }
}
