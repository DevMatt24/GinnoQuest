extends Area2D

signal activated

@export var spawn_offset := Vector2.ZERO
@export var glow_color := Color(1.0, 0.85, 0.3)
@export var label_text := "¡Punto guardado!"

var is_active := false
var idle_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound: AudioStreamPlayer = get_node_or_null("ActivateSound")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_set_inactive_look()

# Apagado: gris oscuro y animación casi detenida
func _set_inactive_look() -> void:
	sprite.play()
	sprite.speed_scale = 0.0
	sprite.frame = 0
	sprite.modulate = Color(0.45, 0.45, 0.5)

func _on_body_entered(body: Node2D) -> void:
	if is_active or not body.is_in_group("player"):
		return
	is_active = true
	set_deferred("monitoring", false)

	body.respawn_position = global_position + spawn_offset
	activated.emit()

	if sound and sound.stream:
		sound.play()

	_play_activation()

func _play_activation() -> void:
	# 1. Se enciende: color normal, anima y rebota
	sprite.speed_scale = 1.0
	var t := create_tween()
	sprite.modulate = Color(2.0, 1.8, 1.2)               # destello
	t.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	var bounce := create_tween()
	bounce.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.1)
	bounce.tween_property(sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Anillo de luz que se expande
	_spawn_ring()

	# 3. Chispas
	_spawn_sparks()

	# 4. Cartel flotante
	_spawn_label()

	# 5. Brillo suave permanente
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(sprite, "modulate", Color(1.15, 1.1, 0.95), 1.0)
	idle_tween.tween_property(sprite, "modulate", Color.WHITE, 1.0)

func _spawn_ring() -> void:
	var ring := Node2D.new()
	ring.z_index = 50
	ring.position = Vector2(0, -10)
	add_child(ring)
	var data := {"r": 4.0}
	ring.draw.connect(func():
		ring.draw_arc(Vector2.ZERO, data.r, 0.0, TAU, 40, glow_color, 3.0))
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float):
		data.r = v
		ring.queue_redraw(), 4.0, 60.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(ring.queue_free)

func _spawn_sparks() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -20)
	p.z_index = 50
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = glow_color
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _spawn_label() -> void:
	var l := Label.new()
	l.text = label_text
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", glow_color)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.17, 0.23))
	l.add_theme_constant_override("outline_size", 5)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	l.position = Vector2(-60, -70)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 24.0, 1.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	t.chain().tween_callback(l.queue_free)
