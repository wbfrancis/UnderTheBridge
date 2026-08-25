class_name EmoteDirector
extends RefCounted

## Decides which single Emote Bubble each actor shows.
##
## Emote Bubbles are purely presentational: nothing here acknowledges, blocks,
## completes, or cancels gameplay. The module owns state diffing, transient
## creation, priority, preemption, deduplication, queue limits, duration, and
## deterministic ordering. It reads only the sanitized `emote_view`.

const MAX_PENDING_TRANSIENTS := 2

## One centralized table. Nothing else picks an icon, a duration, or a priority.
## Colour only reinforces the icon and silhouette; it is never the only cue.
const CATALOG := {
	# Critical persistent states. These suppress every transient.
	&"escaping": {
		"category": &"persistent", "critical": true, "priority": 100,
		"icon": "!", "shape": &"burst", "color": "e65c70", "label": "Running",
	},
	&"investigating": {
		"category": &"persistent", "critical": true, "priority": 90,
		"icon": "?", "shape": &"diamond", "color": "df9d65", "label": "Searching",
	},
	&"unconscious": {
		"category": &"persistent", "critical": true, "priority": 80,
		"icon": "Z", "shape": &"circle", "color": "9aa7b4", "label": "Out cold",
	},
	# Transients sit above the ordinary states so a change stays readable.
	&"danger_reaction": {
		"category": &"transient", "critical": false, "priority": 75, "duration": 2.5,
		"icon": "!", "shape": &"diamond", "color": "df745f", "label": "Alarmed",
	},
	&"relationship_gain": {
		"category": &"transient", "critical": false, "priority": 72, "duration": 2.0,
		"icon": "+", "shape": &"circle", "color": "8fc4af", "label": "Warmer",
	},
	&"mood_up": {
		"category": &"transient", "critical": false, "priority": 70, "duration": 2.0,
		"icon": "^", "shape": &"circle", "color": "8fbf9f", "label": "Pleased",
	},
	&"mood_down": {
		"category": &"transient", "critical": false, "priority": 70, "duration": 2.0,
		"icon": "v", "shape": &"square", "color": "d3be76", "label": "Unhappy",
	},
	&"drink_result": {
		"category": &"transient", "critical": false, "priority": 68, "duration": 1.75,
		"icon": "U", "shape": &"circle", "color": "e2a56e", "label": "Drink",
	},
	&"command_result": {
		"category": &"transient", "critical": false, "priority": 66, "duration": 1.25,
		"icon": "*", "shape": &"square", "color": "b9a0db", "label": "Order done",
	},
	# Ordinary persistent states.
	&"bathroom": {
		"category": &"persistent", "critical": false, "priority": 60,
		"icon": "W", "shape": &"square", "color": "7fc7c4", "label": "Bathroom",
	},
	&"ordering": {
		"category": &"persistent", "critical": false, "priority": 50,
		"icon": "U", "shape": &"circle", "color": "d9c56f", "label": "Wants a drink",
	},
	&"conversation": {
		"category": &"persistent", "critical": false, "priority": 40,
		"icon": "~", "shape": &"circle", "color": "e6edf3", "label": "Talking",
	},
	&"cultist_action": {
		"category": &"persistent", "critical": false, "priority": 30,
		"icon": "+", "shape": &"square", "color": "8fc4af", "label": "Working",
	},
}

## Band ladders. A move up or down the ladder is public; the value behind it is not.
const MOOD_BANDS: Array[String] = ["Miserable", "Unhappy", "Content", "Happy"]
const DANGER_BANDS: Array[String] = ["Calm", "Uneasy", "Suspicious", "Alarmed", "Maximum"]
const RAPPORT_BANDS: Array[String] = ["Stranger", "Acquainted", "Friendly", "Trusted"]

var _previous: Dictionary = {}
var _actors: Dictionary = {}


## Starts a new Night. Every bubble, transient, and remembered band is dropped.
func reset() -> void:
	_previous.clear()
	_actors.clear()


## Advances the director by one frame of real time.
##
## `real_delta` is real seconds, so 4x play never shortens a transient. While
## `paused` is true the transient timers freeze and the scene stays inspectable.
func update(emote_view: Dictionary, real_delta: float, paused: bool) -> void:
	for actor_id: StringName in emote_view:
		_update_actor(actor_id, emote_view[actor_id])
	for actor_id: StringName in _actors.keys():
		if not emote_view.has(actor_id):
			_actors.erase(actor_id)
			_previous.erase(actor_id)
	if not paused and real_delta > 0.0:
		_advance_transients(real_delta)


## The bubble each visible actor shows, ordered by priority then actor id.
func bubbles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor_id: StringName in _actors:
		var description := _bubble_for(actor_id)
		if not description.is_empty():
			result.append(description)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["priority"]) == int(right["priority"]):
			return String(left["actor_id"]) < String(right["actor_id"])
		return int(left["priority"]) > int(right["priority"])
	)
	return result


func snapshot() -> Dictionary:
	var pending: Dictionary = {}
	for actor_id: StringName in _actors:
		pending[actor_id] = _actors[actor_id]["pending"].map(
			func(entry: Dictionary) -> StringName: return entry["kind"]
		)
	return {"bubbles": bubbles(), "pending": pending}


# --- Diffing -----------------------------------------------------------------

func _update_actor(actor_id: StringName, row: Dictionary) -> void:
	var present := bool(row["present"])
	if not _actors.has(actor_id):
		_actors[actor_id] = {"state": &"none", "present": present, "pending": [], "active": {}}
	var actor: Dictionary = _actors[actor_id]
	actor["present"] = present
	actor["state"] = StringName(row["state"]) if present else &"none"
	if not present:
		actor["pending"].clear()
		actor["active"] = {}
		_previous.erase(actor_id)
		return

	var changes: Array[StringName] = []
	changes.assign(row.get("changes", []))
	changes.append_array(_band_changes(actor_id, row.get("public", {})))
	# A critical state owns the actor: it suppresses transients while it lasts,
	# so nothing stale can resume when the state ends.
	if _is_critical(actor["state"]):
		actor["pending"].clear()
		actor["active"] = {}
		return
	for kind: StringName in changes:
		_queue_transient(actor, kind)


## Turns public band movement into public transients. The band label is what the
## player already reads in the Hover Summary; the number behind it stays hidden.
func _band_changes(actor_id: StringName, public: Dictionary) -> Array[StringName]:
	var changes: Array[StringName] = []
	var before: Dictionary = _previous.get(actor_id, {})
	_previous[actor_id] = public.duplicate(true)
	if before.is_empty():
		return changes
	var mood := _band_step(MOOD_BANDS, before.get("mood", ""), public.get("mood", ""))
	if mood > 0:
		changes.append(&"mood_up")
	elif mood < 0:
		changes.append(&"mood_down")
	if _band_step(DANGER_BANDS, before.get("danger", ""), public.get("danger", "")) > 0:
		changes.append(&"danger_reaction")
	if _band_step(RAPPORT_BANDS, before.get("rapport", ""), public.get("rapport", "")) > 0:
		changes.append(&"relationship_gain")
	if before.get("order", "") != public.get("order", "") and public.get("order", "") == "served":
		changes.append(&"drink_result")
	elif before.get("activity", "") != "Drinking" and public.get("activity", "") == "Drinking":
		changes.append(&"drink_result")
	return changes


## Returns +1, -1, or 0. An unknown label, such as "???" for an Unidentified
## Patron, never produces a change.
func _band_step(ladder: Array[String], before: Variant, after: Variant) -> int:
	var from := ladder.find(String(before))
	var to := ladder.find(String(after))
	if from < 0 or to < 0 or from == to:
		return 0
	return 1 if to > from else -1


# --- Transients ---------------------------------------------------------------

func _queue_transient(actor: Dictionary, kind: StringName) -> void:
	if not CATALOG.has(kind) or CATALOG[kind]["category"] != &"transient":
		return
	var pending: Array = actor["pending"]
	# Deduplicate: a repeated event of the same kind refreshes, it does not stack.
	if not actor["active"].is_empty() and actor["active"]["kind"] == kind:
		actor["active"]["remaining"] = float(CATALOG[kind]["duration"])
		return
	for entry: Dictionary in pending:
		if entry["kind"] == kind:
			return
	if pending.size() >= MAX_PENDING_TRANSIENTS:
		# Drop the oldest lowest-priority pending transient to make room.
		var victim := 0
		for index in range(pending.size()):
			if int(CATALOG[pending[index]["kind"]]["priority"]) < int(
				CATALOG[pending[victim]["kind"]]["priority"]
			):
				victim = index
		if int(CATALOG[kind]["priority"]) <= int(CATALOG[pending[victim]["kind"]]["priority"]):
			return
		pending.remove_at(victim)
	pending.append({"kind": kind})
	_promote(actor)


func _advance_transients(real_delta: float) -> void:
	for actor_id: StringName in _actors:
		var actor: Dictionary = _actors[actor_id]
		if actor["active"].is_empty():
			_promote(actor)
			continue
		actor["active"]["remaining"] = float(actor["active"]["remaining"]) - real_delta
		if float(actor["active"]["remaining"]) <= 0.0:
			actor["active"] = {}
			_promote(actor)


func _promote(actor: Dictionary) -> void:
	if not actor["active"].is_empty() or actor["pending"].is_empty():
		return
	var best := 0
	for index in range(actor["pending"].size()):
		if int(CATALOG[actor["pending"][index]["kind"]]["priority"]) > int(
			CATALOG[actor["pending"][best]["kind"]]["priority"]
		):
			best = index
	var chosen: Dictionary = actor["pending"][best]
	actor["pending"].remove_at(best)
	actor["active"] = {
		"kind": chosen["kind"],
		"remaining": float(CATALOG[chosen["kind"]]["duration"]),
	}


# --- Selection ----------------------------------------------------------------

func _bubble_for(actor_id: StringName) -> Dictionary:
	var actor: Dictionary = _actors[actor_id]
	if not bool(actor["present"]):
		return {}
	var chosen: StringName = &""
	var state: StringName = actor["state"]
	if CATALOG.has(state):
		chosen = state
	if not actor["active"].is_empty():
		var transient: StringName = actor["active"]["kind"]
		if chosen.is_empty() or int(CATALOG[transient]["priority"]) > int(
			CATALOG[chosen]["priority"]
		):
			chosen = transient
	if chosen.is_empty():
		return {}
	var entry: Dictionary = CATALOG[chosen]
	return {
		"actor_id": actor_id,
		"emote": chosen,
		"category": entry["category"],
		"priority": int(entry["priority"]),
		"icon": entry["icon"],
		"shape": entry["shape"],
		"color": entry["color"],
		"label": entry["label"],
	}


func _is_critical(state: StringName) -> bool:
	return CATALOG.has(state) and bool(CATALOG[state]["critical"])
