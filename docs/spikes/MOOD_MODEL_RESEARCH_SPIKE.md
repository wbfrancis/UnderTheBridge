# Mood Model Research Spike

Status: **Research — informs a design decision, no code changed**

## Question

Today `patron_mood.gd` and `patron_suspicion.gd` are two independent 0–100 meters. Mood
is a hidden meter that drives the tip multiplier; Suspicion is a separate meter that drives
Escape and Investigation. The design question is whether to stop treating **Mood as a meter**
and instead treat Mood as the *gestalt summary* of a Patron's state of mind — a single
derived label, the way The Sims 4 shows one Emotion — while the underlying decaying meter
measures **Fun**, and Suspicion feeds *into* the Mood summary rather than living wholly beside it.

The Sims series is the load-bearing prior art here, because it has shipped both architectures:
The Sims 3 sums many small modifiers into one Mood value, and The Sims 4 replaced that single
bar with a discrete derived Emotion chosen by weighted vote. The user's proposal is, in Sims
terms, "adopt the Sims 4 derivation but keep a Sims-style Fun motive as one of its inputs."
This spike documents how each Sims model actually computes its summary, confirms where "Fun"
sits, and maps both onto our two-meter situation with the concrete rules our design would owe.

## The Sims 3 model: many moodlets → one Mood value

The Sims 3 Mood is a single scalar. A **moodlet** is a discrete, usually time-limited modifier
with a numeric mood-point value, a source, and a duration; moodlets are positive or negative,
and come from needs, environment, and events (a good meal, a nice room, a death in the family).
The overall Mood is the running sum of every active moodlet's points, layered on top of the
contribution from the six needs. The mood bar tops out around +150 mood points, and the game
buckets the summed value into display states — roughly Happy (~+10 to +25), Very Happy
(~+25 to +75), and Elated (~+75 and up). Reaching and holding the upper bands (a net moodlet
total of about +50 or more) is what earns a steady stream of Lifetime Happiness points, which is
the currency the whole system feeds. ([Carl's Sims 3 moodlets guide](https://www.carls-sims-3-guide.com/info/moodlets.php);
[The Sims Wiki: Mood](https://www.thesimswiki.com/wiki/Mood);
[List of Moodlets (The Sims 3), The Sims Wiki](https://www.thesimswiki.com/wiki/List_of_Moodlets_(The_Sims_3)))

The important structural point for us: in Sims 3 the *summary is the meter*. There is no separate
"what kind of unhappy" — everything collapses into one signed number, and the label is just a
band on that number. That is essentially what our current `PatronMood` already is: a clamped
scalar with `band()` thresholds. Sims 3 is the model we already have, minus the multiplicity of
input moodlets.

## The Sims 4 model: weighted buffs → one discrete Emotion

The Sims 4 threw out the single mood bar. A Sim is instead in exactly one of ~15–16 discrete
**Emotions** — Fine (the neutral default), Happy, Sad, Angry, Flirty, Focused, Playful, Tense,
Uncomfortable, Confident, Energized, Bored, Embarrassed, Inspired, Dazed (and later Scared).
([simscommunity: Sims 4 Emotions Guide](https://simscommunity.info/2022/10/08/the-sims-4-emotions-guide/))

Emotions are not a meter you fill. Each active **buff** (the Sims 4 name for a moodlet) carries
an emotion *type* and an intensity *weight*. The game computes the current emotion by summing the
weights of all active buffs per emotion, and the emotion with the highest total wins and becomes
the displayed state; when nothing is active the Sim falls back to Fine.
"To calculate the Sim's emotional state, the game adds up the strength value of all moodlets and
the emotion with the highest total value takes precedence."
([Carl's Sims 4 Emotions guide](https://www.carls-sims-4-guide.com/emotions/), via search excerpt;
[The Sims Wiki: Emotion](https://www.thesimswiki.com/wiki/Emotion))

**Happy is a special amplifier, not just another competitor.** Happy buffs do not merely add to a
"Happy" pile — if any positive emotion is present, Happy's weight is converted onto the leading
positive emotion at a 1:1 ratio, pushing that emotion higher. Carl's worked example: a Sim with
Focus +1 and Happy +6 ends up Focused at +7, because the Happy weight rolls into the strongest
positive emotion rather than standing on its own. And the vote is genuinely a running tally that
can flip: "If a Sim has +4 to Happy but only +2 Angry, they will stay happy… If one of the
positive Happy Moodlets runs out and the balance shifts to +2 Happy, +2 Angry, the Sim will
become Angry." ([Carl's Sims 4 Emotions guide](https://www.carls-sims-4-guide.com/emotions/), via
search excerpt) The summed total also sets an *intensity tier* (e.g. Happy vs Very Happy), so the
label carries a magnitude, not only a category.

Two honesty notes on sourcing. First, EA/Maxis never published the emotion algorithm; the
summation-and-1:1-conversion description above is the community consensus from guides
(Carl's, The Sims Wiki, simscommunity) and mod/data-mining work, not an official spec. Second,
the exact per-buff weights and tier thresholds live in the game's tuning data and are known only
through reverse engineering, so treat specific numbers as illustrative of the *shape*, not as a
formula to copy verbatim.

## The needs model and where "Fun" sits

In both games the summary sits on top of a separate layer of **needs/motives** — decaying bars the
player must refill. The Sims 3 uses six: Hunger, Social, Bladder, Hygiene, Energy, and **Fun**.
([Carl's Sims 3 Motives guide](https://www.carls-sims-3-guide.com/info/motives.php);
[The Sims Wiki: Motive](https://sims.fandom.com/wiki/Motive)) Fun is unambiguously a *need*, a
decaying meter, and it is distinct from Mood/Emotion, which is the *derived* summary. The two are
wired together through moodlets: a full Fun bar grants a positive moodlet ("Having a Blast" in
Sims 3) that decays as the bar drains, and a starved need produces a negative moodlet that drags
the summary down — Carl's notes that low Hunger "will trash your Sim's mood," low Social makes
"Sims start to suffer a low mood," and low Hygiene "lowers their mood."
([Carl's Sims 3 Motives guide](https://www.carls-sims-3-guide.com/info/motives.php)) The Sims 4
keeps Fun as one of its needs and routes it into the emotion system the same way — a low Fun need
pushes toward Bored/Tense buffs, a satisfied one toward Playful.

So the Sims precedent directly supports the user's instinct: **Fun is the meter, the mood/emotion
label is derived from it (plus everything else).** Neither game makes "mood" itself the thing you
fill; you fill needs and accumulate events, and the summary falls out.

## Mapping onto our model

**Where we are.** `PatronMood` is a Sims-3-shaped scalar: start 75, clamp 0–100, no passive
recovery, discrete events (`prompt order service +5`, `wrong drink -10`, `first Talk +5`,
`failed order -20`, `overdrink collapse -15`), banded into Miserable/Unhappy/Content/Happy, and
the band sets the tip multiplier (0× / 0.5× / 1× / 1.5×). `PatronSuspicion` is a fully parallel
0–100 meter with its own bands (Calm→Maximum), its own recoverable-decay model (a 20 s quiet
period then −5 every 10 s), and hard consequences: 100 triggers Escape or Investigation. The two
meters never talk to each other. (See `scripts/patrons/patron_mood.gd`,
`scripts/patrons/patron_suspicion.gd`.)

**What the proposal is, in Sims terms.** Rename the tip-driving meter to **Fun** (a Sims motive:
it can decay, it responds to service events), and make **Mood** a Sims-4-style *derived label*
computed from weighted inputs — Fun being one input, Suspicion being another. That is coherent and
well-precedented: it is exactly the Sims-4 architecture (discrete summary chosen by weighted vote)
sitting on a Sims-style Fun motive. It also buys narrative legibility we don't have today — a
Patron who is high-Fun but high-Suspicion could read as "Uneasy" or "Tense" instead of the current
contradiction where a Patron can be Mood-Happy and Suspicion-Alarmed at the same time with no
single word for their state.

**Where the analogy holds.** The derivation math is directly borrowable: assign each input an
emotion-ish weight, sum, take the max, use Sims-4-style tiers for intensity. Fun-as-a-motive is a
clean lift. The tip multiplier can key off the *derived label* instead of raw Fun bands, which is
arguably more expressive.

**Where the analogy breaks — the open questions the design must answer.** The Sims summary is
*consequence-free flavor*: being Angry in Sims 4 nudges autonomy and skill gains, but nothing in
the world *fires* at max Anger. Our Suspicion is the opposite — it owns a hard state transition
(Escape/Investigation at 100) with its own recovery curve and its own public bands the Outcome
Modal already reports. A soft gestalt label cannot own that. So folding Suspicion into Mood is
really folding *the display* of Suspicion into a shared label while Suspicion the mechanism keeps
running underneath. Concretely the design owes:

1. **Aggregation rule.** What are the inputs (Fun, Suspicion, and what else — needs like Bladder
   from the bathroom system?), what weight does each carry, and are they signed contributions to
   named emotions or a single valence axis? Sims 4 needs an explicit per-emotion weight table; we
   would too.
2. **Dominance / tiebreak.** Sims 4's answer is "highest summed weight wins, Happy amplifies the
   leading positive, Fine is the floor." We need our own version: does high Suspicion always
   dominate the label regardless of Fun (a scared Patron reads Scared even if entertained), or do
   they genuinely compete? Pick a rule and a tiebreak, or the label will flicker.
3. **Hard consequences vs soft summary.** Suspicion must keep its own 0–100 value, its recovery,
   and its 100-triggers-Escape behavior *independent of* the label — the label is a read-out, not
   the source of truth. Decide explicitly that the gestalt summary is display-only and never gates
   Escape/Investigation, or you will have coupled a cosmetic layer to a terminal state machine.
4. **Tip multiplier.** Today tips key off Mood bands. If Mood becomes a gestalt of Fun *and*
   Suspicion, does a nervous-but-entertained Patron tip well? Probably tips should stay keyed to
   the **Fun** meter (the thing service actually moves), with the gestalt label used for
   presentation and emote selection — otherwise Suspicion silently starts taxing income, which is a
   real balance change, not a refactor.
5. **Recovery semantics.** Fun-as-a-motive implies passive decay/recovery, which today's Mood
   deliberately does *not* have. Confirm whether Fun should decay over a visit; that is a genuine
   gameplay change, not just a rename.

## Recommendation (synthesis)

The evidence points toward the split the user is leaning to, with one firm boundary. The Sims
lineage validates the core move: needs (including **Fun**) are the meters, and the "mood" a player
reads is a *derived* summary — Sims 4 proves a discrete, weighted-vote label is more legible than a
single hidden bar, and gives us a ready-made aggregation-and-dominance algorithm (sum weights per
emotion, highest wins, an amplifier for ties, a neutral floor). So renaming the tip meter to Fun
and deriving a Mood *label* from it is sound and well-precedented. The boundary is Suspicion:
unlike any Sims emotion, our Suspicion owns a hard terminal transition, so it must stay a
first-class meter with its own value, recovery, and Escape trigger — Suspicion may *feed the label*
and even dominate it, but the label must not become the thing that decides Escape, and tips should
stay anchored to Fun rather than the blended gestalt unless we deliberately want fear to cut
income. In short: adopt Sims-4 derivation for presentation and emote choice, keep Sims-style Fun as
the tip-bearing motive, and keep Suspicion mechanically separate while letting it *inform* the
summary — which means the design's real work is writing down the four missing rules above
(weights, dominance/tiebreak, display-only guarantee, tip anchoring), not the rename itself.

## Sources

- Carl's Sims 3 Guide — Moodlets: https://www.carls-sims-3-guide.com/info/moodlets.php
- Carl's Sims 3 Guide — Motives/Needs (fetched; confirms Fun is a decaying need feeding mood): https://www.carls-sims-3-guide.com/info/motives.php
- The Sims Wiki — Mood: https://www.thesimswiki.com/wiki/Mood
- The Sims Wiki — List of Moodlets (The Sims 3): https://www.thesimswiki.com/wiki/List_of_Moodlets_(The_Sims_3)
- Carl's Sims 4 Guide — Emotions (source of the summation and Happy 1:1 amplifier quotes; via search excerpt, page blocked to direct fetch): https://www.carls-sims-4-guide.com/emotions/
- The Sims Wiki — Emotion: https://www.thesimswiki.com/wiki/Emotion
- Sims fandom — Motive: https://sims.fandom.com/wiki/Motive
- SimsCommunity — The Sims 4 Emotions Guide (fetched; full emotion list, Fine as default, Happy amplifier): https://simscommunity.info/2022/10/08/the-sims-4-emotions-guide/

Sourcing caveat: EA/Maxis never published the emotion/mood algorithms. The weighting, 1:1 Happy
conversion, and intensity tiers are community consensus from the guides above plus mod/data-mining
work; exact per-buff weights live in tuning data known only through reverse engineering, so treat
specific numbers as illustrative of the mechanism's shape.

Local files reviewed for the current model: `scripts/patrons/patron_mood.gd`,
`scripts/patrons/patron_suspicion.gd`.
