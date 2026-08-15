# Under the Bridge — Asset Migration Manifest

## 1. Decision labels

- **Keep pristine**: preserve unchanged as source/archive evidence.
- **Re-export/clean**: create a curated Godot-facing copy from editable source.
- **Rebuild**: author again in Blender, Godot, or the 2D art tool.
- **Reference only**: inspect visually or behaviorally; do not copy into the project.
- **Archive only**: retain outside the active project; do not use as migration input.
- **Discard**: exclude from the Godot repository.

All existing art is assumed CC0 by user instruction. The assumption is not independently verified.

## 2. Environment source

| ID | Source | Evidence | Decision | Godot destination / action |
|---|---|---|---|---|
| ENV-001 | `Speakeasy.blend` | Blender 5.2; 39 meshes, 18 materials, one camera, one light; metric; no missing referenced images | Keep pristine | Preserve original outside active edits; hash before migration. |
| ENV-002 | `Speakeasy_Godot.blend` | Does not yet exist | Re-export/clean | Create curated copy under `assets/environment/`; direct-import through Blender/glTF. |
| ENV-003 | 12 referenced JPG textures | Valid external image references from `.blend` | Re-export/clean | Copy with portable relative paths under `assets/environment/textures/`. |
| ENV-004 | Nine unused JPGs | Present in `Textures` but not referenced | Archive only | Keep with original source; migrate only if deliberately selected. |
| ENV-005 | `color_121212.hdr` | Present but unused | Archive only | Do not import initially. |
| ENV-006 | `Render Result` image datablock | Empty Blender runtime datablock | Discard | No migration action. |
| ENV-007 | Blender camera | One source camera | Discard/rebuild | Rebuild fixed high-angle camera in Godot. |
| ENV-008 | Blender light | One source light | Discard/rebuild | Rebuild lighting and environment in Godot. |
| ENV-009 | 18 Blender materials | 17 appear used; glass/specular behavior needs review | Rebuild | Recreate used materials in Godot and visually validate. |
| ENV-010 | `wall_stuccoSPEC.jpg` | Tagged sRGB despite specular role | Rebuild/validate | Verify channel use and color-space import. |
| ENV-011 | `T1`, `T2`, `T4`, `T6` | Separate meshes at about 103,785 polygons each | Clean if measured | Link/instance or reduce only if spike shows cost. |
| ENV-012 | Two fancy chairs | About 17,607 polygons each | Clean if measured | Preserve for visual spike; optimize only if needed. |
| ENV-013 | Repeated furniture/props | Every repeated mesh currently has one user | Re-export/clean | Convert obvious repeats to shared meshes/instances where safe. |
| ENV-014 | 45 legacy OBJ files | More objects than curated `.blend` | Archive only | Do not restore omitted objects automatically. |
| ENV-015 | `Speakeasy.fbx` | Legacy interchange copy | Archive only | Not a migration input. |
| ENV-016 | `Speakeasy.usdc` | Legacy interchange copy | Archive only | Not a migration input. |
| ENV-017 | `Speakeasy.blend1` | Older backup with different hash | Archive only | Preserve with source archive, never canonical. |

### Environment cleanup selection

Keep in `Speakeasy_Godot.blend`:

- room shell, walls, floor, and ceiling
- stairs and hallway structure
- bar and backbar
- doors
- tables, stools, chairs, and furniture
- bottles and glasses
- piano
- paintings and signs
- light shades/fixtures as geometry

Exclude source camera/light and any unused staging objects. Apply transform cleanup, semantic naming, grouping, and repeat instancing without changing the pristine source.

## 3. Missing environment/gameplay art

| ID | Asset | Decision | Prototype treatment |
|---|---|---|---|
| NEW-ENV-001 | Bathroom room dressing | Rebuild | Greybox first; visual polish only after danger spike. |
| NEW-ENV-002 | Toilet | Rebuild | Simple readable prop with seated/standing interaction transforms. |
| NEW-ENV-003 | Trapdoor | Rebuild | Animated greybox plus open/closed visual state. |
| NEW-ENV-004 | External Trapdoor control | Rebuild | Player-readable control outside bathroom. |
| NEW-ENV-005 | Tunnel Intake | Rebuild | Clear terminal threshold near hallway stairs. |
| NEW-ENV-006 | Front exit | Rebuild | Explicit navigation target and defeat threshold. |
| NEW-ENV-007 | Interaction/queue markers | Rebuild | Invisible runtime points with editor-visible gizmos. |
| NEW-ENV-008 | Collision/navigation proxies | Rebuild | Author in Godot or cleaned Blender copy based on spike. |

## 4. Character and 2D source

| ID | Source | Evidence | Decision | Action |
|---|---|---|---|---|
| CHAR-001 | `Bartender.png` | 64x64 RGBA, one pose | Reference/temporary | Use only for 2.5D visual spike. |
| CHAR-002 | `Bartender.aseprite` | 128x128, one frame | Keep pristine | Store as editable source through Git LFS. |
| CHAR-003 | `bartender_model.psd` | 32x40, 8-bit RGB | Keep pristine | Store as editable/reference source through Git LFS. |
| CHAR-004 | `brainstorm_board.aseprite` | Design/reference board | Keep pristine | Source reference, not runtime content. |
| CHAR-005 | 16 modular limb PNGs | 6-11 px, early cutout experiment; duplicate `.png.png` suffixes | Archive/reference | Normalize names and re-export only if a spike deliberately uses them. |
| CHAR-006 | Spine sample/source content | Incomplete experiment/demo | Discard | Do not migrate runtime or sample data. |
| CHAR-007 | PaperZD experiment | Incomplete Unreal animation experiment | Discard | Do not migrate. |
| NEW-CHAR-001 | Three Cultist variants | Missing | Rebuild | Minimal silhouettes/palette variants for required states. |
| NEW-CHAR-002 | Eight Patron variants | Missing | Rebuild | Authored cast with readable group/value distinctions. |
| NEW-CHAR-003 | Animation state set | Missing | Rebuild | Idle, walk, work, talk, carry/support, unconscious, Investigation, Escape. |

## 5. Unreal reference and discard inventory

| ID | Unreal content | Decision | Rationale |
|---|---|---|---|
| UE-001 | `_Maps/Test.umap` | Reference only | Active dressed map; exact transforms were not extracted. Use screenshots selectively. |
| UE-002 | 17 project Blueprints | Reference only | Preserve intent where useful; rewrite behavior in GDScript. |
| UE-003 | `2DCameraBP`, `2DCharacterBP`, `2DControllerBP`, `2DGameModeBP` | Discard/rebuild | Prototype experiments do not match accepted command architecture. |
| UE-004 | `BP_NPC`, `MyAIController` | Discard/rebuild | Replace with Patron state model. |
| UE-005 | Smart Objects, behavior tree, blackboard, tasks | Discard/rebuild | Replace with `InteractionRegistry` and explicit states. |
| UE-006 | UE4/UE5 mannequins | Discard | 420+ MB character content irrelevant to presentation. |
| UE-007 | `AdvancedSidescrollerCam` | Discard | Demo/plugin content; rebuild small camera behavior. |
| UE-008 | Spine GettingStarted examples | Discard | Demo assets and audio unrelated to slice. |
| UE-009 | `LevelPrototyping`, `TopDownMap` | Discard | Stock/demo content. |
| UE-010 | HLOD, built data, external actors | Discard | Unreal-generated implementation data. |
| UE-011 | Duplicated Environment imports and `zDump` | Discard | Superseded by canonical Blender source. |
| UE-012 | All `.uasset` and `.umap` binaries | Discard from repo | Not portable or useful as Godot source. |
| UE-013 | DDC, logs, telemetry, inspection projects | Discard | Generated diagnostic material. |

## 6. Repository placement and tracking

Planned tracked assets:

```text
assets/environment/Speakeasy_Godot.blend
assets/environment/textures/<12 referenced images>
assets/characters/<runtime sprite exports>
source_art/characters/<PSD and Aseprite sources>
```

Use Git LFS for `.blend`, `.psd`, `.aseprite`, and other large binary source files. Generated imports and build output stay ignored.

## 7. Manifest completion checklist

- [ ] Hash pristine environment and character sources.
- [ ] Create `Speakeasy_Godot.blend` without altering the original.
- [ ] Record the final keep/exclude object list.
- [ ] Make the 12 referenced texture paths portable.
- [ ] Validate transforms and meter scale.
- [ ] Record material overrides and color-space decisions.
- [ ] Measure high-poly props before optimizing.
- [ ] Add greybox bathroom, Trapdoor, front exit, and Tunnel Intake.
- [ ] Produce minimal Cultist and Patron state sprites.
- [ ] Confirm no Unreal binaries entered the repository.
- [ ] Record the user-provided CC0 assumption in release documentation.
