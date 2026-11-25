extends RigidBody2D

@export var fuse_time := 1.6
@export var damage := 2            # daño al jugador
@export var enemy_damage := 3      # daño a enemigos (si la desvías, los mata)
@export var deflect_speed := Vector2(380.0, -260.0)

var exploded := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var explosion: AnimatedSprite2D = $Explosion
@onready var blast_area: Area2D = $BlastArea

func _ready() -> void:
	explosion.hide()
	sprite.play("fuse")
	await get_tree().create_timer(fuse_time).timeout
	_explode()

# Lo llama el ataque del jugador (mismo método que usan los enemigos)
func take_damage(_amount: int, source_x: float) -> void:
	if exploded:
		return
	var dir := signf(global_position.x - source_x)
	if dir == 0.0:
		dir = 1.0
	linear_velocity = Vector2(dir * deflect_speed.x, deflect_speed.y)
	angular_velocity = dir * 10.0

	var t := create_tween()
	sprite.modulate = Color(1.5, 1.5, 1.5)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _explode() -> void:
	if exploded:
		return
	exploded = true
	set_deferred("freeze", true)
	sprite.hide()
	explosion.global_rotation = 0.0   # por si la TNT venía girando
	explosion.show()
	explosion.play("explode")

	for body in blast_area.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var amount := damage if body.is_in_group("player") else enemy_damage
		body.take_damage(amount, global_position.x)

	await explosion.animation_finished
	queue_free()
