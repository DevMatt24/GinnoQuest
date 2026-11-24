@tool
extends AnimatableBody2D

enum Direction { HORIZONTAL, VERTICAL }

@export var direction: Direction = Direction.HORIZONTAL:
	set(value):
		direction = value
		queue_redraw()
@export var distance := 200.0:
	set(value):
		distance = value
		queue_redraw()
@export var speed := 80.0
@export var wait_time := 0.5
@export var smooth := true   # frena y acelera suave en los extremos
@export var start_reversed := false   # arranca yendo hacia el lado contrario

func _get_offset() -> Vector2:
	return Vector2(distance, 0.0) if direction == Direction.HORIZONTAL else Vector2(0.0, distance)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var origin := global_position
	var target := origin + _get_offset()
	if start_reversed:
		var tmp := origin
		origin = target
		target = tmp
		global_position = origin
	_start_loop(origin, target)

func _start_loop(a: Vector2, b: Vector2) -> void:
	var duration := maxf(a.distance_to(b) / speed, 0.01)
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	var trans := Tween.TRANS_SINE if smooth else Tween.TRANS_LINEAR
	tween.tween_property(self, "global_position", b, duration).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
	tween.tween_property(self, "global_position", a, duration).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)

# Dibuja el recorrido en el editor (solo se ve ahí, no en el juego)
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var offset := _get_offset()
	draw_line(Vector2.ZERO, offset, Color(1, 0.9, 0.2, 0.8), 2.0)
	draw_circle(offset, 5.0, Color(1, 0.9, 0.2, 0.8))
