class_name PatronPerception
extends RefCounted

# Producer that turns danger in the room into the domain stimuli each Patron can
# perceive. It decides *who* perceives *what* — line of sight for visual events,
# room adjacency for sound, global pressure for Unattended Bodies, and nearby
# Companion influence — then hands the routing back to the caller. It never
# chooses Patron states; PatronSuspicion owns the score math (TECH section 8).

const VIEW_RANGE_METRES := 20.0
const VIEW_CONE_HALF_ANGLE_DEGREES := 60.0
const BODY_GRACE_SECONDS := 3.0
const BODY_PRESSURE_INTERVAL_SECONDS := 5.0
const COMPANION_INTERVAL_SECONDS := 10.0
const COMPANION_RANGE_METRES := 5.0

# Room-hearing relationship: two rooms share sound when they are the same room
# or directly adjacent. Cross-room vision is always blocked; there are no
# intra-room occluders (Week-4 tunables, approved model).
const ROOM_ADJACENCY := {
	&"front": [&"main_hall"],
	&"main_hall": [&"front", &"hallway"],
	&"hallway": [&"main_hall", &"bathroom"],
	&"bathroom": [&"hallway"],
}

var _bodies: Dictionary = {}
var _companion_accumulator: float = 0.0


# perceivers: Array of {id, room, position, facing}. Returns the ids that see an
# event at source_position in source_room: same room, within view range, and
# inside the facing cone. There are no intra-room occluders.
func visual_recipients(
		source_room: StringName,
		source_position: Vector2,
		perceivers: Array
) -> Array:
	var cone_limit := cos(deg_to_rad(VIEW_CONE_HALF_ANGLE_DEGREES))
	var recipients: Array[StringName] = []
	for perceiver: Dictionary in perceivers:
		if perceiver["room"] != source_room:
			continue
		var offset: Vector2 = source_position - perceiver["position"]
		var distance := offset.length()
		if distance > VIEW_RANGE_METRES:
			continue
		if distance <= 0.0001:
			recipients.append(perceiver["id"])
			continue
		var facing: Vector2 = perceiver["facing"]
		if facing.dot(offset) / distance >= cone_limit:
			recipients.append(perceiver["id"])
	return recipients


# perceivers: Array of {id, room, position, facing}. Returns the ids that hear a
# sound emitted in source_room through the room-hearing relationship.
func auditory_recipients(source_room: StringName, perceivers: Array) -> Array:
	var recipients: Array[StringName] = []
	for perceiver: Dictionary in perceivers:
		if hears(perceiver["room"], source_room):
			recipients.append(perceiver["id"])
	return recipients


func hears(listener_room: StringName, source_room: StringName) -> bool:
	if listener_room == source_room:
		return true
	var neighbours: Array = ROOM_ADJACENCY.get(source_room, [])
	return listener_room in neighbours


# --- Unattended Bodies -------------------------------------------------------
# Each Unattended Body applies global pressure once its grace period ends, every
# BODY_PRESSURE_INTERVAL_SECONDS. Bodies stack. Pressure pauses while a body is
# supported or dragged; dropping it starts a fresh grace period.

func add_body(body_id: StringName, room: StringName, position: Vector2) -> void:
	_bodies[body_id] = _fresh_body(room, position)


func set_body_state(body_id: StringName, state: StringName) -> void:
	if _bodies.has(body_id):
		_bodies[body_id]["state"] = state


func drop_body(body_id: StringName, room: StringName, position: Vector2) -> void:
	_bodies[body_id] = _fresh_body(room, position)


func remove_body(body_id: StringName) -> void:
	_bodies.erase(body_id)


# Advances every body's grace and pressure timers by delta. Returns the body ids
# that produced a pressure tick this step; the caller applies one +5 stimulus to
# every active Patron per returned id (so N stacked bodies appear N times).
func advance_bodies(delta: float) -> Array:
	var ticks: Array[StringName] = []
	for body_id: StringName in _bodies:
		var body: Dictionary = _bodies[body_id]
		if body["state"] != &"unattended":
			continue
		if body["grace"] > 0.0001:
			body["grace"] = maxf(0.0, body["grace"] - delta)
			continue
		body["accumulator"] += delta
		while body["accumulator"] + 0.0001 >= BODY_PRESSURE_INTERVAL_SECONDS:
			body["accumulator"] -= BODY_PRESSURE_INTERVAL_SECONDS
			ticks.append(body_id)
	return ticks


# --- Companion influence -----------------------------------------------------
# Every COMPANION_INTERVAL_SECONDS a Patron drifts up toward the highest-Suspicion
# Arrival Group member within COMPANION_RANGE_METRES and the same room.

func advance_companion_timer(delta: float) -> int:
	_companion_accumulator += delta
	var rounds := 0
	while _companion_accumulator + 0.0001 >= COMPANION_INTERVAL_SECONDS:
		_companion_accumulator -= COMPANION_INTERVAL_SECONDS
		rounds += 1
	return rounds


# candidates: Array of {id, room, position, score}. Returns the single highest
# scoring candidate in the same room and within Companion range, or {} if none
# apply. Taking one winner is what keeps multiple friends from stacking.
func highest_nearby_influence(
		perceiver_room: StringName,
		perceiver_position: Vector2,
		candidates: Array
) -> Dictionary:
	var best: Dictionary = {}
	for candidate: Dictionary in candidates:
		if candidate["room"] != perceiver_room:
			continue
		if perceiver_position.distance_to(candidate["position"]) > COMPANION_RANGE_METRES:
			continue
		if best.is_empty() or float(candidate["score"]) > float(best["score"]):
			best = candidate
	return best


func _fresh_body(room: StringName, position: Vector2) -> Dictionary:
	return {
		"room": room,
		"position": position,
		"state": &"unattended",
		"grace": BODY_GRACE_SECONDS,
		"accumulator": 0.0,
	}
