extends Area2D

@export var value := 1

var collected := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound: AudioStreamPlayer = $PickupSound

func _ready() -> void:
	monitoring = false
	await get_tree().create_timer(0.4).timeout
	monitoring = true
	body_entered.connect(_on_body_entered)
	sprite.play("spin")
	# Desfasa la animación para que no giren todas sincronizadas
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("spin")

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true

	if body.has_method("add_coins"):
		body.add_coins(value)
		_show_popup()

	set_deferred("monitoring", false)
	if sound and sound.stream:
		sound.play()

	# Pequeño salto y desvanecimiento
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - 16.0, 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	await tween.finished

	if sound and sound.playing:
		await sound.finished
	queue_free()
func _show_popup() -> void:
	var s := scale.x   # la escala que le puso el enemigo (1 si es una moneda normal)

	var label := Label.new()
	label.text = "+%d" % value
	label.z_index = 100
	label.add_theme_font_size_override("font_size", int(16 * s))
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", int(4 * s))
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Se agrega al nivel (no a la moneda) para que sobreviva a queue_free()
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-8 * s, -24 * s)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0 * s, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
