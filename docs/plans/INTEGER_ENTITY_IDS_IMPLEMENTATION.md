# Integer entity ids

Status: **Plan — awaiting approval, nothing implemented**
Branch: `integer-entity-ids`, stacked on the unmerged `mood-satisfaction-model`.

## Why

Patron and Cultist identity is currently an authored name: `&"patron_june"`,
`&"cultist_01"`. A name is not identity, and code that binds to one says nothing
about why it wants that entity. A test asking about the Grime penalty should ask
for the Slob, not for June. Identity becomes an integer; the name becomes what it
always was, display data in the content layer.

## Settled decisions

- **Patrons and Cultists only.** Arrival Groups, Smart Objects, bar work
  positions, and the Trapdoor keep their StringName ids. Those name a kind of
  authored fixture, not an instance, and `&"trapdoor_control"` reads better than
  a number.
- **Ids are authored constants, not spawn order.** A Patron's id is fixed in the
  roster, so a debug snapshot or a failing test names the same Patron across runs
  and reordering the arrival table renumbers nothing.
- **Tests select by role, never by literal.** A bare `1` is worse than
  `patron_june`: equally uninformative and no longer searchable. Tests ask for
  the state they need and get whichever Patron has it.

## Three hazards found while surveying

These are the parts that will break quietly if the change is done mechanically.

**1. Every seeded roll is derived from the id string.** `_new_patron` seeds each
Patron's RNG with `hash("%d:%s:patron" % [_seed, id])`
(`scripts/simulation/ordinary_visit_session.gd:1119`). Changing the id changes
that hash, which rerolls Ideal Intoxication and every seeded decision that
follows: bathroom checks, wrong-drink acceptance, stay-behind, collapse
reactions. Tests asserting specific seeded outcomes will fail with correct-looking
but different numbers, which is the worst kind of failure to read.

*Resolution:* add an explicit `seed_key` to each roster entry, keep its current
value (`"patron_june"` and so on), and seed from that instead of from the id. The
key is content, sits beside the display name, and never appears in a signature or
a dictionary key. Behaviour is then provably unchanged, and every test that
passes today still passes. Retiring the string keys later is a separate,
deliberate re-baselining, not a side effect of a rename.

**2. The order queue tie-breaks on a lexicographic id comparison.**
`String(left["id"]) < String(right["id"])`
(`scripts/simulation/ordinary_visit_session.gd:1833`) breaks the tie when two
Orders were requested at the same instant. With integers, `"10" < "9"` is true,
so Patron 10 would be served before Patron 9. Must become a numeric comparison.

**3. Prototypes key lookup tables by Patron name.** `perception_greybox.gd` maps
ids to colours and scales (`:135`, `:141`) and holds `PATRON_IDS` arrays. These
are dictionary literals that a signature change will not catch, because they are
data, not calls.

## Surface

24 scripts and 21 test files. 514 typed id parameters. About 930 named-id
literals: 461 `patron_june`, 208 `patron_mara`, 201 `patron_elias`, and 61 across
the other five. The simulation holds roughly 20 dictionaries keyed by entity id.

## Stages

Each stage ends with the full headless suite green and its own commit. No stage
depends on a later one, so the work can stop between any two.

**Stage 1 — Roster and seed key.** Add `id` as an integer and `seed_key` as a
StringName to `FULL_NIGHT_PATRON_DEFINITIONS` and the two-Patron default roster,
alongside the existing name ids. Switch `_new_patron` to seed from `seed_key`.
Nothing else changes yet; the string ids stay authoritative. This stage exists to
prove the seeding is decoupled before anything moves, and the suite must pass
untouched. If a single test moves here, the decoupling is wrong.

**Stage 2 — Flip the roster to integer identity.** Make the integer the id the
session stores and keys by. Update `FULL_NIGHT_GROUP_DEFINITIONS` patron lists,
the `companions` arrays, `CULTIST_IDS`, and the ~20 id-keyed dictionaries in
`ordinary_visit_session.gd`. Fix the lexicographic tie-break at `:1833`. Change
the typed signatures from `StringName` to `int` across the session and
`game_session.gd` (203 of the 514 signatures live in these two files). Tests
still refer to Patrons by name at this point through a temporary lookup, so the
suite proves the simulation is intact before the tests are rewritten.

**Stage 3 — Test role helpers.** Add helpers to a shared test utility:
`any_arrived_patron(session)`, `patron_with_trait(session, trait)`,
`patron_in_group(session, group_id)`, `companion_of(session, patron)`, and
`friendship_capturable_patron(session)`. Replace every named literal in the 21
test files with the helper that says why the test wants that Patron. Delete the
temporary lookup from Stage 2. This is the stage that pays off the original
complaint, and it is the largest by line count.

**Stage 4 — Slices, prototypes, and the review harness.** The 12 slice scripts,
`perception_greybox.gd`, `bathroom_danger_scenario.gd`, and
`production_review_harness.gd`. Rebuild the name-keyed colour and scale tables as
id-keyed. These are demo and diagnostic surfaces, so they come last: a break here
is visible immediately and costs nothing in the shipping path.

**Stage 5 — Retire the display-name coupling.** Confirm no signature, dictionary
key, or comparison outside the roster mentions a Patron name. `seed_key` stays,
documented as content. Update `CONTEXT.md` if the glossary needs a line saying
identity is an integer and the name is display data.

## What this does not do

It does not renumber or rename the authored cast. June, Mara, Elias and the rest
keep their names where names belong — in the roster, on the Patron Profile, and
in the HUD. It does not touch Arrival Group, Smart Object, or Action ids. It
changes no gameplay rule, and Stage 1 exists specifically so it changes no seeded
outcome either.

## Rollback

Every stage is one commit on a branch that nothing else builds on yet. Stage 1 is
independently valuable and safe to keep even if the rest is abandoned, because
decoupling the RNG from identity is correct regardless. Stages 2 through 4 revert
cleanly as a block.

## Open question for approval

Stage 1 keeps the current seeded behaviour by preserving the string as a
`seed_key`. The alternative is to seed from the integer, accept that every
Patron rerolls, and re-baseline whichever tests assert seeded outcomes. That is
cleaner in the end — no vestigial strings — but it mixes a behaviour change into
a rename, and the re-baselined numbers would have to be taken on trust. The plan
above assumes the conservative option.
