class_name PatronSatisfaction
extends RefCounted

const STARTING_VALUE := 75.0
const MINIMUM := 0.0
const MAXIMUM := 100.0
## Decay stops at the bottom of the Unhappy band. Neglect makes a Patron cheap
## and unhappy; only a service failure carries them below this floor.
const DECAY_FLOOR := 25.0
## Slow enough to cross about one band across a nine-minute visit.
const DECAY_PER_SECOND := 0.05

## A Satisfaction Modifier offsets the meter while it lasts instead of moving it
## once. A modifier with no envelope holds its full magnitude until something
## removes it, which is how standing pressure like Sighted Grime works. A
## modifier with an envelope fades in, holds, then fades out and expires, which
## is how the Smoking bump works.
var _base := STARTING_VALUE
var _modifiers: Dictionary = {}
var _rewarded_talk_partners: Dictionary = {}
var _events: Array[Dictionary] = []


## Moves the base meter once. Discrete service events use this; anything that
## should lift again later belongs in a modifier.
func change(amount: float, cause: StringName) -> float:
	var before := _base
	_base = clampf(_base + amount, MINIMUM, MAXIMUM)
	var applied := _base - before
	if not is_zero_approx(applied):
		_events.append({"cause": cause, "amount": applied, "value": value()})
	return applied


func complete_talk(cultist_id: int) -> bool:
	if cultist_id == ActorIds.NO_ACTOR or _rewarded_talk_partners.has(cultist_id):
		return false
	_rewarded_talk_partners[cultist_id] = true
	change(5.0, &"first_talk")
	return true


## Adds a modifier, or updates the one already held for this source. A repeat
## refreshes the envelope rather than adding a second copy, and takes the new
## magnitude, so a growing Grime cluster scales one weight instead of stacking
## several. Leave the envelope at zero for pressure that lasts until removed.
func add_modifier(
	source: StringName,
	magnitude: float,
	fade_in: float = 0.0,
	hold: float = 0.0,
	fade_out: float = 0.0,
) -> void:
	if source.is_empty():
		return
	_modifiers[source] = {
		"magnitude": magnitude,
		"elapsed": 0.0,
		"fade_in": maxf(0.0, fade_in),
		"hold": maxf(0.0, hold),
		"fade_out": maxf(0.0, fade_out),
	}


func remove_modifier(source: StringName) -> bool:
	return _modifiers.erase(source)


func has_modifier(source: StringName) -> bool:
	return _modifiers.has(source)


## The signed offset a single modifier contributes right now.
func modifier_contribution(source: StringName) -> float:
	if not _modifiers.has(source):
		return 0.0
	return _contribution(_modifiers[source])


func _contribution(modifier: Dictionary) -> float:
	var magnitude := float(modifier["magnitude"])
	var fade_in := float(modifier["fade_in"])
	var hold := float(modifier["hold"])
	var fade_out := float(modifier["fade_out"])
	if fade_in <= 0.0 and hold <= 0.0 and fade_out <= 0.0:
		return magnitude
	var elapsed := float(modifier["elapsed"])
	if elapsed < fade_in:
		return magnitude * (elapsed / fade_in)
	if elapsed < fade_in + hold:
		return magnitude
	var falling := elapsed - fade_in - hold
	if falling < fade_out:
		return magnitude * (1.0 - falling / fade_out)
	return 0.0


func _is_expired(modifier: Dictionary) -> bool:
	var total := (
		float(modifier["fade_in"]) + float(modifier["hold"]) + float(modifier["fade_out"])
	)
	if total <= 0.0:
		return false
	return float(modifier["elapsed"]) >= total


## The sum of every active modifier offset.
func modifier_total() -> float:
	var total := 0.0
	for source: StringName in _modifiers:
		total += _contribution(_modifiers[source])
	return total


## True while the Patron holds any modifier that lifts the meter, which is what
## holds decay off so a cigarette or a conversation reads as real respite. This
## asks about magnitude rather than the contribution right now, so a modifier
## still fading in already counts: a cigarette just lit is respite too.
func has_positive_modifier() -> bool:
	for source: StringName in _modifiers:
		if float(_modifiers[source]["magnitude"]) > 0.0:
			return true
	return false


## Advances envelopes, drops expired modifiers, then applies decay.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	# A modifier still lifting the meter when the tick began holds decay off for
	# that whole tick, so respite is not clipped by the moment it ends.
	var was_lifted := has_positive_modifier()
	var expired: Array[StringName] = []
	for source: StringName in _modifiers:
		var modifier: Dictionary = _modifiers[source]
		modifier["elapsed"] = float(modifier["elapsed"]) + delta
		if _is_expired(modifier):
			expired.append(source)
	for source: StringName in expired:
		_modifiers.erase(source)
	if not was_lifted:
		_apply_decay(delta)


func _apply_decay(delta: float) -> void:
	if _base <= DECAY_FLOOR:
		return
	_base = maxf(DECAY_FLOOR, _base - DECAY_PER_SECOND * delta)


## The base meter, before modifier offsets.
func base_value() -> float:
	return _base


## The effective meter: the base plus every active modifier offset.
func value() -> float:
	return clampf(_base + modifier_total(), MINIMUM, MAXIMUM)


static func band_for_value(value_: float) -> String:
	if value_ >= 80.0:
		return "Happy"
	if value_ >= 50.0:
		return "Content"
	if value_ >= 25.0:
		return "Unhappy"
	return "Miserable"


func band() -> String:
	return band_for_value(value())


func tip_multiplier() -> float:
	match band():
		"Happy": return 1.5
		"Content": return 1.0
		"Unhappy": return 0.5
	return 0.0


func snapshot() -> Dictionary:
	var modifiers: Dictionary = {}
	for source: StringName in _modifiers:
		modifiers[source] = _contribution(_modifiers[source])
	return {
		"value": value(),
		"base_value": _base,
		"band": band(),
		"tip_multiplier": tip_multiplier(),
		"modifiers": modifiers,
		"modifier_total": modifier_total(),
		"rewarded_talk_partners": _rewarded_talk_partners.keys(),
		"events": _events.duplicate(true),
	}
