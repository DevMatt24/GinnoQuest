extends Area2D

@export var items: Array[ShopItem] = []
@export_multiline var greeting := "¡Bienvenido, viajero! ¿Qué necesitás?"


@export var prompt_offset := Vector2(0, -64)   # sobre la cabeza del jugador
@export var key_color := Color(0.98, 0.86, 0.5)
var bob_time := 0.0
var player: Node2D
var prompt: Node2D
var key_label: Label
var show_tween: Tween
var bob_tween: Tween

@onready var shop_ui: CanvasLayer = $ShopUI

func _ready() -> void:
	_build_prompt()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	shop_ui.closed.connect(_on_shop_closed)

	if InputMap.has_action("interact"):
		for ev in InputMap.action_get_events("interact"):
			if ev is InputEventKey:
				var code: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
				key_label.text = OS.get_keycode_string(code)
				break
	else:
		push_warning("Falta la acción 'interact' en el Mapa de entrada")
func _make_label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l

func _build_prompt() -> void:
	prompt = Node2D.new()
	prompt.position = prompt_offset
	prompt.z_index = 100
	
	prompt.modulate.a = 0.0
	prompt.visible = true
	add_child(prompt)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	prompt.add_child(box)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.17, 0.23, 0.96)   # azul verdoso oscuro
	style.border_color = key_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var key_panel := PanelContainer.new()
	key_panel.add_theme_stylebox_override("panel", style)
	key_label = _make_label("E", key_color, 18)
	key_panel.add_child(key_label)
	box.add_child(key_panel)

	box.add_child(_make_label("Interactuar", Color(0.96, 0.93, 0.82), 16))

	# Centra el aviso sobre el vendedor cuando el contenedor ya calculó su tamaño
	await get_tree().process_frame
	box.position = Vector2(-box.size.x / 2.0, -box.size.y / 2.0)

func _kill_tweens() -> void:
	if show_tween: show_tween.kill()
	if bob_tween: bob_tween.kill()

func _process(delta: float) -> void:
	if player and prompt.visible:
		bob_time += delta
		var bob := sin(bob_time * 4.0) * 3.0
		prompt.global_position = player.global_position + prompt_offset + Vector2(0, bob)

func _show_prompt() -> void:
	if show_tween: show_tween.kill()
	prompt.visible = true
	prompt.modulate.a = 0.0
	prompt.scale = Vector2(0.6, 0.6)
	show_tween = create_tween().set_parallel(true)
	show_tween.tween_property(prompt, "modulate:a", 1.0, 0.2)
	show_tween.tween_property(prompt, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_prompt(instant := false) -> void:
	if show_tween: show_tween.kill()
	if instant:
		prompt.visible = false
		return
	show_tween = create_tween()
	show_tween.tween_property(prompt, "modulate:a", 0.0, 0.15)
	show_tween.tween_callback(func(): prompt.visible = false)
func _start_bob() -> void:
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(prompt, "position:y", prompt_offset.y - 4.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(prompt, "position:y", prompt_offset.y, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		_hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if player and not shop_ui.visible and event.is_action_pressed("interact"):
		_hide_prompt(true)
		shop_ui.open(player, items, greeting)

func _on_shop_closed() -> void:
	if player:
		_show_prompt()
