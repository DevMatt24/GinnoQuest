class_name Enemy
extends CharacterBody2D

const SPEED := 60.0
signal died
@export var frames: SpriteFrames
@export var faces_right := true
@export var max_health := 3
@export var attack_damage := 1
@export var attack_cooldown := 1.0
@export var coin_scene: PackedScene = preload("res://Scene/coin.tscn")   # ajustá la ruta
@export var coin_value := 2
@export var attack_hit_point := 0.5 
var health := 0
var direction := 1
var is_dead := false
var is_attacking := false
var can_attack := true
var stun_time := 0.0
const DETECT_RANGE := 180.0   # a qué distancia te ve
const STOP_DISTANCE := 34.0   # a qué distancia se frena frente a vos
const CHASE_SPEED := 70.0

var player: Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_ray: RayCast2D = $FloorRay
@onready var damage_area: Area2D = $DamageArea

func _ready() -> void:
	add_to_group("enemy")
	if frames:
		sprite.sprite_frames = frames
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	sprite.flip_h = direction < 0
	floor_ray.position.x = absf(floor_ray.position.x) * direction
	sprite.play("walk")
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0.0
		move_and_slide()
		return

	if stun_time > 0.0:
		# Retroceso por golpe
		stun_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	elif is_attacking:
		velocity.x = 0.0
	else:
		if _player_in_sight():
			_chase()
		else:
			_patrol()

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	if is_dead or is_attacking:
		return
	if stun_time > 0.0 or absf(velocity.x) < 1.0:
		sprite.play("idle")
	else:
		sprite.play("walk")

func _turn() -> void:
	direction *= -1
	sprite.flip_h = direction < 0   # invertí el > si tu sprite mira al otro lado
	floor_ray.position.x = absf(floor_ray.position.x) * direction
	floor_ray.force_raycast_update()

func _check_attack() -> void:
	if not can_attack:
		return
	var dx := player.global_position.x - global_position.x
	if signf(dx) != float(direction):
		return
	for body in damage_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			_attack(body)
			return
func _attack(target: Node2D) -> void:
	is_attacking = true
	can_attack = false
	sprite.play("attack1")

	# El daño cae a mitad de la animación
	var frames := sprite.sprite_frames
	var duration := frames.get_frame_count("attack1") / frames.get_animation_speed("attack1")
	await get_tree().create_timer(duration * 0.5).timeout

	if not is_dead and is_instance_valid(target) and damage_area.overlaps_body(target):
		target.take_damage(attack_damage, global_position.x)

	await get_tree().create_timer(duration * 0.5).timeout
	is_attacking = false

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, source_x: float) -> void:
	if is_dead:
		return
	health -= amount

	var push := signf(global_position.x - source_x)
	velocity = Vector2(push * 200.0, -150.0)
	stun_time = 0.25
	is_attacking = false   # un golpe interrumpe su ataque

	var tween := create_tween()
	sprite.modulate = Color(1, 0.3, 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit()
	damage_area.set_deferred("monitoring", false)
	_drop_coin()
	sprite.play("dead")
	await sprite.animation_finished
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
func _player_in_sight() -> bool:
	if player == null or player.get("is_dead"):
		return false
	var d := player.global_position - global_position
	return absf(d.x) < DETECT_RANGE and absf(d.y) < 40.0

func _patrol() -> void:
	if is_on_wall() or not floor_ray.is_colliding():
		_set_direction(-direction)
	velocity.x = direction * SPEED

func _chase() -> void:
	var dx := player.global_position.x - global_position.x
	if dx != 0.0:
		_set_direction(1 if dx > 0.0 else -1)   # siempre te mira de frente

	if absf(dx) > STOP_DISTANCE and floor_ray.is_colliding() and not is_on_wall():
		velocity.x = direction * CHASE_SPEED
	else:
		velocity.x = 0.0   # se planta frente a vos
	_check_attack()

func _set_direction(new_dir: int) -> void:
	if new_dir == direction:
		return
	direction = new_dir
	sprite.flip_h = direction < 0   # sprite mira a la derecha por defecto
	floor_ray.position.x = absf(floor_ray.position.x) * direction
	damage_area.scale.x = direction
	floor_ray.force_raycast_update()
	

@export var coin_scale := 2.0
func _drop_coin() -> void:
	if coin_scene == null:
		return
	var coin := coin_scene.instantiate()
	coin.value = coin_value
	coin.scale = Vector2(coin_scale, coin_scale)
	coin.global_position = global_position + Vector2(0, -8)
	get_parent().call_deferred("add_child", coin)
	var start := global_position + Vector2(0, -8)
	coin.position = start
	get_parent().call_deferred("add_child", coin)

	var tween := create_tween()
	tween.tween_property(coin, "position:y", start.y - 24.0, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(coin, "position:y", start.y + 8.0, 0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
