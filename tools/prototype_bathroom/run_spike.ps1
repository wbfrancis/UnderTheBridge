param(
    [string]$GodotBin = "",
    [switch]$SkipTests,
    [switch]$SkipCapture
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$workspaceRoot = Split-Path -Parent $projectRoot
$knownGodot = Join-Path $workspaceRoot "Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
$profileRoot = Join-Path $projectRoot ".godot\bathroom_spike_profile"
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

if (-not $SkipTests) {
    & $GodotBin --headless --path $projectRoot -s res://addons/gut/gut_cmdln.gd `
        -gdir=res://tests -ginclude_subdirs -gexit
    if ($LASTEXITCODE -ne 0) {
        throw "Headless tests failed with exit code $LASTEXITCODE."
    }
}

$scene = "res://scenes/prototypes/bathroom_danger_spike.tscn"
$report = "res://artifacts/bathroom_danger_chain/validation.json"
& $GodotBin --headless --path $projectRoot $scene -- `
    "--stage=investigation" "--report=$report"
if ($LASTEXITCODE -ne 0) {
    throw "Bathroom validation report failed with exit code $LASTEXITCODE."
}

if (-not $SkipCapture) {
    $capture = "res://artifacts/bathroom_danger_chain/bathroom_danger_chain.png"
    & $GodotBin --path $projectRoot --fixed-fps=60 --disable-vsync `
        --rendering-method gl_compatibility $scene -- `
        "--stage=investigation" "--capture=$capture"
    if ($LASTEXITCODE -ne 0) {
        throw "Bathroom evidence capture failed with exit code $LASTEXITCODE."
    }
}

Write-Host "Bathroom danger-chain spike complete. Evidence: $projectRoot\artifacts\bathroom_danger_chain"
