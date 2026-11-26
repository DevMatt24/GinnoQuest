extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -430.0
@onready var cam: Camera2D = $Camera2D
var bounds := Rect2()  # área permitida; vacía = sin límites
@onready var walk_sound: AudioStreamPlayer2D = $WalkSound
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_particles_right: CPUParticles2D = $Particles/JumpParticlesRight
@onready var jump_particles_left: CPUParticles2D = $Particles/JumpParticlesLeft
@onready var land_particles_left: CPUParticles2D = $Particles/LandParticlesLeft
@onready var land_particles_right: CPUParticles2D = $Particles/LandParticlesRight
@onready var attack_area: Area2D = $AttackArea

@export var start_shield := 5
@export var start_shield_defense := 1
signal coins_changed(total: int)
var shield_level := 0
var shield: int = 0
var shield_defense: int = 0

signal shield_changed(current: int)

var is_defending := false

var respawn_position := Vector2.ZERO
var is_respawning := false

var coins := 0
const SAFE_FALL_SPEED := 650.0    # hasta acá no hay daño
const DEADLY_FALL_SPEED := 1000.0 # desde acá, el daño máximo
const FALL_DAMAGE_MIN := 1
const FALL_DAMAGE_MAX := 3
var is_attacking := false
signal health_changed(current: int, maximum: int)
signal died
var hit_bodies: Array = []
const MAX_HEALTH := 6
const KNOCKBACK := Vector2(250.0, -250.0)

var camera_target_y := 0.0
const VOID_Y := 800.0 
var health := MAX_HEALTH
var is_dead := false
var is_hurt := false
var invulnerable := false 
var was_on_floor := true
const half_width := 17 # ajustalo al ancho de tu CollisionShape2D / 2
func _ready() -> void:
	shield = start_shield
	shield_defense = start_shield_defense
	shield_changed.emit(shield)
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	respawn_position = global_position 
	walk_sound.volume_db = -45
	attack_area.area_entered.connect(_on_attack_area_area_entered)

func _physics_process(delta: float) -> void:
	if global_position.y > VOID_Y:
		fall_into_void(1)
	if is_respawning:
		return
	if is_dead:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	# Defensa: mantener la tecla, en el suelo, con escudo disponible
	is_defending = Input.is_action_pressed("defend") \
		and shield > 0 and is_on_floor() \
		and not is_attacking and not is_hurt
	# 1. Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Salto
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_defending:
		velocity.y = JUMP_VELOCITY
		jump_particles_left.restart()
		jump_particles_right.restart()
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_hurt and not is_defending:
		_attack()
	# 3. Movimiento lateral
	var direction := 0.0 if is_defending else Input.get_axis("left", "right")
	if not is_hurt:
		velocity.x = direction * SPEED

	# 4. Mover y detectar aterrizaje
	var fall_speed := velocity.y   # se guarda ANTES de move_and_slide()
	move_and_slide()
	if bounds.has_area():
		var clamped_x := clampf(global_position.x, bounds.position.x + half_width, bounds.end.x - half_width)
		if clamped_x != global_position.x:
			global_position.x = clamped_x
			velocity.x = 0.0
	if is_on_floor() and not was_on_floor and fall_speed > 150.0:
		land_particles_left.restart()
		land_particles_right.restart()
		_check_fall_damage(fall_speed)
	was_on_floor = is_on_floor()

	# 5. Orientación y animaciones
	_update_character(direction)
	_update_walk_sound(direction)
	_update_camera_look(delta)
	_update_camera_follow(delta)


func _update_character(direction: float) -> void:
	if is_dead:
		return
	if is_hurt:
		animated_sprite.play("hurt")
		return
	if is_attacking:
		return
	if is_defending:
		if animated_sprite.animation != "defend":
			animated_sprite.play("defend")
		return
	if direction != 0.0:
		animated_sprite.flip_h = direction < 0.0

	if not is_on_floor():
		animated_sprite.play("jump")
	elif direction != 0.0:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

func _update_walk_sound(direction: float) -> void:
	var walking := direction != 0.0 and is_on_floor()

	if walking:
		if not walk_sound.playing:
			walk_sound.play()
	else:
		if walk_sound.playing:
			walk_sound.stop()


func take_damage(amount: int, source_x: float) -> void:
	if invulnerable or is_dead:
		return

	# Solo bloquea si defiende y el golpe viene de frente
	var facing := -1.0 if animated_sprite.flip_h else 1.0
	var from_front := signf(source_x - global_position.x) == facing
	if is_defending and from_front and shield > 0 and amount > 0:
		_block_hit(amount, source_x)
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)

	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)

	if health == 0:
		_die()
		return

	# Retroceso
	var push := signf(global_position.x - source_x)
	velocity = Vector2(push * KNOCKBACK.x, KNOCKBACK.y)
	is_hurt = true
	invulnerable = true

	var tween := create_tween().set_loops(5)
	tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.1)
	tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)

	await get_tree().create_timer(0.3).timeout
	is_hurt = false
	await get_tree().create_timer(0.7).timeout
	invulnerable = false
	animated_sprite.modulate.a = 1.0

func _die() -> void:
	is_dead = true
	velocity.x = 0.0
	animated_sprite.play("death")
	died.emit()


func _attack() -> void:
	is_attacking = true
	hit_bodies.clear()
	attack_area.scale.x = -1.0 if animated_sprite.flip_h else 1.0
	animated_sprite.play("attack")
	attack_area.set_deferred("monitoring", true)

	await get_tree().create_timer(0.15).timeout
	attack_area.set_deferred("monitoring", false)

	await get_tree().create_timer(0.15).timeout
	is_attacking = false


func _on_attack_area_body_entered(body: Node2D) -> void:
	if not is_attacking or body in hit_bodies:
		return

	if body.has_method("take_damage"):
		hit_bodies.append(body)
		body.take_damage(attack_damage, global_position.x)
func _on_health_changed(current: int, maximum: int) -> void:
	pass # Replace with function body.

var coins_collected := 0

func add_coins(amount: int) -> void:
	coins += amount
	coins_collected += amount
	coins_changed.emit(coins)
func _update_camera_look(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var target_y := -60.0
	if velocity.y < -50.0:      # subiendo
		target_y = -110.0
	elif velocity.y > 50.0:     # cayendo
		target_y = -20.0
	cam.offset.y = lerpf(cam.offset.y, target_y, 2.0 * delta)

func _update_camera_follow(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if is_on_floor():
		camera_target_y = global_position.y
	# Si cae por debajo de la altura guardada (se cae a un pozo), la sigue igual
	camera_target_y = minf(camera_target_y, global_position.y + 120.0)
	cam.global_position.y = lerpf(cam.global_position.y, camera_target_y, 2.5 * delta)


var attack_damage := 1
var weapon_level := 0

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func heal(amount: int) -> void:
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _check_fall_damage(fall_speed: float) -> void:
	if fall_speed <= SAFE_FALL_SPEED:
		return
	var t := inverse_lerp(SAFE_FALL_SPEED, DEADLY_FALL_SPEED, fall_speed)
	var damage := roundi(lerpf(FALL_DAMAGE_MIN, FALL_DAMAGE_MAX, clampf(t, 0.0, 1.0)))
	_take_fall_damage(damage)

func _take_fall_damage(amount: int) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_die()
		return

	# Aturdimiento breve, sin retroceso lateral
	is_hurt = true
	var tween := create_tween().set_loops(3)
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.4, 0.4), 0.08)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)
	await get_tree().create_timer(0.4).timeout
	is_hurt = false

func fall_into_void(damage := 1) -> void:
	if is_dead or is_respawning:
		return
	is_respawning = true
	velocity = Vector2.ZERO

	health = maxi(health - damage, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		is_respawning = false
		_die()
		return

	# Fundido, teletransporte y vuelta
	var t := create_tween()
	t.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
	await t.finished

	global_position = respawn_position
	velocity = Vector2.ZERO
	was_on_floor = true   # evita partículas y daño de caída falsos

	invulnerable = true
	var t2 := create_tween()
	t2.tween_property(animated_sprite, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(1.0).timeout
	invulnerable = false
	is_respawning = false
func _on_attack_area_area_entered(area: Area2D) -> void:
	if not is_attacking:
		return
	var target := area.get_parent()
	if target in hit_bodies:
		return
	if target.has_method("take_damage"):
		hit_bodies.append(target)
		target.take_damage(attack_damage, global_position.x)

func upgrade_weapon(extra_damage: int) -> void:
	upgrade_attack(extra_damage)


func upgrade_attack(amount: int) -> void:
	weapon_level += 1
	attack_damage += amount


func upgrade_shield(amount: int) -> void:
	shield += amount * 3
	shield_level += 1
	shield_defense += amount
	shield_changed.emit(shield)


func upgrade_shield_defense(amount: int) -> void:
	shield_defense += amount

func _block_hit(amount: int, source_x: float) -> void:
	var absorbed := mini(amount, maxi(shield_defense, 1))
	var remaining := amount - absorbed
	shield -= 1
	shield_changed.emit(shield)

	# Pequeño empujón hacia atrás y destello azul
	var push := signf(global_position.x - source_x)
	velocity.x = push * 120.0
	var t := create_tween()
	animated_sprite.modulate = Color(0.6, 0.8, 1.6)
	t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

	# Breve invulnerabilidad para que una explosión no pegue dos veces
	invulnerable = true
	get_tree().create_timer(0.3).timeout.connect(func(): invulnerable = false)

	# Si el escudo no absorbió todo, el resto sí hace daño
	if remaining > 0:
		invulnerable = false
		take_damage_unblocked(remaining)

	if shield <= 0:
		_break_shield()

func take_damage_unblocked(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_die()

func _break_shield() -> void:
	shield = 0
	shield_defense = 0
	is_defending = false
	shield_changed.emit(shield)
	# Destello rojo de "se rompió"
	var t := create_tween()
	animated_sprite.modulate = Color(1.6, 0.4, 0.4)
	t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.4)

func respawn() -> void:
	is_dead = false
	is_hurt = false
	is_attacking = false
	is_respawning = false
	invulnerable = true

	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

	global_position = respawn_position
	velocity = Vector2.ZERO
	was_on_floor = true
	animated_sprite.modulate.a = 1.0
	animated_sprite.play("idle")

	await get_tree().create_timer(1.5).timeout
	invulnerable = false
