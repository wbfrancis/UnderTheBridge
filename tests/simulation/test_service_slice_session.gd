extends GutTest

const SERVICE_SESSION_PATH := "res://scripts/simulation/service_slice_session.gd"


func test_player_commanded_service_prepares_carries_delivers_and_pays() -> void:
	var session_script := load(SERVICE_SESSION_PATH)
	var session = session_script.new()
	session.start()
	assert_true(session.select_cultist(&"cultist_02"))
	var action_ids: Array[int] = session.queue_full_service()
	assert_eq(action_ids.size(), 4)
	var queued: Dictionary = session.snapshot()["cultist_queues"][&"cultist_02"]
	assert_eq(queued["active"]["name"], &"prepare_drink")
	assert_eq(queued["pending"].size(), 3)

	session.advance(10.25)
	var completed: Dictionary = session.snapshot()
	assert_eq(completed["order"]["state"], &"served")
	assert_eq(completed["order"]["payment"], 5)
	assert_eq(completed["order"]["tip"], 2)
	assert_eq(completed["order_system"]["revenue"], 5)
	assert_eq(completed["prepared_drinks"].size(), 1)
	assert_eq(completed["prepared_drinks"].values()[0]["state"], &"served")
	assert_true(completed["cultist_queues"][&"cultist_02"]["active"].is_empty())


func test_stale_patron_fails_visibly_pays_nothing_and_queue_continues() -> void:
	var session_script := load(SERVICE_SESSION_PATH)
	var session = session_script.new()
	session.start()
	var action_ids: Array[int] = session.queue_full_service(&"cultist_01")
	assert_eq(action_ids.size(), 4)
	assert_true(session.patron_leaves())
	session.advance(2.0)

	var failed: Dictionary = session.snapshot()
	assert_eq(failed["order"]["state"], &"cancelled")
	assert_eq(failed["order"]["payment"], 0)
	assert_eq(failed["order_system"]["revenue"], 0)
	assert_true(failed["cultist_queues"][&"cultist_01"]["active"].is_empty())
	var failed_actions := 0
	var queue_continued := false
	for event: Dictionary in failed["service_events"]:
		if event["event"] == &"action_failed":
			failed_actions += 1
		elif event["event"] == &"queue_continued":
			queue_continued = true
	assert_eq(failed_actions, 3)
	assert_true(queue_continued)
