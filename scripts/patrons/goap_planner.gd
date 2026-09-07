class_name GoapPlanner
extends RefCounted

## Pure, bounded uniform-cost search. Facts and effects are boolean; action
## names give equal-cost plans a stable order, independent of input order.
static func plan(facts: Dictionary, goal: Dictionary, actions: Array, limit: int = 128) -> Dictionary:
	var ordered := actions.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	var frontier: Array = [{"facts": facts.duplicate(), "steps": [], "cost": 0.0, "order": 0}]
	var visited: Dictionary = {}
	var expanded := 0
	var serial := 0
	while not frontier.is_empty() and expanded < limit:
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["cost"] < b["cost"] if a["cost"] != b["cost"] else a["order"] < b["order"])
		var node: Dictionary = frontier.pop_front()
		var key := _key(node["facts"])
		if visited.has(key) and float(visited[key]) <= float(node["cost"]):
			continue
		visited[key] = node["cost"]
		expanded += 1
		if matches(node["facts"], goal):
			return {"status": &"ready", "steps": node["steps"], "cost": node["cost"], "expanded": expanded}
		for action: Dictionary in ordered:
			if not matches(node["facts"], action["preconditions"]):
				continue
			var next: Dictionary = node["facts"].duplicate()
			next.merge(action["effects"], true)
			var steps: Array = node["steps"].duplicate()
			steps.append(action.duplicate(true))
			serial += 1
			frontier.append({"facts": next, "steps": steps,
				"cost": float(node["cost"]) + maxf(0.001, float(action.get("cost", 1.0))), "order": serial})
	return {"status": &"search_limit" if not frontier.is_empty() else &"no_plan", "steps": [], "expanded": expanded}


static func matches(facts: Dictionary, required: Dictionary) -> bool:
	for key: Variant in required:
		if not facts.has(key) or not is_same(facts[key], required[key]):
			return false
	return true


static func _key(facts: Dictionary) -> String:
	var keys := facts.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key: Variant in keys:
		parts.append("%s=%s" % [key, facts[key]])
	return "|".join(parts)
