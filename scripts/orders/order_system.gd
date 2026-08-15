class_name OrderSystem
extends RefCounted

const BASE_PAYMENT := 5
const FAST_TIP := 2
const STANDARD_TIP := 1

var _next_order_number: int = 1
var _orders: Dictionary = {}
var _recent_events: Array[Dictionary] = []
var _revenue: int = 0
var _tips: int = 0


func create_order(patron_id: StringName, requested_at: float) -> StringName:
	if patron_id.is_empty():
		return &""
	var order_id := StringName("order_%03d" % _next_order_number)
	_next_order_number += 1
	_orders[order_id] = {
		"id": order_id,
		"patron_id": patron_id,
		"state": &"open",
		"requested_at": maxf(requested_at, 0.0),
		"terminal_at": -1.0,
		"terminal_reason": &"",
		"payment": 0,
		"tip": 0,
	}
	_record_event(order_id, &"created")
	return order_id


func serve_order(order_id: StringName, delivered_at: float) -> bool:
	if not is_open(order_id):
		return false
	var order: Dictionary = _orders[order_id]
	var elapsed := maxf(0.0, delivered_at - float(order["requested_at"]))
	var tip := 0
	if elapsed <= 30.0:
		tip = FAST_TIP
	elif elapsed <= 45.0:
		tip = STANDARD_TIP
	order["state"] = &"served"
	order["terminal_at"] = delivered_at
	order["terminal_reason"] = &"delivered"
	order["payment"] = BASE_PAYMENT
	order["tip"] = tip
	_revenue += BASE_PAYMENT
	_tips += tip
	_record_event(order_id, &"served", {"elapsed": elapsed, "payment": BASE_PAYMENT, "tip": tip})
	return true


func cancel_order(order_id: StringName, cancelled_at: float, reason: StringName) -> bool:
	if not is_open(order_id):
		return false
	var order: Dictionary = _orders[order_id]
	order["state"] = &"cancelled"
	order["terminal_at"] = cancelled_at
	order["terminal_reason"] = reason
	order["payment"] = 0
	order["tip"] = 0
	_record_event(order_id, &"cancelled", {"reason": reason})
	return true


func is_open(order_id: StringName) -> bool:
	return _orders.has(order_id) and _orders[order_id]["state"] == &"open"


func order_snapshot(order_id: StringName) -> Dictionary:
	if not _orders.has(order_id):
		return {}
	return _orders[order_id].duplicate(true)


func snapshot() -> Dictionary:
	return {
		"orders": _orders.duplicate(true),
		"revenue": _revenue,
		"tips": _tips,
		"recent_events": _recent_events.duplicate(true),
	}


func _record_event(order_id: StringName, state: StringName, details: Dictionary = {}) -> void:
	_recent_events.append({
		"order_id": order_id,
		"state": state,
		"details": details.duplicate(true),
	})
