# Under the Bridge — Prototype Game Design Document

## 1. Purpose

This four-week vertical slice must prove one fantasy: directing a small cult crew that runs a convincing Prohibition speakeasy while covertly selecting and capturing patrons. It is not a content-complete game or a migration of the Unreal implementation.

The slice is followed by one week of observed evaluation. Expansion is conditional on the evaluation criteria in section 16.

## 2. Product definition

- Platform: Windows desktop
- Input: mouse and keyboard
- Engine: Godot 4.7.1
- Scripting: statically typed GDScript
- Presentation: pixel-art characters in a 3D speakeasy
- Camera: fixed low-elevated long-lens perspective 2.5D view, square to the bar/backbar wall, with pan and zoom but no rotation
- Session: one restartable 18-minute Night
- Cast: three Cultists and eight authored Patrons
- Tone: stylized, systemic, non-graphic

## 3. Design pillars

1. **Hospitality creates cover.** Timely drinks earn cash and keep Patrons content; neglect creates openings for Suspicion.
2. **Every Patron is a possible victim.** Vulnerability, value, relationships, and risk inform target choice.
3. **Commands create opportunity cost.** Every Cultist committed to service, conversation, interception, or body handling is unavailable elsewhere.
4. **Captures create stories.** The four routes interact with friends, bathroom timing, witnesses, and escape rather than behaving like isolated buttons.
5. **Information is readable.** The player sees actionable bands and intentions without receiving every internal number.

## 4. Night structure

The prototype uses a compressed diegetic clock. Preparation begins just before sunset and the doors open at approximately 7:00 PM.

| Phase | Approximate clock | Duration | Rules |
|---|---|---:|---|
| Preparation | 6:59-7:00 PM | 1 minute | Position Cultists and assign initial work; no Patrons yet. |
| Active operation | 7:00-7:15 PM | 15 minutes | Arrivals, service, social play, capture, investigation, and escape. |
| Closing | 7:15-7:17 PM | 2 minutes | No new Orders; remaining eligible Patrons prepare to leave. |

The player may pause and issue commands at any time. Available speeds are pause, 1x, 2x, and 4x. Starting an Escape forces the game back to 1x but does not pause it.

## 5. Authored patron cast

The slice uses a fixed cast for reproducible tuning and bug reports.

| Approximate arrival | Night offset | Group |
|---|---:|---|
| 7:00:30 PM | 1:30 | Pair |
| 7:02 PM | 3:00 | Sad solo Patron |
| 7:04 PM | 5:00 | Trio |
| 7:06 PM | 7:00 | Pair |

Each Arrival Group has authored companion relationships. Every Patron begins with zero Friendship toward every Cultist. The sad solo Patron guarantees access to the Friendship Capture route.

An Arrival Group reserves its complete authored seat set before entering. If the full set is unavailable, the group waits outside. After entry, Patrons walk to their assigned seats and remain near them for ordering, drinking, and socializing until another behavior makes them move.

A group normally prepares to leave nine minutes after being seated. An active Order, drink, bathroom visit, or conversation delays departure until that activity resolves. A missing Companion blocks Normal Departure and begins the missing-friend process.

### Staying behind

When a group leaves, the member with the lowest stay preference is the departure anchor and always leaves. The remaining member of a pair, or remaining two members of a trio, roll independently:

`stay chance = 10% + 0.5 × Active Bartender Friendship + 15 × Intoxication level − 0.6 × Suspicion`

Clamp the chance to 0-90%. A maximum-suspicion Patron never stays. If several Cultists occupy bar work positions, use the Patron's highest Friendship among them; an unattended bar contributes zero Friendship. A stayer becomes a solo Patron until Closing and rolls only once per Night. Their friends' known departure does not trigger missing-friend Suspicion.

## 6. Patron loop and visible information

Normal Patrons arrive, find a seat, order, drink, socialize, use the bathroom as Bladder fills, and eventually leave. Exceptional states add following, investigation, escape, unconsciousness, dragging, and capture.

### Normal play

Hovering any Cultist or Patron opens a small Hover Summary beside that person after a short delay. Leaving the actor closes the Hover Summary. Left-clicking a Cultist makes them the Selected Cultist. Left-clicking a Patron opens the persistent Patron Info Panel without changing the Selected Cultist.

Before the Cultists identify a Patron, profile fields show question marks. Observable Status remains visible: activity, Mood, Suspicion band, Intoxication, Order state, and player-created drug state. A completed Talk Action identifies the Patron for the whole crew and reveals the limited Patron Profile:

- name and Ideal Intoxication
- current visible activity or intent
- qualitative Mood
- Suspicion band, without an exact value
- qualitative Intoxication level
- Arrival Group and companion relationships
- Friendship band with the selected Cultist
- Order status
- known Drugged Drink status and countdown
- qualitative victim value and risk

Bladder level, bathroom probability, exact patience, exact Suspicion, hidden causes, and internal timers are not shown during normal play. The Order list, Hover Summary, and Patron Info Panel expose urgent intentions during this phase. Overhead intent icons belong to the later emote-bubble system.

The Patron Info Panel stays open until the player closes it, inspects another Patron, or the Patron leaves play. Its Talk and Offer Drink commands use the Selected Cultist.

### Debug mode

Debug mode may expose exact Bladder and bathroom probability, Intoxication and decay time, Ideal Intoxication, Overdrink Limit, Excess Drink count, Mood and patience, Suspicion value/cause/recovery, the complete Friendship matrix, lifecycle/activity state, drug timer, current target and reservation, navigation destination, Action progress, Night seed, and recent random rolls. Debug presentation exists for development and evaluation diagnosis, not as the intended player experience.

### Mood

Mood is a hidden 0-100 value that begins at 75. Normal play shows Miserable at 0-24, Unhappy at 25-49, Content at 50-79, and Happy at 80-100. Mood does not recover passively.

- Prompt Order service adds 5 Mood.
- The first completed Talk Action for each Cultist-Patron pair adds 5 Mood. Later Talks can still build Friendship.
- A failed Order removes 20 Mood.
- An Overdrink Collapse removes 15 Mood once from each Patron in the same room when they first notice that body.

Tips use the Patron's Mood band when payment occurs: Miserable pays no tip, Unhappy pays half, Content pays the base tip, and Happy pays one-and-a-half times the base tip. Reaching zero Mood causes Normal Departure.

## 7. Drink service

1. An eligible seated Patron below Ideal Intoxication creates an Order automatically.
2. The Order enters a shared visible list.
3. A Cultist prepares the generic drink at the bar in 5 seconds.
4. The Prepared Drink waits physically on the bar.
5. A Cultist carries one drink and serves its Patron.
6. Payment occurs on delivery; faster service adds a small tip.

At 30 seconds, an unserved Patron becomes visibly impatient. At 60 seconds, the Order is cancelled, the Patron pays nothing, loses 20 Mood, and gains 5 Suspicion. A second failed Order causes Normal Departure.

After drinking for about 30 seconds, the Patron socializes for a variable interval before they may order again. There are no recipes, tabs, change-making, supplies, or inventory economy.

Each Patron has an Ideal Intoxication sampled for the Night. A Patron places an Order only while below that level. After finishing a drink, an eligible Patron socializes for a seeded 20-40 seconds before ordering again. If Intoxication later decays below Ideal Intoxication, ordering can resume. A rare Patron with Sober Ideal Intoxication sits and socializes without ordering.

The Offer Drink Action is available only while the Selected Cultist carries a Prepared Drink and the Inspected Patron can receive it without an active Order. It pays nothing. The Patron uses a seeded 80% acceptance roll, including for a hidden Drugged Drink. A refusal blocks another offer for 60 seconds, and the rejected drink remains with the Cultist.

## 8. Bladder, bathroom, and Trapdoor

Finishing drinks raises Bladder. Patrons do not wait for a full meter and are not compelled automatically at maximum. Every 5 simulated seconds, an otherwise eligible Patron with at least 50% Bladder makes a seeded bathroom decision check:

`bathroom chance = 1% + 89% × ((Bladder − 50%) / 50%)`

Clamp the result from 1% at 50% Bladder to 90% at 100%. Patrons below 50% do not roll. A Patron already committed to another terminal or bathroom-related state does not roll. Choosing the trip creates the bathroom intent and stops further checks until that visit resolves. Completing seated bathroom use empties Bladder to 0%.

- One Patron may occupy the bathroom.
- One authored first-in/first-out Bathroom Line position sits outside.
- Additional Patrons retain bathroom intent at their seats. The earliest waiting intent claims the line when it opens.
- Queue waiting raises impatience, not Suspicion.

Bathroom use lasts about 13 seconds:

| Phase | Duration | Trapdoor vulnerability |
|---|---:|---|
| Enter and approach | 2 seconds | Vulnerable while standing |
| Seated use | 8 seconds | Protected |
| Stand and prepare to leave | 3 seconds | Vulnerable |

The external control opens the Trapdoor for a 2-second pulse followed by a 3-second cooldown. A seated occupant does not fall, and the activation does not remain armed. Seeing it open while seated is Hard Evidence; a Max Drunk occupant therefore gains 25 soft Suspicion instead of permanent maximum Suspicion. Every activation creates a nearby +10 sound event.

## 9. Intoxication

Intoxication has four levels: sober (0), buzzed (1), drunk (2), and Max Drunk (3). Finishing an ordinary or Drugged Drink raises Intoxication by one, capped at 3, and resets its decay timer. After four simulated minutes without finishing another drink, Intoxication falls by one level; it continues falling by one level every four minutes until sober.

Ideal Intoxication uses the same four-level scale. At the start of each Night, sample a normal distribution with mean 2 and standard deviation 0.6, round it, and clamp it to 0-3. This makes Sober possible but rare.

Each Patron also receives a seeded uniform Overdrink Limit from one through five. A drink finished while the Patron is already Max Drunk adds one to the cumulative Excess Drink count. The drink that first raises the Patron to Max Drunk does not count. The count does not reset after Intoxication decays. Reaching the Overdrink Limit causes immediate Overdrink Collapse and the same unconscious state used by a Drugged Drink. If that drink was drugged, immediate collapse makes its later countdown irrelevant.

While Max Drunk, every Hard Evidence event is downgraded to +25 soft Suspicion instead of setting Suspicion to 100 permanently. The downgrade is evaluated when the event is witnessed and is not upgraded retroactively when the Patron sobers. Separate Hard Evidence events may accumulate, and reaching 100 through those soft increases still causes the normal maximum-Suspicion behavior. Non-Hard-Evidence stimuli retain their listed values.

## 10. Capture routes

### 10.1 Bathroom Trapdoor

Time the 2-second opening pulse while a Patron or Investigator is standing. Falling through completes Capture immediately. Tunnels are implied and are not playable.

### 10.2 Drugged Drink

- The Night begins with two drug doses.
- Preparing a Drugged Drink is an explicit 8-second Action.
- The glass has a player-only marker and affects whoever drinks it; it is not target-locked.
- The countdown begins at the first sip.
- At 10 seconds the Patron becomes visibly drowsy.
- At 20 seconds the Patron collapses and becomes unconscious.
- The drink raises Bladder and Intoxication normally.
- Seeing the dosing is Hard Evidence and normally sets the witness to 100 Suspicion; Max Drunk applies the downgrade in section 9.

After any collapse, each conscious Companion in the same room independently makes a seeded 50% Mood-reaction roll. A successful roll removes 20 Mood. An Overdrink Collapse also removes the normal 15 Mood from every Patron in the room. Drugged Drink and knockout collapse keep their normal Suspicion effects without giving non-Companions the Overdrink Mood loss.

After a 2-second reaction, the least Intoxicated conscious, non-Miserable Companion in the same room becomes the Helper; authored group order breaks ties. A Companion who was already Miserable cannot help. The Helper spends 4 seconds supporting the victim, then moves toward the front exit at 60% speed. One Cultist may attempt a 6-second Rescue Persuasion before they cross the exit.

On success, the Helper carries the victim while following the Cultist to the Tunnel Intake; crossing it captures both Patrons. On failure, the Helper gains 25 Suspicion and resumes leaving. Only one Rescue Persuasion is allowed for that collapse. Reaching the front causes both Patrons to leave; it causes immediate defeat only if the Helper has maximum Suspicion.

Without a Helper, the unconscious Patron remains an Unattended Body until dragged.

### 10.3 Manual knockout and dragging

- Approach within 1.2 meters.
- Perform a 2-second interruptible wind-up.
- Impact is the Commitment Point and leaves the victim unconscious for the Night.
- A visual witness receives Hard Evidence; a Patron who only hears it gains 25 Suspicion.
- Picking up the body takes 1 second.
- Dragging occupies the Cultist, prevents pending Actions from starting, and reduces movement to 50%.
- Cancelling a drag drops the body and restarts its unattended grace period.
- Crossing the Tunnel Intake completes Capture.

There is no combat, waking, restraint, or struggle system.

### 10.4 Friendship Capture

Find a sad Patron, offer a cigarette for 10 Friendship, and sustain conversation at about 0.75 Friendship per second. At Trusted Friendship (75+), the receptive Patron deterministically follows that Cultist to the Tunnel Intake. The route consumes about 90 seconds of direct Cultist attention but avoids a random roll.

## 11. Friendship and Rescue Persuasion

Friendship is stored separately for every Patron-Cultist pair and does not decay during the Night.

| Score | Band |
|---:|---|
| 0-24 | Stranger |
| 25-49 | Acquainted |
| 50-74 | Friendly |
| 75-100 | Trusted |

Rescue Persuasion uses the Helper's Friendship toward the acting Cultist and the Helper's personal Suspicion:

`success chance = 25% + 0.7 × (Friendship − Suspicion)`

Clamp to 5-95%. Display the exact chance before commitment and roll once at completion using the Night's seeded random source.

## 12. Suspicion

Suspicion is personal and tracked internally from 0-100.

| Score | Band | Behavior |
|---:|---|---|
| 0-24 | Calm | Normal behavior |
| 25-49 | Uneasy | Concern animation and attention toward source |
| 50-74 | Suspicious | Watches Cultists and hallway; persuasion penalty |
| 75-99 | Alarmed | Stops ordering, seeks companions, moves toward front area |
| 100 | Maximum | Commits to Investigation or Escape; no further decay |

### Suspicion stimuli

| Event | Effect |
|---|---:|
| Cancelled Order | +5 |
| Hearing nearby Trapdoor | +10 |
| Hearing nearby knockout | +25 |
| Seeing unexplained collapse | +10 |
| Failed Rescue Persuasion | +25 |
| First seeing a Cultist drag a body | +50 |
| Continuing to see a body dragged | +10 every 5 seconds |
| First seeing a Cultist drag an Overdrink body | +25 |
| Continuing to see an Overdrink body dragged | +5 every 5 seconds |
| Seeing a body cross the Tunnel Intake | +25 |
| Seeing a drink dosed | Hard Evidence rule |
| Witnessing knockout | Hard Evidence rule |
| Witnessing Trapdoor Capture | Hard Evidence rule |
| Seeing Trapdoor open while seated | Hard Evidence rule |
| Missing Companion at 20 seconds | +25 |
| Missing Companion at 30 seconds | +25 |
| Missing Companion at 40 seconds | Set to 100 |

Visual evidence requires facing and unobstructed line of sight. Sounds use room-based hearing.

For a Patron below Max Drunk, Hard Evidence sets Suspicion to 100 permanently. For a Max Drunk Patron, the same event adds 25 soft Suspicion and does not create a permanent floor.

Soft Suspicion begins recovering after 20 quiet seconds at 5 points per 10 seconds. Missing-friend Suspicion recovers at the same rate if the Companion safely returns.

### Unattended Bodies

After a 3-second grace period, each non-Overdrink Unattended Body adds 5 Suspicion every 5 seconds to each Patron who can see it. Bodies stack. Pressure stops while a Helper supports the victim or a Cultist drags them; dropping or abandoning the victim starts a new grace period.

An Overdrink body never creates collapse or Unattended Body Suspicion. Patrons in the same room lose 15 Mood once when they first notice it, including Patrons who enter later. Openly dragging or capturing that body remains suspicious, but uses half the normal drag values. Faster dragging can prevent recurring five-second increases but cannot prevent the first-seen increase for a witness.

### Companion influence

Every 10 seconds, a Patron gains up to 5 soft Suspicion toward the highest-suspicion Arrival Group member within 5 meters and the same room. Multiple friends do not stack. Influence only moves upward and stops on separation or equality. Reaching 100 through this influence causes Escape, not bathroom Investigation.

## 13. Investigation, Escape, and interception

A maximum-suspicion Patron worried about a missing Companion enters Investigation. They bypass the bathroom queue but wait for an existing occupant. Once inside, they search while standing for 5 seconds. Completion discovers the closed Trapdoor and changes the Patron to Escape. The player may use the Trapdoor during the vulnerable search.

Maximum Suspicion caused by Hard Evidence or general danger skips Investigation. After a 2-second shock reaction, the Patron runs toward the front exit at 140% speed.

Each escaping Patron permits one Intercept Action. A Cultist who reaches them stalls them for 5 seconds but cannot reduce Suspicion and remains occupied. This gives another Cultist time to use an existing capture route. If the Patron resumes and crosses the front exit, the player loses immediately.

## 14. Cultist commands and autonomy

Each Cultist owns one active Action and three pending Actions. A normal command clears pending Actions and interrupts the current Action only before its Commitment Point. If the current Action is committed, it finishes before the new command. Holding Shift while issuing a command appends it instead.

The HUD shows the complete ordered Action Queue for the selected Cultist: active Action first, followed by up to three pending Actions. Each row shows the Action name, target when relevant, and a small `x` control.

- Clicking `x` on a pending Action removes it immediately.
- Clicking `x` on the active Action requests cancellation under the normal Commitment Point rules.
- Once the active Action has crossed its Commitment Point, its `x` is disabled because removal cannot undo the consequence.

Cancellation loses elapsed time but no abstract resource. Invalid targets fail with a visible reason and the Cultist continues to the next Action. Dragging can always be interrupted by dropping the body. Cultist switching is instantaneous, and the queue panel updates to the newly selected Cultist.

When the queue is empty, the Cultist idles. Cultists never move or serve through safe autonomy.

### Emote Bubbles

Each Cultist and Patron can show one overhead Emote Bubble, never two at once. Bubbles are purely presentational: they never acknowledge, block, complete, or cancel an Action, and the Hover Summary and Patron Info Panel keep the detailed text. A bubble carries an icon and a distinct silhouette, so colour reinforces meaning without ever being the only cue. An accessibility setting adds a short label beside the icon and scales the whole overlay from 75% to 150%.

Persistent state bubbles last as long as their source state, in this order, highest first: Escape, Investigation, unconscious, bathroom, ordering, conversation, and an active contextual Cultist Action. Ordinary Move needs no bubble because its destination marker already communicates it. The unconscious bubble reads the same for an Overdrink Collapse and a Drugged Drink collapse, so it never reveals why a Patron went down.

Transient bubbles mark a visible change and use real-time duration, so 4x play never makes one flash past: a danger reaction for 2.5 seconds, a Friendship band gain for 2 seconds, a Mood band move for 2 seconds, a drink result for 1.75 seconds, and a Cultist command result for 1.25 seconds. Pause freezes those timers so the player can read the room. Escape, Investigation, and unconscious suppress every transient while they last, and when such a state ends the bubble recomputes from current state instead of resuming a stale transient. Each actor holds at most two waiting transients; a repeat of the same kind refreshes rather than stacks, and the oldest lowest-priority one is discarded first.

Bubbles are drawn at a fixed pixel size above each actor's head. They stay clear of the top controls, the Hover Summary, and the Patron Info Panel, they keep their previous position while conditions hold so they do not jitter, and a lower-priority bubble hides when no legal position is left.

### Contextual commands

Right-clicking a Patron or an authored smart object takes precedence over the floor behind it and opens a Context Menu. The menu opens even when only one command applies, so target clicks stay predictable. A normal right-click opens it in Replace mode and a Shift+right-click opens it in Append mode; the header names the mode. Escape or a click outside closes the menu without touching the queue.

The menu lists only commands that relate to the target. A command whose target relates but whose condition is temporary appears disabled with a short reason, such as `Prepare Drink (No open Order)`. Eligibility reads only current world state, Selected Cultist state, and player-readable Patron knowledge, so an Unidentified Patron shows as `???` and no menu label reveals an exact Suspicion, Mood, Bladder, Overdrink value, or roll.

A Patron target offers Talk, Serve Order, Offer Drink, Offer Cigarette, Knock Out, Pick Up Body, Intercept, Lead to Tunnel, and Rescue Persuasion. The bar work position offers Prepare Drink and Prepare Drugged Drink; a Cultist carries at most one Prepared Drink, and an Offer Drink spends it whether or not the Patron takes it. The bathroom Trapdoor control offers Activate Trapdoor. The Tunnel Intake is a destination for a drag or a follow that is already under way; it creates no Capture command of its own. While a Cultist drags a body, the floor menu adds Drop Body Here.

Choosing a command reserves the authored approach position, then the Cultist walks there. The approach is interruptible and the gameplay effect fires exactly once, at the Commitment Point, after arrival. A reservation conflict rejects the command with a visible reason instead of creating a hidden wait queue. The target is rechecked when the menu opens, when the command is chosen, before movement starts, and at the Commitment Point; a stale target fails visibly, releases its reservation, and the queue advances.

### Movement and navigation

Left-clicking a Cultist selects them. A normal right-click on reachable empty floor clears pending Actions and creates a Move Action; it redirects an active Move immediately. Shift+right-click appends a Move Action. Small numbered floor markers show queued destinations without drawing path lines. A click near inaccessible geometry moves to the nearest reachable floor point; a distant correction is rejected with visible feedback.

Cultists move at 1.5 meters per second and Patrons at 1.3 meters per second. Escape uses 140% Patron speed, Helper movement uses 60%, and dragging uses 50% Cultist speed. Characters use soft avoidance and cannot permanently block one another. Exclusive work points and waiting positions use reservations.

Four seconds without route progress requests a new path. A Cultist Move Action fails visibly after fifteen seconds without progress, then the next queued Action starts. A blocked Patron moves to the nearest valid waiting position and retries; emergency behavior never ends because a path temporarily fails.

Talk, Offer Drink, and service timers begin only after the Cultist reaches and reserves the required interaction position. A Patron's approach position is a free floor point beside them, because a seat pad blocks the Patron's own spot. If the target starts leaving, the Action cancels, releases its reservation, and preserves any carried Prepared Drink.

Conflicting Patron behaviors use this priority: Capture or unconsciousness, Escape, Investigation, Helper duty, Normal Departure, bathroom, Order, then socializing. Collapse and Capture apply immediately. Escape, Investigation, and Helper duty interrupt socializing, Talk, and Order waiting. A Patron finishes an active bathroom phase before Escape. Bathroom urgency interrupts Talk but waits for drinking to finish. Normal Departure waits for an active Order, drink, bathroom visit, or Talk to finish.

## 15. Win, loss, and results

The player succeeds by capturing at least three Patrons and reaching the results screen without a maximum-suspicion Patron escaping. Meeting the quota early does not end the Night.

Immediate defeat occurs only when a maximum-suspicion Patron crosses the front exit. Ordinary dissatisfied Patrons may leave without ending the Night. Reaching Closing with fewer than three Captures produces a failed-operation result rather than an earlier forced stop.

At Closing, no Patron creates a new Order and every eligible Patron starts Normal Departure after their committed activity resolves. The results screen waits until every Patron exits or reaches a terminal state, up to a 60-second maximum closing period.

The results screen reports:

- Captures and methods
- drink revenue and tips
- Orders served, cancelled, and missed
- highest Suspicion reached
- escaping Patrons intercepted
- total Unattended Body time
- success or failure

Cash affects score and feedback but is not a victory requirement.

## 16. Evaluation criteria

Run at least eight observed sessions across four people: one unassisted attempt and one informed attempt per person where practical.

Continue development when:

- At least six of eight sessions complete without a softlock, stuck actor, or broken Action Queue.
- At least three of four testers can explain why Suspicion rose and what they could have done.
- All four capture routes succeed at least once across the test set.
- At least three of four testers identify service-versus-capture tension as the main appeal.
- At least three of four testers voluntarily want another Night.
- Typical sessions take about 15-25 real minutes depending on pause and speed use.
- The game maintains its target frame rate and survives ten clean restart cycles.
- No route is clearly safer, faster, and more rewarding than all alternatives.

If the fantasy succeeds but clarity, balance, or reliability fails, spend one additional week revising the slice. Do not expand content until the central tension succeeds.

## 17. Explicit v1 scope

Included:

- One speakeasy room, bathroom, hallway, front exit, and implied tunnel
- Three generalist Cultists
- Eight authored Patrons
- Generic drink service and light cash scoring
- Four Capture routes
- Personal Suspicion, companion absence, limited friend influence
- Action Queues and time controls
- Results screen and clean restart
- Settings persistence only

Deferred:

- Campaign or Night-to-Night persistence
- recipes, supply chains, stock, or broader economy
- specialized bartenders, hosts, or bouncers
- blackmail
- more rooms, Cultists, Patrons, or capture methods
- playable tunnels
- combat, restraint, waking, or graphic violence
- procedural Patron generation
- broad rumor/gossip simulation
- full character animation production
