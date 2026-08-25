class_name NightClock
extends Control

## The analog Night Clock face.
##
## One control draws the whole clock: bezel, dial, all twelve numerals, the two
## hands, and the centre pin. Nothing outside this module positions a numeral,
## so the face keeps its proportions at every HUD size.
##
## The module owns no time rule. It is given a clock-face reading in minutes
## past midnight and draws it.

const BEZEL_COLOR := Color("4D2D18")
const BRASS_COLOR := Color("A8793E")
const FACE_COLOR := Color("EAD8A8")
const FACE_SHADE_COLOR := Color("BFA775")
const INK_COLOR := Color("352416")
const PIN_COLOR := Color("A14C3E")

var _clock_minutes := 20.0 * 60.0


## The clock-face reading, in minutes past midnight. 20 * 60 is 8:00 PM.
func set_clock_minutes(value: float) -> void:
	if is_equal_approx(_clock_minutes, value):
		return
	_clock_minutes = value
	queue_redraw()


func clock_minutes() -> float:
	return _clock_minutes


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	if radius <= 4.0:
		return
	var center := size * 0.5
	draw_circle(center, radius, BEZEL_COLOR)
	draw_circle(center, radius * 0.93, BRASS_COLOR)
	draw_circle(center, radius * 0.86, FACE_SHADE_COLOR)
	draw_circle(center, radius * 0.83, FACE_COLOR)
	_draw_numerals(center, radius)
	_draw_hands(center, radius)
	draw_circle(center, maxf(3.0, radius * 0.08), PIN_COLOR)


# Twelve numerals on one ring. The font size follows the radius so every numeral
# stays readable when the HUD scales.
func _draw_numerals(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := int(maxf(10.0, radius * 0.28))
	for hour in range(1, 13):
		var angle := deg_to_rad(float(hour) * 30.0 - 90.0)
		var anchor := center + Vector2(cos(angle), sin(angle)) * radius * 0.65
		var text := str(hour)
		var text_size := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
		)
		draw_string(
			font,
			anchor + Vector2(-text_size.x * 0.5, font_size * 0.36),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			INK_COLOR
		)


func _draw_hands(center: Vector2, radius: float) -> void:
	var minutes := fposmod(_clock_minutes, 720.0)
	var hour_angle := deg_to_rad(minutes * 0.5 - 90.0)
	var minute_angle := deg_to_rad(fposmod(minutes, 60.0) * 6.0 - 90.0)
	draw_line(
		center,
		center + Vector2(cos(hour_angle), sin(hour_angle)) * radius * 0.42,
		INK_COLOR,
		maxf(2.5, radius * 0.065)
	)
	draw_line(
		center,
		center + Vector2(cos(minute_angle), sin(minute_angle)) * radius * 0.62,
		INK_COLOR,
		maxf(2.0, radius * 0.045)
	)
