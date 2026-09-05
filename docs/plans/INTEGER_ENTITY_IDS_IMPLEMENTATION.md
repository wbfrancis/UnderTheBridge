# Integer entity IDs

Status: implemented on `integer-entity-ids`. No push is authorized.

## Contract

Patrons and Cultists use fixed, authored positive integer IDs in one shared
namespace. `ActorIds.NO_ACTOR` is zero and never identifies an actor. The roster
uses one sequence; a number does not encode actor kind or roster position.
`ActorRoster` owns display names, group membership, companion references and
seed keys. Reordering the roster does not renumber anyone.

Arrival Groups, Smart Objects, Orders, Prepared Drinks and Action names retain
their existing IDs. A command target can refer to an actor or an authored object,
so its ID stays a Variant paired with its target kind. Event sources can likewise
refer to actors or locations. Actor-only APIs, snapshots, ownership tables,
perception recipients and navigation signals use integers.

Each Patron has a required authored `seed_key`. RNG seeds derive from this key,
never from identity. The retained string keys are content, not actor identifiers.
Both the opening-pair mode and full Night read the same roster.

## Tests and review tools

`ScenarioActors` selects explicit fixtures through relationships and service
rank, with assertions for cardinality and ambiguity. Tests that depend on an
existing seeded outcome use those fixtures; synthetic unit-test actors use named
local constants. Display names are never selectors.

Review command-line arguments accept an authored numeric ID or the roles
`opening_patron`, `opening_companion`, and `friendship_candidate`. The conversion
occurs at this text boundary. Runtime APIs have no name-to-ID compatibility shim.

Order, emote and avoidance tie-breaks compare IDs numerically.

## Completed steps

1. Decoupled RNG streams from identity before changing any IDs (`83b0cd1`).
2. Migrated the integer core and its snapshot consumers together (`0fa156b`).
   An input-only shim could not keep snapshot consumers compatible, so the
   dependency-wide change replaced the proposed staged string shim.
3. Added explicit test fixtures and selection-preservation tests (`0a1c0d9`).
4. Migrated review selectors, visual tables and command-line inputs (`29e126d`).
5. Removed duplicated roster content and added identity and preservation checks.

The checks cover positive unique IDs, relationship resolution, zero ownership,
renumbered RNG streams, numeric ordering, actor/location sources, and fifteen
pre-migration gameplay checkpoints across three seeds. The trace fixture is
`tests/fixtures/actor_seed_trace.json`; its expected values came from the original
working tree before the integer conversion.

## Working-tree scope and manual review

Validation applies to the full working tree. Earlier tracked changes that the
conversion depends on are described in the stage-2 commit. Pre-existing untracked
modules, including their necessary integer updates, remain uncommitted at the
user's instruction. These commits alone are not a standalone checkout of the
complete current game.

The user performs manual Godot review. Check selection of both Cultists, Patron
inspection, Prepare/Serve Drink, Generated Move cancellation, and offscreen
indicator targeting. Compare labels, colours and actor positions with the current
approved scene. Automated scene tests also cover the complete drink-service cycle.
