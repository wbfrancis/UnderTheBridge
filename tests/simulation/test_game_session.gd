extends GutTest

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"


func test_time_controls_advance_without_rendering() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	assert_not_null(game_session_script, "GameSession should be available through its public script.")
	if game_session_script == null:
		return

	var session = game_session_script.new()
	session.start_night(12_345)

	assert_true(session.set_time_scale(0.0))
	session.advance(10.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 0.0, 0.0001)

	assert_true(session.set_time_scale(1.0))
	session.advance(5.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 5.0, 0.0001)

	assert_true(session.set_time_scale(2.0))
	session.advance(3.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 11.0, 0.0001)

	assert_true(session.set_time_scale(4.0))
	session.advance(2.0)
	assert_almost_eq(float(session.snapshot()["simulated_seconds"]), 19.0, 0.0001)

	assert_false(session.set_time_scale(3.0), "Only pause, 1x, 2x, and 4x are supported.")
	assert_almost_eq(float(session.snapshot()["time_scale"]), 4.0, 0.0001)


func test_seeded_replay_is_repeatable_and_restart_is_clean() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	assert_not_null(game_session_script)
	if game_session_script == null:
		return

	var first_session = game_session_script.new()
	var replay_session = game_session_script.new()
	first_session.start_night(77_031)
	replay_session.start_night(77_031)
	first_session.set_time_scale(4.0)
	replay_session.set_time_scale(4.0)
	first_session.advance(5.0)
	replay_session.advance(5.0)

	var first_snapshot: Dictionary = first_session.snapshot()
	var replay_snapshot: Dictionary = replay_session.snapshot()
	assert_eq(first_snapshot["night_seed"], 77_031)
	assert_gt(first_snapshot["representative_rolls"].size(), 0)
	assert_eq(first_snapshot["representative_rolls"], replay_snapshot["representative_rolls"])
	assert_eq(first_snapshot["representative_outcome"], replay_snapshot["representative_outcome"])

	first_session.restart_night(88_042)
	var restarted_snapshot: Dictionary = first_session.snapshot()
	assert_eq(restarted_snapshot["night_seed"], 88_042)
	assert_almost_eq(float(restarted_snapshot["simulated_seconds"]), 0.0, 0.0001)
	assert_almost_eq(float(restarted_snapshot["time_scale"]), 1.0, 0.0001)
	assert_true(restarted_snapshot["representative_rolls"].is_empty())
	assert_eq(restarted_snapshot["representative_outcome"], &"running")


func test_all_authored_arrival_groups_complete_non_capture_visits() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.set_time_scale(4.0)
	session.advance(270.0)

	var state: Dictionary = session.snapshot()
	assert_eq(state["patrons"]["authored_count"], 8)
	assert_eq(state["patrons"]["arrived_count"], 8)
	assert_eq(state["patrons"]["normal_departure_count"], 8)
	assert_eq(state["patrons"]["active_count"], 0)
	assert_eq(state["patrons"]["arrival_groups"].size(), 4)
	assert_eq(state["orders"]["served_count"], 8)
	assert_eq(state["captures"], 0)


func test_safe_autonomy_serves_or_idles_and_never_starts_capture() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(210.0)

	var state: Dictionary = session.snapshot()
	assert_gt(state["safe_autonomy"]["events"].size(), 0)
	assert_eq(state["safe_autonomy"]["capture_actions_started"], 0)
	assert_eq(state["cultists"].size(), 3)
	for cultist_id: StringName in state["cultists"]:
		assert_true(
			state["cultists"][cultist_id]["activity"] in [&"safe_service", &"idle"],
			"Safe autonomy may only perform service or idle behavior."
		)


func test_time_controls_reach_closing_and_basic_non_capture_results() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)

	session.set_time_scale(0.0)
	session.advance(120.0)
	assert_eq(session.snapshot()["phase"], &"preparation")
	assert_eq(session.snapshot()["simulated_seconds"], 0.0)

	session.set_time_scale(1.0)
	session.advance(60.0)
	assert_eq(session.snapshot()["phase"], &"active_operation")
	session.set_time_scale(2.0)
	session.advance(450.0)
	assert_eq(session.snapshot()["phase"], &"closing")
	session.set_time_scale(4.0)
	session.advance(30.0)

	var results_state: Dictionary = session.snapshot()
	assert_eq(results_state["phase"], &"results")
	assert_eq(results_state["outcome"], &"failed_operation")
	assert_true(results_state["results"]["visible"])
	assert_eq(results_state["results"]["night_seed"], 707)
	assert_false(session.set_time_scale(1.0), "Results stop the Night clock until restart.")


func test_restart_constructs_a_clean_second_night() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.set_time_scale(4.0)
	session.advance(270.0)
	assert_gt(session.snapshot()["orders"]["served_count"], 0)

	session.restart_night(808)
	var restarted: Dictionary = session.snapshot()
	assert_eq(restarted["night_seed"], 808)
	assert_eq(restarted["phase"], &"preparation")
	assert_eq(restarted["simulated_seconds"], 0.0)
	assert_eq(restarted["time_scale"], 1.0)
	assert_eq(restarted["patrons"]["active_count"], 0)
	assert_eq(restarted["orders"]["all"].size(), 0)
	assert_eq(restarted["runtime"]["spawned_patrons"], 0)
	assert_eq(restarted["runtime"]["prepared_drinks"], 0)
	assert_eq(restarted["runtime"]["actions"], 0)
	assert_eq(restarted["runtime"]["reservations"], 0)
	assert_eq(restarted["runtime"]["timers"], 0)
	assert_true(restarted["visit_events"].is_empty())
	assert_false(restarted["results"]["visible"])


func test_personal_suspicion_is_independent_and_hidden_behind_normal_bands() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	assert_true(session.report_patron_stimulus(&"patron_june", &"cancelled_order"))
	assert_true(session.report_patron_stimulus(&"patron_june", &"cancelled_order"))
	var state: Dictionary = session.snapshot()
	var june_normal: Dictionary = state["normal_patron_views"][&"patron_june"]
	var mara_normal: Dictionary = state["normal_patron_views"][&"patron_mara"]
	var june_debug: Dictionary = state["debug_patron_views"][&"patron_june"]

	assert_eq(june_normal["suspicion_band"], "Uneasy")
	assert_eq(june_normal["suspicion_cue"], "Cancelled Order")
	assert_eq(mara_normal["suspicion_band"], "Calm")
	assert_eq(mara_normal["suspicion_cue"], "No concern")
	assert_false(june_normal.has("suspicion"), "Normal play must not expose exact Suspicion.")
	assert_eq(june_debug["suspicion"], 30.0)
	assert_eq(june_debug["suspicion_cause"], &"soft")
	assert_eq(june_debug["latest_suspicion_stimulus"], &"cancelled_order")


func test_soft_suspicion_recovers_only_after_quiet_period_at_approved_rate() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)
	session.report_patron_stimulus(&"patron_june", &"cancelled_order")
	session.report_patron_stimulus(&"patron_june", &"cancelled_order")

	session.advance(29.9)
	var waiting: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(waiting["suspicion"], 30.0)
	assert_almost_eq(waiting["suspicion_next_recovery_in"], 0.1, 0.001)
	session.advance(0.1)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 25.0)
	session.advance(10.0)
	var debug: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(debug["suspicion"], 20.0)
	assert_eq(debug["suspicion_cause"], &"soft")
	assert_true(debug["suspicion_recoverable"])

	session.advance(40.0)
	var recovered: Dictionary = session.snapshot()
	assert_eq(recovered["debug_patron_views"][&"patron_june"]["suspicion"], 0.0)
	assert_false(recovered["debug_patron_views"][&"patron_june"]["suspicion_recoverable"])
	assert_eq(recovered["normal_patron_views"][&"patron_june"]["suspicion_band"], "Calm")
	assert_eq(recovered["normal_patron_views"][&"patron_june"]["suspicion_cue"], "No concern")


func test_hard_evidence_creates_permanent_maximum_suspicion_and_escape_response() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	assert_true(session.report_patron_stimulus(&"patron_mara", &"drink_dosed_seen"))
	var observed: Dictionary = session.snapshot()
	assert_eq(observed["normal_patron_views"][&"patron_mara"]["suspicion_band"], "Maximum")
	var debug: Dictionary = observed["debug_patron_views"][&"patron_mara"]
	assert_eq(debug["suspicion"], 100.0)
	assert_eq(debug["suspicion_cause"], &"hard_evidence")
	assert_eq(debug["suspicion_maximum_response"], &"escape")
	assert_false(debug["suspicion_recoverable"])

	session.advance(120.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_mara"]["suspicion"], 100.0)


func test_max_drunk_observer_converts_each_hard_evidence_event_to_recoverable_twenty_five() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	assert_true(session.report_patron_stimulus(&"patron_june", &"knockout_witnessed", true))
	var first: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(first["suspicion"], 25.0)
	assert_eq(first["suspicion_cause"], &"soft")
	assert_true(first["suspicion_recoverable"])
	assert_eq(first["hard_evidence_downgrade_count"], 1)

	session.advance(30.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 20.0)
	assert_true(session.report_patron_stimulus(&"patron_june", &"trapdoor_capture_witnessed", true))
	var second: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(second["suspicion"], 45.0)
	assert_eq(second["hard_evidence_downgrade_count"], 2)
	assert_eq(second["suspicion_maximum_response"], &"none")


func test_approved_danger_and_missing_companion_causes_select_their_responses() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	assert_true(session.report_patron_stimulus(&"patron_june", &"knockout_heard"))
	var june: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(june["suspicion"], 25.0)
	assert_eq(june["suspicion_cause"], &"general_danger")
	assert_true(june["suspicion_recoverable"])

	assert_true(session.report_patron_stimulus(&"patron_mara", &"missing_companion_40"))
	var mara: Dictionary = session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(mara["suspicion"], 100.0)
	assert_eq(mara["suspicion_cause"], &"missing_companion")
	assert_eq(mara["suspicion_maximum_response"], &"investigation")


func test_auditory_danger_reaches_only_rooms_in_the_hearing_relationship() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	var same_room: Array = session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_01")
	assert_true(&"patron_june" in same_room, "Patrons in the source room hear the knockout.")
	assert_true(&"patron_mara" in same_room)
	var june: Dictionary = session.snapshot()["debug_patron_views"][&"patron_june"]
	assert_eq(june["suspicion"], 25.0)
	assert_eq(june["suspicion_cause"], &"general_danger")

	var adjacent: Array = session.report_danger_event(&"knockout_heard", &"auditory", &"hallway", &"cultist_01")
	assert_true(&"patron_june" in adjacent, "The hallway is adjacent to the main hall, so its sounds carry.")
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)

	var non_adjacent: Array = session.report_danger_event(&"knockout_heard", &"auditory", &"bathroom", &"cultist_01")
	assert_true(non_adjacent.is_empty(), "The bathroom is not adjacent to the main hall, so it is unheard.")
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)


func test_visual_danger_requires_facing_and_same_room_line_of_sight() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	# The seated pair faces the bar counter at the origin; an event there is in
	# front of them, in the same room, and within range.
	var seen: Array = session.report_danger_event(
		&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(0.0, 0.0)
	)
	assert_true(&"patron_june" in seen, "A danger in the facing cone and same room is seen.")
	assert_true(&"patron_mara" in seen)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)

	# Behind the seated pair, outside the facing cone, so unseen even in the room.
	var behind: Array = session.report_danger_event(
		&"body_drag_seen_first", &"visual", &"main_hall", &"cultist_01", Vector2(-18.0, 6.0)
	)
	assert_true(behind.is_empty(), "A danger behind the Patron falls outside the facing cone.")
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)

	# A different room blocks vision entirely, whatever the position.
	var cross_room: Array = session.report_danger_event(
		&"drink_dosed_seen", &"visual", &"bathroom", &"cultist_01", Vector2(0.0, 0.0)
	)
	assert_true(cross_room.is_empty(), "Cross-room vision is blocked by the room boundary.")
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)


func test_unattended_body_pressure_after_grace_stacks_globally_and_pauses_when_supported() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	session.add_unattended_body(&"body_a", &"hallway", Vector2(14.0, 6.0))
	session.add_unattended_body(&"body_b", &"main_hall", Vector2(0.0, 8.0))
	session.advance(3.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 0.0,
		"No pressure during the 3-second grace period.")

	session.advance(5.0)
	var after_tick: Dictionary = session.snapshot()["debug_patron_views"]
	assert_eq(after_tick[&"patron_june"]["suspicion"], 10.0, "Two bodies stack to +10 per interval.")
	assert_eq(after_tick[&"patron_mara"]["suspicion"], 10.0, "Pressure is global to every active Patron.")

	session.set_unattended_body_state(&"body_a", &"supported")
	session.advance(5.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 15.0,
		"A supported body applies no pressure; only body_b ticks.")

	session.drop_unattended_body(&"body_a", &"main_hall", Vector2(0.0, 8.0))
	session.advance(3.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 15.0,
		"Dropping the body starts a fresh grace period, so it does not tick yet.")
	session.advance(5.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 25.0,
		"After its new grace, body_a resumes pressure alongside body_b.")


func test_companion_influence_drifts_up_toward_highest_nearby_group_member() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	# June and Mara share a table (within 5 m, same room, same Arrival Group).
	# Pin June at a stable sub-maximum with two non-recoverable stimuli so he is a fixed
	# target to chase and does not act on his Suspicion (a Maximum-Suspicion Patron now
	# Escapes, which is covered by the Escape test).
	assert_true(session.report_patron_stimulus(&"patron_june", &"missing_companion_20"))
	assert_true(session.report_patron_stimulus(&"patron_june", &"missing_companion_30"))
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0)

	session.advance(10.0)
	var first: Dictionary = session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(first["suspicion"], 5.0, "Mara drifts up at most 5 per 10-second interval.")
	assert_eq(first["suspicion_cause"], &"companion_influence")
	assert_true(first["suspicion_recoverable"], "Companion influence is soft.")

	session.advance(10.0)
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_mara"]["suspicion"], 10.0,
		"Each interval adds another step.")

	# Influence never overshoots the target and June is not dragged downward by his
	# lower-Suspicion companion.
	session.advance(200.0)
	var settled: Dictionary = session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(settled["suspicion"], 50.0, "Influence stops on equality, so Mara settles at the target.")
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_june"]["suspicion"], 50.0,
		"Influence only moves upward; June is unaffected by Mara.")


func test_debug_view_identifies_perception_source_recipient_cause_and_timing() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	session.report_danger_event(&"knockout_heard", &"auditory", &"main_hall", &"cultist_02")
	var state: Dictionary = session.snapshot()
	var debug: Dictionary = state["debug_patron_views"][&"patron_june"]
	var normal: Dictionary = state["normal_patron_views"][&"patron_june"]

	assert_true(debug.has("recent_perceptions"), "Debug view exposes the perception trace.")
	assert_false(normal.has("recent_perceptions"), "Normal play hides the perception trace.")
	assert_eq(debug["room"], &"main_hall", "Debug view exposes the perceiving room.")
	assert_false(normal.has("room"), "Normal play hides the room model.")

	var trace: Array = debug["recent_perceptions"]
	assert_gt(trace.size(), 0)
	var latest: Dictionary = trace[-1]
	assert_eq(latest["source"], &"cultist_02", "The trace names the stimulus source.")
	assert_eq(latest["recipient"], &"patron_june", "The trace names the recipient.")
	assert_eq(latest["stimulus"], &"knockout_heard")
	assert_eq(latest["cause"], &"general_danger", "The trace names the resulting cause.")
	assert_almost_eq(float(latest["at"]), 100.0, 0.001, "The trace records recent timing.")


func test_full_night_trapdoor_capture_creates_witness_and_companion_consequences() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(100.0)

	# A standing occupant is captured by the Trapdoor pulse in the live Night.
	assert_true(
		session.debug_force_bathroom(&"patron_june"),
		"An arrived Patron can be placed in the bathroom for the scenario."
	)
	assert_true(session.activate_trapdoor(), "The Trapdoor arms against the current occupant.")
	var after_capture: Dictionary = session.snapshot()
	assert_eq(after_capture["debug_patron_views"][&"patron_june"]["lifecycle"], &"captured")
	assert_eq(after_capture["captures"], 1)

	# The captured Patron's Companion grows suspicious of the unexplained absence.
	session.advance(20.0)
	var mara: Dictionary = session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_almost_eq(float(mara["suspicion"]), 25.0, 0.001)
	assert_eq(mara["suspicion_cause"], &"missing_companion")

	# A seated occupant is not captured; the pulse leaves Hard Evidence and the witness stays.
	var witness_session = game_session_script.new()
	witness_session.start_night(707)
	witness_session.advance(100.0)
	assert_true(witness_session.debug_force_bathroom(&"patron_mara"))
	witness_session.advance(2.05)
	var seated: Dictionary = witness_session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(seated["activity"], &"seated_bathroom_use", "The witness has sat down to use the bathroom.")
	assert_true(witness_session.activate_trapdoor())
	var witness: Dictionary = witness_session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(float(witness["suspicion"]), 100.0)
	assert_eq(witness["suspicion_cause"], &"hard_evidence")
	assert_eq(witness["activity"], &"seated_bathroom_use", "The seated witness is not captured and stays put.")
	assert_eq(witness_session.snapshot()["captures"], 0)


func test_missing_companion_max_drives_investigation_while_proof_drives_escape() -> void:
	var game_session_script := load(GAME_SESSION_PATH)

	# Missing-Companion path: capturing June leaves Mara's absence clock running to Maximum,
	# and a missing-Companion Maximum drives Investigation.
	var missing_session = game_session_script.new()
	missing_session.start_night(707)
	missing_session.advance(100.0)
	assert_true(missing_session.debug_force_bathroom(&"patron_june"))
	assert_true(missing_session.activate_trapdoor())
	missing_session.advance(40.0)
	var mara: Dictionary = missing_session.snapshot()["debug_patron_views"][&"patron_mara"]
	assert_eq(float(mara["suspicion"]), 100.0)
	assert_eq(mara["suspicion_cause"], &"missing_companion")
	assert_eq(mara["suspicion_maximum_response"], &"investigation")
	assert_eq(mara["lifecycle"], &"investigating", "Missing-Companion Maximum sends Mara to investigate.")

	# Proof path: seeing his own drink dosed is Hard Evidence, and Hard Evidence at Maximum
	# drives Escape rather than Investigation.
	var proof_session = game_session_script.new()
	proof_session.start_night(707)
	proof_session.advance(200.0)
	assert_true(proof_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen"))
	proof_session.advance(0.2)
	var elias: Dictionary = proof_session.snapshot()["debug_patron_views"][&"patron_elias"]
	assert_eq(float(elias["suspicion"]), 100.0)
	assert_eq(elias["suspicion_cause"], &"hard_evidence")
	assert_eq(elias["lifecycle"], &"escaping", "Proof at Maximum drives Escape.")


func test_escape_forces_single_speed_and_permits_one_five_second_intercept() -> void:
	var game_session_script := load(GAME_SESSION_PATH)
	var session = game_session_script.new()
	session.start_night(707)
	session.advance(200.0)

	# Run at 4x, then trigger an Escape; Escape forces the Night back to 1x.
	assert_true(session.set_time_scale(4.0))
	assert_true(session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen"))
	session.advance(1.0)
	assert_almost_eq(float(session.snapshot()["time_scale"]), 1.0, 0.0001,
		"Starting an Escape forces the Night to 1x.")
	assert_false(session.set_time_scale(4.0), "Faster than 1x is refused while a Patron is escaping.")
	assert_false(session.set_time_scale(2.0))
	assert_eq(session.snapshot()["debug_patron_views"][&"patron_elias"]["lifecycle"], &"escaping")

	# Exactly one 5-second Intercept is permitted per escaping Patron.
	assert_true(session.begin_intercept(&"patron_elias", &"cultist_01"))
	assert_false(session.begin_intercept(&"patron_elias", &"cultist_02"),
		"A second Intercept on the same escaping Patron is refused.")
	assert_false(session.snapshot()["active_intercept"].is_empty())

	session.advance(5.0)
	var after: Dictionary = session.snapshot()
	assert_true(after["active_intercept"].is_empty(), "The 5-second Intercept resolves and releases its slot.")
	assert_eq(after["debug_patron_views"][&"patron_elias"]["lifecycle"], &"escaping",
		"The Patron resumes escaping after a completed Intercept.")
	assert_true(after["debug_patron_views"][&"patron_elias"]["intercept_attempted"])


func test_only_max_suspicion_front_exit_crossing_causes_immediate_defeat() -> void:
	var game_session_script := load(GAME_SESSION_PATH)

	# A clean Night: eight Patrons complete visits and leave through the front exit as
	# Normal Departures. Crossing the exit at calm Suspicion never causes defeat.
	var clean_session = game_session_script.new()
	clean_session.start_night(707)
	clean_session.set_time_scale(4.0)
	clean_session.advance(300.0)
	var clean: Dictionary = clean_session.snapshot()
	assert_eq(clean["phase"], &"results", "The clean Night reaches its results phase.")
	assert_false(clean["defeat"], "Normal Departures across the front exit never cause defeat.")
	assert_ne(clean["outcome"], &"defeat")
	assert_gt(clean["patrons"]["normal_departure_count"], 0, "Patrons did cross the exit normally.")

	# A maximum-Suspicion escaper crossing the same exit causes immediate defeat.
	var loss_session = game_session_script.new()
	loss_session.start_night(707)
	loss_session.advance(200.0)
	assert_true(loss_session.report_patron_stimulus(&"patron_elias", &"drink_dosed_seen"))
	loss_session.advance(0.2)
	assert_eq(loss_session.snapshot()["debug_patron_views"][&"patron_elias"]["lifecycle"], &"escaping")
	loss_session.advance(10.0)
	var loss: Dictionary = loss_session.snapshot()
	assert_true(loss["defeat"], "A maximum-Suspicion escaper reaching the front exit is defeat.")
	assert_eq(loss["outcome"], &"defeat")
	assert_eq(loss["phase"], &"results", "Defeat ends the Night immediately.")
	assert_eq(loss["debug_patron_views"][&"patron_elias"]["lifecycle"], &"exited")
	assert_almost_eq(float(loss["time_scale"]), 0.0, 0.0001, "The results phase pauses the clock.")
