param(
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$knownGodot = Join-Path $workspaceRoot "Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
$testProfileRoot = Join-Path $projectRoot ".godot\headless_profile"

# Keep automated imports and tests independent from the interactive editor profile.
$env:APPDATA = Join-Path $testProfileRoot "Roaming"
$env:LOCALAPPDATA = Join-Path $testProfileRoot "Local"
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

& $GodotBin --headless --path $projectRoot -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
if ($LASTEXITCODE -ne 0) {
    throw "Headless tests failed with exit code $LASTEXITCODE."
}
