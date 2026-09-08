param(
    [string]$GodotBin = "C:\Users\wbfra\OneDrive\Documents\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
)

# Opens the focused Grime, Traits, and Modifier Tooltip review in the production scene.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
& $GodotBin --path $ProjectRoot res://scenes/prototypes/main_test.tscn -- `
    --stage=grime_traits --presentation-prototype
exit $LASTEXITCODE
