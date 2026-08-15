param(
    [string]$GodotBin = "",
    [int]$DurationSeconds = 600,
    [int[]]$Scales = @(1, 4),
    [switch]$CaptureOnly,
    [switch]$SkipCapture
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$workspaceRoot = Split-Path -Parent $projectRoot
$knownGodot = Join-Path $workspaceRoot "Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
$profileRoot = Join-Path $projectRoot ".godot\navigation_spike_profile"
$env:APPDATA = Join-Path $profileRoot "Roaming"
$env:LOCALAPPDATA = Join-Path $profileRoot "Local"
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    if (Test-Path -LiteralPath $knownGodot) {
        $GodotBin = $knownGodot
    } else {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $godotCommand) {
            throw "Godot was not found. Pass -GodotBin with the console executable path."
        }
        $GodotBin = $godotCommand.Source
    }
}

& $GodotBin --headless --editor --import --path $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE."
}

if (-not $CaptureOnly) {
    foreach ($scale in $Scales) {
        $reportPath = "res://artifacts/navigation_reservations/stress_${scale}x.json"
        & $GodotBin --headless --path $projectRoot --fixed-fps=60 --disable-vsync `
            res://scenes/prototypes/navigation_reservation_spike.tscn -- `
            "--stress-scale=$scale" "--stress-duration=$DurationSeconds" "--report=$reportPath"
        if ($LASTEXITCODE -ne 0) {
            throw "Navigation stress run at ${scale}x failed with exit code $LASTEXITCODE."
        }
    }
}

if (-not $SkipCapture) {
    & $GodotBin --path $projectRoot --fixed-fps=60 --disable-vsync --rendering-method gl_compatibility `
        res://scenes/prototypes/navigation_reservation_spike.tscn -- `
        "--stress-scale=4" "--stress-duration=120" "--capture-at=75" `
        "--capture=res://artifacts/navigation_reservations/navigation_reservations.png"
    if ($LASTEXITCODE -ne 0) {
        throw "Navigation evidence capture failed with exit code $LASTEXITCODE."
    }
}

Write-Host "Navigation stress spike complete. Evidence: $projectRoot\artifacts\navigation_reservations"
