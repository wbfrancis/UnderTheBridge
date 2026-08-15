# Under the Bridge

Design and migration workspace for a Godot vertical slice of **Under the Bridge**, a command-driven 2.5D speakeasy management game about serving patrons while covertly capturing them.

## Status

Planning is complete. Foundation spikes are validating the riskiest technical assumptions before feature production begins.

- Target: Windows desktop, mouse and keyboard
- Tools: Godot 4.7.1, typed GDScript, Blender 5.2
- Schedule: four-week vertical slice followed by one evaluation week
- Scope: three cultists, eight authored patrons, one 18-minute night

## Headless tests

From the project root, run the lean contract suite with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test_headless.ps1
```

The runner uses the known local Godot 4.7.1 console executable when present, otherwise it uses `godot` from `PATH`. Pass `-GodotBin "C:\path\to\godot_console.exe"` to override it. Automated runs use an isolated profile under the ignored `.godot` folder and do not modify the interactive editor profile.

## Project documents

- [Domain glossary](./CONTEXT.md)
- [Prototype game design document](./docs/PROTOTYPE_GDD.md)
- [Unreal-to-Godot migration guide](./docs/UNREAL_TO_GODOT_MIGRATION.md)
- [Technical design and state model](./docs/TECHNICAL_DESIGN.md)
- [Asset migration manifest](./docs/ASSET_MIGRATION_MANIFEST.md)
- [Milestone backlog](./docs/MILESTONE_BACKLOG.md)
- [Headless simulation spike](./docs/spikes/HEADLESS_SIMULATION_SPIKE.md)
- [Navigation and reservation spike](./docs/spikes/NAVIGATION_RESERVATION_SPIKE.md)
- [Bathroom danger-chain spike](./docs/spikes/BATHROOM_DANGER_CHAIN_SPIKE.md)
- [Service Action Queue slice](./docs/slices/SERVICE_ACTION_QUEUE_SLICE.md)

## Scope gate

Do not add campaign persistence, recipes, inventory economy, specialized staff roles, extra rooms, extra cultists, or additional capture methods until the evaluation criteria in the GDD have been measured.
