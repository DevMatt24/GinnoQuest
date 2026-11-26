extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)
@onready var attack_area: Area2D = $AttackArea
@export var max_health := 20
@export var speed := 70.0
@export var attack_damage := 2
@export var attack_range := 90.0
@export var attack_cooldown := 1.8
@export var attack_hit_point := 0.5     # en qué parte de "atacar" cae el golpe (0 a 1)
@export var faces_right := true
@export var coin_scene: PackedScene
@export var coin_value := 10

var health := 0
var direction := -1
var active := false
var busy := false          # rugiendo, atacando o herido
var can_attack := true
var is_dead := false
var start_position := Vector2.ZERO
var player: Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	start_position = global_position
	player = get_tree().get_first_node_in_group("player")
	_apply_flip()
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = 0.0

	if active and not busy and not is_dead and player and not player.get("is_dead"):
		var dx := player.global_position.x - global_position.x
		_set_direction(1 if dx > 0.0 else -1)
		if can_attack and _player_in_attack_area():
			_attack()
		elif absf(dx) > attack_range * 0.8:
			velocity.x = direction * speed

	move_and_slide()

	if not busy and not is_dead:
		var anim := "walk" if absf(velocity.x) > 1.0 else "idle"
		if sprite.animation != anim:
			sprite.play(anim)

func _set_direction(d: int) -> void:
	if d == direction:
		return
	direction = d
	_apply_flip()

func _apply_flip() -> void:
	sprite.flip_h = (direction < 0) if faces_right else (direction > 0)
	attack_area.scale.x = direction if faces_right else -direction
func _anim_time(anim: String) -> float:
	var f := sprite.sprite_frames
	return f.get_frame_count(anim) / f.get_animation_speed(anim)

# Lo llama el nivel al entrar a la arena
func activate() -> void:
	if active or is_dead:
		return
	active = true
	busy = true
	sprite.play("roar")
	await get_tree().create_timer(_anim_time("roar")).timeout
	busy = false

# Si el jugador muere durante la pelea, el jefe vuelve a su lugar
func reset() -> void:
	if is_dead:
		return
	active = false
	busy = false
	can_attack = true
	health = max_health
	health_changed.emit(health, max_health)
	global_position = start_position
	velocity = Vector2.ZERO
	sprite.play("idle")

func _attack() -> void:
	busy = true
	can_attack = false
	sprite.play("atacar")
	var duration := _anim_time("atacar")

	await get_tree().create_timer(duration * attack_hit_point).timeout
	if is_dead or not active:
		return
	# Golpea a quien esté dentro del área en este momento
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("player"):
			b.take_damage(attack_damage, global_position.x)

	await get_tree().create_timer(duration * (1.0 - attack_hit_point)).timeout
	busy = false

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, _source_x: float) -> void:
	if is_dead or not active:
		return   # no recibe daño mientras ruge al empezar
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)

	var t := create_tween()
	sprite.modulate = Color(1.0, 0.4, 0.4)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	if health == 0:
		_die()
		return

	# Si está atacando no se interrumpe; si no, reacciona al golpe
	if not busy:
		busy = true
		sprite.play("hurt")
		await get_tree().create_timer(minf(_anim_time("hurt"), 0.5)).timeout
		busy = false

func _die() -> void:
	is_dead = true
	active = false
	busy = true
	sprite.play("dead")
	died.emit()
	_drop_coin()
	await get_tree().create_timer(_anim_time("dead") + 0.8).timeout
	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)

func _drop_coin() -> void:
	if coin_scene == null:
		return
	var coin := coin_scene.instantiate()
	coin.value = coin_value
	coin.scale = Vector2(2, 2)
	coin.global_position = global_position + Vector2(0, -16)
	get_parent().call_deferred("add_child", coin)
func _player_in_attack_area() -> bool:
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false
