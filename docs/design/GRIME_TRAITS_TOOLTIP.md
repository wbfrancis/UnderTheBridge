# Grime, Traits, Smoking, Reason With, and the Modifier Tooltip — settled design

Design-only tuning for linked mechanics. Vocabulary lives in `CONTEXT.md`; this file
holds the settled numbers and design decisions. It does not prescribe implementation.
Values are starting points to tune in playtest.

## Grime & cleaning

Grime is a per-spot **patch** on any Cultist-reachable surface (floor, table, bar). Its
size is measured in **seconds-to-clean**: 2s minimum on creation, 30s maximum, linear in between. The
**Clean** Action is a proximity Action whose duration equals the patch's current clean
time. Patches never spread; they only grow where they sit. One Cultist reserves a patch
for Clean and snapshots its size when the Action commits. Completion removes that
snapshot amount; Grime added during the Action remains. Cancellation removes nothing.
The remainder may be below 2s; the next Clean takes that actual remaining time. For
example, a 29s snapshot that grows to the 30s cap leaves 1s after completion. Do not
round that remainder up or discard it. Delete a patch only when its size reaches zero.

The scene supplies stable Grime slots and surface bounds. Finished drinks merge at the
Patron's authored seat or drinking-position slot. Normal Bathroom Visit Grime uses one
bathroom-use slot, while Ruined Bathroom uses its own blocking slot. Bladder soiling
always creates a fresh patch at the Patron's current position with an event-based ID.

**Sources**

- Finished drink: **+3s** at the drinker's spot, **50% chance** per drink. A **Slob**
  always leaves grime (100%) and at **×1.5** size.
- Bathroom Visit: **+4s** at the bathroom, every visit.
- Bladder-soiling (Bladder full for 60s): a fresh **+8s** patch where the Patron stands;
  Bladder resets to 0.
- Ruined Bathroom: when a Max Drunk Patron starts Seated Bathroom Use, make one seeded
  **20% roll**. Success creates one separate **28s** patch that **blocks new Bathroom
  Visits** until cleaned. The current visit finishes, and its normal +4s patch still
  occurs.
- Cultists generate no grime. The Trapdoor neither makes nor clears grime.
- Patches cap at 30s.

**Sighted Grime.** A patch counts when its **center** is in the Patron's **same room**,
within **5 horizontal meters**, and inside the Patron's horizontal facing cone:
**60 degrees to either side, 120 degrees total**. Distance and cone boundaries count as
inside. Count the whole patch or none of it; an overlapping stain edge does not count
when its center is outside. This reuses actor room-and-facing perception, with the 5m
Grime range. Floor, table, and bar patches follow the same rule. There is no requirement
to look down and no within-room occlusion by furniture; sight never crosses rooms.

**Satisfaction effect** (no Suspicion effect, ever). Sum the clean-seconds of Sighted
Grime for each Patron:

- **≥ 6s** total crosses a **Germaphobe's** threshold.
- **≥ 15s** total crosses **everyone's** threshold.
- Above threshold: a source-scoped **Satisfaction penalty draining ~2/sec** (Germaphobe
  **×2**), recovering at the same rate once the grime is cleaned or out of sight.

This pressure is a source-scoped **Satisfaction Modifier**. It cannot reduce a normal
Patron below 25 Satisfaction. It can reduce a Germaphobe to 0 and cause Normal Departure.
Recovery repays only the loss applied by this modifier.

## Traits

Each Patron receives one uniformly selected **Drink Preference** at Night start. Two
independent 50% rolls add up to two more Traits, producing a 25% / 50% / 25% distribution
of one / two / three total Traits. Select uniformly from complete valid loadouts for the
rolled count, using the Patron's authored seed key. Traits are hidden until the Patron is
Identified, but their effects are always live — which is what drives the tooltip's `???`.
A single Trait can also become known early through behavior.

Each Trait lists the Trait IDs that make it ineligible. These lists are reciprocal and
contain no missing, duplicate, or self references. Incompatible pairs are Weak/Strong,
Hollow Leg/Lightweight, Lush/Lightweight, Paranoid/Trusting, Nosy/Oblivious,
Germaphobe/Slob, Big Tipper/Tightwad, and Sociable/Grouch.

Baselines these build on: Knock Out base ladder **40 / 60 / 80 / 95%** (Sober / Tipsy /
Drunk / Max Drunk); KO-attempt notice base **50%**; tip bands **0 / 50 / 100 / 150%**;
start Satisfaction **75**; baseline Overdrink Limit **1–3**.

| Trait | Effect |
|---|---|
| **Weak** | Knock Out **+15** points *(excludes Strong)* |
| **Strong** | Knock Out **−15** points |
| **Hollow Leg** | Overdrink Limit **+2** (maximum 5); Intoxication gain **−33%** |
| **Lush** | Ideal Intoxication **+1 level**; orders more often *(excludes Lightweight)* |
| **Lightweight** | Intoxication gain **+50%**; Ideal **−1 level**; Overdrink Limit **−1** |
| **Nurser** | drink-finish time **×1.5** |
| **Wine / Beer / Whiskey Drinker** | Drink Preference; wrong type = base price, **half** tip |
| **Paranoid** | Suspicion gain **×1.5**; KO-notice **+20** (→70%) *(excludes Trusting)* |
| **Trusting** | Suspicion gain **×0.5**; Friendship gain **×1.5** |
| **Nosy** | missing-Companion Investigation after **30s** instead of **60s**; hearing-only KO-notice **+15**; Reason With **−20** |
| **Oblivious** | hearing-only KO-notice **−25** (→25%); Reason With **+20**; confusion before a Hard-Evidence response reveals the Trait |
| **Germaphobe** | Grime Satisfaction penalty **×2**; reacts at the **6s** small-patch threshold |
| **Slob** | always leaves drink Grime, **×1.5** size; immune to Grime Satisfaction pressure |
| **Big Tipper** | **+50** points to each tip band *(excludes Tightwad)* |
| **Tightwad** | **−50** points to each tip band (min 0) |
| **Sociable** | start Satisfaction **+15**; Talk Satisfaction reward **×1.5** *(excludes Grouch)* |
| **Grouch** | start Satisfaction **−15**; **no** Talk Satisfaction unless the Satisfaction band is already Happy |
| **Non-Smoker** | refuses a Cigarette, **−5** Satisfaction on the offer, and the refusal **reveals** this Trait |

**Intoxication progress.** Store hidden integer progress with six points per visible
level: 0–5 Sober, 6–11 Tipsy, 12–17 Drunk, and 18 Max Drunk. Any completed drink adds 6,
Hollow Leg adds 4, and Lightweight adds 9. While progress is above zero, remove one point
every 40 gameplay seconds, which equals one visible level per four gameplay minutes.
Finishing another drink does not reset this steady decay. A drink counts as an Excess
Drink only when progress was already 18 before completion. Ideal Intoxication and the
Knock Out ladder read the visible level.

Knock Out notice modifiers apply only to the seeded hearing roll. A Patron who directly
sees the attempt still receives Hard Evidence.

## Reason With

**Reason With** is a five-second proximity Action against any Patron at 95–100 Suspicion.
Hard Evidence blocks it unless the Patron is Oblivious. An Oblivious Patron shows
confusion during the existing two-second Hard-Evidence reaction, which reveals the Trait;
this presentation replaces the normal reaction but adds no delay.

Contact pauses the Patron. Success lowers Suspicion to 50, clears an Oblivious Patron's
Hard-Evidence lock when applicable, cancels Investigation or Escape, and returns the
Patron to normal behavior. Failure resumes the prior behavior. Each continuous visit to
the 95–100 range permits one completed roll; falling below 95 resets eligibility for a
later visit. Only a completed roll consumes the attempt. Cancellation before the roll
releases the hold and resumes prior behavior without consuming the attempt. The chance
is 60%, modified by Oblivious +20 and Nosy −20, and clamped to 5–95%.

Reason With can start during Intercept, including a direct switch by the same Cultist.
The Patron stays held throughout the handoff. Reason With pauses Intercept's remaining
time; success ends both Actions, while failure or cancellation resumes the remaining
Intercept time. Do not briefly release the Patron to run away between these Actions.

## Smoking

An idle Action any character can take.

- A **Patron** who smokes gets a temporary Satisfaction bump peaking at **+10**: 10s
  fade-in, 40s hold, then 10s fade-out.
- Patrons **self-initiate** smoking at a low idle rate when not otherwise busy, so the room
  feels alive. **Offer Cigarette** forces it on command.
- A **Cultist** smoking is cosmetic — no effect.
- A **Non-Smoker** never self-initiates and takes the **−5** on an offer.
- An accepted Offer Cigarette retains its existing **+10 Friendship** reward. It is
  available only when the Patron can start an idle Action; interruption removes only the
  remaining Smoking modifier.

## The Modifier Tooltip

A generic hover breakdown for any shown percentage. Knock Out and Reason With are its
first uses; both use the same reusable frame (Base → modifiers → Total).

- **Base** line (neutral), labelled with its source (e.g. the Intoxication level).
- One line per modifier: **green with a leading +** for an increase, **red with a leading
  −** for a decrease.
- **Total** at the bottom, in brass.
- Knock Out math: Base = the intoxication ladder; Traits add/subtract flat points; Total
  clamps to **5–99%**.
- Reason With math: Base = 60%; Traits add/subtract flat points; Total clamps to
  **5–95%**.
- **Unknown Modifier**: when a modifier comes from a Trait that isn't yet known, its line
  and the Total both show a **neutral grey `???`** — grey so the player can't tell whether
  it helps or hurts. Known modifiers still show alongside a `???`. Learning the Trait
  (Identifying the Patron, or a behavioral reveal) resolves the `???`.
- The Context Menu row shows the same Total, so a `???` Total appears on the menu row too.

Approved visual mockup: https://claude.ai/code/artifact/b48244e7-b5ce-4e03-8d39-bcdc9d5e48a9

Local reference: `docs/design/visuals/modifier-tooltip.png`. The written rules above
control behavior; the local image controls frame, spacing, type, colors, and hierarchy.

## Grime visual design — settled

The Grime appearance and static-patch sight round is closed. The prior 20 Traits,
Smoking, Modifier Tooltip, clean times, and Satisfaction thresholds remain settled.
Per-Trait balance is deferred until Traits are visible in-game, unless requested
separately.

**Confirmed direction (2026-09-04)**

- Show patch severity through modest footprint growth plus denser, darker residue.
  Keep growth local and within the surface edge.
- Do not show seconds-to-clean to the player, including on hover or inspection.
  Clean-seconds remain the design measure for the settled mechanics above.
- Use slightly pulsing brass outlines on Grime during Patron inspection. The outlines
  are the only Grime inspection signal for now; do not add a separate panel, severity
  bar, or threshold labels. Clean-time numbers remain hidden.
- Outline **every patch of Sighted Grime**, including patches below a Satisfaction
  threshold and patches seen by a Slob. The outlines mean "this Patron sees this," not
  "this Patron loses Satisfaction from this." Their presence or absence must not reveal
  a hidden Trait.
- The user approved the rough board's stain appearance and light-to-heavy treatment,
  including the tabletop example. The inspection outlines are approved with the added
  slight pulse. The pulse must stay restrained rather than flash or expand the patch.

**Approved stain reference**

[Grime rough visual study](visuals/grime-study-v1.png) supplies the approved flat,
irregular stains with broken edges, dark residue, restrained wet highlights, and
Light / Moderate / Heavy treatments on floor and wood. Only the stain treatment and
brass outline style are visual references. The `Grime In Sight` panel on this board was
rejected: omit the entire panel, bar, and `Sensitive` / `Standard` labels. Add a slight
pulse to the outlines during inspection.

There is no explicit visual indicator of the 6s or 15s threshold for now. The settled
Satisfaction rules still apply. Grime severity reads through the stains themselves.

The board is a rough concept generated with the built-in image tool, using
`artifacts/green_folio_hud/inspected.png` as the camera and Green Folio style reference.
It is not a game screenshot or approval of a camera or HUD change. Outlined patches are
illustrative; actual outline membership follows the settled Sighted Grime rule above.
Source-specific variants and cleaning animation are outside this approved rough visual's
scope; the board supplies no additional rules for them.
