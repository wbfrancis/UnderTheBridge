# Use visible Action Chains

One Cultist owns one ordered, unlimited Action Queue. A proximity-dependent Patron command creates a visible Generated Move Action when the Cultist is not adjacent. The Generated Move and requested Action share one Action Chain identity. Cancellation or failure removes every unfinished link in that chain, then the next unrelated Action starts.

This decision supersedes only ADR 0002's four-Action limit and hidden contextual-command approach. ADR 0002 still controls the single `CultistCommandSystem` seam, serializable targets, one queue authority, `GameSession` eligibility, and activation-time reservations.

The command seam owns proximity policy, Action Chain creation, cascade rules, and reservation transfer. The scene adapter supplies geometry facts and drives navigation. It never creates or changes a chain. The Generated Move tracks the Patron's live valid Approach Position, and its reservation passes to the requested Action without a release gap.

The Bottom HUD keeps the active Action pinned at the left. Pending Action Tiles scroll horizontally without a queue-size limit. A small connector marks adjacent tiles from one Action Chain.

## Considered Options

- Keeping the four-Action limit was rejected because the limit blocked valid player plans without protecting a gameplay rule.
- Keeping approach movement hidden was rejected because players could not see, cancel, or understand a required part of the command.
- Letting the scene adapter build chains was rejected because that would split command policy across the domain seam and one presentation scene.
- Reserving every pending chain at issue time was rejected because pending work must not hold a position before activation.
