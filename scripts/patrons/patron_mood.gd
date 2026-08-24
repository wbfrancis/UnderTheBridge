class_name PatronMood
extends RefCounted

const STARTING_VALUE := 75.0
const MINIMUM := 0.0
const MAXIMUM := 100.0

var _value := STARTING_VALUE
var _rewarded_talk_partners: Dictionary = {}
var _events: Array[Dictionary] = []


func change(amount: float, cause: StringName) -> float:
	var before := _value
	_value = clampf(_value + amount, MINIMUM, MAXIMUM)
	var applied := _value - before
	if not is_zero_approx(applied):
		_events.append({"cause": cause, "amount": applied, "value": _value})
	return applied


func complete_talk(cultist_id: StringName) -> bool:
	if cultist_id.is_empty() or _rewarded_talk_partners.has(cultist_id):
		return false
	_rewarded_talk_partners[cultist_id] = true
	change(5.0, &"first_talk")
	return true


func value() -> float:
	return _value


func band() -> String:
	if _value >= 80.0:
		return "Happy"
	if _value >= 50.0:
		return "Content"
	if _value >= 25.0:
		return "Unhappy"
	return "Miserable"


func tip_multiplier() -> float:
	match band():
		"Happy": return 1.5
		"Content": return 1.0
		"Unhappy": return 0.5
	return 0.0


func snapshot() -> Dictionary:
	return {
		"value": _value,
		"band": band(),
		"tip_multiplier": tip_multiplier(),
		"rewarded_talk_partners": _rewarded_talk_partners.keys(),
		"events": _events.duplicate(true),
	}
