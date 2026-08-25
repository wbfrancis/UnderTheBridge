param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

# Writes the Green Folio Bottom HUD approval frames. Each frame opens one HUD
# state in the real presentation scene, so the reviewer sees the shipped HUD.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Scene = "res://scenes/prototypes/ticket16_presentation_review.tscn"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\green_folio_hud"
New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

# The Patrons need time to walk in, so every frame runs the same settle budget.
$Frames = 720
$Frames_ = @(
    @{ Name = "night";           Extra = @() },
    @{ Name = "inspected";       Extra = @("--inspect-patron=patron_june") },
    @{ Name = "action_queue";    Extra = @("--hud-preview=queue") },
    @{ Name = "settings_menu";   Extra = @("--hud-preview=settings") },
    @{ Name = "developer_menu";  Extra = @("--hud-preview=developer") },
    @{ Name = "pause_menu";      Extra = @("--hud-preview=pause") },
    @{ Name = "outcome_success"; Extra = @("--hud-preview=outcome_victory") },
    @{ Name = "outcome_failed";  Extra = @("--hud-preview=outcome_failed") },
    @{ Name = "outcome_exposed"; Extra = @("--hud-preview=outcome_exposed") }
)

foreach ($Frame in $Frames_) {
    $CapturePath = "res://artifacts/green_folio_hud/$($Frame.Name).png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility $Scene -- `
        "--stage=full_cast" "--capture-frames=$Frames" "--identify-patron=patron_june" `
        @($Frame.Extra) "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Green Folio HUD capture failed for $($Frame.Name)." }
}

Write-Host "Green Folio HUD approval frames written to $ArtifactDir"
