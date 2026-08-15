# Service Action Queue slice

## Goal

Issue #6 proves the first player-commanded hospitality path: select a Cultist, edit that Cultist's Action Queue, prepare and carry a physical Prepared Drink, deliver it to one Patron, receive payment and a speed-based tip, or observe a stale-target failure that pays nothing and does not deadlock the queue.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\service_slice\run_slice.ps1
```

The interactive scene is `scenes/slices/service_action_queue_slice.tscn`. Its guided evidence stages are `queued`, `carried`, `served`, and `failed`.

## Ownership and boundaries

- `OrderSystem` owns the Order from `open` to exactly one terminal state: `served` or `cancelled`. Only it records payment and tips.
- `ServiceSliceSession` composes three Cultist Action Queues, one authored Patron, one Order, and physical Prepared Drink state. It emits snapshots and visible service events.
- `CultistActionQueue` remains the authority for one active and up to three pending Actions, cancellation before the Commitment Point, pending removal, stale-target failure, and progression.
- The HUD stores no gameplay truth. It submits commands and rebuilds its selected-Cultist view from emitted snapshots.

The slice uses a provisional balance value of `$5` payment, `$2` tip within 30 seconds, `$1` within 45 seconds, and no tip afterward. Those values are data candidates for later tuning, not a new economy system.

## Focused verification

- Happy path: `Prepare → Pick up → Deliver → Return to bar`; the physical Prepared Drink moves from the bar to the selected Cultist to June; the Order becomes served and pays once.
- Stale path: June leaves; the Order becomes cancelled, service Actions fail visibly as invalid targets, the safe final Action continues, and payment remains zero.
- Queue controls: the selected-Cultist HUD exposes an `×` for active cancellation before commitment and immediate removal of pending Actions.
- Complete headless suite: 15 tests and 142 assertions.

## Deliberate exclusions

- Automatic Orders, impatience timers, the second failed Order, and Normal Departure belong to later tickets.
- Navigation travel is represented by Action durations here; the navigation spike already proved movement and reservations separately.
- Recipes, drink varieties, inventory, tabs, and supply management remain out of scope.
