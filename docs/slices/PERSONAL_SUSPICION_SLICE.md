# Personal Suspicion slice

Ticket #9 adds one independent Suspicion state per Patron to the ordinary-visit simulation.

## Player presentation

Normal play exposes a qualitative band and a plain-language visible cause. Exact values, cause classifications, recovery timing, downgrade counts, and maximum-response selection are confined to the debug presentation.

## Approved rules represented

- Bands are Calm (0–24), Uneasy (25–49), Suspicious (50–74), Alarmed (75–99), and Maximum (100).
- Soft Suspicion waits for 20 quiet seconds, then recovers by 5 every 10 seconds.
- Hard Evidence normally sets permanent Maximum Suspicion and selects Escape.
- A Max Drunk observer converts each Hard Evidence observation into recoverable +25 Suspicion at observation time.
- Missing Companion at 40 seconds sets Maximum Suspicion and selects Investigation.

## Run and verify

Run `tools/personal_suspicion/run_slice.ps1`. It executes the lean test suite, captures all five evidence states, and writes `artifacts/personal_suspicion/validation.json`.
