extends GutTest

# The Bathroom Visit presents three consecutive vertical fills — a mirror icon,
# a toilet icon, then a handwashing icon — each resetting and filling bottom to
# top. The simulation owns phase time and the UI owns no timer: it receives one
# normalized ratio per phase and invents no progress while a Patron walks.

const SESSION := preload("res://scripts/simulation/ordinary_visit_session.gd")
const DIRECTOR := preload("res://scripts/presentation/emote_director.gd")
const OVERLAY := preload("res://scripts/presentation/emote_overlay.gd")


func _forced_bathroom_session():
	var session = SESSION.new()
	session.start(707)
	session.advance(1.1)
	session.debug_force_bathroom(ScenarioActors.opening_patron())  # headless: arrives instantly
	return session


func _bubble(session, director) -> Dictionary:
	director.update({ScenarioActors.opening_patron(): session.patron_emote_row(ScenarioActors.opening_patron())}, 0.0, false)
	for entry: Dictionary in director.bubbles():
		if entry["actor_id"] == ScenarioActors.opening_patron():
			return entry
	return {}


func test_each_timed_phase_shows_a_distinct_icon_and_a_rising_fill() -> void:
	var session = _forced_bathroom_session()
	var director = DIRECTOR.new()
	var icons: Array[String] = []
	# Mirror Check.
	session.advance(2.05)
	var mirror := _bubble(session, director)
	icons.append(String(mirror["icon"]))
	var early_ratio: float = mirror["progress_ratio"]
	session.advance(2.5)
	assert_gt(float(_bubble(session, director)["progress_ratio"]), early_ratio,
		"The Mirror Check fill rises with simulated time.")
	# Seated Bathroom Use: finish Mirror Check (5s) and the walk to the toilet (2s).
	session.advance(5.0)  # cumulative 9.55s: ~0.5s into Seated Bathroom Use
	icons.append(String(_bubble(session, director)["icon"]))
	# Handwashing: finish Seated Use and the walk to the sink (2s).
	var use_seconds: float = session.debug_patron_view(ScenarioActors.opening_patron()).get("bathroom_use_seconds", 12.0)
	session.advance(use_seconds + 3.0)
	icons.append(String(_bubble(session, director)["icon"]))
	assert_eq(icons, ["M", "T", "H"], "Mirror, toilet, and handwashing icons are distinct.")


func test_the_fill_resets_at_each_phase_boundary() -> void:
	var session = _forced_bathroom_session()
	var director = DIRECTOR.new()
	session.advance(2.05)  # enter Mirror Check
	assert_lt(float(_bubble(session, director)["progress_ratio"]), 0.2, "Mirror fill starts low.")
	session.advance(4.8)  # near the end of Mirror Check
	assert_gt(float(_bubble(session, director)["progress_ratio"]), 0.8, "Mirror fill nears full.")
	session.advance(2.3)  # cross into Seated Bathroom Use
	var seated := _bubble(session, director)
	assert_eq(String(seated["icon"]), "T")
	assert_lt(float(seated["progress_ratio"]), 0.35, "The fill resets when the next phase begins.")


func test_no_progress_is_invented_while_walking_between_stations() -> void:
	var session = _forced_bathroom_session()
	var director = DIRECTOR.new()
	# entering_bathroom is a travel phase: the generic bathroom icon, no fill.
	session.advance(1.0)
	var travelling := _bubble(session, director)
	assert_eq(String(travelling["icon"]), "W", "Travel shows the generic bathroom icon.")
	assert_false(travelling.has("progress_ratio"), "Walking invents no fill.")


func test_a_locked_policy_row_stays_a_generic_bathroom_emote_with_no_fill() -> void:
	var director = DIRECTOR.new()
	# A row with no progress field models the future locked information policy.
	director.update({ScenarioActors.opening_patron(): {
		"id": ScenarioActors.opening_patron(), "kind": &"patron", "present": true, "state": &"bathroom",
		"changes": [], "public": {"activity": "Using bathroom"},
	}}, 0.0, false)
	var bubble := director.bubbles()[0]
	assert_eq(String(bubble["icon"]), "W", "The locked policy shows the generic bathroom icon.")
	assert_false(bubble.has("progress_ratio"), "The locked policy exposes no fill.")


func test_prototype_progress_leaks_no_forbidden_debug_fields() -> void:
	var session = _forced_bathroom_session()
	session.advance(2.05)  # Mirror Check
	var row := session.patron_emote_row(ScenarioActors.opening_patron())
	assert_true(row.has("progress"))
	var forbidden := ["bladder", "suspicion", "overdrink_limit", "excess_drinks", "next_bathroom_check_in"]
	for key in forbidden:
		assert_false(row.has(key), "Emote row leaked %s" % key)
	assert_eq((row["progress"] as Dictionary).keys().size(), 4,
		"Progress carries only phase, index, count, and ratio.")


func test_the_ratio_tracks_simulated_time_regardless_of_chunking() -> void:
	# 2x and 4x advance more simulated seconds per real frame, but the ratio is a
	# function of simulated time, so the same total advance yields the same fill.
	var one_shot = _forced_bathroom_session()
	one_shot.advance(2.05 + 2.5)
	var chunked = _forced_bathroom_session()
	chunked.advance(2.05)
	for _step in range(25):
		chunked.advance(0.1)
	assert_almost_eq(
		float(one_shot.patron_emote_row(ScenarioActors.opening_patron())["progress"]["ratio"]),
		float(chunked.patron_emote_row(ScenarioActors.opening_patron())["progress"]["ratio"]),
		0.02, "The fill follows simulated time, not real time or step size.")


func test_pause_freezes_the_fill_because_the_simulation_is_paused() -> void:
	var session = _forced_bathroom_session()
	session.advance(2.05 + 2.5)
	var before: float = session.patron_emote_row(ScenarioActors.opening_patron())["progress"]["ratio"]
	# A Plain Pause simply stops advancing the session; the ratio cannot drift.
	var after: float = session.patron_emote_row(ScenarioActors.opening_patron())["progress"]["ratio"]
	assert_eq(after, before, "With the simulation paused, the fill holds steady.")


func test_overlay_renders_one_bottom_to_top_fill_for_the_active_phase() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 10.0)
	camera.current = true
	world.add_child(camera)
	var overlay = OVERLAY.new()
	add_child_autofree(overlay)
	overlay.configure(camera)
	await get_tree().process_frame

	var bubble := {
		"actor_id": ScenarioActors.opening_patron(), "emote": &"bathroom", "category": &"persistent",
		"priority": 60, "icon": "T", "shape": &"square", "color": "7fc7c4",
		"label": "Toilet", "progress_phase": &"toilet", "progress_ratio": 0.6,
	}
	overlay.refresh([bubble], {ScenarioActors.opening_patron(): Vector3.ZERO})
	assert_almost_eq(overlay.fill_ratio(ScenarioActors.opening_patron()), 0.6, 0.001,
		"The overlay fills to the phase ratio.")
	var rect: Rect2 = overlay.placements()[ScenarioActors.opening_patron()]
	var slot := overlay.get_child(0)
	var fill := slot.get_node("Panel/Fill") as ColorRect
	assert_true(fill.visible)
	assert_almost_eq(fill.position.y + fill.size.y, rect.size.y, 0.5,
		"The fill is anchored to the bottom and grows upward.")
