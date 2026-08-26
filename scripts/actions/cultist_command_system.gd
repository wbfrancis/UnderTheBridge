class_name CultistCommandSystem
extends RefCounted

## The single seam between player input and Cultist gameplay operations.
##
## The module owns the command catalog, the Action Queue lifecycle, Action Chain
## creation and cascade, target revalidation, the Commitment Point, execution
## dispatch, and reservation cleanup. GameSession stays the gameplay authority:
## this module never copies an eligibility rule, it asks the session for one.
##
## Every Patron command needs the Cultist to be adjacent. When the Cultist is not
## adjacent, the module adds a visible Generated Move in front of the requested
## Action; the pair form one Action Chain. The live scene is a thin adapter that
## supplies geometry facts (positions, adjacency) and drives NavigableActor3D; it
## never creates a chain or removes a dependent Action.

const ACTION_QUEUE_SCRIPT := preload("res://scripts/actions/cultist_action_queue.gd")
const INTERACTION_REGISTRY_SCRIPT := preload("res://scripts/interactions/interaction_registry.gd")

const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]

const TARGET_FLOOR := &"floor"
const TARGET_PATRON := &"patron"
const TARGET_OBJECT := &"smart_object"

## The internal command used for a Generated Move. It renders as Move, targets a
## Patron, never appears in a Context Menu, and has no gameplay effect.
const GENERATED_MOVE := &"generated_move"

## One centralized catalog. Menu order follows the per-kind command lists below,
## so the same target always produces the same option order. Patron commands are
## proximity-dependent: they need a Generated Move when the Cultist is not
## adjacent. Floor and smart-object commands are not proximity-dependent.
const CATALOG := {
	&"move": {"label": "Move", "kinds": [TARGET_FLOOR, TARGET_OBJECT], "reserves": false, "requires_proximity": false},
	&"drop_body": {"label": "Drop Body Here", "kinds": [TARGET_FLOOR, TARGET_OBJECT], "reserves": false, "requires_proximity": false},
	&"talk": {"label": "Talk", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"serve_order": {"label": "Serve Order", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"offer_drink": {"label": "Offer Drink", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"offer_cigarette": {"label": "Offer Cigarette", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"knock_out": {"label": "Knock Out", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"pick_up_body": {"label": "Pick Up Body", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"intercept": {"label": "Intercept", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"lead_to_tunnel": {"label": "Lead to Tunnel", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"rescue_persuasion": {"label": "Rescue Persuasion", "kinds": [TARGET_PATRON], "reserves": true, "requires_proximity": true},
	&"prepare_drink": {"label": "Prepare Drink", "kinds": [TARGET_OBJECT], "reserves": true, "requires_proximity": false},
	&"prepare_drugged_drink": {"label": "Prepare Drugged Drink", "kinds": [TARGET_OBJECT], "reserves": true, "requires_proximity": false},
	&"activate_trapdoor": {"label": "Activate Trapdoor", "kinds": [TARGET_OBJECT], "reserves": true, "requires_proximity": false},
	GENERATED_MOVE: {"label": "Move", "kinds": [], "reserves": true, "requires_proximity": false},
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
	&"chain_cancelled": "Cancelled with its Action Chain",
	&"cultist_busy": "Cultist is occupied",
	&"dependency_failed": "A prerequisite failed",
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
## Shift appends it. A proximity command issued while not adjacent gains a visible
## Generated Move prerequisite, so the two form one Action Chain. `context` is a
## request-only geometry fact: {is_adjacent: bool}. The returned dictionary is the
## visible outcome and reports the requested `action_id`, the `chain_id`, and any
## `generated_action_ids`, so no caller has to guess which id is player intent.
func issue(
		cultist_id: StringName,
		command: StringName,
		target: Dictionary,
		append: bool,
		context: Dictionary = {}
) -> Dictionary:
	if _session == null or not _queues.has(cultist_id):
		return _reject(cultist_id, command, &"invalid_target")
	if not CATALOG.has(command) or command == GENERATED_MOVE or target.is_empty():
		return _reject(cultist_id, command, &"unknown_command")
	if command not in _commands_for_target(target):
		return _reject(cultist_id, command, &"unknown_command")
	# Revalidation point 2: the command was chosen, so check the target again.
	var state := _availability(command, cultist_id, target)
	if not bool(state["available"]):
		return _reject(cultist_id, command, state["reason"])

	var normalized := _normalized_target(target)
	var is_adjacent := bool(context.get("is_adjacent", false))
	var needs_move := _requires_proximity(command) and not is_adjacent
	var specs: Array[Dictionary] = []
	if needs_move:
		specs.append(_generated_move_spec(command, normalized))
	specs.append(_command_spec(command, normalized))

	var queue = _queues[cultist_id]
	var result: Dictionary
	if append:
		result = queue.append_chain(specs)
	else:
		_release(cultist_id)
		result = queue.replace_with_chain(specs)
	_record_removed(cultist_id, result.get("removed", []), &"replace")
	_sync_active(cultist_id)

	var action_ids: Array = result["action_ids"]
	var requested_action_id := int(action_ids[action_ids.size() - 1])
	var generated_action_ids: Array[int] = []
	for index in range(action_ids.size() - 1):
		generated_action_ids.append(int(action_ids[index]))
	var chain_id := int(result["chain_id"])

	var still_queued := _find_action(cultist_id, requested_action_id)
	if still_queued.is_empty():
		var failure: Dictionary = _feedback[cultist_id]
		return {
			"accepted": false,
			"action_id": requested_action_id,
			"chain_id": chain_id,
			"generated_action_ids": generated_action_ids,
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
		"action_id": requested_action_id,
		"chain_id": chain_id,
		"generated_action_ids": generated_action_ids,
		"command": command,
		"reason": &"",
		"message": message,
	}


## Removes a queued Action and every unfinished link of its Action Chain.
func remove_pending(cultist_id: StringName, action_id: int) -> bool:
	if not _queues.has(cultist_id):
		return false
	if _find_action(cultist_id, action_id).is_empty():
		return false
	var result := _cancel_action(cultist_id, action_id)
	return bool(result.get("cancelled", false))


## Cancels the running Action for one Cultist, cascading through its Action
## Chain. Cancellation is only allowed before the Commitment Point, because after
## it the gameplay effect has fired and no undo exists. A refusal carries a
## visible reason, never a silent no-op.
func request_cancel_active(cultist_id: StringName) -> Dictionary:
	if _session == null or not _queues.has(cultist_id):
		return _cancel_refusal(cultist_id, -1, &"", &"invalid_target")
	var action := _active_action(cultist_id)
	if action.is_empty():
		return _cancel_refusal(cultist_id, -1, &"", &"no_active_action")
	return _cancel_action(cultist_id, int(action["id"]))


# Cancels one Action and its unfinished chain links. Releases the reservation
# once when the cascade removes the active Action that held it.
func _cancel_action(cultist_id: StringName, action_id: int) -> Dictionary:
	var target := _find_action(cultist_id, action_id)
	if target.is_empty():
		return _cancel_refusal(cultist_id, action_id, &"", &"no_active_action")
	var command: StringName = target["payload"]["command"]
	var active := _active_action(cultist_id)
	var active_id := int(active["id"]) if not active.is_empty() else -1
	if not active.is_empty() and int(active["id"]) == action_id and bool(active["payload"]["committed"]):
		return _cancel_refusal(cultist_id, action_id, command, &"already_committed")

	var result: Dictionary = _queues[cultist_id].cancel_chain(action_id)
	var removed: Array = result["removed"]
	if removed.is_empty():
		return _cancel_refusal(cultist_id, action_id, command, &"already_committed")
	var active_removed := false
	for snap: Dictionary in removed:
		if int(snap["id"]) == active_id:
			active_removed = true
	if active_removed:
		_release(cultist_id)
	_record_removed(cultist_id, removed, &"player_request")
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


## Navigation reported arrival at the approach point for a navigate-mode Action.
## A Generated Move completes and hands its reservation to the dependent Patron
## Action. A floor or smart-object Action commits its effect here. This is the
## Commitment Point: the gameplay effect fires exactly once.
func notify_reached(cultist_id: StringName, action_id: int) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty() or int(action["id"]) != action_id:
		return {"committed": false, "reason": &"invalid_target"}
	var payload: Dictionary = action["payload"]
	var command: StringName = payload["command"]
	var target: Dictionary = payload["target"]
	if command == GENERATED_MOVE:
		return _complete_generated_move(cultist_id, action_id)

	# Revalidation point 4: the approach is over, so check the target one last time.
	var state := _availability_for(cultist_id, action)
	if not bool(state["available"]):
		_fail_active(cultist_id, state["reason"])
		return {"committed": false, "reason": state["reason"]}
	return _commit_active(cultist_id, action_id, command, target)


## The adapter reports the live proximity result for a Patron Action that has
## reached the head of the queue. The command system either commits the Action or
## inserts a Generated Move prerequisite. The adapter never edits the chain.
func resolve_proximity(cultist_id: StringName, action_id: int, is_adjacent: bool) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty() or int(action["id"]) != action_id:
		return {"committed": false, "reason": &"invalid_target", "changed": false}
	var payload: Dictionary = action["payload"]
	var command: StringName = payload["command"]
	var target: Dictionary = payload["target"]

	var state := _availability_for(cultist_id, action)
	if not bool(state["available"]):
		_fail_active(cultist_id, state["reason"])
		return {"committed": false, "reason": state["reason"], "changed": true}
	if not is_adjacent:
		# The Patron moved out of reach, so insert one visible Generated Move ahead
		# of this Action. The reservation stays with this Cultist across the insert.
		_queues[cultist_id].insert_prerequisite_for_active(_generated_move_spec(command, target))
		_sync_active(cultist_id)
		return {"committed": false, "reason": &"approaching", "changed": true, "inserted_move": true}
	var result := _commit_active(cultist_id, action_id, command, target)
	result["changed"] = true
	return result


# The Generated Move has no gameplay effect. It completes, keeps the approach
# reservation, and lets the dependent Patron Action become active with the slot
# already held, so no other Cultist can steal it in a release gap.
func _complete_generated_move(cultist_id: StringName, action_id: int) -> Dictionary:
	_record(cultist_id, action_id, GENERATED_MOVE, &"completed", &"")
	_queues[cultist_id].complete_active()
	_sync_active(cultist_id)
	return {"committed": true, "reason": &"", "generated": true, "changed": true}


func _commit_active(
		cultist_id: StringName, action_id: int, command: StringName, target: Dictionary
) -> Dictionary:
	var outcome := _execute(command, cultist_id, target)
	_queues[cultist_id].set_payload_value(action_id, "committed", true)
	_record(cultist_id, action_id, command, &"committed", outcome["reason"])
	if not bool(outcome["ok"]):
		_fail_active(cultist_id, outcome["reason"])
		return {"committed": true, "reason": outcome["reason"]}
	_note(cultist_id, &"completed", "%s done." % CATALOG[command]["label"], outcome["reason"])
	_release(cultist_id)
	_queues[cultist_id].complete_active()
	_sync_active(cultist_id)
	return {"committed": true, "reason": outcome["reason"]}


## Navigation could not reach the approach point. Nothing was committed; the
## whole Action Chain fails once and the next unrelated Action starts.
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


## What the adapter should do for this Cultist, or {} when idle. A Generated Move,
## a floor Move, and a smart-object Action use `navigate`. A Patron Action whose
## prerequisites finished uses `check_proximity`: the adapter reports adjacency
## through resolve_proximity and never navigates it itself.
func active_request(cultist_id: StringName) -> Dictionary:
	var action := _active_action(cultist_id)
	if action.is_empty():
		return {}
	var payload: Dictionary = action["payload"]
	var target: Dictionary = payload["target"]
	var command: StringName = payload["command"]
	var mode := &"navigate"
	if command != GENERATED_MOVE and StringName(target["kind"]) == TARGET_PATRON:
		mode = &"check_proximity"
	return {
		"action_id": int(action["id"]),
		"command": command,
		"mode": mode,
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

## Brings the active Action into a runnable state: it clears a stale Action or
## chain, takes the approach reservation, and stops when the queue is idle or the
## head Action is ready for the adapter to drive.
func _sync_active(cultist_id: StringName) -> void:
	var guard := 0
	while guard < 16:
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
		var state := _availability_for(cultist_id, action)
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
	var active_id := int(action["id"])
	_release(cultist_id)
	var result: Dictionary = _queues[cultist_id].fail_active_chain(reason)
	for snap: Dictionary in result["removed"]:
		var snap_command: StringName = snap["payload"]["command"]
		if int(snap["id"]) == active_id:
			_record(cultist_id, int(snap["id"]), snap_command, &"failed", reason)
		else:
			_record(cultist_id, int(snap["id"]), snap_command, &"cancelled", &"dependency_failed")
	_note(
		cultist_id,
		&"failed",
		"%s failed: %s." % [CATALOG[command]["label"], _reason_label(reason)],
		reason
	)


func _record_removed(cultist_id: StringName, removed: Array, reason: StringName) -> void:
	for snap: Dictionary in removed:
		_record(cultist_id, int(snap["id"]), snap["payload"]["command"], &"cancelled", reason)


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

## Reads the availability rule for one queued Action, including a Generated Move,
## whose validity is the validity of the Patron command it approaches for.
func _availability_for(cultist_id: StringName, action: Dictionary) -> Dictionary:
	var payload: Dictionary = action["payload"]
	return _availability(
		StringName(payload["command"]),
		cultist_id,
		payload["target"],
		StringName(payload.get("chain_command", &"")),
	)


## Every rule comes from the gameplay authority. Move is the one command this
## module answers for, because it has no gameplay effect of its own. A Generated
## Move defers to the command it precedes.
func _availability(
		command: StringName,
		cultist_id: StringName,
		target: Dictionary,
		chain_command: StringName = &""
) -> Dictionary:
	if command == GENERATED_MOVE:
		var effective := chain_command if not chain_command.is_empty() else &"move"
		return _availability(effective, cultist_id, target)
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
		GENERATED_MOVE, &"move":
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

func _requires_proximity(command: StringName) -> bool:
	return CATALOG.has(command) and bool(CATALOG[command].get("requires_proximity", false))


func _command_spec(command: StringName, normalized: Dictionary) -> Dictionary:
	return {
		"name": command,
		"target_id": StringName(normalized["id"]),
		"duration_seconds": INF,
		"commitment_seconds": INF,
		"target_is_valid": true,
		"generated": false,
		"payload": {
			"command": command,
			"target": normalized,
			"committed": false,
			"reserved": false,
			"engagement_cleared": false,
		},
	}


func _generated_move_spec(chain_command: StringName, normalized: Dictionary) -> Dictionary:
	return {
		"name": GENERATED_MOVE,
		"target_id": StringName(normalized["id"]),
		"duration_seconds": INF,
		"commitment_seconds": INF,
		"target_is_valid": true,
		"generated": true,
		"payload": {
			"command": GENERATED_MOVE,
			"chain_command": chain_command,
			"target": normalized,
			"committed": false,
			"reserved": false,
			"engagement_cleared": false,
		},
	}


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
	var generated := command == GENERATED_MOVE or bool(action.get("generated", false))
	return {
		"id": int(action["id"]),
		"command": command,
		"icon": &"move" if command == GENERATED_MOVE else command,
		"label": CATALOG[command]["label"],
		"target_kind": target["kind"],
		"target_id": target["id"],
		"target_label": _target_label(cultist_id, target),
		"stage": &"committed" if bool(payload["committed"]) else &"approaching",
		"cancellable": not bool(payload["committed"]),
		"chain_id": int(action.get("chain_id", -1)),
		"chain_index": int(action.get("chain_index", 0)),
		"chain_size": int(action.get("chain_size", 1)),
		"generated": generated,
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
		"chain_id": -1,
		"generated_action_ids": [],
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
