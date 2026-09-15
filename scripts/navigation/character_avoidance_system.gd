class_name CharacterAvoidanceSystem
extends RefCounted

## Pure incident policy. Presentation supplies geometry; this module decides
## which idle character receives Step Aside. It never moves a character itself.
const BLOCK_SECONDS := 1.0
const BLOCK_DISTANCE := 1.2
const STEP_DISTANCE := 1.4
const PRIORITY_IDLE := 0
const PRIORITY_PATRON := 1
const PRIORITY_PLAYER := 2
const PRIORITY_BODY := 3
const PRIORITY_DANGER := 4

var _incidents: Dictionary = {}


func advance(delta: float, actors: Array[Dictionary]) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	if delta <= 0.0:
		return requests
	var live_movers: Dictionary = {}
	var claimed: Dictionary = {}
	var ordered := actors.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return int(a["id"]) < int(b["id"])
	)
	for mover: Dictionary in ordered:
		if not bool(mover.get("moving", false)):
			continue
		var mover_key := "%s:%s" % [mover["id"], mover["action_id"]]
		live_movers[mover_key] = true
		for blocker: Dictionary in ordered:
			if mover["id"] == blocker["id"] or claimed.has(blocker["id"]):
				continue
			if not bool(blocker.get("can_yield", false)) or int(blocker["priority"]) >= int(mover["priority"]):
				continue
			var key := StringName("%s:%s" % [mover_key, blocker["id"]])
			var incident: Dictionary = _incidents.get(key, {"elapsed": 0.0, "issued": false, "mover": mover_key})
			if bool(incident["issued"]):
				continue
			if _distance_to_segment(blocker["position"], mover["position"], mover["segment_end"]) > BLOCK_DISTANCE:
				incident["elapsed"] = 0.0
			else:
				incident["elapsed"] += delta
				if float(incident["elapsed"]) + 0.0001 >= BLOCK_SECONDS:
					var forward: Vector3 = (mover["position"] as Vector3).direction_to(mover["segment_end"])
					var side := Vector3(-forward.z, 0.0, forward.x)
					if side.is_zero_approx():
						side = Vector3.RIGHT
					requests.append({
						"actor_id": blocker["id"], "incident_id": key,
						"position": blocker["position"] + side * STEP_DISTANCE,
						"alternate": blocker["position"] - side * STEP_DISTANCE,
					})
					incident["issued"] = true
					claimed[blocker["id"]] = true
			_incidents[key] = incident
	for key: StringName in _incidents.keys():
		if not live_movers.has(_incidents[key]["mover"]):
			_incidents.erase(key)
	return requests


func reset() -> void:
	_incidents.clear()


func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var span := finish - start
	if span.length_squared() <= 0.0001:
		return point.distance_to(finish)
	var weight := clampf((point - start).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(start + span * weight)
