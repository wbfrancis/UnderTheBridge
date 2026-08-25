# Under the Bridge

This glossary defines the gameplay language for the prototype. It keeps design, code, tests, and playtest reports aligned without prescribing implementation.

## People and relationships

**Cultist**:
A player-commanded worker who can serve patrons and perform capture actions.
_Avoid_: Employee, unit, character

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
The visible current condition of a Patron, including activity, mood, Suspicion band, Intoxication, Order state, and player-created drug state.
_Avoid_: Patron Profile, hidden state

**Emote Bubble**:
The single overhead icon that shows one actor's urgent intention or expressive change. It is presentational only: it never acknowledges, blocks, or changes gameplay, and it carries no name, value, percentage, countdown, or hidden cause.
_Avoid_: Thought bubble, status icon

**Hover Summary**:
The small temporary view of a Cultist or Patron that appears while the pointer rests on that person.
_Avoid_: Tooltip, summary menu

**Patron Info Panel**:
The persistent detailed view of an Inspected Patron. It stays open until the player closes or replaces it, or the Patron leaves play.
_Avoid_: Full info menu, character sheet

**Selected Cultist**:
The Cultist who receives player commands and supplies Cultist-specific relationship context. Inspecting a Patron does not change the Selected Cultist.
_Avoid_: Active Cultist, focused unit

**Inspected Patron**:
The Patron whose full information panel is open. An Inspected Patron and a Selected Cultist can exist at the same time.
_Avoid_: Selected Patron, targeted Patron

## Service and needs

**Order**:
A patron's request for one generic drink, represented from request through delivery or cancellation.
_Avoid_: Ticket when referring to the whole gameplay concept

**Mood**:
A Patron's 0-100 measure of satisfaction during the Night, shown as Miserable, Unhappy, Content, or Happy. Mood changes tips, and a Patron at zero makes a Normal Departure.
_Avoid_: Happiness, morale, patience

**Prepared Drink**:
A physical drink waiting at the bar or being carried to a patron.
_Avoid_: Inventory item

**Drugged Drink**:
A specially prepared drink that makes its consumer drowsy and then unconscious on a predictable countdown.
_Avoid_: Poison

**Bladder**:
A patron need increased by drinking that creates a rising chance of choosing a bathroom trip once at least half full.
_Avoid_: Bathroom meter

**Bathroom Line**:
The single waiting position for a Patron who intends to use the occupied bathroom.
_Avoid_: Bathroom Action Queue, waiting room

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
The unconscious state caused when a Patron reaches their Overdrink Limit. Patrons in the same room lose Mood instead of gaining Suspicion from the collapse or unattended body.
_Avoid_: Drugged collapse, passing out roll

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
The committed behavior of a maximum-suspicion patron attempting to cross the front exit and expose the operation.
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

**Friendship Capture**:
The deterministic route in which a sad, trusted patron voluntarily follows a Cultist to the Tunnel Intake.
_Avoid_: Rescue Persuasion

## Commands and time

**Action**:
A validated Cultist command with a target, duration, interruptibility, and commitment point.
_Avoid_: Task, job

**Action Queue**:
One active Action followed by up to three pending Actions belonging to one Cultist. A normal command clears the queue, while Shift+command appends the Action.
_Avoid_: Behavior tree

**Action Tile**:
The square HUD item for one active or pending Action in the Selected Cultist's Action Queue. The complete row of Action Tiles stays visible above the Bottom HUD while a Cultist is selected.
_Avoid_: Queue item, action row

**Context Menu**:
The small list of commands that a right-click on a Patron or an authored smart object opens for the Selected Cultist. It shows the queue mode, disables a command that a temporary condition blocks, and reveals no hidden Patron value.
_Avoid_: Radial menu, action wheel

**Bottom HUD**:
The persistent player interface rooted to the lower screen edge. It groups the Selected Cultist, Night and playback state, and Inspected Patron into three zones whose detailed panels open upward.
_Avoid_: Top bar, control strip

**Pause Menu**:
The in-Night menu opened with Escape. It pauses the Night and offers Resume, Restart, Settings, and Quit.
_Avoid_: Main Menu, title screen

**Offscreen Indicator**:
A screen-edge marker for an urgent actor who is outside the camera view. Pressing it moves the camera to that actor; a transient Hard Evidence marker lasts 2.5 real seconds and freezes during pause.
_Avoid_: Minimap marker, notification badge

**Outcome Modal**:
The blocking end-of-Night popup that reports Success, Operation Failed, or Exposed with its cause and Capture quota progress. It offers Restart and Quit before a future detailed results view.
_Avoid_: Victory screen, game-over screen

**Smart Object**:
An authored world target that offers its own commands, such as the bar work position, the Trapdoor control, or the Tunnel Intake.
_Avoid_: Interactable, prop

**Approach Position**:
The authored floor point a Cultist walks to and reserves before a command reaches its Commitment Point.
_Avoid_: Interaction slot, work spot

**Move Action**:
A player-commanded Action that sends the Selected Cultist to a floor destination through the Action Queue. A normal right-click clears the queue, while Shift+right-click appends the Move Action.
_Avoid_: Direct movement, locomotion override

**Talk Action**:
A player-commanded Action that lets the Selected Cultist speak with an Inspected Patron and identify that Patron when the Action completes.
_Avoid_: Chat, interview

**Offer Drink Action**:
A player-commanded Action that offers a carried Prepared Drink to an Inspected Patron without an Order.
_Avoid_: Free Order, forced drink

**Commitment Point**:
The moment after which cancelling an Action cannot undo its gameplay consequence.
_Avoid_: Completion

**Night**:
One self-contained 18-minute operation ending in an Outcome Modal and clean restart.
_Avoid_: Level, campaign day

**Simulation Speed**:
The selected rate at which a Night advances: 1x, 2x, or 4x. Pause stops advancement without changing the selected rate.
_Avoid_: Playback rate, time scale

**Night Clock**:
The analog-style HUD clock that maps an 8:00 PM to 2:00 AM operation onto the 18-minute Night. Its hover summary gives the current time, Closing time, and time remaining.
_Avoid_: Timer, countdown
