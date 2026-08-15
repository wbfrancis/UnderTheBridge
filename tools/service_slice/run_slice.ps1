param(
    [string]$GodotBin = "",
    [switch]$SkipTests,
    [switch]$SkipCapture
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$workspaceRoot = Split-Path -Parent $projectRoot
$knownGodot = Join-Path $workspaceRoot "Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
$profileRoot = Join-Path $projectRoot ".godot\service_slice_profile"
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
if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE." }

if (-not $SkipTests) {
    & $GodotBin --headless --path $projectRoot -s res://addons/gut/gut_cmdln.gd `
        -gdir=res://tests -ginclude_subdirs -gexit
    if ($LASTEXITCODE -ne 0) { throw "Headless tests failed with exit code $LASTEXITCODE." }
}

$scene = "res://scenes/slices/service_action_queue_slice.tscn"
$report = "res://artifacts/service_action_queue/validation.json"
& $GodotBin --headless --path $projectRoot $scene -- "--stage=served" "--report=$report"
if ($LASTEXITCODE -ne 0) { throw "Service validation report failed with exit code $LASTEXITCODE." }

if (-not $SkipCapture) {
    foreach ($stage in @("queued", "carried", "served", "failed")) {
        $capture = "res://artifacts/service_action_queue/service_${stage}.png"
        & $GodotBin --path $projectRoot --fixed-fps=60 --disable-vsync `
            --rendering-method gl_compatibility $scene -- `
            "--stage=$stage" "--capture=$capture"
        if ($LASTEXITCODE -ne 0) { throw "Service $stage capture failed with exit code $LASTEXITCODE." }
    }
}

Write-Host "Service Action Queue slice complete. Evidence: $projectRoot\artifacts\service_action_queue"
