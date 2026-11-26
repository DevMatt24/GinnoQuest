extends Area2D

signal entered(body: Node2D)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hide()
	monitoring = false
	body_entered.connect(func(b: Node2D):
		if b.is_in_group("player"):
			entered.emit(b))

func appear() -> void:
	show()

	var final_scale := scale

	scale = final_scale * 0.85
	modulate.a = 0.0

	sprite.play()

	var t := create_tween().set_parallel(true)

	# Pequeño rebote hasta recuperar su tamaño original.
	t.tween_property(self, "scale", final_scale, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Aparición gradual.
	t.tween_property(self, "modulate:a", 1.0, 0.5)

	t.chain().tween_callback(func(): monitoring = true)
