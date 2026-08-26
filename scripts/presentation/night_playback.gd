class_name NightPlayback
extends RefCounted

## The one owner of interactive playback state for a Night.
##
## NightPlayback holds the selected Simulation Speed, the Plain Pause toggle, the
## Pause Menu return state, and the Escape speed-lock synchronization. It turns
## player intent into requests against GameSession, which stays the only
## authority that accepts or rejects a time scale. The module never advances the
## Night and never reads a hidden Patron value; it only reflects what the
## authority accepted.
##
## Callers use four calls:
##
##   reset(session, initial_speed)   start a fresh Night at one running speed
##   submit(kind, payload)           report one piece of playback intent
##   synchronize()                   re-read the authority after it advanced
##   snapshot()                      a display-ready description of playback

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var _session = null
var _selected_speed: float = 1.0
var _plain_paused: bool = false
var _pause_menu_open: bool = false
var _pre_menu_time_scale: float = 1.0
var _pre_menu_plain_paused: bool = false
var _feedback: String = ""
var _feedback_serial: int = 0


## Starts a fresh Night. The interactive Night begins running at one speed, so a
## reset requests that speed from the authority right away.
func reset(session, initial_speed: float = 1.0) -> void:
	_session = session
	_selected_speed = initial_speed if initial_speed in SPEEDS else 1.0
	_plain_paused = false
	_pause_menu_open = false
	_pre_menu_time_scale = _selected_speed
	_pre_menu_plain_paused = false
	_feedback = ""
	_feedback_serial = 0
	if _session != null:
		_session.set_time_scale(_selected_speed)


## One entry point for playback intent. The result says whether the authority
## accepted the request and carries a display-ready reason when it did not, so no
## caller has to interpret a bare Boolean.
func submit(kind: StringName, payload: Dictionary = {}) -> Dictionary:
	# The Outcome Modal owns the screen at Results; every time request is refused
	# there, and the recorded playback state stays exactly as it was.
	if _session != null and _session.has_method("accepts_time_control") and (
		not _session.accepts_time_control()
	):
		return _refused(&"night_over", "")
	match kind:
		&"select_speed":
			return _select_speed(float(payload.get("value", _selected_speed)))
		&"toggle_plain_pause":
			return _toggle_plain_pause()
		&"open_pause_menu":
			return _open_pause_menu()
		&"dismiss_pause_menu":
			return _dismiss_pause_menu()
		&"resume_from_pause_menu":
			return _resume_from_pause_menu()
	return _refused(&"unknown_request", "")


## Re-reads the authority after the simulation changed the scale by itself. The
## only such change is an Escape forcing 1x; when that happens the selected speed
## drops to 1x so the HUD cannot keep a disabled speed pressed.
func synchronize() -> Dictionary:
	if _session == null:
		return snapshot()
	var available: Array = _available_scales()
	if not _speed_available(_selected_speed, available) and not is_equal_approx(
		_selected_speed, 1.0
	):
		_selected_speed = 1.0
	if _current_scale() > 0.0:
		_plain_paused = false
	return snapshot()


## A display-ready description of playback. It carries presentation state only.
func snapshot() -> Dictionary:
	var available: Array = _available_scales()
	return {
		"selected_speed": _selected_speed,
		"time_scale": _current_scale(),
		"plain_paused": _plain_paused,
		"pause_menu_open": _pause_menu_open,
		"speed_enabled": {
			1.0: _speed_available(1.0, available),
			2.0: _speed_available(2.0, available),
			4.0: _speed_available(4.0, available),
		},
		"speed_lock_reason": _lock_reason(),
		"feedback": _feedback,
		"feedback_serial": _feedback_serial,
	}


# --- Transitions -------------------------------------------------------------

func _select_speed(value: float) -> Dictionary:
	# Space and speed shortcuts do nothing while the Pause Menu blocks the Night.
	if _pause_menu_open:
		return _refused(&"pause_menu_open", "")
	if value not in SPEEDS:
		return _refused(&"unsupported_speed", "That speed is not available.")
	# Selecting the speed the Night already runs at is an accepted no-op, so the
	# button never flickers off and back on.
	if _current_scale() > 0.0 and is_equal_approx(_current_scale(), value) and is_equal_approx(
		_selected_speed, value
	):
		return _accepted()
	if _session.set_time_scale(value):
		_selected_speed = value
		_plain_paused = false
		return _accepted()
	return _refused(&"speed_locked", "%dx is not available right now." % int(value))


func _toggle_plain_pause() -> Dictionary:
	if _pause_menu_open:
		return _refused(&"pause_menu_open", "")
	if _current_scale() > 0.0:
		if _session.set_time_scale(0.0):
			_plain_paused = true
			return _accepted()
		return _refused(&"cannot_pause", "The Night cannot pause right now.")
	if _session.set_time_scale(_selected_speed):
		_plain_paused = false
		return _accepted()
	return _refused(&"cannot_resume", "The Night cannot resume right now.")


func _open_pause_menu() -> Dictionary:
	if _pause_menu_open:
		return _accepted()
	_pre_menu_time_scale = _current_scale()
	_pre_menu_plain_paused = _plain_paused
	_pause_menu_open = true
	_session.set_time_scale(0.0)
	return _accepted()


func _dismiss_pause_menu() -> Dictionary:
	if not _pause_menu_open:
		return _refused(&"pause_menu_closed", "")
	_pause_menu_open = false
	_plain_paused = _pre_menu_plain_paused
	_session.set_time_scale(_pre_menu_time_scale)
	return _accepted()


func _resume_from_pause_menu() -> Dictionary:
	_pause_menu_open = false
	_plain_paused = false
	_session.set_time_scale(_selected_speed)
	return _accepted()


# --- Helpers -----------------------------------------------------------------

func _current_scale() -> float:
	if _session == null:
		return 0.0
	return _session.current_time_scale()


func _available_scales() -> Array:
	if _session != null and _session.has_method("time_control"):
		return _session.time_control()["available_scales"]
	return SUPPORTED_SCALES_FALLBACK


func _lock_reason() -> StringName:
	if _session != null and _session.has_method("time_control"):
		return StringName(_session.time_control()["lock_reason"])
	return &""


func _speed_available(value: float, available: Array) -> bool:
	for scale: float in available:
		if is_equal_approx(scale, value):
			return true
	return false


func _accepted() -> Dictionary:
	return {"accepted": true, "reason": &"", "feedback": _feedback}


func _refused(reason: StringName, feedback_text: String) -> Dictionary:
	if not feedback_text.is_empty():
		_feedback = feedback_text
		_feedback_serial += 1
	return {"accepted": false, "reason": reason, "feedback": feedback_text}


const SUPPORTED_SCALES_FALLBACK: Array = [0.0, 1.0, 2.0, 4.0]
