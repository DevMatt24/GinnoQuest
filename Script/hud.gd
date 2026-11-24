extends CanvasLayer

@onready var hearts: Array[AnimatedSprite2D] = []
var last_health := -1

func _ready() -> void:
	for slot in $HeartsContainer.get_children():
		hearts.append(slot.get_node("Heart"))
	

func update_health(current: int, _maximum: int) -> void:
	for i in hearts.size():
		var heart := hearts[i]
		var points := clampi(current - i * 2, 0, 2)   # 2 = lleno, 1 = medio, 0 = vacío
		var previous := clampi(last_health - i * 2, 0, 2) if last_health >= 0 else points

		if points == previous:
			_set_state(heart, points)
		elif points < previous:
			_play_loss(heart, previous, points)
		else:
			_set_state(heart, points)   # curación

	last_health = current

func _set_state(heart: AnimatedSprite2D, points: int) -> void:
	match points:
		2: heart.play("full")
		1: heart.play("half")
		0: heart.play("empty")

func _play_loss(heart: AnimatedSprite2D, from: int, to: int) -> void:
	# Elige la animación de transición según cuánto perdió
	var anim := "lose_half" if from == 2 else "lose_last"
	if from == 2 and to == 0:
		anim = "lose_half"   # si perdió 2 de golpe, pasa por medio y luego vacío
	if heart.sprite_frames.has_animation(anim):
		heart.play(anim)
		await heart.animation_finished
	_set_state(heart, to)
@onready var coin_label: Label = $CoinCounter/Control/CoinLabel

func update_coins(total: int) -> void:
	coin_label.text = str(total)

	# Pequeño rebote al sumar
	coin_label.pivot_offset = coin_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(coin_label, "scale", Vector2(1.3, 1.3), 0.07)
	tween.tween_property(coin_label, "scale", Vector2.ONE, 0.07)
