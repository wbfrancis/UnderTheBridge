class_name CultistCommandSystem
extends RefCounted

## The single seam between player input and Cultist gameplay operations.
##
## The module owns the command catalog, the Action Queue lifecycle, target
## revalidation, the approach stage, the Commitment Point, execution dispatch,
## and reservation cleanup. GameSession stays the gameplay authority: this
## module never copies an eligibility rule, it asks the session for one.
##
## The live scene is a thin adapter. It picks targets, renders the menu and the
## markers, moves NavigableActor3D, and forwards navigation callbacks.

const ACTION_QUEUE_SCRIPT := preload("res://scripts/actions/cultist_action_queue.gd")
const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")

const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]

const TARGET_FLOOR := &"floor"
const TARGET_PATRON := &"patron"
const TARGET_OBJECT := &"smart_object"

## One centralized catalog. Menu order follows the per-kind command lists below,
## so the same target always produces the same option order.
const CATALOG := {
	&"move": {"label": "Move", "kinds": [TARGET_FLOOR, TARGET_OBJECT], "reserves": false},
	&"drop_body": {"label": "Drop Body Here", "kinds": [TARGET_FLOOR, TARGET_OBJECT], "reserves": false},
	&"talk": {"label": "Talk", "kinds": [TARGET_PATRON], "reserves": true},
	&"serve_order": {"label": "Serve Order", "kinds": [TARGET_PATRON], "reserves": true},
	&"offer_drink": {"label": "Offer Drink", "kinds": [TARGET_PATRON], "reserves": true},
	&"offer_cigarette": {"label": "Offer Cigarette", "kinds": [TARGET_PATRON], "reserves": true},
	&"knock_out": {"label": "Knock Out", "kinds": [TARGET_PATRON], "reserves": true},
	&"pick_up_body": {"label": "Pick Up Body", "kinds": [TARGET_PATRON], "reserves": true},
	&"intercept": {"label": "Intercept", "kinds": [TARGET_PATRON], "reserves": true},
	&"lead_to_tunnel": {"label": "Lead to Tunnel", "kinds": [TARGET_PATRON], "reserves": true},
	&"rescue_persuasion": {"label": "Rescue Persuasion", "kinds": [TARGET_PATRON], "reserves": true},
	&"prepare_drink": {"label": "Prepare Drink", "kinds": [TARGET_OBJECT], "reserves": true},
	&"prepare_drugged_drink": {"label": "Prepare Drugged Drink", "kinds": [TARGET_OBJECT], "reserves": true},
	&"activate_trapdoor": {"label": "Activate Trapdoor", "kinds": [TARGET_OBJECT], "reserves": true},
}

const PATRON_COMMANDS: Array[StringName] = [
	&"talk",
	&"serve_order",
	&"offer_drink",
	&"offer_cigarette",
	&"knock_out",
	&"pick_up_body",
	&"intercept",
	&"lead_to_tunnel",
	&"rescue_persuasion",
]
const FLOOR_COMMANDS: Array[StringName] = [&"move", &"drop_body"]
## Authored smart objects and the commands each one offers, in menu order.
const OBJECT_COMMANDS := {
	&"bar_work_position": [&"prepare_drink", &"prepare_drugged_drink", &"move"],
	&"trapdoor_control": [&"activate_trapdoor", &"move"],
	&"tunnel_intake": [&"move", &"drop_body"],
}

const REASON_LABELS := {
	&"": "",
	&"already_attempted": "Already attempted",
	&"already_committed": "That Action is already under way",
	&"already_carrying": "Already carrying a drink",
	&"approach_reserved": "Another Cultist holds that position",
	&"cultist_busy": "Cultist is occupied",
	&"drug_prep_running": "A dose is already being prepared",
	&"invalid_target": "That target is gone",
	&"no_active_action": "No Action is running",
	&"no_doses": "No dose remains",
	&"no_open_order": "No open Order",
	&"no_prepared_drink": "No Prepared Drink carried",
	&"night_over": "The Night is over",
	&"not_carrying_body": "Not carrying a body",
	&"not_receptive": "Not receptive right now",
	&"patron_unavailable": "Patron is unavailable",
	&"path_stuck": "Could not reach the target",
	&"queue_full": "The Action Queue is full",
	&"rejected": "The command was rejected",
	&"trapdoor_busy": "The Trapdoor is not ready",
	&"unknown_command": "Unknown command",
}

var _session = null
var _queues: Dictionary = {}
var _registry = INTERACTION_REGISTRY_SCRIPT.new()
var _objects: Dictionary = {}
var _feedback: Dictionary = {}
var _events: Array[Dictionary] = []


## Starts a new Night. Every queue, reservation, and outcome message is dropped.
func reset(session) -> void:
	_session = session
	_queues.clear()
	_registry = INTERACTION_REGISTRY_SCRIPT.new()
	_feedback.clear()
	_events.clear()
	for cultist_id in CULTIST_IDS:
		_queues[cultist_id] = ACTION_QUEUE_SCRIPT.new()
		_feedback[cultist_id] = {"message": "", "reason": &"", "outcome": &"idle"}
	for object_id: StringName in OBJECT_COMMANDS:
		if _objects.has(object_id):
			_registry.register_slot(object_id, TARGET_OBJECT)


## Records an authored smart object and its approach slot. The position is the
## authored approach point the Cultist walks to, never a scene node.
func register_smart_object(object_id: StringName, label: String, approach_position: Vector3) -> bool:
	if not OBJECT_COMMANDS.has(object_id):
		return false
	_objects[object_id] = {"label": label, "approach_position": approach_position}
	_registry.register_slot(object_id, TARGET_OBJECT)
	return true


## The command descriptions for one Selected Cultist and one target. The menu
## renders these verbatim; it owns no eligibility branch of its own.
func resolve_options(cultist_id: StringName, target: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _session == null or not _queues.has(cultist_id) or target.is_empty():
		return options
	for command: StringName in _commands_for_target(target):
		var state := _availability(command, cultist_id, target)
		if not bool(state["visible"]):
			continue
		options.append({
			"command": command,
			"label": _option_label(command, state),
			"available": bool(state["available"]),
			"reason": state["reason"],
			"reason_label": _reason_label(state["reason"]),
			"target_kind": target["kind"],
			"target_id": target["id"],
			"target_label": _target_label(cultist_id, target),
		})
	return options


## Issues Move or a chosen context command. A normal issue replaces the queue,
## Shift appends it. The returned dictionary is the visible outcome.
func issue(
		cultist_id: StringName,
		command: StringName,
		target: Dictionary,
		append: bool
) -> Dictionary:
	if _session == null or not _queues.has(cultist_id):
		return _reject(cultist_id, command, &"invalid_target")
	if not CATALOG.has(command) or target.is_empty():
		return _reject(cultist_id, command, &"unknown_command")
	if command not in _commands_for_target(target):
		return _reject(cultist_id, command, &"unknown_command")
	# Revalidation point 2: the command was chosen, so check the target again.
	var state := _availability(command, cultist_id, target)
	if not bool(state["available"]):
		return _reject(cultist_id, command, state["reason"])

	var payload := {
		"command": command,
		"target": _normalized_target(target),
		"committed": false,
		"reserved": false,
		"engagement_cleared": false,
	}
	var queue = _queues[cultist_id]
	var action_id: int = (
		queue.append(command, StringName(target["id"]), INF, INF, true, payload)
		if append
		else queue.replace(command, StringName(target["id"]), INF, INF, true, payload)
	)
	if action_id < 0:
		return _reject(cultist_id, command, &"queue_full")
	if not append:
		_release(cultist_id)
	_sync_active(cultist_id)

	var still_queued := _find_action(cultist_id, action_id)
	if still_queued.is_empty():
		var failure: Dictionary = _feedback[cultist_id]
		return {
			"accepted": false,
			"action_id": action_id,
			"command": command,
			"reason": failure["reason"],
			"message": failure["message"],
		}
	var verb := "queued" if append else "started"
	var message := "%s %s for %s." % [
		CATALOG[command]["label"], verb, _display_name(cultist_id),
	]
	_note(cultist_id, &"accepted", message, &"")
	return {
		"accepted": true,
		"action_id": action_id,
		"command": command,
		"reason": &"",
		"message": message,
	}


## Removes one pending Action. The active Action is never removed this way.
func remove_pending(cultist_id: StringName, action_id: int) -> bool:
	if not _queues.has(cultist_id):
		return false
	if not _queues[cultist_id].remove_pending(action_id):
		return false
	_note(cultist_id, &"cancelled", "Pending Action removed.", &"")
	return true


## Cancels the running Action for one Cultist. Cancellation is only allowed
## before the Commitment Point, because after it the gameplay effect has fired
## and no undo exists. A refusal carries a visible reason, never a silent no-op.
func request_cancel_active(cultist_id: StringName) -> Dictionary:
	if _session == null or not _queues.has(cultist_id):
		return _cancel_refusal(cultist_id, -1, &"", &"invalid_target")
	var action := _active_action(cultist_id)
	if action.is_empty():
		return _cancel_refusal(cultist_id, -1, &"", &"no_active_action")
	var action_id := int(action["id"])
	var command: StringName = action["payload"]["command"]
	if bool(action["payload"]["committed"]):
		return _cancel_refusal(cultist_id, action_id, command, &"already_committed")
	# The reservation goes back before the queue moves on, so the next Action can
	# take the slot it needs in the same step.
	_release(cultist_id)
	if not _queues[cultist_id].cancel_active():
		return _cancel_refusal(cultist_id, action_id, command, &"already_committed")
	_record(cultist_id, action_id, command, &"cancelled", &"player_request")
	var message := "%s cancelled." % CATALOG[command]["label"]
	_note(cultist_id, &"cancelled", message, &"")
	_sync_active(cultist_id)
	return {
		"cancelled": true,
		"action_id": action_id,
		"command": command,
		"reason": &"",
		"message": message,
	}


func _cancel_refusal(
		cultist_id: StringName,
		action_id: int,
		command: StringName,
		reason: StringName
) -> Dictionary:
	var label: String = CATALOG[command]["label"] if CATALOG.has(command) else "Action"
	var message := "%s cannot be cancelled: %s." % [label, _reason_label(reason)]
	if _feedback.has(cultist_id):
		_note(cultist_id, &"rejected", message, reason)
	return {
		"cancelled": false,
		"action_id": action_id,
		"command": command,
		"reason": reason,
		"message": message,
	}


## Navigation reported arrival at the approach point. This is the Commitment
## Point: the gameplay effect fires exactly once, then the Action completes.
func notify_reached(cultist_id: StringName, action_id: int) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty() or int(action["id"]) != action_id:
		return {"committed": false, "reason": &"invalid_target"}
	var payload: Dictionary = action["payload"]
	var command: StringName = payload["command"]
	var target: Dictionary = payload["target"]

	# Revalidation point 4: the approach is over, so check the target one last time.
	var state := _availability(command, cultist_id, target)
	if not bool(state["available"]):
		_fail_active(cultist_id, state["reason"])
		return {"committed": false, "reason": state["reason"]}

	var outcome := _execute(command, cultist_id, target)
	_queues[cultist_id].set_payload_value(action_id, "committed", true)
	_record(cultist_id, action_id, command, &"committed", outcome["reason"])
	if not bool(outcome["ok"]):
		_fail_active(cultist_id, outcome["reason"])
		return {"committed": true, "reason": outcome["reason"]}
	_note(
		cultist_id,
		&"completed",
		"%s done." % CATALOG[command]["label"],
		outcome["reason"]
	)
	_release(cultist_id)
	_queues[cultist_id].complete_active()
	_sync_active(cultist_id)
	return {"committed": true, "reason": outcome["reason"]}


## Navigation could not reach the approach point. Nothing was committed.
func notify_failed(cultist_id: StringName, action_id: int, reason: StringName) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty() or int(action["id"]) != action_id:
		return {"failed": false, "reason": &"invalid_target"}
	_fail_active(cultist_id, reason)
	return {"failed": true, "reason": reason}


## Re-checks every queued target and drops the ones that went stale. The adapter
## calls this whenever the session state changes.
func refresh(cultist_id: StringName = &"") -> void:
	var ids: Array = [cultist_id] if not cultist_id.is_empty() else _queues.keys()
	for id: StringName in ids:
		if _queues.has(id):
			_sync_active(id)


## What the adapter should navigate toward for this Cultist, or {} when idle.
func active_request(cultist_id: StringName) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty():
		return {}
	var payload: Dictionary = action["payload"]
	var target: Dictionary = payload["target"]
	return {
		"action_id": int(action["id"]),
		"command": payload["command"],
		"target_kind": target["kind"],
		"target_id": target["id"],
		"position": target["position"],
	}


## The normal snapshot. It carries no exact Suspicion, Mood, Bladder, Overdrink
## value, roll, or internal timer.
func snapshot() -> Dictionary:
	var cultists: Dictionary = {}
	var action_count := 0
	for cultist_id: StringName in _queues:
		var state: Dictionary = _queues[cultist_id].snapshot()
		var pending: Array[Dictionary] = []
		for entry: Dictionary in state["pending"]:
			pending.append(_action_view(cultist_id, entry))
		var active := _action_view(cultist_id, state["active"])
		action_count += (0 if active.is_empty() else 1) + pending.size()
		cultists[cultist_id] = {
			"active": active,
			"pending": pending,
			"action_count": (0 if active.is_empty() else 1) + pending.size(),
			"markers": _markers(cultist_id, state),
			"feedback": _feedback[cultist_id].duplicate(true),
		}
	return {
		"cultists": cultists,
		"action_count": action_count,
		"reserved_slots": _registry.snapshot()["actor_slots"].duplicate(true),
		"recent_events": _events.duplicate(true),
	}


## The debug snapshot adds reservation internals for the debug overlay only.
func debug_snapshot() -> Dictionary:
	var result := snapshot()
	result["registry"] = _registry.snapshot()
	var raw: Dictionary = {}
	for cultist_id: StringName in _queues:
		raw[cultist_id] = _queues[cultist_id].snapshot()
	result["raw_queues"] = raw
	return result


# --- Queue lifecycle ---------------------------------------------------------

## Brings the active Action into a runnable state: it clears a stale Action,
## takes the approach reservation, and stops when the queue is idle or the head
## Action is ready for the adapter to drive.
func _sync_active(cultist_id: StringName) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var action := _active_action(cultist_id)
		if action.is_empty():
			_release(cultist_id)
			return
		var payload: Dictionary = action["payload"]
		var command: StringName = payload["command"]
		var target: Dictionary = payload["target"]
		if bool(payload["committed"]):
			return
		# Revalidation point 3: movement has not started yet.
		var state := _availability(command, cultist_id, target)
		if not bool(state["available"]):
			_fail_active(cultist_id, state["reason"])
			continue
		if not bool(payload["reserved"]) and bool(CATALOG[command]["reserves"]):
			var slot := _slot_for(target)
			# A Patron's interaction slot exists as soon as a Cultist aims at them.
			_registry.register_slot(slot, StringName(target["kind"]))
			if not _registry.request_slot(cultist_id, slot):
				_fail_active(cultist_id, &"approach_reserved")
				continue
			_queues[cultist_id].set_payload_value(int(action["id"]), "reserved", true)
		# A new Action replaces any standing engagement, such as an active Talk.
		# Done once per Action so a session snapshot cannot loop back into here.
		if not bool(payload["engagement_cleared"]):
			_queues[cultist_id].set_payload_value(int(action["id"]), "engagement_cleared", true)
			if _session != null and _session.has_method("end_cultist_engagement"):
				_session.end_cultist_engagement(cultist_id)
		return


func _fail_active(cultist_id: StringName, reason: StringName) -> void:
	var action := _active_action(cultist_id)
	if action.is_empty():
		return
	var command: StringName = action["payload"]["command"]
	_release(cultist_id)
	_queues[cultist_id].fail_active(reason)
	_record(cultist_id, int(action["id"]), command, &"failed", reason)
	_note(
		cultist_id,
		&"failed",
		"%s failed: %s." % [CATALOG[command]["label"], _reason_label(reason)],
		reason
	)


func _release(cultist_id: StringName) -> void:
	_registry.release_actor(cultist_id)
	var action := _active_action(cultist_id)
	if not action.is_empty():
		_queues[cultist_id].set_payload_value(int(action["id"]), "reserved", false)


func _active_action(cultist_id: StringName) -> Dictionary:
	if not _queues.has(cultist_id):
		return {}
	return _queues[cultist_id].snapshot()["active"]


func _find_action(cultist_id: StringName, action_id: int) -> Dictionary:
	var state: Dictionary = _queues[cultist_id].snapshot()
	if not state["active"].is_empty() and int(state["active"]["id"]) == action_id:
		return state["active"]
	for entry: Dictionary in state["pending"]:
		if int(entry["id"]) == action_id:
			return entry
	return {}


# --- Eligibility and execution ----------------------------------------------

## Every rule comes from the gameplay authority. Move is the one command this
## module answers for, because it has no gameplay effect of its own.
func _availability(command: StringName, cultist_id: StringName, target: Dictionary) -> Dictionary:
	if command == &"move":
		var reachable: bool = (
			target["kind"] != TARGET_OBJECT or _objects.has(StringName(target["id"]))
		)
		return {
			"visible": true,
			"available": reachable,
			"reason": &"" if reachable else &"invalid_target",
			"detail": "",
		}
	if _session == null or not _session.has_method("command_availability"):
		return {"visible": false, "available": false, "reason": &"unknown_command", "detail": ""}
	var state: Dictionary = _session.command_availability(
		command, cultist_id, StringName(target["id"])
	)
	return {
		"visible": bool(state.get("visible", false)),
		"available": bool(state.get("available", false)),
		"reason": StringName(state.get("reason", &"")),
		"detail": String(state.get("detail", "")),
	}


## Fires the gameplay operation. Called once, at the Commitment Point.
func _execute(command: StringName, cultist_id: StringName, target: Dictionary) -> Dictionary:
	var target_id := StringName(target["id"])
	match command:
		&"move":
			return {"ok": true, "reason": &""}
		&"drop_body":
			return _outcome(_session.drop_body(cultist_id), &"not_carrying_body")
		&"talk":
			return _outcome(_session.begin_conversation(cultist_id, target_id), &"rejected")
		&"serve_order":
			return _outcome(_session.serve_patron_order(target_id, cultist_id), &"no_open_order")
		&"offer_drink":
			# The offer itself is the effect. A refusal is a visible result, not a failure.
			var offer: Dictionary = _session.offer_drink(target_id, cultist_id)
			return {"ok": true, "reason": StringName(offer["reason"])}
		&"offer_cigarette":
			return _outcome(_session.offer_cigarette(cultist_id, target_id), &"rejected")
		&"knock_out":
			return _outcome(_session.begin_knockout(cultist_id, target_id), &"cultist_busy")
		&"pick_up_body":
			return _outcome(_session.pick_up_body(cultist_id, target_id), &"cultist_busy")
		&"intercept":
			return _outcome(_session.begin_intercept(target_id, cultist_id), &"rejected")
		&"lead_to_tunnel":
			return _outcome(
				_session.begin_friendship_capture(cultist_id, target_id), &"not_receptive"
			)
		&"rescue_persuasion":
			return _outcome(_session.attempt_rescue_persuasion(cultist_id), &"already_attempted")
		&"prepare_drink":
			return _outcome(_session.prepare_drink(cultist_id), &"already_carrying")
		&"prepare_drugged_drink":
			return _outcome(
				_session.prepare_drugged_drink_for_next_order(cultist_id), &"no_open_order"
			)
		&"activate_trapdoor":
			return _outcome(_session.activate_trapdoor(), &"trapdoor_busy")
	return {"ok": false, "reason": &"unknown_command"}


func _outcome(succeeded: bool, failure_reason: StringName) -> Dictionary:
	return {"ok": succeeded, "reason": &"" if succeeded else failure_reason}


# --- Targets and presentation ------------------------------------------------

func _commands_for_target(target: Dictionary) -> Array:
	match StringName(target.get("kind", &"")):
		TARGET_PATRON:
			return PATRON_COMMANDS
		TARGET_FLOOR:
			return FLOOR_COMMANDS
		TARGET_OBJECT:
			return OBJECT_COMMANDS.get(StringName(target["id"]), [])
	return []


## A serializable target reference: kind, id, live position, and the authored
## approach slot. Scene nodes never enter this state.
func _normalized_target(target: Dictionary) -> Dictionary:
	var kind := StringName(target.get("kind", TARGET_FLOOR))
	var id := StringName(target.get("id", &"floor"))
	var position: Vector3 = target.get("position", Vector3.ZERO)
	if kind == TARGET_OBJECT and _objects.has(id):
		position = _objects[id]["approach_position"]
	return {
		"kind": kind,
		"id": id,
		"position": position,
		"approach_slot": _slot_for({"kind": kind, "id": id}),
	}


func _slot_for(target: Dictionary) -> StringName:
	match StringName(target["kind"]):
		TARGET_PATRON:
			return StringName("approach_%s" % target["id"])
		TARGET_OBJECT:
			return StringName(target["id"])
	return &""


func _target_label(cultist_id: StringName, target: Dictionary) -> String:
	match StringName(target["kind"]):
		TARGET_PATRON:
			return _patron_name(cultist_id, StringName(target["id"]))
		TARGET_OBJECT:
			var id := StringName(target["id"])
			return _objects[id]["label"] if _objects.has(id) else _humanize(id)
	return "Floor"


func _option_label(command: StringName, state: Dictionary) -> String:
	var label: String = CATALOG[command]["label"]
	var detail: String = state["detail"]
	return label if detail.is_empty() else "%s — %s" % [label, detail]


## The Patron's player-readable name. An Unidentified Patron stays "???".
func _patron_name(cultist_id: StringName, patron_id: StringName) -> String:
	if _session == null or not _session.has_method("patron_view"):
		return _humanize(patron_id)
	var view: Dictionary = _session.patron_view(patron_id, cultist_id)
	return String(view["name"]) if not view.is_empty() else _humanize(patron_id)


func _action_view(cultist_id: StringName, action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var payload: Dictionary = action["payload"]
	var command: StringName = payload["command"]
	var target: Dictionary = payload["target"]
	return {
		"id": int(action["id"]),
		"command": command,
		"label": CATALOG[command]["label"],
		"target_kind": target["kind"],
		"target_id": target["id"],
		"target_label": _target_label(cultist_id, target),
		"stage": &"committed" if bool(payload["committed"]) else &"approaching",
		"cancellable": not bool(payload["committed"]),
	}


func _markers(cultist_id: StringName, state: Dictionary) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var ordered: Array[Dictionary] = []
	if not state["active"].is_empty():
		ordered.append(state["active"])
	for entry: Dictionary in state["pending"]:
		ordered.append(entry)
	for index in range(ordered.size()):
		var payload: Dictionary = ordered[index]["payload"]
		var target: Dictionary = payload["target"]
		if target["kind"] == TARGET_PATRON:
			continue
		markers.append({
			"position": target["position"],
			"index": index + 1,
			"label": CATALOG[payload["command"]]["label"],
		})
	return markers


func _display_name(cultist_id: StringName) -> String:
	return String(cultist_id).replace("cultist_", "Cultist ")


func _reason_label(reason: StringName) -> String:
	return REASON_LABELS.get(reason, _humanize(reason))


func _humanize(value: Variant) -> String:
	return String(value).replace("_", " ").capitalize()


func _reject(cultist_id: StringName, command: StringName, reason: StringName) -> Dictionary:
	var label: String = CATALOG[command]["label"] if CATALOG.has(command) else _humanize(command)
	var message := "%s rejected: %s." % [label, _reason_label(reason)]
	if _feedback.has(cultist_id):
		_note(cultist_id, &"rejected", message, reason)
	return {
		"accepted": false,
		"action_id": -1,
		"command": command,
		"reason": reason,
		"message": message,
	}


func _note(cultist_id: StringName, outcome: StringName, message: String, reason: StringName) -> void:
	_feedback[cultist_id] = {"message": message, "reason": reason, "outcome": outcome}


func _record(
		cultist_id: StringName,
		action_id: int,
		command: StringName,
		state: StringName,
		reason: StringName
) -> void:
	_events.append({
		"cultist_id": cultist_id,
		"action_id": action_id,
		"command": command,
		"state": state,
		"reason": reason,
	})
