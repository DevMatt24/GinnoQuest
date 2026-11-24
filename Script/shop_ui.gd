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
	if buttons.size() > 0:
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
		b.add_theme_constant_override("h_separation", 14)
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
			b.text = "%s     •     %s" % [
				item.item_name,
				price_text
			]

			b.add_theme_color_override(
				"font_color",
				Color("#FFF0D0")
			)

			b.modulate = Color.WHITE

		else:
			b.text = "%s     •     %s\n%s" % [
				item.item_name,
				price_text,
				reason
			]

			b.add_theme_color_override(
				"font_color",
				Color("#D4BDA0")
			)

			b.modulate.a = 0.85
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
	var panel: Control = $Panel

	# Posición y tamaño.
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -300
	panel.offset_bottom = -20

	# Panel medieval de madera oscura.
	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color("#49301F")
	panel_style.border_color = Color("#D9AC58")
	panel_style.set_border_width_all(4)

	panel_style.set_corner_radius_all(8)

	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14

	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(3, 4)

	panel.add_theme_stylebox_override("panel", panel_style)

	# Espacio entre los productos.
	items_box.add_theme_constant_override("separation", 8)

	# Diálogo del mercader.
	dialogue.add_theme_font_size_override("font_size", 20)
	dialogue.add_theme_color_override(
		"font_color", Color("#FFE5AE")
	)
	dialogue.add_theme_color_override(
		"font_outline_color", Color("#24170F")
	)
	dialogue.add_theme_constant_override("outline_size", 4)

	# Monedas.
	coins_label.add_theme_font_size_override("font_size", 19)
	coins_label.add_theme_color_override(
		"font_color", Color("#FFD36E")
	)
	coins_label.add_theme_color_override(
		"font_outline_color", Color("#24170F")
	)
	coins_label.add_theme_constant_override("outline_size", 3)

	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_button(b: Button) -> void:

	# Tamaño compacto.
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false

	# Colores medievales.
	var wood_normal := Color("#68452C")
	var wood_hover := Color("#92633B")
	var wood_pressed := Color("#49301F")

	b.add_theme_stylebox_override(
		"normal",
		_make_style(wood_normal, Color("#B98A4B"))
	)

	b.add_theme_stylebox_override(
		"hover",
		_make_style(wood_hover, Color("#FFE09A"))
	)

	b.add_theme_stylebox_override(
		"focus",
		_make_style(wood_hover, Color("#FFE09A"))
	)

	b.add_theme_stylebox_override(
		"pressed",
		_make_style(wood_pressed, Color("#E8B95E"))
	)

	# Tipografía.
	b.add_theme_color_override(
		"font_color", Color("#FFF0D0")
	)

	b.add_theme_color_override(
		"font_hover_color", Color("#FFE39B")
	)

	b.add_theme_color_override(
		"font_focus_color", Color("#FFE39B")
	)

	b.add_theme_color_override(
		"font_pressed_color", Color("#FFFFFF")
	)

	b.add_theme_color_override(
		"font_outline_color", Color("#24170F")
	)

	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_font_size_override("font_size", 17)

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:

	var s := StyleBoxFlat.new()

	s.bg_color = bg
	s.border_color = border

	s.set_border_width_all(2)
	s.set_corner_radius_all(5)

	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 7

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
