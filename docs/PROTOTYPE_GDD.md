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
- Camera: fixed high-angle perspective with pan and zoom, no rotation
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

| Phase | Simulated time | Rules |
|---|---:|---|
| Preparation | 1 minute | Position Cultists and assign initial work; no Patrons yet. |
| Active operation | 15 minutes | Arrivals, service, social play, capture, investigation, and escape. |
| Closing | 2 minutes | No new Orders; remaining eligible Patrons prepare to leave. |

The player may pause and issue commands at any time. Available speeds are pause, 1x, 2x, and 4x. Starting an Escape forces the game back to 1x but does not pause it.

## 5. Authored patron cast

The slice uses a fixed cast for reproducible tuning and bug reports.

| Arrival | Group |
|---:|---|
| 1:30 | Pair |
| 3:00 | Sad solo Patron |
| 5:00 | Trio |
| 7:00 | Pair |

Each Arrival Group has authored companion relationships. Every Patron begins with zero Friendship toward every Cultist. The sad solo Patron guarantees access to the Friendship Capture route.

A group normally prepares to leave nine minutes after being seated. An active Order, drink, bathroom visit, or conversation delays departure until that activity resolves. A missing Companion blocks Normal Departure and begins the missing-friend process.

### Staying behind

When a group leaves, the member with the lowest stay preference is the departure anchor and always leaves. The remaining member of a pair, or remaining two members of a trio, roll independently:

`stay chance = 10% + 0.5 × Active Bartender Friendship + 15 × Intoxication level − 0.6 × Suspicion`

Clamp the chance to 0-90%. A maximum-suspicion Patron never stays. If several Cultists occupy bar work positions, use the Patron's highest Friendship among them; an unattended bar contributes zero Friendship. A stayer becomes a solo Patron until Closing and rolls only once per Night. Their friends' known departure does not trigger missing-friend Suspicion.

## 6. Patron loop and visible information

Normal Patrons arrive, find a seat, order, drink, socialize, use the bathroom as Bladder fills, and eventually leave. Exceptional states add following, investigation, escape, unconsciousness, dragging, and capture.

When selected, a Patron shows segmented indicators for:

- Bladder
- service patience
- mood
- Suspicion band
- Intoxication
- drugged status and countdown
- companion relationships
- qualitative victim value and risk

Overhead icons appear only for urgent intentions: ordering, bathroom need, Investigation, or Escape.

## 7. Drink service

1. A seated Patron creates an Order automatically.
2. The Order enters a shared visible list.
3. A Cultist prepares the generic drink at the bar in 5 seconds.
4. The Prepared Drink waits physically on the bar.
5. A Cultist carries one drink and serves its Patron.
6. Payment occurs on delivery; faster service adds a small tip.

At 30 seconds, an unserved Patron becomes visibly impatient. At 60 seconds, the Order is cancelled, the Patron pays nothing, loses mood, and gains 15 Suspicion. A second failed Order causes Normal Departure.

After drinking for about 30 seconds, the Patron socializes for a variable interval before they may order again. There are no recipes, tabs, change-making, supplies, or inventory economy.

## 8. Bladder, bathroom, and Trapdoor

Finishing drinks raises Bladder. A full Bladder compels a bathroom trip.

- One Patron may occupy the bathroom.
- Two authored first-in/first-out queue positions sit outside.
- Additional Patrons defer and retry after roughly 10 seconds.
- Queue waiting raises impatience, not Suspicion.

Bathroom use lasts about 13 seconds:

| Phase | Duration | Trapdoor vulnerability |
|---|---:|---|
| Enter and approach | 2 seconds | Vulnerable while standing |
| Seated use | 8 seconds | Protected |
| Stand and prepare to leave | 3 seconds | Vulnerable |

The external control opens the Trapdoor for a 2-second pulse followed by a 3-second cooldown. A seated occupant does not fall, and the activation does not remain armed. A seated Patron who sees it open reaches maximum Suspicion unless they are Max Drunk. Every activation creates a nearby +10 sound event.

## 9. Intoxication

Intoxication has four visible levels: sober (0), buzzed (1), drunk (2), and Max Drunk (3). Finishing an ordinary or Drugged Drink raises Intoxication by one. It does not decay during the Night.

Max Drunk suppresses only the seated Trapdoor observation. It does not suppress reactions to assault, dosing, unconscious bodies, dragging, or other Hard Evidence.

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
- Seeing the dosing is Hard Evidence and sets the witness to 100 Suspicion.

If the victim has a conscious Companion, the strongest friend becomes the Helper after a 2-second reaction. The Helper spends 4 seconds supporting the victim, then moves toward the front exit at 60% speed. One Cultist may attempt a 6-second Rescue Persuasion before they cross the exit.

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
| Cancelled Order | +15 |
| Hearing nearby Trapdoor | +10 |
| Hearing nearby knockout | +25 |
| Seeing unexplained collapse | +10 |
| Failed Rescue Persuasion | +25 |
| First seeing a Cultist drag a body | +50 |
| Continuing to see a body dragged | +10 every 5 seconds |
| Seeing a drink dosed | Set to 100; Hard Evidence |
| Witnessing knockout | Set to 100; Hard Evidence |
| Witnessing Trapdoor Capture | Set to 100; Hard Evidence |
| Seeing Trapdoor open while seated | Set to 100 unless Max Drunk |
| Missing Companion at 20 seconds | +25 |
| Missing Companion at 30 seconds | +25 |
| Missing Companion at 40 seconds | Set to 100 |

Visual evidence requires facing and unobstructed line of sight. Sounds use room-based hearing.

Soft Suspicion begins recovering after 20 quiet seconds at 5 points per 10 seconds. Hard Evidence is permanent. Missing-friend Suspicion recovers at the same rate if the Companion safely returns.

### Unattended Bodies

After a 3-second grace period, every Unattended Body adds 5 Suspicion to every active Patron every 5 seconds. Bodies stack. Pressure stops while a Helper supports the victim or a Cultist drags them; dropping or abandoning the victim starts a new grace period.

### Companion influence

Every 10 seconds, a Patron gains up to 5 soft Suspicion toward the highest-suspicion Arrival Group member within 5 meters and the same room. Multiple friends do not stack. Influence only moves upward and stops on separation or equality. Reaching 100 through this influence causes Escape, not bathroom Investigation.

## 13. Investigation, Escape, and interception

A maximum-suspicion Patron worried about a missing Companion enters Investigation. They bypass the bathroom queue but wait for an existing occupant. Once inside, they search while standing for 5 seconds. Completion discovers the closed Trapdoor and changes the Patron to Escape. The player may use the Trapdoor during the vulnerable search.

Maximum Suspicion caused by Hard Evidence or general danger skips Investigation. After a 2-second shock reaction, the Patron runs toward the front exit at 140% speed.

Each escaping Patron permits one Intercept Action. A Cultist who reaches them stalls them for 5 seconds but cannot reduce Suspicion and remains occupied. This gives another Cultist time to use an existing capture route. If the Patron resumes and crosses the front exit, the player loses immediately.

## 14. Cultist commands and autonomy

Each Cultist owns one active Action and three pending Actions. Normal commands append. A "do now" command clears pending Actions and interrupts the current Action only before its Commitment Point.

Cancellation loses elapsed time but no abstract resource. Invalid targets fail with a visible reason and the Cultist continues to the next Action. Dragging can always be interrupted by dropping the body. Cultist switching is instantaneous.

When the queue is empty, safe autonomy may continue assigned service work or idle. Autonomy never creates capture-related Actions.

## 15. Win, loss, and results

The player succeeds by capturing at least three Patrons and reaching the results screen without a maximum-suspicion Patron escaping. Meeting the quota early does not end the Night.

Immediate defeat occurs only when a maximum-suspicion Patron crosses the front exit. Ordinary dissatisfied Patrons may leave without ending the Night. Reaching Closing with fewer than three Captures produces a failed-operation result rather than an earlier forced stop.

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
