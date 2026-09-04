class_name PatronMood
extends RefCounted

## Mood is the one word the game shows for a Patron's state of mind. It is
## derived whenever it is read and stored nowhere, which is why this class holds
## no state and offers only static reads. Because Mood owns no value and no rule
## consults it, a presentation choice can never alter who escapes: Escape,
## Investigation, tips, and Normal Departure all read Satisfaction or Suspicion
## directly.
##
## Below the Suspicious band the word reports Satisfaction. At or above it the
## word reports fear instead, on Suspicion's own boundaries. The threshold sits
## at 50 so the player gets a full band of warning before an Alarmed Patron
## visibly stops ordering and drifts toward the front.

## The Suspicion score at which fear takes the word over from Satisfaction.
const FEAR_THRESHOLD := 50.0

const WARY := "Wary"
const AFRAID := "Afraid"
const PANICKED := "Panicked"

## Every word Mood can report, ordered from worst to best on the Satisfaction
## side, then the three fear steps. Presentation uses this to know the full set
## without hard-coding it.
const SATISFACTION_WORDS: Array[String] = ["Miserable", "Unhappy", "Content", "Happy"]
const FEAR_WORDS: Array[String] = [WARY, AFRAID, PANICKED]


## The single word for a Patron holding this Satisfaction and this Suspicion.
static func label(satisfaction_value: float, suspicion_score: float) -> String:
	if suspicion_score >= FEAR_THRESHOLD:
		return fear_word(suspicion_score)
	return PatronSatisfaction.band_for_value(satisfaction_value)


## True when Suspicion has taken the word over, so presentation can colour or
## prioritise a frightened Patron without re-deriving the threshold.
static func is_fear(suspicion_score: float) -> bool:
	return suspicion_score >= FEAR_THRESHOLD


## The fear step for a Suspicion score, on Suspicion's own band boundaries.
static func fear_word(suspicion_score: float) -> String:
	if suspicion_score >= 100.0:
		return PANICKED
	if suspicion_score >= 75.0:
		return AFRAID
	return WARY
