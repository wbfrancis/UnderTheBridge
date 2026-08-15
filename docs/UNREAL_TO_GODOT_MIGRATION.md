# Under the Bridge — Unreal-to-Godot Migration Guide

## 1. Migration stance

Migrate the game's intent and selected source art, not Unreal's implementation. Rebuild behavior idiomatically in Godot and preserve the Unreal project read-only as a reference.

Technology baseline:

- Unreal reference: Unreal Engine 5.4, Blueprint-heavy
- Destination: Godot 4.7.1 with typed GDScript
- Environment authoring: Blender 5.2
- Character presentation: `AnimatedSprite3D` in a 3D scene

## 2. Evidence snapshot

The Unreal project contains 770 content files totaling about 606 MB:

- 743 `.uasset`
- 14 `.umap`
- 13 raw Spine sample files

The active map is `/Game/_Maps/Test`; the active game mode is `/Game/Blueprints/2DGameModeBP`. Native C++ is boilerplate. Existing work proves camera, movement, navigation, AI, and Smart Object experiments but does not implement the new Night, service, Suspicion, capture, UI, economy, or persistence systems.

The asset-registry inspection did not recover Blueprint graphs or exact `Test.umap` transforms. Do not repeat that extraction work. Use screenshots only when a specific visible arrangement matters.

## 3. Source priority

1. `Speakeasy.blend` is the canonical environment source.
2. Original PSD, Aseprite, PNG, and texture files are source/reference material.
3. The dressed Unreal map is visual reference only.
4. Unreal `.uasset` and `.umap` files are never migration inputs.

All existing art is treated as CC0 under an explicit user-provided assumption. This provenance has not been independently verified; record the assumption in any future release notes or asset credits audit.

## 4. Concept mapping

| Unreal concept | Godot destination | Decision |
|---|---|---|
| `Test.umap` | `Node3D` Night scene | Rebuild from cleaned Blender environment and greybox additions. |
| `2DGameModeBP` | `GameSession` plus `NightDirector` | Rewrite; do not reproduce GameMode conventions. |
| Player Controller/Pawn Blueprints | selection/input controller plus `CultistAgent` scenes | Rewrite around queued commands. |
| NPC/AI Controller Blueprints | `PatronAgent` state model | Rewrite as explicit hierarchical states. |
| Behavior Tree/Blackboard/StateTree | typed states and deep modules | Discard; behavior trees add no leverage for the small authored cast. |
| Smart Objects | `InteractionRegistry` plus authored interaction points | Rebuild occupancy, reservations, and queues. |
| UE NavMesh and AI movement | `NavigationRegion3D`, `CharacterBody3D`, `NavigationAgent3D` | Rebuild and stress at 4x. |
| Walkable trace experiments | navigation and interaction validation | Rebuild from explicit destinations and reservations. |
| PaperZD/Spine experiments | `AnimatedSprite3D` state selection | Discard experiments; author a minimal new sprite set. |
| Blueprint timers | central simulation clock | Rewrite; actors do not own wall-clock timers. |
| Data Assets/Data Tables | immutable Godot `Resource` definitions | Re-author only data needed by the slice. |
| Input mappings | Godot Input Map | Rebuild for mouse/keyboard selection, commands, camera, pause, and speed. |
| Unreal materials | Godot materials | Rebuild and visually validate glass, specular, transparency, and lighting. |
| Unreal save/config | settings-only persistence | Rebuild; no campaign state. |

## 5. Environment pipeline

### 5.1 Preserve and clean

Keep the original `Speakeasy.blend` unchanged. Create `Speakeasy_Godot.blend` as the migration copy.

The source contains:

- 39 meshes, one camera, and one light
- 18 materials
- 12 referenced external image files
- no armature, animation, collision proxies, or navigation proxies
- metric scale at one unit per meter

In Blender 5.2:

1. Remove the source camera and light from the import selection.
2. Retain only the room shell, stairs, bar/backbar, doors, furniture, bottles, glasses, piano, paintings, signs, and light shades.
3. Apply or normalize transforms where the visual spike proves necessary; several objects retain 90-degree X rotation or non-unit scale.
4. Give functional groups and collision ownership meaningful names.
5. Link or instance repeated meshes where practical.
6. Do not optimize the four roughly 104k-polygon tables or 17.6k-polygon fancy chairs until measurement shows a problem.
7. Keep referenced texture paths relative and portable.

Place the cleaned `.blend` and its 12 referenced textures under the Godot project. Let Godot 4.7.1 use Blender's glTF import path. Do not create an independently maintained `.glb` copy unless direct import proves unreliable.

### 5.2 Validated visual-spike decisions

Ticket #2 validated the direct-import route with a 21-object bar vignette and the existing Bartender sprite:

- Keep one Blender unit equal to one Godot meter. The imported room section is approximately 3.6 by 5.4 meters; defer any rescaling until the 11-agent movement spike measures circulation.
- Use Forward+ as the Windows prototype baseline. Compatibility also rendered successfully, but it offers no advantage for the planned mirror and lighting treatment.
- Use a fixed perspective camera as the initial presentation: 34° vertical FOV, position `(4.0, 4.2, 5.2)`, aimed at `(0.15, 0.6, 0.2)` in the representative vignette.
- Present pixel characters as fixed-Y `Sprite3D` billboards with nearest filtering, alpha discard, and an initial scale of 0.05 meters per source pixel.
- Preserve imported material and node names. Replace the named `mirror`, `glass1`, and `glass_lamp` surfaces with Godot-native material resources; ordinary opaque materials may remain direct imports.
- Treat `wall_stuccoSPEC.jpg` as non-color data when the production Blender copy is cleaned.
- Keep texture references relative as `//Textures/<filename>` and save the derived Blender file without remapping those paths toward the pristine source directory.

The reproducible settings, source hashes, reimport probe, and final evidence frame are recorded in `docs/spikes/VISUAL_IMPORT_SPIKE.md`.

### 5.3 Rebuild in Godot

- Fixed high-angle camera, pan, and zoom
- Lighting and environment settings
- All used materials
- Static collision and occluder decisions
- Baked navigation region
- Interaction points and approach markers
- Stool, table, bar, queue, bathroom, exit, and Tunnel Intake reservations
- Missing bathroom, toilet, Trapdoor, outside control, front exit, and tunnel threshold

## 6. Character pipeline

Use `Bartender.png` only to prove the 2.5D visual treatment. Preserve `bartender_model.psd`, `Bartender.aseprite`, and `brainstorm_board.aseprite` as editable/reference sources.

The existing character source is not a production animation set:

- `Bartender.png`: 64x64 RGBA, one pose
- `Bartender.aseprite`: 128x128, one frame
- `bartender_model.psd`: 32x40
- 16 modular body-part PNGs: 6-11 pixels per dimension, several with `.png.png` filenames

Author a minimal prototype set for three Cultists and eight Patrons using palette swaps and readable silhouettes. Required state coverage is idle, walk, work, talk, carry/support, unconscious, Investigation, and Escape. Do not port Spine or PaperZD.

## 7. Content to exclude

Do not copy into the repository:

- `.uasset`, `.umap`, built data, HLOD, and external-actor files
- UE mannequin content
- `AdvancedSidescrollerCam` samples
- Spine GettingStarted assets and sample audio
- PaperZD and `SpineCharacter` experiments
- Smart Object, behavior-tree, blackboard, or StateTree assets
- stock `LevelPrototyping` and `TopDownMap` content
- `zDump` and duplicated Speakeasy Unreal imports
- DDC, telemetry, logs, or inspection projects

Treat `Speakeasy.fbx`, `Speakeasy.usdc`, and `Speakeasy.blend1` as archive-only. Do not restore objects from the 45 legacy OBJ files merely because the cleaned Blender source contains 39 meshes.

## 8. Proposed repository layout

```text
UnderTheBridge/
  project.godot                 # created only when implementation begins
  assets/
    environment/
      Speakeasy_Godot.blend
      textures/
    characters/
    ui/
  source_art/                   # editable/reference files ignored by Godot as needed
  scenes/
  scripts/
  tests/
  docs/
```

Track `.blend`, PSD, and Aseprite source files through Git LFS. Never place generated `.godot` imports or build output under version control.

## 9. Migration sequence

1. Record hashes and preserve original sources.
2. Create and clean `Speakeasy_Godot.blend` without altering the original.
3. Run the visual/import spike using one representative room section and `Bartender.png`.
4. Establish scale, camera, pixel filtering, occlusion, materials, and lighting.
5. Import the curated environment and add greybox gameplay spaces.
6. Author collision, navigation, and interaction points in Godot.
7. Run the 11-agent movement and reservation spike at 1x and 4x.
8. Replace temporary character art only after the gameplay state set is stable.

## 10. Migration completion checks

- Original sources remain unchanged and recoverable.
- The cleaned `.blend` imports reproducibly on a machine with Blender 5.2 and Godot 4.7.1.
- Scale, floor plane, camera angle, and sprite size are documented.
- Glass, mirror, lamp glass, and specular materials receive visual sign-off.
- The main room, bathroom, front exit, and Tunnel Intake are navigable.
- Eleven agents complete the movement spike without deadlock.
- No Unreal binary content exists in the Godot repository.
