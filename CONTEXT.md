# Under the Bridge

This glossary defines the gameplay language for the prototype. It keeps design, code, tests, and playtest reports aligned without prescribing implementation.

## People and relationships

**Cultist**:
A player-commanded worker who can serve patrons and perform capture actions.
_Avoid_: Employee, unit, character

**Incapacitated Cultist**:
A Cultist temporarily unable to act after a failed Knock Out Action. The Action Queue shows this state as `Knocked Out`.
_Avoid_: Unconscious Patron, disabled Cultist

**Patron**:
A non-player guest who drinks, socializes, develops suspicion, and may become a victim.
_Avoid_: Customer, civilian, NPC

**Arrival Group**:
The authored set of patrons who enter together and recognize one another as companions.
_Avoid_: Party, table

**Companion**:
A patron connected to another member of the same Arrival Group and eligible to notice their absence or help them leave.
_Avoid_: Teammate

**Helper**:
The conscious companion who takes responsibility for a collapsed patron and tries to remove them through the front exit.
_Avoid_: Carrier, rescuer

**Active Bartender**:
A cultist currently assigned to the bar work position when a departing patron decides whether to stay behind.
_Avoid_: Bartender class, bartender specialization

**Friendship**:
A per-patron, per-cultist relationship measuring trust built during the current night.
_Avoid_: Affinity, loyalty

## Knowledge and inspection

**Identified Patron**:
A Patron whose name and complete limited profile the Cultists have learned during the current Night.
_Avoid_: Discovered Patron, unlocked Patron

**Patron Profile**:
The limited set of personal facts shown for an Identified Patron. Before identification, its fields appear unknown, while directly observable status remains visible.
_Avoid_: Character sheet, NPC data

**Observable Status**:
The visible current condition of a Patron, including activity, Mood, Intoxication, Order state, and player-created drug state. Mood is the only word shown for state of mind; the Suspicion band is not displayed beside it during play.
_Avoid_: Patron Profile, hidden state

**Emote Bubble**:
The single overhead icon that shows one actor's urgent intention or expressive change. It is presentational only and can contain Emote Progress without showing an exact value or hidden cause.
_Avoid_: Thought bubble, status icon

**Emote Progress**:
A vertical fill inside an Emote Bubble that shows progress through the current observable activity phase. Consecutive phases reset the fill and start it again.
_Avoid_: Countdown, action timer

**Hover Summary**:
The small temporary view of a Cultist or Patron that appears while the pointer rests on that person.
_Avoid_: Tooltip, summary menu

**Patron Info Panel**:
The persistent detailed view of an Inspected Patron. It stays open until the player closes or replaces it, or the Patron leaves play.
_Avoid_: Full info menu, character sheet

**Modifier Tooltip**:
The hover breakdown of a shown percentage, such as a fleeing Patron's Knock Out chance. It lists a neutral Base, then each named modifier with a green plus for an increase or a red minus for a decrease, then the Total.
_Avoid_: Formula popup, stat tooltip

**Unknown Modifier**:
A Modifier Tooltip line whose cause is a Trait the Cultists have not yet learned. It shows a neutral grey `???` in place of the name and value, so the player cannot tell whether it helps or hurts, and forces the Total to show `???` as well, until that Trait becomes known.
_Avoid_: Hidden modifier, question marks

**Selected Cultist**:
The Cultist who receives player commands and supplies Cultist-specific relationship context. Inspecting a Patron does not change the Selected Cultist.
_Avoid_: Active Cultist, focused unit

**Inspected Patron**:
The Patron whose full information panel is open. An Inspected Patron and a Selected Cultist can exist at the same time.
_Avoid_: Selected Patron, targeted Patron

## Service and needs

**Order**:
A Patron's request for Wine, Beer, or Liquor, represented from request through delivery or cancellation.
_Avoid_: Ticket when referring to the whole gameplay concept

**Mood**:
A Patron's state of mind as one word, derived on demand and never stored. Mood reports the Satisfaction band — Miserable, Unhappy, Content, or Happy — until Suspicion reaches the Suspicious band, and then reports Wary, Afraid, or Panicked for the Suspicious, Alarmed, and Maximum Suspicion bands. Mood is a read-out that owns no value of its own and never decides behavior: Escape, Investigation, tips, and Normal Departure all read the meter beneath it.
_Avoid_: Happiness, morale, patience, Mood meter, Mood value

**Satisfaction**:
A Patron's hidden 0-100 measure of how well the Night is treating them, starting at 75 before Traits shift it. Prompt service, a correct drink, a clean room, conversation, and a cigarette raise it; a failed Order, a wrong drink, Sighted Grime, and a witnessed collapse lower it. Satisfaction decays slowly while nothing sustains it, stopping at the Unhappy band; only a service failure carries it below that floor. Satisfaction sets the tip multiplier, and a Patron at zero makes a Normal Departure.
_Avoid_: Mood, Fun, happiness, morale

**Satisfaction Modifier**:
One named, duration-bearing contribution to a Patron's Satisfaction, such as the Smoking bump or the pressure of Sighted Grime. A modifier applies continuously while it lasts, and Satisfaction does not decay while a positive one is active. A repeat from the same source refreshes its duration instead of adding a second copy, except where a source is defined to scale a single modifier by magnitude, as a Grime cluster does.
_Avoid_: Moodlet, buff, status effect

**Prepared Drink**:
A Wine, Beer, or Liquor drink that waits in one of three bar spaces or travels with its assigned Cultist.
_Avoid_: Inventory item

**Drugged Drink**:
A Prepared Drink with a drug dose that makes its consumer drowsy and then unconscious on a predictable countdown.
_Avoid_: Poison

**Drink Service**:
The player-selected delivery of one Prepared Drink to one Patron, with or without a matching Order.
_Avoid_: Serve Order, automatic service

**Bladder**:
A patron need increased by drinking that creates a rising chance of choosing a bathroom trip once at least half full. A Patron whose Bladder stays full for sixty seconds soils itself where it stands, dropping a Grime patch and resetting the Bladder to zero.
_Avoid_: Bathroom meter

**Bathroom Line**:
The single waiting position for a Patron who intends to use the occupied bathroom.
_Avoid_: Bathroom Action Queue, waiting room

**Bathroom Visit**:
A Patron's three-phase bathroom sequence: Mirror Check, Seated Bathroom Use, then Handwashing.
_Avoid_: Bathroom Action, toilet cycle

**Mirror Check**:
The five-second standing phase in which a Patron looks in the bathroom mirror before using the toilet.
_Avoid_: Bathroom entry pause, approach phase

**Seated Bathroom Use**:
The protected toilet phase whose duration is sampled from eight through fifteen seconds for each Bathroom Visit.
_Avoid_: Seated use, toilet pause

**Handwashing**:
The five-second standing phase after Seated Bathroom Use and before the Patron leaves the bathroom.
_Avoid_: Bathroom exit pause, standing exit

**Intoxication**:
A slowly decaying four-level condition increased by finishing drinks; its highest level is **Max Drunk**.
_Avoid_: Drunkenness meter

**Ideal Intoxication**:
A per-Patron preferred Intoxication level sampled for the current Night. A Patron does not place an Order at or above this level but can accept an offered drink.
_Avoid_: Ideal Drunkness, drink limit

**Excess Drink**:
A drink finished while a Patron is already Max Drunk. Excess Drinks accumulate for the Night even if the Patron's Intoxication later falls.
_Avoid_: Extra Order, overflow drink

**Overdrink Limit**:
A hidden per-Patron threshold of one through five Excess Drinks. Reaching it causes Overdrink Collapse.
_Avoid_: Alcohol tolerance, knockout roll

**Overdrink Collapse**:
The unconscious state caused when a Patron reaches their Overdrink Limit. Patrons in the same room lose Satisfaction instead of gaining Suspicion from the collapse or unattended body.
_Avoid_: Drugged collapse, passing out roll

## Cleanliness

**Grime**:
A patch of dirt on any Cultist-reachable surface — floor, table, or bar — left by Patron use. Each patch has a size that grows with use and sets its clean time, from a two-second minimum to a thirty-second maximum. Patches near one another in a room read as a cluster that scales one Satisfaction Modifier rather than applying several. Players judge size through modest footprint growth and denser, darker residue; clean-time numbers are not shown. The Trapdoor neither makes nor clears Grime.
_Avoid_: Dirt, mess, stain

**Grime Inspection**:
A view associated with an Inspected Patron that marks every patch of Sighted Grime with slightly pulsing brass outlines, regardless of its Satisfaction effect or the Patron's Traits. It has no separate panel, severity bar, threshold labels, or clean-time numbers.
_Avoid_: Global cleanliness meter, room dirt score

**Sighted Grime**:
Grime whose patch center is in the Patron's room, within five horizontal meters, and inside the Patron's facing cone, including the boundaries. Sight counts the whole patch or none of it; floor and tabletop patches follow the same rule without looking down or furniture blocking sight.
_Avoid_: Nearby Grime, room-wide Grime

**Ruined Bathroom**:
The state a Max Drunk Patron can cause during Seated Bathroom Use: one large Grime patch that blocks new Bathroom Visits until a Cultist cleans it.
_Avoid_: Broken bathroom, clogged toilet

## Traits

**Trait**:
A named, per-Night characteristic of a Patron that shifts a gameplay value or behavior. A Patron holds one Drink Preference plus one or two other Traits, with no contradictory pair. Traits are Patron Profile facts, hidden until the Patron is Identified, but their effects stay active while hidden. A single Trait can also become known before full identification when the Patron reveals it through behavior, such as refusing a Cigarette.
_Avoid_: Perk, tag, personality

**Drink Preference**:
The single Trait naming a Patron's preferred Order type — Wine, Beer, or Liquor. Serving the other type still pays base price but halves the Satisfaction-based tip.
_Avoid_: Favorite drink, taste

Catalog (values settled separately):
- **Weak** / **Strong**: easier / harder Knock Out (mutually exclusive).
- **Hollow Leg**: high Overdrink Limit, slow Intoxication.
- **Lush** / **Lightweight**: high vs low Ideal Intoxication and drink capacity (mutually exclusive).
- **Nurser**: finishes drinks slowly.
- **Wine Drinker** / **Beer Drinker** / **Whiskey Drinker**: the three Drink Preferences.
- **Paranoid** / **Trusting**: faster vs slower Suspicion, and harder vs easier Friendship Capture (mutually exclusive).
- **Nosy**: more likely to Investigate; notices Knock Out attempts more.
- **Oblivious**: notices less; reacts slowly to Hard Evidence.
- **Germaphobe**: extra Grime Satisfaction penalty; reacts to small patches.
- **Slob**: makes more Grime; immune to Grime Satisfaction penalty.
- **Big Tipper** / **Tightwad**: higher vs lower tips (mutually exclusive).
- **Sociable** / **Grouch**: higher vs lower starting Satisfaction; a Grouch gains no Satisfaction from Talk unless already Happy (mutually exclusive).
- **Non-Smoker**: refuses a Cigarette and takes a minor Satisfaction penalty when offered one; the refusal reveals this Trait.

## Danger and capture

**Suspicion**:
A personal 0-100 measure of how strongly a patron believes the speakeasy is unsafe or criminal.
_Avoid_: Global alert, heat

**Soft Suspicion**:
Suspicion that can recover after its source resolves and the patron experiences a quiet period.
_Avoid_: Temporary suspicion

**Hard Evidence**:
Directly witnessed criminal evidence that normally fixes a Patron at maximum Suspicion. A Max Drunk Patron instead interprets each Hard Evidence event as recoverable Suspicion.
_Avoid_: Proof meter

**Unattended Body**:
An unconscious patron who is neither being supported by a Helper nor dragged by a Cultist.
_Avoid_: Corpse

**Investigation**:
The committed behavior of a maximum-suspicion patron searching the bathroom for a missing companion.
_Avoid_: Search when referring to the whole state

**Escape**:
The committed behavior of a maximum-suspicion patron attempting to cross the front exit and expose the operation. Escape limits Simulation Speed to 1x, but Plain Pause and intercept commands remain available.
_Avoid_: Normal departure, leaving

**Normal Departure**:
A non-alarmed patron leaving because their visit ended or service failed; it does not expose the operation.
_Avoid_: Escape

**Capture**:
The terminal removal of a patron into the implied tunnels.
_Avoid_: Kill, elimination

**Trapdoor**:
The player-activated bathroom mechanism that captures a standing occupant during a short opening pulse.
_Avoid_: Tunnel entrance

**Tunnel Intake**:
The hallway threshold where a dragged, following, or helper-supported patron becomes captured.
_Avoid_: Trapdoor

**Rescue Persuasion**:
A chance-based attempt to convince a Helper to carry their collapsed companion through the Tunnel Intake.
_Avoid_: Friendship capture

**Desire**:
The single thing a Patron wants from the Night — work, company, or a particular indulgence — hidden until a Cultist draws it out in conversation and then satisfied by an offer that matches it. Satisfying a Desire is what opens the Friendship Capture route. The term is settled here for shared vocabulary; the conversation that discovers a Desire is deferred.
_Avoid_: Want, need, goal, motivation

**Friendship Capture**:
The deterministic route in which a trusted Patron whose Desire a Cultist has satisfied voluntarily follows that Cultist to the Tunnel Intake.
_Avoid_: Rescue Persuasion

## Commands and time

**Action**:
A character's unit of work with a target, duration, and interruption rules, produced by a Cultist command or a Patron intent.
_Avoid_: Task, job

**Action Queue**:
One active Action followed by any number of pending Actions belonging to one character, with interrupted work held for resumption. Cultist queues are visible to players; Patron queues are visible only in debug mode.
_Avoid_: Behavior tree

**Action Chain**:
A sequence of Actions linked by dependency inside one Action Queue. Cancellation or failure removes its unfinished Actions, then the next unrelated queued Action can start.
_Avoid_: Task Chain, combo

**Action Tile**:
The square HUD item for one active or pending Action in the Selected Cultist's Action Queue, including a cancellable Step Aside when an idle Cultist moves out of another character's path.
_Avoid_: Queue item, action row

**Context Menu**:
The small list of commands that a right-click on a Patron or an authored smart object opens for the Selected Cultist. It shows the queue mode, disables a command that a temporary condition blocks, and reveals no hidden Patron value.
_Avoid_: Radial menu, action wheel

**Bottom HUD**:
The persistent player interface rooted to the lower screen edge. It groups the Selected Cultist, Night and playback state, and Inspected Patron into three zones whose detailed panels open upward.
_Avoid_: Top bar, control strip

**Pause Menu**:
The blocking in-Night menu opened with Escape. Closing it with Escape restores the prior playback state, while Resume starts the Night at its selected Simulation Speed.
_Avoid_: Main Menu, title screen

**Controls Card**:
The blocking help modal shown before a player's first Night. It holds live Night progression until dismissed and can be reopened from the Pause Menu.
_Avoid_: Tutorial, onboarding popup, Controls Guide

**Plain Pause**:
The non-blocking pause toggled with Space or the Bottom HUD. It stops the Night while camera control, inspection, and command entry remain available.
_Avoid_: Pause Menu, planning mode

**Offscreen Indicator**:
A screen-edge marker for an urgent actor who is outside the camera view. Pressing it moves the camera to that actor; a transient Hard Evidence marker lasts 2.5 real seconds and freezes during pause.
_Avoid_: Minimap marker, notification badge

**Outcome Modal**:
The blocking end-of-Night popup that owns the full results report. It states the outcome (Success, Operation Failed, or Exposed) and its cause, then reports Capture quota progress, Captures grouped by nonzero causal method, drink revenue and tips, Orders served, cancelled, and missed, the highest Suspicion band, escaping Patrons intercepted, and total Unattended Body time. It offers Restart and Quit. There is no second results screen.
_Avoid_: Victory screen, game-over screen, a separate detailed results view

**Smart Object**:
An authored world target that offers its own commands, such as the bar work position, the Trapdoor control, or the Tunnel Intake.
_Avoid_: Interactable, prop

**Approach Position**:
The authored floor point a Cultist walks to and reserves before a command reaches its Commitment Point.
_Avoid_: Interaction slot, work spot

**Move Action**:
A player-commanded Action that sends the Selected Cultist to a floor destination through the Action Queue. A normal right-click clears the queue, while Shift+right-click appends the Move Action.
_Avoid_: Direct movement, locomotion override

**Generated Move Action**:
A visible Move Action that the game adds before a proximity-dependent Patron Action when the Cultist is not adjacent. It tracks the Patron's valid Approach Position and is a linked prerequisite of the requested Action.
_Avoid_: Hidden approach, automatic pathing

**Talk Action**:
A proximity-dependent Action that lets the Selected Cultist speak with an Inspected Patron and identify that Patron when the Action completes.
_Avoid_: Chat, interview

**Offer Cigarette Action**:
A proximity-dependent Action in which the Selected Cultist offers a cigarette to an Inspected Patron. A Patron who accepts starts Smoking; a Non-Smoker refuses and loses a little Satisfaction.
_Avoid_: Smoke Action, cigarette command

**Smoking**:
An idle Action any character can take. For a Patron it applies a Satisfaction Modifier that fades in, holds, then fades out over about sixty seconds. The Offer Cigarette Action triggers it.
_Avoid_: Cigarette break, smoke animation

**Serve Drink Action**:
An Action Chain that reserves one Prepared Drink, sends an assigned Cultist to collect it, and offers it to the chosen Patron.
_Avoid_: Serve Order, Offer Drink Action

**Admit Group Action**:
The three-second entrance Action in which a Cultist opens and holds the front door for one waiting Arrival Group.
_Avoid_: Automatic entry, Open Door Action

**Ask to Leave Action**:
The ten-second social Action in which a Cultist asks a conscious Arrival Group to make a Normal Departure.
_Avoid_: Eject, force out

**Stir Action**:
A proximity Action in which one active Cultist restores an Incapacitated Cultist before natural recovery.
_Avoid_: Revive, rescue

**Commitment Point**:
The moment after which cancelling an Action cannot undo its gameplay consequence.
_Avoid_: Completion

**Night**:
One self-contained 18-minute operation ending in an Outcome Modal and clean restart.
_Avoid_: Level, campaign day

**Simulation Speed**:
The selected rate at which a Night advances: 1x, 2x, or 4x. Pause stops advancement without changing the selected rate or its visible selection.
_Avoid_: Playback rate, time scale

**Night Clock**:
The analog-style HUD clock that maps an 8:00 PM to 2:00 AM operation onto the 18-minute Night. Its hover summary gives the current time, Closing time, and time remaining.
_Avoid_: Timer, countdown
