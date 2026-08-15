# Navigation and Reservation Spike

Status: **Pass — keep the approach**

Ticket: #4

Branch: `prototype/navigation-reservations`

## Question

Can three Cultists and eight Patrons repeatedly navigate a crowded speakeasy greybox at 1x and 4x while one authority prevents duplicate destination ownership and reliably releases reservations after completion, cancellation, and terminal state changes?

## Result

Yes. Both ten-simulated-minute scenarios passed at a real 60 Hz navigation/avoidance step.

| Measurement | 1x | 4x |
|---|---:|---:|
| Completed interactions | 733 | 678 |
| Scheduled cancellations | 31 | 31 |
| Terminal state changes | 8 | 8 |
| Successful repaths | 13 | 25 |
| Stuck events | 0 | 0 |
| Cleanup failures | 0 | 0 |
| Registry invariant violations | 0 | 0 |
| Close-overlap samples below 0.46 m | 0 | 0 |
| Minimum measured agent separation | 0.520 m | 0.473 m |

Every actor completed interactions in both runs. The increased 4x repath count is acceptable: higher-speed path following refreshed paths without producing a fifteen-second stuck event or unreleased reservation.

Primary evidence:

- `artifacts/navigation_reservations/stress_1x.json`
- `artifacts/navigation_reservations/stress_4x.json`
- `artifacts/navigation_reservations/navigation_reservations.png`

## Scenario

The seeded harness uses eleven colored, labeled `CharacterBody3D` actors and nineteen authored destinations:

- eight seats;
- three bar positions;
- one bathroom occupant position;
- two bathroom queue positions;
- four approach points;
- one front exit.

Actors reserve before navigating, interact briefly on arrival, release, then choose another eligible destination. Every nineteen simulated seconds the harness cancels one actor. Every seventy-one simulated seconds it performs a terminal state change, releases the destination, temporarily removes the actor, and reintroduces them through the entrance.

A stuck failure requires fifteen simulated seconds without meaningful movement. The actor requests a new path after each four-second no-progress interval, so successful repaths remain diagnostic data rather than failures.

## Decisions

- Keep one `InteractionRegistry` as the authority for all exclusive destinations.
- A slot has at most one owner and an actor has at most one exclusive reservation.
- Completion, cancellation, and terminal state transitions all call the same `release_actor` seam.
- General destination contention does not create a hidden registry queue. Actors receive rejection and retry later. Bathroom FIFO ordering remains explicit bathroom-domain behavior for its later ticket.
- Reserve the authored approach point before pathing. Do not let collision arrival decide interaction ownership.
- Use `NavigationAgent3D` once per physics frame, 2D RVO avoidance for the flat floor plane, and ordinary actor collision as a last-resort separation constraint.
- Scale desired movement speed and gameplay duration from simulation time while keeping navigation updates at 60 Hz.
- Use one pre-baked static navigation mesh in production. The spike bakes simple static collision geometry at runtime only to remain self-contained.
- Keep automatic testing narrow: the registry exclusivity/cleanup contract is protected by one GUT test; navigation quality remains this measured observational scenario.

These choices follow Godot's documented requirement to call `get_next_path_position()` once per physics frame and use the `velocity_computed` avoidance result to move the parent actor. The runtime bake uses static collision geometry instead of renderer meshes to avoid GPU readback stalls. See the official [NavigationAgent3D reference](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html), [NavigationAgent guide](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html), and [navigation-mesh guide](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html).

## Reproduce

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prototype_navigation\run_stress.ps1
```

The command imports the project, runs the full ten-minute 1x and 4x scenarios headlessly, writes both JSON reports, and then launches a short rendered 4x pass to refresh the screenshot. The full 1x run intentionally processes 36,000 physics frames and can take several minutes in a restricted remote environment.

For a shorter diagnostic run without rendering:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prototype_navigation\run_stress.ps1 -DurationSeconds 60 -Scales 4 -SkipCapture
```

## Deliberate omissions

This is a movement and exclusivity harness, not Patron behavior. It does not implement Arrival Groups, Orders, bathroom FIFO promotion, the Trapdoor, Suspicion, capture behavior, final animation, or production room geometry. The capsule actors, debug labels, runtime bake, autonomous random destination selection, and periodic transition injection are throwaway instrumentation.
