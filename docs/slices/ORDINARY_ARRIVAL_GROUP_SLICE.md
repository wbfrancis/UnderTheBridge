# Ordinary Arrival Group slice

Ticket #7 integrates one authored pair's non-capture visit. It answers whether the ordinary Patron loop is readable and deterministic before later danger systems are layered onto it.

## Included

- exclusive authored seats for June and Mara
- one complete Order, service, drink, payment, and tip per Patron
- seeded five-second bathroom checks only while eligible
- a three-phase Bathroom Visit — Mirror Check, seeded 8–15s Seated Bathroom Use, Handwashing — with standing travel between the mirror, toilet, and sink stations
- bathroom occupancy and Bladder reset at the end of Seated Bathroom Use
- Intoxication gain and one-level decay after four drink-free minutes
- Normal Departure at nine seated minutes, delayed by active visit behavior
- separate normal and debug Patron snapshots

## Deliberately excluded

Suspicion, capture, missing Companions, stay-behind rolls, additional Orders, and the full Night schedule belong to later tickets.

## Focused verification

Run `tools/ordinary_visit/run_slice.ps1`. The runner executes the lean project suite, writes one deterministic JSON report, and captures served, bathroom, debug, and departure evidence frames.
