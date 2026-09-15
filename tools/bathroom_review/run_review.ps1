param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

# Renders the Bathroom Visit and Trapdoor review: a Patron at each station with its
# Emote Progress fill, then a standing capture through the open panels, the close,
# and the empty room after removal. Frames land at 1280x720, 1024x576, and 1920x1080.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Scene = "res://scenes/prototypes/main_test.tscn"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\bathroom_review"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

# Each mode runs from a fresh Night so the two Companions never contaminate each
# other's frames through the missing-Companion Suspicion clock.
foreach ($Mode in @("capture", "visit")) {
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync `
        --rendering-method gl_compatibility $Scene -- `
        "--bathroom-mode=$Mode" `
        "--bathroom-report=res://artifacts/bathroom_review/validation_$Mode.json"
    $Report = Join-Path $ArtifactDir "validation_$Mode.json"
    if (-not (Select-String -Path $Report -Pattern '"passed"\s*:\s*true' -Quiet)) {
        throw "Bathroom review validation ($Mode) reported a failure."
    }
}
Write-Host "Bathroom review evidence written to $ArtifactDir"
