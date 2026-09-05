extends GutTest

const SUBJECT_ACTOR_ID: int = 1001
const OTHER_ACTOR_ID: int = 1002
const THIRD_ACTOR_ID: int = 1003

const GAME_SESSION_PATH := "res://scripts/simulation/game_session.gd"
const EMOTE_DIRECTOR_PATH := "res://scripts/presentation/emote_director.gd"

# Every hidden simulation value the sanitized emote_view must never carry.
const FORBIDDEN_KEYS: Array[String] = [
	"suspicion", "suspicion_cause", "bladder", "bathroom_probability",
	"next_bathroom_check_in", "recent_bathroom_rolls", "satisfaction_value",
	"overdrink_limit", "excess_drinks", "ideal_intoxication",
	"ideal_intoxication_level", "intoxication_level", "collapse_cause",
	"drug_countdown", "dosed_pending", "friendship", "reservation",
	"escape_remaining", "missing_seconds", "intercept_attempted", "night_seed",
	"roll", "remaining", "elapsed_seconds", "recent_perceptions",
]


func _director():
	var director = load(EMOTE_DIRECTOR_PATH).new()
	director.reset()
	return director


func _row(
		actor_id: int,
		state: StringName,
		public: Dictionary = {},
		changes: Array = []
) -> Dictionary:
	return {
		"id": actor_id,
		"kind": &"patron",
		"present": true,
		"state": state,
		"changes": changes,
		"public": public,
	}


func _view(rows: Array[Dictionary]) -> Dictionary:
	var view: Dictionary = {}
	for row: Dictionary in rows:
		view[row["id"]] = row
	return view


func _shown(director) -> Dictionary:
	var shown: Dictionary = {}
	for bubble: Dictionary in director.bubbles():
		shown[bubble["actor_id"]] = bubble["emote"]
	return shown


# --- Catalog and state -------------------------------------------------------

func test_every_persistent_state_appears_from_its_source_and_ends_with_it() -> void:
	var director = _director()
	var states: Array[StringName] = [
		&"escaping", &"investigating", &"unconscious", &"cultist_incapacitated", &"bathroom",
		&"ordering", &"conversation",
	]
	for state: StringName in states:
		director.reset()
		director.update(_view([_row(SUBJECT_ACTOR_ID, state)]), 0.1, false)
		assert_eq(_shown(director).get(SUBJECT_ACTOR_ID, &""), state,
			"%s must show its own bubble." % state)
		director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
		assert_false(_shown(director).has(SUBJECT_ACTOR_ID),
			"%s must disappear when its source state ends." % state)


func test_an_absent_actor_shows_nothing() -> void:
	var director = _director()
	var row := _row(SUBJECT_ACTOR_ID, &"ordering")
	director.update(_view([row]), 0.1, false)
	row["present"] = false
	director.update(_view([row]), 0.1, false)
	assert_true(director.bubbles().is_empty(), "A captured or exited actor shows no bubble.")


func test_escape_preempts_everything_and_investigation_preempts_ordinary_states() -> void:
	var director = _director()
	var calm := {"satisfaction": "Content", "danger": "Calm", "rapport": "Stranger"}
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"ordering", calm)]), 0.1, false)
	# A Mood drop queues a transient over the ordinary Ordering state.
	director.update(_view([
		_row(SUBJECT_ACTOR_ID, &"ordering", {"satisfaction": "Unhappy", "danger": "Calm", "rapport": "Stranger"})
	]), 0.1, false)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"mood_down",
		"A transient reads over an ordinary persistent state.")

	director.update(_view([_row(SUBJECT_ACTOR_ID, &"escaping")]), 0.1, false)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"escaping", "Escape preempts every other bubble.")

	var second = _director()
	second.update(_view([_row(OTHER_ACTOR_ID, &"bathroom")]), 0.1, false)
	second.update(_view([_row(OTHER_ACTOR_ID, &"investigating")]), 0.1, false)
	assert_eq(_shown(second)[OTHER_ACTOR_ID], &"investigating",
		"Investigation preempts bathroom, order, and conversation.")


func test_a_critical_state_suppresses_transients_and_none_resume_afterwards() -> void:
	var director = _director()
	var calm := {"satisfaction": "Content", "danger": "Calm", "rapport": "Stranger"}
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", calm)]), 0.1, false)
	# The Mood drop arrives in the same update that turns the Patron unconscious.
	director.update(_view([
		_row(SUBJECT_ACTOR_ID, &"unconscious", {"satisfaction": "Miserable", "danger": "Calm", "rapport": "Stranger"})
	]), 0.1, false)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"unconscious")

	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", {"satisfaction": "Miserable", "danger": "Calm", "rapport": "Stranger"})]), 0.1, false)
	assert_false(_shown(director).has(SUBJECT_ACTOR_ID),
		"When the critical state ends the director recomputes; no stale transient resumes.")


func test_one_actor_never_shows_two_bubbles_or_holds_more_than_two_transients() -> void:
	var director = _director()
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
	director.update(_view([_row(
		SUBJECT_ACTOR_ID, &"none", {},
		[&"service_smile", &"service_frown", &"mood_up", &"relationship_gain"]
	)]), 0.0, false)

	assert_eq(director.bubbles().size(), 1, "One actor shows one bubble.")
	var pending: Array = director.snapshot()["pending"][SUBJECT_ACTOR_ID]
	assert_lte(pending.size(), 2, "At most two transients wait behind the active one.")


func test_repeated_events_of_one_kind_are_deduplicated() -> void:
	var director = _director()
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", {}, [&"service_smile", &"service_smile"])]), 0.0, false)
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", {}, [&"service_smile"])]), 0.0, false)

	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"service_smile")
	assert_true(director.snapshot()["pending"][SUBJECT_ACTOR_ID].is_empty(),
		"A repeated event refreshes the active transient instead of stacking.")


# --- Timing ------------------------------------------------------------------

func test_transients_use_real_time_so_four_times_play_does_not_shorten_them() -> void:
	var director = _director()
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", {}, [&"service_frown"])]), 0.0, false)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"service_frown")

	# Two real seconds, delivered as frames at any simulation speed.
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 1.7, false)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"service_frown", "The transient still has time left.")
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.4, false)
	assert_false(_shown(director).has(SUBJECT_ACTOR_ID), "The transient ends on its real duration.")


func test_repeated_snapshots_do_not_restart_one_public_emotional_event() -> void:
	var director = _director()
	var row := _row(ActorIds.CULTIST_IDS[0], &"none")
	row["events"] = [{"id": 7, "kind": &"service_smile"}]
	director.update(_view([row]), 0.0, false)
	assert_eq(_shown(director)[ActorIds.CULTIST_IDS[0]], &"service_smile")

	director.update(_view([row]), 1.7, false)
	director.update(_view([row]), 0.4, false)
	assert_false(
		_shown(director).has(ActorIds.CULTIST_IDS[0]),
		"Repeated snapshots of one event cannot restart its transient."
	)

	row["events"] = [{"id": 8, "kind": &"service_smile"}]
	director.update(_view([row]), 0.0, false)
	assert_eq(
		_shown(director)[ActorIds.CULTIST_IDS[0]],
		&"service_smile",
		"A later emotional event starts a new transient."
	)


func test_pause_freezes_transient_timers() -> void:
	var director = _director()
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"none", {}, [&"service_frown"])]), 0.0, false)
	for _frame in range(20):
		director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 1.0, true)
	assert_eq(_shown(director)[SUBJECT_ACTOR_ID], &"service_frown",
		"Pause freezes the timer so the player can inspect the scene.")


func test_reset_clears_every_bubble_for_a_new_night() -> void:
	var director = _director()
	director.update(_view([_row(SUBJECT_ACTOR_ID, &"escaping"), _row(OTHER_ACTOR_ID, &"ordering")]), 0.1, false)
	assert_eq(director.bubbles().size(), 2)
	director.reset()
	assert_true(director.bubbles().is_empty(), "A restart leaves no bubble behind.")


func test_bubble_order_is_deterministic_by_priority_then_actor_id() -> void:
	var director = _director()
	director.update(_view([
		_row(THIRD_ACTOR_ID, &"ordering"),
		_row(SUBJECT_ACTOR_ID, &"ordering"),
		_row(OTHER_ACTOR_ID, &"escaping"),
	]), 0.1, false)
	var order: Array = director.bubbles().map(
		func(bubble: Dictionary) -> int: return bubble["actor_id"]
	)
	assert_eq(order, [OTHER_ACTOR_ID, SUBJECT_ACTOR_ID, THIRD_ACTOR_ID])


func test_every_bubble_carries_an_icon_a_silhouette_and_a_label() -> void:
	var director = _director()
	for emote: StringName in load(EMOTE_DIRECTOR_PATH).CATALOG:
		director.reset()
		director.update(_view([_row(SUBJECT_ACTOR_ID, &"none")]), 0.1, false)
		director.update(_view([_row(SUBJECT_ACTOR_ID, emote, {}, [emote])]), 0.0, false)
		var bubbles: Array = director.bubbles()
		assert_eq(bubbles.size(), 1, "%s produces one bubble." % emote)
		if bubbles.is_empty():
			continue
		assert_false(String(bubbles[0]["icon"]).is_empty(), "%s has an icon." % emote)
		assert_false(String(bubbles[0]["shape"]).is_empty(), "%s has a silhouette." % emote)
		assert_false(String(bubbles[0]["label"]).is_empty(), "%s has an accessible label." % emote)


# --- Information safety -------------------------------------------------------

func _assert_no_forbidden_keys(value: Variant, path: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var name := str(key)
			assert_false(name in FORBIDDEN_KEYS,
				"emote_view leaks %s at %s." % [name, path])
			_assert_no_forbidden_keys(value[key], "%s/%s" % [path, name])
	elif value is Array:
		for index in range(value.size()):
			_assert_no_forbidden_keys(value[index], "%s[%d]" % [path, index])


func test_the_emote_view_carries_no_hidden_simulation_value() -> void:
	var session = _session_with_first_group()
	session.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 3, 1, 0, 3)
	session.report_patron_stimulus(ScenarioActors.opening_companion(), &"drink_dosed_seen")
	session.advance(2.2)

	var view: Dictionary = session.snapshot()["emote_view"]
	assert_false(view.is_empty(), "The normal snapshot carries the emote_view.")
	_assert_no_forbidden_keys(view, "emote_view")


func test_unknown_patrons_show_bubbles_without_leaking_profile_fields() -> void:
	var session = _session_with_first_group()
	var row: Dictionary = session.snapshot()["emote_view"][ScenarioActors.opening_patron()]

	assert_eq(row["state"], &"ordering", "An Unidentified Patron still shows their intention.")
	assert_false(row.has("name"), "The emote_view carries no Patron name.")
	assert_eq(String(row["public"]["rapport"]), "???",
		"An Unidentified Patron's Friendship stays unknown.")

	var director = _director()
	director.update(session.snapshot()["emote_view"], 0.1, false)
	assert_eq(_shown(director)[ScenarioActors.opening_patron()], &"ordering")


func test_both_collapse_causes_show_the_same_public_unconscious_bubble() -> void:
	var overdrink = _session_with_first_group()
	overdrink.debug_set_patron_drink_state(ScenarioActors.opening_patron(), 3, 1, 0, 3)
	overdrink.debug_force_finish_drink(ScenarioActors.opening_patron())
	overdrink.advance(0.2)

	var drugged = _session_with_first_group()
	drugged.prepare_drugged_drink(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0])
	drugged.advance(8.1)
	drugged.serve_patron_order(ScenarioActors.opening_patron(), ActorIds.CULTIST_IDS[0])
	drugged.advance(21.0)

	var overdrink_row: Dictionary = overdrink.snapshot()["emote_view"][ScenarioActors.opening_patron()]
	var drugged_row: Dictionary = drugged.snapshot()["emote_view"][ScenarioActors.opening_patron()]
	assert_eq(overdrink_row["state"], &"unconscious")
	assert_eq(drugged_row["state"], overdrink_row["state"],
		"An Overdrink Collapse and a Drugged Drink collapse read the same in public.")


func test_ordinary_move_needs_no_cultist_bubble() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)

	var moving := {ActorIds.CULTIST_IDS[0]: {
		"active": {"command": &"move", "label": "Move"},
		"pending": [],
		"action_count": 1,
		"markers": [],
		"feedback": {"message": "", "reason": &"", "outcome": &"accepted"},
	}}
	assert_eq(session.emote_view(moving)[ActorIds.CULTIST_IDS[0]]["state"], &"none",
		"The destination marker already communicates an ordinary Move.")

	var working := {ActorIds.CULTIST_IDS[0]: {
		"active": {"command": &"knock_out", "label": "Knock Out"},
		"pending": [],
		"action_count": 1,
		"markers": [],
		"feedback": {"message": "", "reason": &"", "outcome": &"accepted"},
	}}
	assert_eq(session.emote_view(working)[ActorIds.CULTIST_IDS[0]]["state"], &"none",
		"A contextual Cultist Action also needs no mechanics bubble.")


func test_a_finished_command_produces_no_emote_event() -> void:
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	var finished := {ActorIds.CULTIST_IDS[1]: {
		"active": {},
		"pending": [],
		"action_count": 0,
		"markers": [],
		"feedback": {
			"message": "Talk done.", "reason": &"", "outcome": &"completed", "event_id": 42,
		},
	}}
	var row: Dictionary = session.emote_view(finished)[ActorIds.CULTIST_IDS[1]]
	assert_true(row["events"].is_empty(), "Mechanical completion stays in command feedback.")

	var director = _director()
	director.update(session.emote_view(), 0.1, false)
	director.update(session.emote_view(finished), 0.0, false)
	assert_false(_shown(director).has(ActorIds.CULTIST_IDS[1]))


func _session_with_first_group():
	var session = load(GAME_SESSION_PATH).new()
	session.start_night(707)
	session.advance(3.1)
	assert_true(session.begin_admit_group(ActorIds.CULTIST_IDS[0]))
	session.advance(15.0)
	return session
