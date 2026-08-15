extends GutTest

const ORDER_SYSTEM_PATH := "res://scripts/orders/order_system.gd"


func test_served_order_reaches_one_terminal_state_and_pays_once() -> void:
	var order_system_script := load(ORDER_SYSTEM_PATH)
	var orders = order_system_script.new()
	var order_id: StringName = orders.create_order(&"patron_june", 0.0)

	assert_true(orders.serve_order(order_id, 9.0))
	assert_false(orders.serve_order(order_id, 10.0), "A served Order cannot pay twice.")
	assert_false(orders.cancel_order(order_id, 11.0, &"late_cancel"))
	var order: Dictionary = orders.order_snapshot(order_id)
	assert_eq(order["state"], &"served")
	assert_eq(order["payment"], 5)
	assert_eq(order["tip"], 2)
	assert_eq(orders.snapshot()["revenue"], 5)
	assert_eq(orders.snapshot()["tips"], 2)


func test_cancelled_order_is_terminal_and_pays_nothing() -> void:
	var order_system_script := load(ORDER_SYSTEM_PATH)
	var orders = order_system_script.new()
	var order_id: StringName = orders.create_order(&"patron_june", 0.0)

	assert_true(orders.cancel_order(order_id, 4.0, &"patron_left"))
	assert_false(orders.serve_order(order_id, 9.0))
	var order: Dictionary = orders.order_snapshot(order_id)
	assert_eq(order["state"], &"cancelled")
	assert_eq(order["payment"], 0)
	assert_eq(order["tip"], 0)
	assert_eq(orders.snapshot()["revenue"], 0)
