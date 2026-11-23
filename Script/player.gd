extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -470.0

var bounds := Rect2()  # área permitida; vacía = sin límites
@onready var walk_sound: AudioStreamPlayer2D = $WalkSound
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_particles_right: CPUParticles2D = $Particles/JumpParticlesRight
@onready var jump_particles_left: CPUParticles2D = $Particles/JumpParticlesLeft
@onready var land_particles_left: CPUParticles2D = $Particles/LandParticlesLeft
@onready var land_particles_right: CPUParticles2D = $Particles/LandParticlesRight

var was_on_floor := true
const half_width := 17 # ajustalo al ancho de tu CollisionShape2D / 2
func _physics_process(delta: float) -> void:
	# 1. Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_particles_left.restart()
		jump_particles_right.restart()

	# 3. Movimiento lateral
	var direction := Input.get_axis("left", "right")
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
	was_on_floor = is_on_floor()

	# 5. Orientación y animaciones
	_update_character(direction)
	_update_walk_sound(direction)

func _update_character(direction: float) -> void:
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
