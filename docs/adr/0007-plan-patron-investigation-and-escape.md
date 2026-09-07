# Plan Patron Investigation and Escape from goals

Patron Investigation and Escape use goal-oriented action planning (GOAP). A Patron Goal describes an intended result; it is distinct from the Patron's Desire, which is the personal fact used by Friendship Capture. The first migration covers Investigation and Escape. Ordinary needs retain their existing transition rules, and Cultists retain player-commanded queues.

This supersedes ADR 0001's transition-table ownership of Investigation and Escape. That table still classifies activities and prevents ordinary actions from replacing urgent work. It no longer chooses or defers actions inside these two goals. ADR 0004's seated Trapdoor misfire remains a specific commitment exception; a direct attack interrupts even that exception.

## Responsibilities

`PatronGoalPlanner` owns perceived facts, goal selection, plan validity, and retry policy. Missing-Companion knowledge selects Investigation. Perceived maximum danger or a direct failed Knock Out selects Escape and replaces the investigation plan. Escape remains committed. An observed Companion return invalidates Investigation and returns the Patron to an available seat, or Normal Departure if none remains. The planner receives no hidden Companion location or capture state.

`GoapPlanner` performs deterministic uniform-cost search over action preconditions, effects, and costs. Action names break equal-cost ties; search stops after 128 expanded states. Expected effects exist only in the search state. They do not change the world or the Patron's knowledge until execution reports success for the current Action identity.

`OrdinaryVisitSession` supplies perceived inputs, validates authoritative availability, and applies gameplay effects. `PatronActionCoordinator.activate_goal_action` starts one planned Action through the shared CharacterActionSystem, clears obsolete deferred work, and respects incapacitation, capture, and terminal guards. The remaining plan is intent, not a set of advance reservations. Reservations are acquired when an Action starts and released when the goal changes or execution fails.

## First action catalog

- Approach the bathroom establishes arrival only after movement completes.
- Search the bathroom requires arrival and owns a fresh five-second queue clock. Successful search discovers the Trapdoor and selects Escape.
- Recover from shock owns the existing two-second queue clock. The avatar stays still during it.
- Leave requires shock to have ended. Only front-exit arrival exposes the operation when physical navigation is enabled; simulation-only runs retain the six-second travel duration.

An attack does not require the Patron to finish drinking or follow the bathroom's mirror, toilet, and handwashing sequence. Capture clears the plan. Interception suspends departure and resumes the leave step without repeating shock. Arrival or failure reports for replaced Action identities are ignored.

## Failure and diagnostics

An unavailable bathroom or failed route leaves the goal blocked. Retry after two simulated seconds, with at most three failures against unchanged conditions. A relevant availability or navigation revision permits another attempt. The planner does not rebuild a healthy plan each frame, and route failure never counts as arrival. `GameSession.navigation_changed` is the explicit notification seam for future navigation-geometry changes.

The debug Patron queue displays the goal, known facts, remaining plan, status, and last reason. Normal presentation shows the observable blocked activity and retains the urgent intention without exposing planner facts. Presentation stops movement for stationary planned actions and reports navigation failures back to the goal executor.

## Remaining migration

Drink service, Bathroom Visits, socializing, and Normal Departure remain on the legacy system. Goal scoring thresholds and Trait-driven costs belong to that migration. Physical table clearance, narrow-passage yielding, and route-progress measurement are separate navigation changes; GOAP consumes their success/failure reports rather than replacing them.

## Validation

Test the planner's cost choice, stable tie-breaking, search bounds, and lack of world mutation. Test the simulation through perceived stimuli and Action completion/failure reports: attacks, bathroom phases, occupied rooms, fresh search timing, stale callbacks, exhausted retries, changed routes, interception, and capture. Keep ordinary seeded gameplay traces unchanged. Visual review remains a separate manual check.
