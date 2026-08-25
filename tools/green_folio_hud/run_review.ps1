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

# Three seconds at the fixed rate lets the 4x review actors spread through the
# room without making the capture suite wait on a complete simulated visit.
$Frames = 180
$Frames_ = @(
    @{ Name = "night";           Extra = @() },
    @{ Name = "inspected";       Extra = @("--inspect-patron=patron_june", "--hud-preview=quiet") },
    @{ Name = "action_queue";    Extra = @("--hud-preview=queue") },
    @{ Name = "settings_menu";   Extra = @("--hud-preview=settings") },
    @{ Name = "developer_menu";  Extra = @("--hud-preview=developer") },
    @{ Name = "clock_hover";     Extra = @("--hud-preview=clock_hover") },
    @{ Name = "speed_2";         Extra = @("--hud-preview=speed_2") },
    @{ Name = "speed_4";         Extra = @("--hud-preview=speed_4") },
    @{ Name = "reduced_motion";  Extra = @("--hud-preview=reduced_motion") },
    @{ Name = "offscreen_indicator"; Extra = @("--hud-preview=offscreen") },
    @{ Name = "pause_menu"; Frames = 60; Extra = @("--hud-preview=pause") },
    @{ Name = "outcome_success"; Frames = 60; Extra = @("--hud-preview=outcome_victory") },
    @{ Name = "outcome_failed"; Frames = 60; Extra = @("--hud-preview=outcome_failed") },
    @{ Name = "outcome_exposed"; Frames = 60; Extra = @("--hud-preview=outcome_exposed") }
)

foreach ($Frame in $Frames_) {
    $FrameCount = if ($Frame.Frames) { $Frame.Frames } else { $Frames }
    $CapturePath = "res://artifacts/green_folio_hud/$($Frame.Name).png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility --resolution 1280x720 $Scene -- `
        "--stage=full_cast" "--capture-frames=$FrameCount" "--identify-patron=patron_june" `
        @($Frame.Extra) "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Green Folio HUD capture failed for $($Frame.Name)." }
}

foreach ($Responsive in @(
    @{ Name = "inspected_1024"; Resolution = "1024x576" },
    @{ Name = "inspected_1920"; Resolution = "1920x1080" }
)) {
    $CapturePath = "res://artifacts/green_folio_hud/$($Responsive.Name).png"
    & $GodotBin --path $ProjectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility `
        --resolution $Responsive.Resolution $Scene -- "--stage=full_cast" "--capture-frames=60" `
        "--identify-patron=patron_june" "--inspect-patron=patron_june" "--hud-preview=quiet" `
        "--capture=$CapturePath"
    if ($LASTEXITCODE -ne 0) { throw "Green Folio HUD responsive capture failed for $($Responsive.Name)." }
}

Write-Host "Green Folio HUD approval frames written to $ArtifactDir"
