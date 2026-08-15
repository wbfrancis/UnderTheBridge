param(
    [string]$GodotBin = "",
    [string]$BlenderBin = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$GodotProfileRoot = Join-Path $ProjectRoot ".godot\visual_spike_profile"
$GodotRoaming = Join-Path $GodotProfileRoot "Roaming"
$GodotLocal = Join-Path $GodotProfileRoot "Local"

# Keep the automated run isolated from (and independent of) the user's Godot
# editor preferences. This also makes headless runs work in restricted sessions.
New-Item -ItemType Directory -Force -Path $GodotRoaming, $GodotLocal | Out-Null
$env:APPDATA = $GodotRoaming
$env:LOCALAPPDATA = $GodotLocal

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $KnownGodot = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
    if (Test-Path -LiteralPath $KnownGodot) {
        $GodotBin = $KnownGodot
    } else {
        $GodotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $GodotCommand) {
            throw "Pass -GodotBin or make the Godot console executable available on PATH."
        }
        $GodotBin = $GodotCommand.Source
    }
}

if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot executable not found: $GodotBin"
}
if (-not (Test-Path -LiteralPath $BlenderBin)) {
    throw "Blender executable not found: $BlenderBin"
}

$env:VISUAL_SPIKE_BLENDER_PATH = $BlenderBin.Replace("\", "/")

& $GodotBin --headless --editor --path $ProjectRoot --script res://tools/prototype_visual/set_blender_path.gd
if ($LASTEXITCODE -ne 0) {
    throw "Godot could not save the Blender editor setting."
}

& $GodotBin --editor --import --headless --path $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Godot asset import failed."
}

& $GodotBin --path $ProjectRoot --rendering-method forward_plus -- --capture=res://artifacts/prototype_visual/final_render.png
if ($LASTEXITCODE -ne 0) {
    throw "Godot visual-spike render failed."
}

Write-Host "Visual spike complete: $ProjectRoot\artifacts\prototype_visual\final_render.png"
