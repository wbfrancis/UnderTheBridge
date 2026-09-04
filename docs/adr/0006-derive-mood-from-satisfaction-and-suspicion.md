# Derive Mood from Satisfaction and Suspicion

Mood stops being a stored value. **Satisfaction** is the hidden 0-100 meter that service, cleanliness, and company move, and that sets tips and Normal Departure. **Suspicion** keeps its own meter, its own recovery, and its sole ownership of Escape and Investigation. **Mood** becomes a single word derived from both whenever it is read: the Satisfaction band below the Suspicious threshold, then Wary, Afraid, or Panicked once Suspicion reaches 50. One pure function computes it, so the Bottom HUD, Hover Summary, Patron Info Panel, and Emote Director cannot disagree.

This gives the player one word for "what is this person's state," which two parallel meters could never express — a Patron could read Happy and Alarmed at the same time with no way to say what they were. It also keeps the dangerous coupling out: because Mood stores nothing and no rule reads it, a presentation choice can never alter who escapes.

Satisfaction gains duration-bearing **Satisfaction Modifiers** at the same time. The permanent instantaneous delta the meter used before could not express the Smoking bump that fades in, holds, and fades out, the standing pressure of Sighted Grime, or the Germaphobe and Slob Traits that scale it — all of which were already specified and none of which were implementable.

## Considered Options

- The Sims 4 model, deriving one of many discrete emotions by weighted vote across all inputs, was rejected because it buys a per-emotion weight table, a dominance rule, and a tiebreak to tune across a dozen-odd states, and an 18-minute Night with a fail state needs the player to answer two questions — can I serve this one, is this one about to bolt — not to read fifteen shades of feeling. The one real loss is naming *which* kind of unhappy, and the Emote Bubble already carries cause as an icon.
- Keeping Mood as the meter and adding modifiers under that name was rejected because the word then has to mean both the service satisfaction that sets tips and the fear that ends the Night, and the glossary would carry one term for two unrelated quantities.
- Naming the meter Fun, as the Sims motive is named, was rejected because the meter integrates prompt service, correct drinks, and a clean room. A Patron served quickly in a clean room is satisfied, not entertained. Fun stays free for a later recreation input if music or games arrive.
- Folding Suspicion into Satisfaction as a penalty before banding was rejected because it makes a frightened Patron indistinguishable from a bored one, destroying the signal the player most needs.
- Letting tips read the derived Mood was rejected because Suspicion would then quietly tax income on top of threatening the Night, punishing one mistake twice. Satisfaction buys money; Suspicion costs Nights.
- Showing the Suspicion band beside Mood during play was rejected as displaying a summary next to its own input. The Outcome Modal still reports the highest Suspicion band, because a debrief teaches the model while an in-play word serves a decision under time pressure.
