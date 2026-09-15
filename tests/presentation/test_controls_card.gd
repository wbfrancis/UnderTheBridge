extends GutTest

# Drives the real playable scene to prove the first-run Controls Card: it blocks
# the Night before any time advances, dismisses through its own button to start
# the Night, persists once per installation, reopens from the Pause Menu without
# clearing that record, and is re-armed by the Developer reset.

const SCENE := "res://scenes/prototypes/main_test.tscn"


func _write_controls_seen(seen: bool) -> void:
	var settings := ConfigFile.new()
	settings.set_value("hud", "emote_labels", false)
	settings.set_value("hud", "ui_scale", 1.0)
	settings.set_value("hud", "controls_seen", seen)
	assert_eq(settings.save("user://settings.cfg"), OK)


func _fresh_scene(controls_seen: bool = false, process_enabled: bool = true):
	_write_controls_seen(controls_seen)
	var presentation = load(SCENE).instantiate()
	if not process_enabled:
		presentation.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(presentation)
	await get_tree().process_frame
	await get_tree().process_frame
	return presentation


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func test_first_run_controls_card_blocks_time_until_dismissed() -> void:
	var presentation = await _fresh_scene(false)
	assert_true(bool(presentation.get("_controls_visible")), "The first-run card is armed.")
	assert_true(bool(presentation._bottom_hud.inspect()["controls_visible"]),
		"The blocking card is on screen.")
	assert_eq(presentation.get("_session").snapshot()["simulated_seconds"], 0.0,
		"The playable Night is still at 0:00 when the Controls Card appears.")

	# The Night is held while the card blocks, even at the fastest speed.
	presentation._submit_playback(&"select_speed", {"value": 4.0})
	await _wait_frames(12)
	assert_eq(presentation.get("_session").snapshot()["simulated_seconds"], 0.0,
		"The Night does not advance behind the blocking Controls Card.")

	# Dismissing it starts the Night and records that the guide was seen.
	presentation._on_hud_intent(&"close_controls", {})
	assert_false(bool(presentation.get("_controls_visible")))
	assert_true(bool(presentation.get("_controls_seen")))
	await _wait_frames(12)
	assert_gt(presentation.get("_session").snapshot()["simulated_seconds"], 0.0,
		"The dismissed card releases the held Night.")


func test_dismissal_persists_so_the_card_stays_seen_across_a_reload() -> void:
	var first = await _fresh_scene(false)
	assert_true(bool(first.get("_controls_visible")))
	first._on_hud_intent(&"close_controls", {})  # marks and saves seen=true
	assert_true(bool(first.get("_controls_seen")))

	# A freshly loaded scene reads the persisted flag and does not block.
	var second = load(SCENE).instantiate()
	second.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(second)
	await get_tree().process_frame
	assert_true(bool(second.get("_controls_seen")), "The seen flag persisted across a reload.")
	assert_false(bool(second.get("_controls_visible")),
		"A returning player is not blocked by the Controls Card.")
	assert_eq(second.get("_session").snapshot()["simulated_seconds"], 0.0,
		"A returning player is created at 0:00 before live processing begins.")
	second.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_frames(12)
	assert_gt(second.get("_session").snapshot()["simulated_seconds"], 0.0,
		"A returning player's Night begins immediately.")


func test_pause_reopen_keeps_the_record_and_developer_reset_rearms_the_card() -> void:
	var presentation = await _fresh_scene(true)
	presentation.set("_controls_seen", true)
	presentation.set("_controls_visible", false)

	# Reopening from the Pause Menu shows the card without changing the record.
	presentation._on_hud_intent(&"open_controls", {})
	assert_true(bool(presentation.get("_controls_visible")))
	presentation._on_hud_intent(&"close_controls", {})
	assert_true(bool(presentation.get("_controls_seen")),
		"A Pause-Menu reopen never clears the seen record.")

	# The Developer reset re-arms the blocking card for the next Night start.
	presentation._on_hud_intent(&"reset_controls_card", {})
	assert_false(bool(presentation.get("_controls_seen")), "Reset clears the seen record.")
	presentation._arm_first_run_controls()
	assert_true(bool(presentation.get("_controls_visible")),
		"After a reset the blocking card appears again.")
