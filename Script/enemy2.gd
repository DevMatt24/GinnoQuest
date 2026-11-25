class_name Thrower
extends Enemy
@export var tnt_scene: PackedScene
@export var throw_range := 360.0
@export var flight_time := 0.9     # cuánto tarda la TNT en llegar
@export var throw_offset := Vector2(16.0, -24.0)

func _player_in_sight() -> bool:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("is_dead"):
		return false
	var d := player.global_position - global_position
	return absf(d.x) < throw_range and absf(d.y) < 120.0

# Reemplaza la persecución: se planta a distancia y lanza
func _chase() -> void:
	var dx := player.global_position.x - global_position.x
	if dx != 0.0:
		_set_direction(1 if dx > 0.0 else -1)
	velocity.x = 0.0
	if can_attack:
		_throw()

func _throw() -> void:
	is_attacking = true
	can_attack = false
	sprite.play("attack1")

	var frames := sprite.sprite_frames
	var duration := frames.get_frame_count("attack1") / frames.get_animation_speed("attack1")

	await get_tree().create_timer(duration * attack_hit_point).timeout
	if is_dead:
		return
	_spawn_tnt()

	await get_tree().create_timer(duration * (1.0 - attack_hit_point)).timeout
	is_attacking = false

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _spawn_tnt() -> void:
	if tnt_scene == null or player == null:
		return
	var tnt: RigidBody2D = tnt_scene.instantiate()
	get_parent().add_child(tnt)
	tnt.global_position = global_position + Vector2(throw_offset.x * direction, throw_offset.y)

	# Velocidad inicial para que la TNT caiga cerca del jugador (tiro parabólico)
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity") * tnt.gravity_scale
	var delta_pos := player.global_position - tnt.global_position
	var vx := clampf(delta_pos.x / flight_time, -450.0, 450.0)
	var vy := (delta_pos.y - 0.5 * g * flight_time * flight_time) / flight_time
	tnt.linear_velocity = Vector2(vx, vy)
	tnt.angular_velocity = direction * 6.0
