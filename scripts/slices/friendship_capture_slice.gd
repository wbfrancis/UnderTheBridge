extends Control

# Headless-first evidence slice for Ticket #14: per-Cultist Friendship built through cigarettes
# and conversation, deterministic Friendship Capture of the sad Patron at Trusted, and one-time
# stay-behind departures — all through the public GameSession API. --report writes a
# machine-checkable validation file, --capture a PNG.

const GAME_SESSION_SCRIPT := preload("res://scripts/simulation/game_session.gd")
const SCENARIOS := {
	"build_friendship": "BUILD FRIENDSHIP",
	"friendship_capture": "FRIENDSHIP CAPTURE",
	"anchor_leaves": "ANCHOR LEAVES",
	"stay_behind": "STAY BEHIND",
	"stay_chance": "STAY CHANCE",
}
const STAY_SEED := 42  # a boosted Mara stays at this seed
const LEAVE_SEED := 707  # a natural Mara leaves at this seed

var _session = GAME_SESSION_SCRIPT.new()
var _scenario: String = "build_friendship"
var _subject_id: int = ScenarioActors.friendship_candidate()
var _cultist_id: int = ActorIds.CULTIST_IDS[0]
var _scenario_trace: String = ""
var _capture_mode: bool = false
var _scenario_buttons: Dictionary = {}
var _state_text: RichTextLabel
var _subject_text: RichTextLabel
var _trace_text: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	_build_ui()
	_set_scenario(_command_line_value("--stage=", "build_friendship"))
	await _finish_command_line_work()


func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("182630")
	normal.border_color = Color("314653")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(9)
	var hover := normal.duplicate()
	hover.bg_color = Color("223743")
	hover.border_color = Color("7399a6")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("704936")
	pressed.border_color = Color("e2a56e")
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("focus", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_color("font_color", "Button", Color("dce7ec"))
	ui_theme.set_color("font_pressed_color", "Button", Color("fff3df"))
	theme = ui_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("081117")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_scenario_strip())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.add_child(_build_state_column())
	body.add_child(_build_trace_column())
	body.add_child(_build_rules_column())
	root.add_child(body)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	var title := Label.new()
	title.text = "UNDER THE BRIDGE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0dbc1"))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "FRIENDSHIP CAPTURE & STAY-BEHIND DEPARTURES  /  TICKET #14"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("8195a2"))
	title_box.add_child(subtitle)

	var rule := Label.new()
	rule.text = "NO AUTONOMOUS CAPTURE  •  the player builds every Friendship"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rule.add_theme_font_size_override("font_size", 15)
	rule.add_theme_color_override("font_color", Color("df9d65"))
	row.add_child(rule)
	return row


func _build_scenario_strip() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	for scenario_id: String in SCENARIOS:
		var button := Button.new()
		button.text = SCENARIOS[scenario_id]
		button.toggle_mode = true
		button.custom_minimum_size.y = 35
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_scenario.bind(scenario_id))
		_scenario_buttons[scenario_id] = button
		row.add_child(button)
	return _panel(row, Color("101d25"), 7)


func _build_state_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("NIGHT STATE", "Friendship, following, departures"))
	_state_text = RichTextLabel.new()
	_state_text.bbcode_enabled = true
	_state_text.scroll_active = false
	_state_text.custom_minimum_size.y = 150
	_state_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_state_text, Color("14242d"), 13))

	column.add_child(_section_title("SUBJECT PATRON", "Friendship matrix, band, state"))
	_subject_text = RichTextLabel.new()
	_subject_text.bbcode_enabled = true
	_subject_text.scroll_active = false
	_subject_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_subject_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_subject_text, Color("101b22"), 13))
	return column


func _build_trace_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 430
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.2
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("SCENARIO TRACE", "What the Friendship route did, step by step"))
	_trace_text = RichTextLabel.new()
	_trace_text.bbcode_enabled = true
	_trace_text.scroll_active = false
	_trace_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trace_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_panel(_trace_text, Color("101b22"), 13))
	return column


func _build_rules_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.add_child(_section_title("ACCEPTANCE CRITERIA", "Ticket #14 — one source of truth"))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.scroll_active = false
	rules.add_theme_font_size_override("normal_font_size", 13)
	rules.text = "[color=#8195a2]FRIENDSHIP[/color]\nStored separately per Cultist, banded Stranger / Acquainted / Friendly / Trusted, and never decays during the Night. A cigarette adds 10; conversation ~0.75 per second.\n\n[color=#8195a2]FRIENDSHIP CAPTURE[/color]\nOnly the sad, receptive Patron follows, and only at Trusted (75+). The lead to the [color=#e7a06c]Tunnel Intake[/color] is deterministic — no roll.\n\n[color=#8195a2]STAY-BEHIND[/color]\nThe departure anchor always leaves; every other eligible member rolls once on the seeded source.\n\n[color=#8195a2]STAY CHANCE[/color]\nclamp(10 + 0.5 x Bartender Friendship + 15 x Intoxication - 0.6 x Suspicion, 0, 90). A maximum-Suspicion Patron never stays."
	column.add_child(_panel(rules, Color("121f27"), 13))
	return column


func _section_title(title: String, subtitle: String) -> Control:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("d8e2e7"))
	box.add_child(heading)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("708591"))
	box.add_child(sub)
	return box


func _panel(content: Control, color: Color, inset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = content.size_flags_vertical
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("263945")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(inset)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


func _set_scenario(scenario_id: String) -> void:
	if not SCENARIOS.has(scenario_id):
		scenario_id = "build_friendship"
	_scenario = scenario_id
	_subject_id = ScenarioActors.friendship_candidate()
	_cultist_id = ActorIds.CULTIST_IDS[0]
	match scenario_id:
		"build_friendship":
			_session.restart_night(707)
			_session.advance(200.0)
			_session.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
			_session.begin_conversation(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
			_session.advance(21.0)
			_session.end_conversation(ActorIds.CULTIST_IDS[0])
			var value: float = _session.friendship_value(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0])
			_scenario_trace = "Offered Elias a cigarette (+10), then conversed 21 s.\nFriendship with Cultist 01 now %.1f (%s); Cultist 02 stays 0.\nFriendship does not decay for the rest of the Night." % [
				value, _session.friendship_band(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0]),
			]
		"friendship_capture":
			_session.restart_night(707)
			_session.advance(200.0)
			for _i in range(8):
				_session.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
			var trusted := _session.begin_friendship_capture(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
			_session.advance(14.1)
			var captured: Dictionary = _session.snapshot()
			_scenario_trace = "Raised Elias to Trusted (%s), then led him out (started=%s).\nHe followed deterministically to the Tunnel Intake — no roll.\nCaptures now %d; lifecycle %s." % [
				_session.friendship_band(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0]), str(trusted),
				captured["captures"], _humanize(_debug_for(ScenarioActors.friendship_candidate())["lifecycle"]),
			]
		"anchor_leaves":
			_subject_id = ScenarioActors.opening_companion()
			_session.restart_night(LEAVE_SEED)
			_session.advance(700.0)
			var anchor: Dictionary = _debug_for(ScenarioActors.opening_patron())
			var member: Dictionary = _debug_for(ScenarioActors.opening_companion())
			_scenario_trace = "June + Mara reach their pre-Closing departure.\nAnchor June always leaves: lifecycle %s.\nMara rolled once (%s) and left: lifecycle %s." % [
				_humanize(anchor["lifecycle"]), str(member["stay_rolled"]), _humanize(member["lifecycle"]),
			]
		"stay_behind":
			_subject_id = ScenarioActors.opening_companion()
			_session.restart_night(STAY_SEED)
			_session.advance(600.0)
			for _i in range(10):
				_session.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.opening_companion())
			var chance: float = _session.stay_behind_chance(ScenarioActors.opening_companion())
			_session.advance(60.0)
			var stayer: Dictionary = _debug_for(ScenarioActors.opening_companion())
			_scenario_trace = "Boosted Mara's stay chance to %.0f%%, then her group left.\nAnchor June departed; Mara's roll kept her behind.\nMara is now a solo Patron: lifecycle %s, stayed %s." % [
				chance, _humanize(stayer["lifecycle"]), str(stayer["stayed_behind"]),
			]
		"stay_chance":
			_session.restart_night(707)
			_session.advance(250.0)
			var intoxication: float = float(_debug_for(ScenarioActors.friendship_candidate())["intoxication_level"])
			var base_chance: float = _session.stay_behind_chance(ScenarioActors.friendship_candidate())
			for _i in range(5):
				_session.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
			var friendly_chance: float = _session.stay_behind_chance(ScenarioActors.friendship_candidate())
			_session.report_patron_stimulus(ScenarioActors.friendship_candidate(), &"knockout_heard")
			var wary_chance: float = _session.stay_behind_chance(ScenarioActors.friendship_candidate())
			_scenario_trace = "Elias Intoxication %.0f -> base stay chance %.0f%%.\nFriendship 50 raises it to %.0f%% (+0.5 per point).\n25 Suspicion lowers it to %.0f%% (-0.6 per point)." % [
				intoxication, base_chance, friendly_chance, wary_chance,
			]
	_refresh(_session.snapshot())


func _refresh(state: Dictionary) -> void:
	for scenario_id: String in _scenario_buttons:
		_scenario_buttons[scenario_id].button_pressed = scenario_id == _scenario
	_state_text.text = _state_markup(state)
	_subject_text.text = _subject_markup(state)
	_trace_text.text = "[color=#e2a56e][b]%s[/b][/color]\n%s" % [SCENARIOS[_scenario], _scenario_trace]


func _state_markup(state: Dictionary) -> String:
	var lines := "Phase  [b]%s[/b]     Clock  [b]%s[/b]\nCaptures  [b]%d[/b] / %d\nDefeat  [b]%s[/b]" % [
		_humanize(state["phase"]), state["clock_label"],
		state["captures"], state["results"]["capture_quota"], str(state["defeat"]),
	]
	var conversations: Dictionary = state["conversations"]
	if not conversations.is_empty():
		for cultist_id: int in conversations:
			lines += "\nConversing  [b]%s[/b] with [b]%s[/b]" % [
				_actor_name(conversations[cultist_id]), _actor_name(cultist_id),
			]
	var follows: Dictionary = state["follows"]
	if follows.has(_subject_id):
		lines += "\nFollowing to intake  [b]%.1f s[/b]" % float(follows[_subject_id]["remaining"])
	return lines


func _subject_markup(state: Dictionary) -> String:
	var subject: Dictionary = state["debug_patron_views"][_subject_id]
	var friendship: Dictionary = subject["friendship"]
	return "[color=#e9edf0][b]%s[/b][/color]\nLifecycle  [b]%s[/b]     Intoxication  [b]%d[/b]\nStay rolled  [b]%s[/b]  ·  Stayed  [b]%s[/b]\nReceptive to Friendship Capture  [b]%s[/b]\n\n[color=#e9edf0][b]Friendship matrix[/b][/color]\nCultist 01  [b]%.1f[/b]  (%s)\nCultist 02  [b]%.1f[/b]  (%s)\nCultist 03  [b]%.1f[/b]  (%s)" % [
		_actor_name(_subject_id), _humanize(subject["lifecycle"]), int(subject["intoxication_level"]),
		str(subject["stay_rolled"]), str(subject["stayed_behind"]), str(subject["friendship_capturable"]),
		float(friendship[ActorIds.CULTIST_IDS[0]]), _band(float(friendship[ActorIds.CULTIST_IDS[0]])),
		float(friendship[ActorIds.CULTIST_IDS[1]]), _band(float(friendship[ActorIds.CULTIST_IDS[1]])),
		float(friendship[ActorIds.CULTIST_IDS[2]]), _band(float(friendship[ActorIds.CULTIST_IDS[2]])),
	]


func _band(value: float) -> String:
	if value >= 75.0:
		return "Trusted"
	if value >= 50.0:
		return "Friendly"
	if value >= 25.0:
		return "Acquainted"
	return "Stranger"


func _debug_for(patron_id: int) -> Dictionary:
	return _session.snapshot()["debug_patron_views"][patron_id]


func _humanize(value: Variant) -> String:
	return str(value).replace("_", " ").capitalize()


func _actor_name(actor_id: Variant) -> String:
	if actor_id is int:
		return ActorRoster.display_name(actor_id)
	return str(actor_id).replace("arrival_group_", "").replace("_", " ").capitalize()



func _command_line_value(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _finish_command_line_work() -> void:
	var capture_path := _command_line_value("--capture=")
	var report_path := _command_line_value("--report=")
	_capture_mode = not capture_path.is_empty() or not report_path.is_empty()
	if not report_path.is_empty():
		var absolute_report := ProjectSettings.globalize_path(report_path)
		DirAccess.make_dir_recursive_absolute(absolute_report.get_base_dir())
		var report := FileAccess.open(absolute_report, FileAccess.WRITE)
		report.store_string(JSON.stringify(_validation_report(), "  "))
	if not capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		var absolute_capture := ProjectSettings.globalize_path(capture_path)
		DirAccess.make_dir_recursive_absolute(absolute_capture.get_base_dir())
		get_viewport().get_texture().get_image().save_png(absolute_capture)
		get_tree().quit()
	elif not report_path.is_empty():
		get_tree().quit()


func _validation_report() -> Dictionary:
	# AC1: Friendship is per-Cultist, banded, and does not decay.
	var build = GAME_SESSION_SCRIPT.new()
	build.start_night(707)
	build.advance(200.0)
	build.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	var per_cultist: bool = is_equal_approx(build.friendship_value(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0]), 10.0) \
		and is_equal_approx(build.friendship_value(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[1]), 0.0)
	build.begin_conversation(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	build.advance(21.0)
	build.end_conversation(ActorIds.CULTIST_IDS[0])
	var built: float = build.friendship_value(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0])
	var band_ok: bool = build.friendship_band(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0]) == "Acquainted"
	build.advance(120.0)
	var no_decay: bool = is_equal_approx(build.friendship_value(ScenarioActors.friendship_candidate(), ActorIds.CULTIST_IDS[0]), built)

	# AC2: only the sad Patron follows, only at Trusted, captured at the intake.
	var capture = GAME_SESSION_SCRIPT.new()
	capture.start_night(707)
	capture.advance(200.0)
	var sub_trusted_refused: bool = not capture.begin_friendship_capture(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	for _i in range(8):
		capture.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	var trusted_follows: bool = capture.begin_friendship_capture(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	capture.advance(14.1)
	var captured_at_intake: bool = capture.snapshot()["captures"] == 1 \
		and capture.snapshot()["debug_patron_views"][ScenarioActors.friendship_candidate()]["lifecycle"] == &"captured"
	for _j in range(8):
		capture.offer_cigarette(ActorIds.CULTIST_IDS[1], ScenarioActors.opening_patron())
	var non_sad_refused: bool = not capture.begin_friendship_capture(ActorIds.CULTIST_IDS[1], ScenarioActors.opening_patron()) \
		and capture.snapshot()["debug_patron_views"][ScenarioActors.opening_patron()]["lifecycle"] == &"active"

	# AC3: the anchor leaves and others roll once; a boosted roll can stay.
	var leave = GAME_SESSION_SCRIPT.new()
	leave.start_night(LEAVE_SEED)
	leave.advance(700.0)
	var leave_views: Dictionary = leave.snapshot()["debug_patron_views"]
	var anchor_leaves: bool = leave_views[ScenarioActors.opening_patron()]["lifecycle"] == &"exited" \
		and not leave_views[ScenarioActors.opening_patron()]["stay_rolled"] \
		and leave_views[ScenarioActors.opening_companion()]["stay_rolled"]

	var stay = GAME_SESSION_SCRIPT.new()
	stay.start_night(STAY_SEED)
	stay.advance(600.0)
	for _k in range(10):
		stay.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.opening_companion())
	stay.advance(60.0)
	var stay_views: Dictionary = stay.snapshot()["debug_patron_views"]
	var stayer_becomes_solo: bool = stay_views[ScenarioActors.opening_patron()]["lifecycle"] == &"exited" \
		and stay_views[ScenarioActors.opening_companion()]["stayed_behind"] \
		and stay_views[ScenarioActors.opening_companion()]["lifecycle"] == &"active" \
		and stay_views[ScenarioActors.opening_companion()]["suspicion_cause"] != &"missing_companion"

	# AC4: the stay chance uses Friendship, Intoxication, and Suspicion with the clamp.
	var math = GAME_SESSION_SCRIPT.new()
	math.start_night(707)
	math.advance(250.0)
	var intoxication := float(math.snapshot()["debug_patron_views"][ScenarioActors.friendship_candidate()]["intoxication_level"])
	var base_ok: bool = is_equal_approx(math.stay_behind_chance(ScenarioActors.friendship_candidate()),
		clampf(10.0 + 15.0 * intoxication, 0.0, 90.0))
	for _m in range(5):
		math.offer_cigarette(ActorIds.CULTIST_IDS[0], ScenarioActors.friendship_candidate())
	var friendly_ok: bool = is_equal_approx(math.stay_behind_chance(ScenarioActors.friendship_candidate()),
		clampf(10.0 + 0.5 * 50.0 + 15.0 * intoxication, 0.0, 90.0))
	math.report_patron_stimulus(ScenarioActors.friendship_candidate(), &"knockout_heard")
	var suspicion_ok: bool = is_equal_approx(math.stay_behind_chance(ScenarioActors.friendship_candidate()),
		clampf(10.0 + 25.0 + 15.0 * intoxication - 0.6 * 25.0, 0.0, 90.0))
	math.report_patron_stimulus(ScenarioActors.friendship_candidate(), &"drink_dosed_seen")
	var max_never_stays: bool = is_equal_approx(math.stay_behind_chance(ScenarioActors.friendship_candidate()), 0.0)

	var checks := {
		"friendship_stored_per_cultist": per_cultist,
		"friendship_bands_and_no_decay": band_ok and no_decay,
		"sub_trusted_cannot_follow": sub_trusted_refused,
		"trusted_sad_patron_captured_at_intake": trusted_follows and captured_at_intake,
		"non_sad_patron_never_follows": non_sad_refused,
		"anchor_leaves_and_others_roll_once": anchor_leaves,
		"successful_roll_makes_solo_patron": stayer_becomes_solo,
		"stay_chance_uses_all_terms_with_clamp": base_ok and friendly_ok and suspicion_ok and max_never_stays,
	}
	return {
		"passed": not checks.values().has(false),
		"slice": "friendship_capture",
		"checks": checks,
		"observed": {
			"built_friendship": built,
			"trusted_follows": trusted_follows,
			"leave_seed_mara": leave_views[ScenarioActors.opening_companion()]["lifecycle"],
			"stay_seed_mara": stay_views[ScenarioActors.opening_companion()]["lifecycle"],
			"intoxication": intoxication,
		},
	}
