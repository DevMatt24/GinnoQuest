extends CanvasLayer

signal closed

@onready var dialogue: Label = $Panel/Margin/VBox/Dialogue
@onready var items_box: VBoxContainer = $Panel/Margin/VBox/Items
@onready var coins_label: Label = $Panel/Margin/VBox/CoinsLabel

var player: Node
var items: Array[ShopItem] = []
var buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # funciona con el juego pausado
	_style_ui()
	hide()

func open(p: Node, shop_items: Array[ShopItem], greeting: String) -> void:
	player = p
	items = shop_items
	get_tree().paused = true
	show()
	$Panel.modulate.a = 0.0
	create_tween().tween_property($Panel, "modulate:a", 1.0, 0.2)
	_say(greeting)

	if not player.coins_changed.is_connected(_refresh):
		player.coins_changed.connect(_refresh)

	_build_buttons()
	_refresh()
	_play_entrance()
	buttons[0].grab_focus()
	buttons[0].grab_focus()

func close() -> void:
	if player and player.coins_changed.is_connected(_refresh):
		player.coins_changed.disconnect(_refresh)
	get_tree().paused = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _price(item: ShopItem) -> int:
	var level: int = player.weapon_level if item.type == ShopItem.Type.WEAPON_UPGRADE else 0
	return item.price + item.price_step * level
func _block_reason(item: ShopItem) -> String:
	match item.type:
		ShopItem.Type.HEAL:
			if player.health >= player.MAX_HEALTH:
				return "Ya tenés la vida llena."
		ShopItem.Type.WEAPON_UPGRADE:
			if player.weapon_level >= item.max_level:
				return "Tu arma ya está al máximo."
	var missing: int = _price(item) - player.coins
	if missing > 0:
		return "Te faltan %d monedas." % missing
	return ""

func _build_buttons() -> void:
	for c in items_box.get_children():
		c.queue_free()
	buttons.clear()

	for i in items.size():
		var b := Button.new()
		_style_button(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = items[i].icon
		b.pressed.connect(_on_item_pressed.bind(i))
		b.focus_entered.connect(_on_item_focused.bind(i))
		b.mouse_entered.connect(b.grab_focus)
		items_box.add_child(b)
		buttons.append(b)

	var exit := Button.new()
	_style_button(exit)
	exit.text = " Salir"
	exit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	exit.pressed.connect(close)
	exit.focus_entered.connect(_grow.bind(exit))
	exit.focus_exited.connect(_shrink.bind(exit))
	items_box.add_child(exit)
	buttons.append(exit)

	for i in items.size():
		buttons[i].focus_exited.connect(_shrink.bind(buttons[i]))

func _play_entrance() -> void:
	await get_tree().process_frame   # espera a que el contenedor calcule tamaños
	for i in buttons.size():
		var b := buttons[i]
		b.pivot_offset = b.size / 2.0
		b.modulate.a = 0.0
		b.scale = Vector2(0.9, 0.9)
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.08)
		t.tween_property(b, "scale", Vector2.ONE, 0.25).set_delay(i * 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Al terminar la cascada, se recalcula el estado (por si cambió la opacidad)
	await get_tree().create_timer(buttons.size() * 0.08 + 0.3).timeout
	_refresh()

# Estado de cada producto: texto, color y bloqueo
func _refresh(_total: int = 0) -> void:
	coins_label.text = "Monedas: %d" % player.coins
	for i in items.size():
		var item := items[i]
		var reason := _block_reason(item)
		var b := buttons[i]
		var price_text := "%d monedas" % _price(item)

		if reason == "":
			b.text = " %s   —   %s" % [item.item_name, price_text]
			b.add_theme_color_override("font_color", TEXT_COLOR)
			b.modulate.a = 1.0
		else:
			b.text = " [X] %s   —   %s   (%s)" % [item.item_name, price_text, reason.trim_suffix(".")]
			b.add_theme_color_override("font_color", Color(0.6, 0.65, 0.65))
			b.modulate.a = 0.75

func _grow(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.1)

func _shrink(b: Control) -> void:
	create_tween().tween_property(b, "scale", Vector2.ONE, 0.1)

func _shake(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	var t := create_tween()
	for angle in [0.03, -0.03, 0.02, -0.02, 0.0]:
		t.tween_property(b, "rotation", angle, 0.04)

func _flash(b: Control) -> void:
	var t := create_tween()
	t.tween_property(b, "modulate", Color(0.7, 1.4, 0.7), 0.1)
	t.tween_property(b, "modulate", Color.WHITE, 0.25)

func _on_item_focused(i: int) -> void:
	_grow(buttons[i])
	_say(items[i].description)

func _on_item_pressed(i: int) -> void:
	var item := items[i]
	var reason := _block_reason(item)
	if reason != "":
		_say(reason, Color(1.0, 0.55, 0.45))
		_shake(buttons[i])
		return

	player.spend_coins(_price(item))
	match item.type:
		ShopItem.Type.HEAL:
			player.heal(item.value)
		ShopItem.Type.WEAPON_UPGRADE:
			player.upgrade_weapon(item.value)

	_say("¡Buena compra!", GRASS)
	_refresh()
	_flash(buttons[i])
	_pop(coins_label)
var type_tween: Tween

const TEXT_COLOR := Color(0.96, 0.93, 0.82)
const GOLD := Color(0.98, 0.86, 0.5)
const GRASS := Color(0.65, 0.9, 0.4)

func _style_ui() -> void:
	# Panel anclado abajo, de lado a lado
	var panel: Control = $Panel
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -250
	panel.offset_bottom = -16

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.17, 0.23, 0.96)
	panel_style.border_color = GOLD
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)

	dialogue.add_theme_font_size_override("font_size", 20)
	dialogue.add_theme_color_override("font_color", TEXT_COLOR)
	coins_label.add_theme_font_size_override("font_size", 18)
	coins_label.add_theme_color_override("font_color", GOLD)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_button(b: Button) -> void:
	var normal_bg := Color(0.12, 0.28, 0.35)
	var hover_bg := Color(0.2, 0.42, 0.45)
	b.add_theme_stylebox_override("normal", _make_style(normal_bg, Color(0.3, 0.55, 0.55)))
	b.add_theme_stylebox_override("hover", _make_style(hover_bg, GRASS))
	b.add_theme_stylebox_override("focus", _make_style(hover_bg, GRASS))
	b.add_theme_stylebox_override("pressed", _make_style(Color(0.3, 0.5, 0.3), GOLD))
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_font_size_override("font_size", 18)
func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# Texto que se escribe letra por letra
func _say(text: String, color := TEXT_COLOR) -> void:
	dialogue.text = text
	dialogue.add_theme_color_override("font_color", color)
	dialogue.visible_ratio = 0.0
	if type_tween:
		type_tween.kill()
	type_tween = create_tween()
	type_tween.tween_property(dialogue, "visible_ratio", 1.0, maxf(text.length() * 0.02, 0.05))

func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.25, 1.25), 0.07)
	t.tween_property(control, "scale", Vector2.ONE, 0.1)
