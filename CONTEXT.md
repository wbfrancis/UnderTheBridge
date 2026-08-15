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

## Service and needs

**Order**:
A patron's request for one generic drink, represented from request through delivery or cancellation.
_Avoid_: Ticket when referring to the whole gameplay concept

**Prepared Drink**:
A physical drink waiting at the bar or being carried to a patron.
_Avoid_: Inventory item

**Drugged Drink**:
A specially prepared drink that makes its consumer drowsy and then unconscious on a predictable countdown.
_Avoid_: Poison

**Bladder**:
A patron need increased by drinking that eventually compels a bathroom trip.
_Avoid_: Bathroom meter

**Intoxication**:
A four-level condition increased by finishing drinks; its highest level is **Max Drunk**.
_Avoid_: Drunkenness meter

## Danger and capture

**Suspicion**:
A personal 0-100 measure of how strongly a patron believes the speakeasy is unsafe or criminal.
_Avoid_: Global alert, heat

**Soft Suspicion**:
Suspicion that can recover after its source resolves and the patron experiences a quiet period.
_Avoid_: Temporary suspicion

**Hard Evidence**:
Directly witnessed criminal evidence that fixes a patron at maximum suspicion.
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
One active Action followed by up to three pending Actions belonging to one Cultist.
_Avoid_: Behavior tree

**Commitment Point**:
The moment after which cancelling an Action cannot undo its gameplay consequence.
_Avoid_: Completion

**Night**:
One self-contained 18-minute operation ending in a results screen and clean restart.
_Avoid_: Level, campaign day
