# Resolve Trapdoor capture in the simulation

`OrdinaryVisitSession` owns the Trapdoor result. Activation snapshots the current bathroom occupant and resolves eligibility from that snapshot — bathroom ownership and posture — and never arms a later Patron. A standing occupant is captured; a seated occupant is a protected misfire that applies the existing Hard Evidence rule exactly once.

Capture is a finite transitional state, not an instant removal. A standing capture enters `trapdoor_falling` and keeps the bathroom reservation while the Trapdoor advances `closed → falling → closing → cooldown → closed`. The Patron becomes terminal `captured` and the bathroom slot releases only after the panels finish closing. The bathroom door reads locked while the panels are open or closing, so no queued Patron enters and no Investigator claims the room until closure; the existing control cooldown still follows and the door may unlock during it.

Presentation animates the result from the authoritative snapshot and never decides capture. The scene adapter reads the Trapdoor `state`, `fall_ratio`, `close_ratio`, `falling_patron`, and `locked` fields, opens the hinged panels, and sinks the captured avatar a bounded depth into the pit where the floor occludes it. The avatar stays present through the fall and close and is removed only when the closed state confirms terminal capture. A physics kill zone is not the gameplay authority; a bounded occluder only hides the avatar below the bathroom floor.

This supersedes the earlier immediate-capture behaviour, in which activation set `captured` and the adapter hid the Patron in the same step. It does not change the snapshot-only eligibility rule or the seated Hard Evidence consequences, which it preserves.

## Considered Options

- Keeping instant capture was rejected because it left no room to animate the fall and close, and removed the Patron before the panels moved.
- Letting a physics kill zone decide capture was rejected because eligibility must come from bathroom ownership and posture, which only the simulation holds.
- Releasing the bathroom slot at activation was rejected because a queued Patron or Investigator could then enter an open Trapdoor before the panels closed.
- Recording a separate ADR for the tunable bathroom phase durations was rejected as unnecessary; those live in the simulation as ordinary constants.
