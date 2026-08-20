class_name PatronSuspicion
extends RefCounted

const QUIET_PERIOD_SECONDS := 20.0
const RECOVERY_INTERVAL_SECONDS := 10.0
const RECOVERY_AMOUNT := 5.0
const HARD_EVIDENCE_STIMULI: Array[StringName] = [
	&"drink_dosed_seen",
	&"knockout_witnessed",
	&"trapdoor_capture_witnessed",
	&"trapdoor_open_seen_seated",
]

var _score: float = 0.0
var _cause: StringName = &"none"
var _latest_stimulus: StringName = &"none"
var _recoverable: bool = false
var _quiet_seconds: float = 0.0
var _recovery_ticks_applied: int = 0
var _maximum_response: StringName = &"none"
var _hard_evidence_downgrade_count: int = 0


func apply_stimulus(stimulus: StringName, observer_is_max_drunk: bool = false) -> bool:
	if stimulus in HARD_EVIDENCE_STIMULI:
		if observer_is_max_drunk and _score < 100.0:
			_score = minf(100.0, _score + 25.0)
			_cause = &"soft"
			_latest_stimulus = stimulus
			_recoverable = _score < 100.0
			_quiet_seconds = 0.0
			_recovery_ticks_applied = 0
			_hard_evidence_downgrade_count += 1
			if _score >= 100.0:
				_maximum_response = &"escape"
			return true
		_score = 100.0
		_cause = &"hard_evidence"
		_latest_stimulus = stimulus
		_recoverable = false
		_quiet_seconds = 0.0
		_recovery_ticks_applied = 0
		_maximum_response = &"escape"
		return true
	if stimulus == &"missing_companion_40" and _score < 100.0:
		_score = 100.0
		_cause = &"missing_companion"
		_latest_stimulus = stimulus
		_recoverable = false
		_quiet_seconds = 0.0
		_recovery_ticks_applied = 0
		_maximum_response = &"investigation"
		return true
	var effect := _stimulus_effect(stimulus)
	if effect.is_empty() or _score >= 100.0:
		return false
	_score = minf(100.0, _score + float(effect["amount"]))
	_cause = effect["cause"]
	_latest_stimulus = stimulus
	_recoverable = bool(effect["recoverable"])
	_quiet_seconds = 0.0
	_recovery_ticks_applied = 0
	if _score >= 100.0:
		_recoverable = false
		_maximum_response = &"investigation" if _cause == &"missing_companion" else &"escape"
	return true


# Gradual Companion influence: drift up toward a nearby group member's higher
# Suspicion by at most RECOVERY_AMOUNT, upward only, stopping on equality.
# Reaching 100 this way selects Escape rather than Investigation.
func apply_companion_influence(neighbor_score: float) -> bool:
	if _score >= 100.0 or neighbor_score <= _score:
		return false
	var delta := minf(RECOVERY_AMOUNT, neighbor_score - _score)
	_score = minf(100.0, _score + delta)
	_cause = &"companion_influence"
	_latest_stimulus = &"companion_influence"
	_recoverable = _score < 100.0
	_quiet_seconds = 0.0
	_recovery_ticks_applied = 0
	if _score >= 100.0:
		_maximum_response = &"escape"
	return true


func advance(simulated_seconds: float) -> float:
	if simulated_seconds <= 0.0 or not _recoverable or _score <= 0.0 or _score >= 100.0:
		return 0.0
	_quiet_seconds += simulated_seconds
	var recoverable_seconds := maxf(0.0, _quiet_seconds - QUIET_PERIOD_SECONDS)
	var earned_ticks := int(floor((recoverable_seconds + 0.0001) / RECOVERY_INTERVAL_SECONDS))
	var new_ticks := maxi(0, earned_ticks - _recovery_ticks_applied)
	if new_ticks == 0:
		return 0.0
	var before := _score
	_score = maxf(0.0, _score - float(new_ticks) * RECOVERY_AMOUNT)
	_recovery_ticks_applied += new_ticks
	if _score <= 0.0:
		_cause = &"none"
		_recoverable = false
	return before - _score


func normal_band() -> String:
	if _score >= 100.0:
		return "Maximum"
	if _score >= 75.0:
		return "Alarmed"
	if _score >= 50.0:
		return "Suspicious"
	if _score >= 25.0:
		return "Uneasy"
	return "Calm"


func normal_cue() -> String:
	if _score <= 0.0:
		return "No concern"
	if _cause == &"hard_evidence":
		return "Hard Evidence"
	if _cause == &"missing_companion":
		return "Missing Companion"
	if _cause == &"companion_influence":
		return "Nervous Company"
	match _latest_stimulus:
		&"cancelled_order":
			return "Cancelled Order"
		&"trapdoor_heard":
			return "Heard Trapdoor"
		&"knockout_heard":
			return "Heard Knockout"
		&"unexplained_collapse_seen":
			return "Saw Collapse"
		&"rescue_persuasion_failed":
			return "Failed Persuasion"
		&"body_drag_seen_first", &"body_drag_seen_continuing":
			return "Saw Body Drag"
		&"unattended_body_pressure":
			return "Unattended Body"
		&"drink_dosed_seen", &"knockout_witnessed", &"trapdoor_capture_witnessed", &"trapdoor_open_seen_seated":
			return "Hard Evidence"
	return "No concern"


func next_recovery_in() -> float:
	if not _recoverable or _score <= 0.0 or _score >= 100.0:
		return -1.0
	var next_tick_at := QUIET_PERIOD_SECONDS + float(_recovery_ticks_applied + 1) * RECOVERY_INTERVAL_SECONDS
	return maxf(0.0, next_tick_at - _quiet_seconds)


func _stimulus_effect(stimulus: StringName) -> Dictionary:
	match stimulus:
		&"cancelled_order":
			return {"amount": 15.0, "cause": &"soft", "recoverable": true}
		&"trapdoor_heard":
			return {"amount": 10.0, "cause": &"general_danger", "recoverable": true}
		&"knockout_heard":
			return {"amount": 25.0, "cause": &"general_danger", "recoverable": true}
		&"unexplained_collapse_seen":
			return {"amount": 10.0, "cause": &"general_danger", "recoverable": true}
		&"rescue_persuasion_failed":
			return {"amount": 25.0, "cause": &"general_danger", "recoverable": true}
		&"body_drag_seen_first":
			return {"amount": 50.0, "cause": &"general_danger", "recoverable": true}
		&"body_drag_seen_continuing":
			return {"amount": 10.0, "cause": &"general_danger", "recoverable": true}
		&"unattended_body_pressure":
			return {"amount": 5.0, "cause": &"general_danger", "recoverable": true}
		&"missing_companion_20", &"missing_companion_30":
			return {"amount": 25.0, "cause": &"missing_companion", "recoverable": false}
	return {}


func snapshot() -> Dictionary:
	return {
		"score": _score,
		"cause": _cause,
		"latest_stimulus": _latest_stimulus,
		"recoverable": _recoverable,
		"quiet_seconds": _quiet_seconds,
		"next_recovery_in": next_recovery_in(),
		"maximum_response": _maximum_response,
		"hard_evidence_downgrade_count": _hard_evidence_downgrade_count,
	}
