class_name ProductionReviewHarness
extends RefCounted

## Automation-only adapter for the production presentation scene.
## The live scene exposes review operations; this module owns command-line input,
## artifact output, deterministic validation setup, and report construction.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")


func value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func flag(name: String) -> bool:
	return name in OS.get_cmdline_user_args()


func capture_after_render(
		host: Node, capture_path: String, wait_frames: int, emote_play_scale: float
) -> void:
	if emote_play_scale >= 0.0:
		await host.call("_wait_for_patrons", wait_frames)
		host.call("_stage_emote_states")
		for _settle in 60:
			await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var staged_result := _save_viewport(host, capture_path)
		await host.get_tree().process_frame
		host.get_tree().quit(staged_result)
		return
	for _frame in wait_frames:
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := _save_viewport(host, capture_path)
	await host.get_tree().process_frame
	host.get_tree().quit(result)


func write_validation_report(host: Node, report_path: String, facts: Dictionary) -> void:
	await host.get_tree().process_frame
	var validation_session = GAME_SESSION_SCRIPT.new()
	validation_session.start_night(707)
	validation_session.advance(421.0)
	var full_cast: Dictionary = validation_session.snapshot()

	var state_session = GAME_SESSION_SCRIPT.new()
	state_session.start_night(707)
	state_session.advance(95.0)
	state_session.begin_knockout(ActorIds.CULTIST_IDS[0], ScenarioActors.opening_patron())
	state_session.begin_conversation(ActorIds.CULTIST_IDS[1], ScenarioActors.opening_companion())
	state_session.prepare_drugged_drink(ScenarioActors.opening_companion(), ActorIds.CULTIST_IDS[2])
	var cultists: Dictionary = state_session.snapshot()["cultists"]

	var scale_session = GAME_SESSION_SCRIPT.new()
	scale_session.start_night(707)
	var four_x_supported: bool = scale_session.set_time_scale(4.0)
	scale_session.advance(1.0)
	four_x_supported = four_x_supported and is_equal_approx(
		float(scale_session.snapshot()["simulated_seconds"]), 4.0
	)

	var source_hash := FileAccess.get_sha256(String(facts["visual_spike_source"]))
	var main_floor := host.find_child("MainRoomFloor", true, false) as MeshInstance3D
	var front_floor := host.find_child("FrontFloor", true, false) as MeshInstance3D
	var checks := {
		"visual_spike_source_unchanged": source_hash == facts["visual_spike_expected_sha256"],
		"all_five_spaces_present": (
			host.find_child("MainRoomFloor", true, false) != null
			and host.find_child("FrontFloor", true, false) != null
			and host.find_child("HallwayFloor", true, false) != null
			and host.find_child("BathroomFloor", true, false) != null
			and host.find_child("IntakeThreshold", true, false) != null
		),
		"three_cultists_exposed": full_cast["cultists"].size() == 3,
		"eight_patrons_exposed": full_cast["debug_patron_views"].size() == 8,
		"eight_distinct_patron_palettes": int(facts["patron_palette_count"]) == 8,
		"active_cultist_states_readable": (
			cultists[ActorIds.CULTIST_IDS[0]]["activity"] == &"knockout_windup"
			and cultists[ActorIds.CULTIST_IDS[1]]["activity"] == &"conversing"
			and cultists[ActorIds.CULTIST_IDS[2]]["activity"] == &"preparing_drugged_drink"
		),
		"four_x_simulation_supported": four_x_supported,
		"entrance_is_left_of_main_hall": host.call("_floor_is_left_of", front_floor, main_floor),
		"hallway_has_no_foreground_wall": host.find_child("HallwayNorthWall", true, false) == null,
		"main_floor_tiles_are_square": host.call("_floor_tiles_are_square", main_floor),
		"minus_and_equals_zoom_without_shift": host.call("_keyboard_zoom_keys_work"),
		"trackpad_pans_in_all_directions": host.call("_trackpad_pans_in_all_directions"),
		"command_trackpad_zoom_is_smooth": host.call("_command_trackpad_zoom_is_smooth"),
		"camera_pan_is_fast_and_eased": host.call("_camera_pan_is_fast_and_eased"),
		"service_area_has_no_loose_labels": host.call("_service_area_labels_are_correct"),
		"service_and_front_buttons_use_consistent_camera": host.call(
			"_service_and_front_buttons_use_consistent_camera"
		),
	}
	var report := {
		"passed": not checks.values().has(false),
		"slice": "ticket16_migrated_presentation",
		"checks": checks,
		"observed": {
			"visual_spike_sha256": source_hash,
			"cultist_count": full_cast["cultists"].size(),
			"patron_count": full_cast["debug_patron_views"].size(),
			"main_hall_metres": [27.0, 12.0],
			"front_metres": [7.0, 14.0],
			"hallway_metres": [4.0, 6.0],
			"bathroom_metres": [4.0, 6.0],
			"cultist_visible_height_metres": facts["cultist_visible_height_metres"],
			"main_floor_tile_metres": host.call("_floor_tile_metres", main_floor),
			"camera_pan_speed_metres_per_second": facts["camera_pan_speed"],
			"camera_pan_acceleration_metres_per_second_squared": facts["camera_pan_acceleration"],
			"camera_pan_deceleration_metres_per_second_squared": facts["camera_pan_deceleration"],
			"service_area_labels": host.call("_service_area_labels"),
		},
	}
	var wrote := save_json(report_path, report)
	host.get_tree().quit(0 if wrote and bool(report["passed"]) else 1)


func save_json(report_path: String, report: Dictionary) -> bool:
	var absolute_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "  "))
	return true


func _save_viewport(host: Node, capture_path: String) -> int:
	var absolute_path := ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	return host.get_viewport().get_texture().get_image().save_png(absolute_path)
