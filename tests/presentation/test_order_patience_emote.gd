extends GutTest

func test_order_fill_tracks_actual_deadline_and_ends_on_cancellation() -> void:
	var session = load("res://scripts/simulation/ordinary_visit_session.gd").new()
	session.start(707)
	session.advance(1.1)
	var patron := ScenarioActors.opening_patron()
	var first: Dictionary = session.patron_emote_row(patron)
	assert_eq(first["progress"]["phase"], &"order_patience")
	var initial := float(first["progress"]["ratio"])
	session.advance(30.0)
	var halfway: Dictionary = session.patron_emote_row(patron)
	assert_almost_eq(float(halfway["progress"]["ratio"]) - initial, 0.5, 0.001)
	var director := EmoteDirector.new()
	director.update({patron: halfway}, 0.1, false)
	var bubble: Dictionary = director.bubbles()[0]
	assert_eq(bubble["progress_phase"], &"order_patience")
	assert_almost_eq(float(bubble["progress_ratio"]), float(halfway["progress"]["ratio"]), 0.001)
	assert_eq(bubble["progress_color"], "e65c70")
	session.advance(30.0)
	assert_false(session.patron_emote_row(patron).has("progress"),
		"Cancelling the order removes its deadline fill.")
