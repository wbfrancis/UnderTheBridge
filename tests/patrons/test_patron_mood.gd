extends GutTest

const MOOD_SCRIPT := preload("res://scripts/patrons/patron_mood.gd")
const SATISFACTION_SCRIPT := preload("res://scripts/patrons/patron_satisfaction.gd")


func test_a_calm_patron_reports_their_satisfaction_band() -> void:
	assert_eq(MOOD_SCRIPT.label(85.0, 0.0), "Happy")
	assert_eq(MOOD_SCRIPT.label(75.0, 10.0), "Content")
	assert_eq(MOOD_SCRIPT.label(30.0, 24.0), "Unhappy")
	assert_eq(MOOD_SCRIPT.label(10.0, 49.0), "Miserable")


func test_fear_takes_the_word_over_at_the_suspicious_band() -> void:
	# One point below the threshold Satisfaction still owns the word.
	assert_eq(MOOD_SCRIPT.label(85.0, 49.0), "Happy")
	assert_eq(MOOD_SCRIPT.label(85.0, 50.0), "Wary", "Fear takes over at 50.")
	assert_eq(MOOD_SCRIPT.label(85.0, 74.0), "Wary")
	assert_eq(MOOD_SCRIPT.label(85.0, 75.0), "Afraid")
	assert_eq(MOOD_SCRIPT.label(85.0, 99.0), "Afraid")
	assert_eq(MOOD_SCRIPT.label(85.0, 100.0), "Panicked")


func test_fear_reports_the_same_word_whatever_the_satisfaction() -> void:
	# A frightened Patron reads the same whether the night went well or badly,
	# which is the point: the player needs the danger, not the service history.
	for satisfaction: float in [0.0, 40.0, 75.0, 100.0]:
		assert_eq(MOOD_SCRIPT.label(satisfaction, 80.0), "Afraid")


func test_is_fear_matches_the_threshold_the_label_uses() -> void:
	assert_false(MOOD_SCRIPT.is_fear(49.0))
	assert_true(MOOD_SCRIPT.is_fear(50.0))
	assert_true(MOOD_SCRIPT.is_fear(100.0))


func test_the_label_reads_a_live_satisfaction_meter() -> void:
	# The derivation must agree with the meter it reads, including modifiers.
	var satisfaction = SATISFACTION_SCRIPT.new()
	assert_eq(MOOD_SCRIPT.label(satisfaction.value(), 0.0), "Content")
	satisfaction.add_modifier(&"smoking", 10.0)
	assert_eq(
		MOOD_SCRIPT.label(satisfaction.value(), 0.0), "Happy", "A modifier can lift the word."
	)
	satisfaction.add_modifier(&"sighted_grime", -40.0)
	assert_eq(MOOD_SCRIPT.label(satisfaction.value(), 0.0), "Unhappy")
	# Suspicion overrides whatever the meter says.
	assert_eq(MOOD_SCRIPT.label(satisfaction.value(), 60.0), "Wary")


func test_mood_stores_nothing_so_two_reads_of_one_state_agree() -> void:
	# Mood owns no value; the same inputs must always give the same word, which
	# is what lets every display site derive it independently without drifting.
	assert_eq(MOOD_SCRIPT.label(62.0, 30.0), MOOD_SCRIPT.label(62.0, 30.0))
	assert_eq(MOOD_SCRIPT.label(62.0, 80.0), MOOD_SCRIPT.label(62.0, 80.0))
