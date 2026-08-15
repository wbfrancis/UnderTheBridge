class_name ServiceSliceSession
extends RefCounted

signal snapshot_changed(snapshot: Dictionary)
signal service_event_recorded(event: Dictionary)

const ACTION_QUEUE_SCRIPT := preload("res://scripts/actions/cultist_action_queue.gd")
const ORDER_SYSTEM_SCRIPT := preload("res://scripts/orders/order_system.gd")
const CULTIST_IDS: Array[StringName] = [&"cultist_01", &"cultist_02", &"cultist_03"]
const PATRON_ID := &"patron_june"
const STEP_SECONDS := 0.05

var _simulated_seconds: float = 0.0
var _selected_cultist_id: StringName = CULTIST_IDS[0]
var _cultist_queues: Dictionary = {}
var _processed_queue_events: Dictionary = {}
var _order_system = ORDER_SYSTEM_SCRIPT.new()
var _order_id: StringName = &""
var _patron_available: bool = true
var _prepared_drinks: Dictionary = {}
var _next_drink_number: int = 1
var _service_events: Array[Dictionary] = []


func start() -> void:
	_simulated_seconds = 0.0
	_selected_cultist_id = CULTIST_IDS[0]
	_cultist_queues.clear()
	_processed_queue_events.clear()
	for cultist_id in CULTIST_IDS:
		_cultist_queues[cultist_id] = ACTION_QUEUE_SCRIPT.new()
		_processed_queue_events[cultist_id] = 0
	_order_system = ORDER_SYSTEM_SCRIPT.new()
	_order_id = _order_system.create_order(PATRON_ID, 0.0)
	_patron_available = true
	_prepared_drinks.clear()
	_next_drink_number = 1
	_service_events.clear()
	_record_service_event(&"slice_started", &"")
	_emit_snapshot()


func restart() -> void:
	start()


func select_cultist(cultist_id: StringName) -> bool:
	if not _cultist_queues.has(cultist_id):
		return false
	_selected_cultist_id = cultist_id
	_record_service_event(&"cultist_selected", cultist_id)
	_emit_snapshot()
	return true


func queue_full_service(cultist_id: StringName = _selected_cultist_id) -> Array[int]:
	if not _cultist_queues.has(cultist_id) or not _order_system.is_open(_order_id):
		return []
	var queue = _cultist_queues[cultist_id]
	var queue_snapshot: Dictionary = queue.snapshot()
	if not queue_snapshot["active"].is_empty() or not queue_snapshot["pending"].is_empty():
		return []
	var action_ids: Array[int] = []
	action_ids.append(queue.append(&"prepare_drink", _order_id, 5.0, 4.0, _patron_available))
	action_ids.append(queue.append(&"pickup_drink", _order_id, 1.0, 0.5, _patron_available))
	action_ids.append(queue.append(&"serve_order", _order_id, 3.0, 2.5, _patron_available))
	action_ids.append(queue.append(&"reset_at_bar", &"bar_work_position", 1.0, 0.5, true))
	_record_service_event(&"service_queued", cultist_id, {"action_ids": action_ids})
	_emit_snapshot()
	return action_ids


func remove_pending_action(action_id: int, cultist_id: StringName = _selected_cultist_id) -> bool:
	if not _cultist_queues.has(cultist_id):
		return false
	var removed: bool = _cultist_queues[cultist_id].remove_pending(action_id)
	if removed:
		_record_service_event(&"pending_action_removed", cultist_id, {"action_id": action_id})
		_emit_snapshot()
	return removed


func cancel_active_action(cultist_id: StringName = _selected_cultist_id) -> bool:
	if not _cultist_queues.has(cultist_id):
		return false
	var cancelled: bool = _cultist_queues[cultist_id].cancel_active()
	if cancelled:
		_record_service_event(&"active_action_cancelled", cultist_id)
		_process_queue_events(cultist_id)
		_emit_snapshot()
	return cancelled


func patron_leaves() -> bool:
	if not _patron_available or not _order_system.is_open(_order_id):
		return false
	_patron_available = false
	_order_system.cancel_order(_order_id, _simulated_seconds, &"patron_left")
	_record_service_event(&"patron_left", PATRON_ID, {"payment": 0})
	_refresh_service_action_validity()
	_emit_snapshot()
	return true


func advance(simulated_seconds: float) -> void:
	if simulated_seconds <= 0.0:
		return
	var remaining := simulated_seconds
	while remaining > 0.0001:
		var step := minf(STEP_SECONDS, remaining)
		_simulated_seconds += step
		_refresh_service_action_validity()
		for cultist_id in CULTIST_IDS:
			_cultist_queues[cultist_id].advance(step)
			_process_queue_events(cultist_id)
		remaining -= step
	_emit_snapshot()


func snapshot() -> Dictionary:
	var queues: Dictionary = {}
	for cultist_id in CULTIST_IDS:
		queues[cultist_id] = _cultist_queues[cultist_id].snapshot()
	return {
		"simulated_seconds": _simulated_seconds,
		"selected_cultist_id": _selected_cultist_id,
		"cultist_queues": queues,
		"order_id": _order_id,
		"order": _order_system.order_snapshot(_order_id),
		"order_system": _order_system.snapshot(),
		"patron_id": PATRON_ID,
		"patron_available": _patron_available,
		"prepared_drinks": _prepared_drinks.duplicate(true),
		"service_events": _service_events.duplicate(true),
	}


func _refresh_service_action_validity() -> void:
	var target_is_valid := _patron_available and _order_system.is_open(_order_id)
	for cultist_id in CULTIST_IDS:
		var queue = _cultist_queues[cultist_id]
		var queue_snapshot: Dictionary = queue.snapshot()
		var actions: Array[Dictionary] = []
		if not queue_snapshot["active"].is_empty():
			actions.append(queue_snapshot["active"])
		for pending_action: Dictionary in queue_snapshot["pending"]:
			actions.append(pending_action)
		for action in actions:
			if action["name"] in [&"prepare_drink", &"pickup_drink", &"serve_order"]:
				queue.set_target_valid(action["id"], target_is_valid)


func _process_queue_events(cultist_id: StringName) -> void:
	var queue_snapshot: Dictionary = _cultist_queues[cultist_id].snapshot()
	var queue_events: Array = queue_snapshot["recent_events"]
	var processed: int = _processed_queue_events[cultist_id]
	while processed < queue_events.size():
		var queue_event: Dictionary = queue_events[processed]
		if queue_event["state"] == &"completed":
			_apply_completed_action(cultist_id, queue_event)
		elif queue_event["state"] == &"failed":
			_record_service_event(
				&"action_failed",
				cultist_id,
				{"action_id": queue_event["id"], "name": queue_event["name"], "reason": queue_event["reason"]}
			)
		elif queue_event["state"] == &"cancelled":
			_record_service_event(
				&"action_cancelled",
				cultist_id,
				{"action_id": queue_event["id"], "name": queue_event["name"], "reason": queue_event["reason"]}
			)
		processed += 1
	_processed_queue_events[cultist_id] = processed


func _apply_completed_action(cultist_id: StringName, queue_event: Dictionary) -> void:
	match queue_event["name"]:
		&"prepare_drink":
			if not _order_system.is_open(_order_id):
				_record_service_event(&"action_effect_failed", cultist_id, {"name": &"prepare_drink"})
				return
			var drink_id := StringName("drink_%03d" % _next_drink_number)
			_next_drink_number += 1
			_prepared_drinks[drink_id] = {
				"id": drink_id,
				"order_id": _order_id,
				"state": &"at_bar",
				"carried_by": &"",
			}
			_record_service_event(&"drink_prepared", cultist_id, {"drink_id": drink_id})
		&"pickup_drink":
			var drink_id := _drink_for_order_at_state(_order_id, &"at_bar")
			if drink_id.is_empty():
				_record_service_event(&"action_effect_failed", cultist_id, {"name": &"pickup_drink"})
				return
			_prepared_drinks[drink_id]["state"] = &"carried"
			_prepared_drinks[drink_id]["carried_by"] = cultist_id
			_record_service_event(&"drink_picked_up", cultist_id, {"drink_id": drink_id})
		&"serve_order":
			var drink_id := _carried_drink_for_order(_order_id, cultist_id)
			if drink_id.is_empty() or not _order_system.serve_order(_order_id, _simulated_seconds):
				_record_service_event(&"action_effect_failed", cultist_id, {"name": &"serve_order"})
				return
			_prepared_drinks[drink_id]["state"] = &"served"
			_prepared_drinks[drink_id]["carried_by"] = &""
			var order: Dictionary = _order_system.order_snapshot(_order_id)
			_record_service_event(
				&"order_served",
				cultist_id,
				{"drink_id": drink_id, "payment": order["payment"], "tip": order["tip"]}
			)
		&"reset_at_bar":
			_record_service_event(&"queue_continued", cultist_id)


func _drink_for_order_at_state(order_id: StringName, state: StringName) -> StringName:
	for drink_id: StringName in _prepared_drinks:
		var drink: Dictionary = _prepared_drinks[drink_id]
		if drink["order_id"] == order_id and drink["state"] == state:
			return drink_id
	return &""


func _carried_drink_for_order(order_id: StringName, cultist_id: StringName) -> StringName:
	for drink_id: StringName in _prepared_drinks:
		var drink: Dictionary = _prepared_drinks[drink_id]
		if (
			drink["order_id"] == order_id
			and drink["state"] == &"carried"
			and drink["carried_by"] == cultist_id
		):
			return drink_id
	return &""


func _record_service_event(
	event_name: StringName,
	actor_id: StringName,
	details: Dictionary = {}
) -> void:
	var event := {
		"at": _simulated_seconds,
		"event": event_name,
		"actor_id": actor_id,
		"details": details.duplicate(true),
	}
	_service_events.append(event)
	if _service_events.size() > 30:
		_service_events.pop_front()
	service_event_recorded.emit(event.duplicate(true))


func _emit_snapshot() -> void:
	snapshot_changed.emit(snapshot())
