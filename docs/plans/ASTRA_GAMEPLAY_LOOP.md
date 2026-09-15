# Astra gameplay direction and iteration loop

## Mandate

Act as an experienced game director for a Sims-style simulation. Make this one-Night prototype a believable bar with rising tactical pressure. Service, relationships, and observation should create capture opportunities. The player should read the room, form a plan, commit Cultists, and handle the consequences.

The user authorizes changes, removals, and replacements within the one-Night prototype. Prefer a stronger choice over an extra mechanic. Do not expand into a campaign, a larger economy, extra rooms, or content production to solve an unproven problem.

Use `/Users/wfrancis/.agents/skills/grilling/SKILL.md` for each design round. The user explicitly overrides its interview requirement: ask and answer the decision frontier yourself, choose your strongest recommendation, then follow its dependent decisions. Do not send routine design choices or approval requests to the user. Record major decisions for their review when they decide the loop is finished. Keep the written rationale concise; record conclusions, alternatives, and evidence rather than private deliberation.

Agent-driven gameplay tests are authorized for this task, replacing the earlier user-only Godot review rule. Use app-scoped control and an isolated game profile. Do not send keystrokes to an unrelated foreground app. Read the Flue skill before operating supported desktop software. Existing asset-editing safety gates still apply to DCC source changes; this mandate does not authorize wholesale asset replacement.

## Branch and starting point

All previously uncommitted work was preserved in `d6ab94e`. Main then joined the completed avatar and visual-spike histories, retaining the newer integrated implementation. The resulting game tree is identical to `d6ab94e`. The baseline passed 371 tests and 10,360 assertions via `tools/test_headless.sh`.

The unfinished `feat/17-evaluation-build` stays separate: its Windows delivery remains open, and its old cast, scene, and evaluation assumptions need further work. Do not merge it into the loop as a shortcut.

Work on a dedicated branch beginning with `codex/`, based on the published main containing this plan. Keep main stable. Commit each accepted experiment separately. Do not merge gameplay experiments back to main without a later user instruction. Preserve recoverable commits for rejected experiments; undo only your own changes.

## Establish what the player can actually do

Read `CONTEXT.md`, `docs/PROTOTYPE_GDD.md`, relevant ADRs, and the current implementation. Trace the configured launch scene before drawing conclusions. At this baseline it is `scenes/prototypes/main_test.tscn`, backed by `scripts/prototypes/perception_greybox.gd`, with two playable Cultists, Vera and Iris. Some older fixtures use three. Resolve source/document conflicts from the real playable build and record corrections.

The current game includes admission, manual drink preparation and delivery, personal Satisfaction and Suspicion, Traits, Grime, Friendship, bathroom routines, companion responses, capture, interception, and results. Cash is a score rather than a win condition. Friendship Capture still uses an authored eligibility flag; discovering and satisfying a Desire is not implemented. Never credit a designed feature as a playable one.

Before any gameplay edits, play a complete Night through the normal interface and record a short diagnosis. Play at 1x enough to assess timing and feedback; use pause and faster speeds as a player would. Include a full manual admission and prepare-drink → deliver → drink → return-to-routine cycle. Do not use debug knowledge to select targets or decide when to act. Debug traces may explain an observation afterward.

If interactive control is unavailable, build a narrowly scoped input/replay and observation tool, or report the concrete blocker. Do not replace playtest evidence with direct state mutation and call it a played Night.

## Initial questions to investigate

These are hypotheses, not an approved implementation backlog. Rank them again after the baseline Night.

1. **Does hospitality help the capture plan?** Compare attentive service with minimum service and early dismissal of witnesses. Seek decisions where a good host creates a useful opportunity. Do not add a cash quota merely to force otherwise uninteresting work.
2. **Do Patrons change the player's plan?** Test whether Traits, companions, and discovered information affect target selection and timing. Friendship should offer a social plan, rather than repeating Talk until a threshold. A small Desire experiment is a candidate only if the current route proves weak.
3. **Does the bathroom solve the Night by itself?** Test the capture → missing Companion → Investigation → another Trapdoor Capture chain. It can create a good story, but should not make other targets and routes irrelevant.
4. **Is service effort a decision or interface friction?** Count repeated setup clicks, command corrections, camera trips, and Cultist idle time. Separate the intended cost of committing a Cultist from unnecessary input. Consider a small command shortcut before broad automation.
5. **Can the player read danger before it is too late?** For each escalation, record the visible cause, warning, response window, and available response. Test explanations without debug meters. Prefer observable behavior and useful feedback to exposing every hidden value.
6. **Does pressure rise and fall?** Look for calm intervals that permit a plan, overlapping demands that force a choice, and mistakes that permit an understandable recovery. Constant chores and sudden unexplained defeat both weaken this rhythm.
7. **Is there a reason to keep playing after three Captures?** Observe the remainder of the Night. If it becomes waiting, compare a tighter end phase or a voluntary push for better results before adding more objectives.

## Repeatable design round

1. **Observe.** Identify one concrete weak moment in a played Night. Save the build commit, seed, setup, inputs, elapsed time, screenshots or recording, and relevant event trace. Separate a bug from a design weakness.
2. **Self-grill.** Map the decision and its dependencies. State the intended player decision, likely failure modes, at least one plausible alternative, and the option of changing nothing. Choose the strongest recommendation. Resolve facts through inspection or tests, not assumptions.
3. **Predict.** Write a falsifiable expectation before editing: what the player should notice or choose differently, what cost remains, and what evidence would make you reject the idea. Define preservation checks for other routes, information hiding, and input behavior.
4. **Prototype.** Make the smallest coherent change that tests the expectation. Prefer tuning or removing friction when sufficient. If changing an ADR or domain rule, state the conflict and update the authoritative text with the experiment; do not quietly work around it.
5. **Check mechanics.** Run focused regression checks through the real command and navigation seams. Run the full headless suite before accepting a code change. Fix failures caused by the experiment. A passing test must prove both the intended result and preservation of relevant behavior.
6. **Check experience.** Replay the same encounter with the same seed and comparable inputs. Then try a different seed or strategy. Use the actual launch scene and normal player commands. Include the manual drink cycle after every accepted gameplay change, and run a complete Night after each significant change to pacing, balance, capture, service, or danger.
7. **Decide.** Keep, revise, or revert based on the observation. Log mixed results and regressions honestly. Two failed variants of one hypothesis trigger reassessment of the premise, rather than another unexamined feature.
8. **Commit and repeat.** Commit the accepted code, tests, current design text, and evidence summary together. Update the review index before starting the next experiment. Move to the highest-impact remaining issue.

Do not stack several untested design changes. Do not treat a winning scripted strategy as proof of clarity or enjoyment. A diagnostic driver that teleports actors, forces bathroom visits, grants Friendship, or calls capture directly proves only rule resolution.

## Coverage across the loop

Maintain a compact matrix of actual tested encounters. Cover service-first and capture-first play; each capture route; a failed capture and attempted recovery; suspicious companions and witnesses; bathroom contention; Grime competing with service; queue replacement, Shift append, cancellation, and stale targets; 1x/2x/4x and pause; success, quota failure, exposure, and restart. Test affected paths each round and the whole matrix at a milestone, rather than repeating unrelated checks without a reason.

For pacing comparisons, record meaningful choices, repetitive commands, idle periods, missed Orders, Captures and methods, danger causes, recovery attempts, and post-quota time. Use these to explain observations, not as surrogate fun scores. Do not reward fewer clicks if it removes the commitment that makes service versus capture interesting.

Existing production-scene tests are useful but do not substitute for interaction. Older full-integration slices use direct simulation operations and old cast assumptions. Review their claims before using their outputs. Screenshots prove appearance at one moment, not a complete playable route.

## Review record

Keep `docs/design/GAMEPLAY_DECISIONS.md` as the user-facing index. Give each major decision a stable ID and a short entry with:

- Status: proposed, testing, kept, revised, or reverted.
- The observed problem and its evidence.
- Chosen recommendation, alternatives, and why this choice best serves the intended Night.
- Expected player effect and rejection condition, written before the experiment.
- Actual before/after evidence, seed, build commits, and verification results.
- What stayed intact, known drawbacks, and uncertainty.
- Links to detailed encounter records and any updated domain document or ADR.

Major decisions include changes to objectives, capture eligibility or routes, autonomy, service incentives, available information, pacing, failure/recovery, and meaningful mechanics that are added or removed. Record reversals as well as successes. Fixes that simply restore intended behavior can share a short maintenance entry.

Store encounter reports under `docs/playtests/astra/`. Keep generated evidence in an ignored artifact location when bulky, and include usable paths or links in the reports. Maintain a current status file there with last commit, completed checks, unresolved issues, next experiment, and exact restart instructions so a later turn can continue without repeating work.

## Milestones and continuation

The first milestone is a played baseline with a ranked diagnosis. The next is one complete, tested improvement with comparable before/after evidence. Later milestones require complete Nights and a current decision index. Give concise progress updates with findings and changed judgments; do not ask the user to choose routine options or stop at each milestone.

The user decides when the loop is finished. Continue while there is an evidence-backed problem worth addressing; do not manufacture work to fill time. If the prototype reaches a stable candidate, freeze gameplay changes and prepare the review build, decision summary, and focused player checklist. Report that it is ready for the user's review, not that an agent proved it fun.

A review candidate needs reliable complete Nights, multiple viable approaches, understandable danger with observed responses, useful service-versus-capture choices, and no known blocker in the coverage matrix. Test the candidate with multiple seeds and at least two distinct strategies. Explain remaining limits and tradeoffs.

The GDD's human evaluation remains separate: eight observed sessions across four people, readable Suspicion, routes exercised, service-versus-capture tension recognized, and desire to replay. Agent testing cannot claim those human findings.
