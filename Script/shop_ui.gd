extends CanvasLayer

signal closed

@onready var dialogue: Label = $Panel/Margin/VBox/Dialogue
@onready var items_box: HBoxContainer = $Panel/Margin/VBox/Items
@onready var coins_label: Label = $Panel/Margin/VBox/CoinsLabel

var player: Node
var items: Array[ShopItem] = []
var buttons: Array[Button] = []
var price_labels: Array[Label] = []
var status_labels: Array[Label] = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # funciona con el juego pausado
	_style_ui()
	hide()

func open(p: Node, shop_items: Array[ShopItem], greeting: String) -> void:
	player = p
	items = shop_items
	# Congelar solamente al jugador
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	if player.has_node("WalkSound"):
		player.get_node("WalkSound").stop()
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
	await get_tree().process_frame
	_position_close_button()
func close() -> void:
	if player and player.coins_changed.is_connected(_refresh):
		player.coins_changed.disconnect(_refresh)

	if is_instance_valid(player):
		player.set_physics_process(true)

	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _price(item: ShopItem) -> int:
	var level := 0

	match item.type:
		ShopItem.Type.WEAPON_UPGRADE:
			level = player.weapon_level
		ShopItem.Type.SHIELD_UPGRADE:
			level = player.shield_level

	return item.price + item.price_step * level
func _block_reason(item: ShopItem) -> String:
	match item.type:
		ShopItem.Type.HEAL:
			if player.health >= player.MAX_HEALTH:
				return "Ya tenés la vida llena."

		ShopItem.Type.WEAPON_UPGRADE:
			if player.weapon_level >= item.max_level:
				return "Tu arma ya está al máximo."

		ShopItem.Type.SHIELD_UPGRADE:
			if player.shield_level >= item.max_level:
				return "Tu escudo ya está al máximo."

	var missing : int = _price(item) - player.coins

	if missing > 0:
		return "Te faltan %d monedas." % missing

	return ""
func _build_buttons() -> void:
	for c in items_box.get_children():
		c.queue_free()
	buttons.clear()
	price_labels.clear()
	status_labels.clear()

	for i in items.size():
		var item := items[i]

		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 160)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_card(b)

		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_right = -6
		content.offset_top = 8
		content.offset_bottom = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)

		var sprite := TextureRect.new()
		sprite.custom_minimum_size = Vector2(55, 55)
		sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.texture = item.icon

		var name_label := _card_label(item.item_name, 17, Color("#FFF0D0"))
		var price_label := _card_label("", 16, Color("#FFD36E"))
		var status_label := _card_label("", 14, Color("#FF8C73"))

		content.add_child(sprite)
		content.add_child(name_label)
		content.add_child(price_label)
		content.add_child(status_label)
		b.add_child(content)

		b.pressed.connect(_on_item_pressed.bind(i))
		b.focus_entered.connect(_on_item_focused.bind(i))
		b.focus_exited.connect(_shrink.bind(b))
		b.mouse_entered.connect(b.grab_focus)

		items_box.add_child(b)
		buttons.append(b)
		price_labels.append(price_label)
		status_labels.append(status_label)

func _card_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#24170F"))
	l.add_theme_constant_override("outline_size", 3)
	return l
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

func _short_reason(item: ShopItem) -> String:
	match item.type:
		ShopItem.Type.HEAL:
			if player.health >= player.MAX_HEALTH:
				return "Vida llena"
		ShopItem.Type.WEAPON_UPGRADE:
			if player.weapon_level >= item.max_level:
				return "Máximo"
		ShopItem.Type.SHIELD_UPGRADE:
			if player.shield_level >= item.max_level:
				return "Máximo"
	var missing: int = _price(item) - player.coins
	if missing > 0:
		return "Faltan %d" % missing
	return ""

func _refresh(_total: int = 0) -> void:
	coins_label.text = "Monedas: %d" % player.coins
	for i in items.size():
		var item := items[i]
		var blocked := _block_reason(item) != ""
		price_labels[i].text = "%d monedas" % _price(item)
		status_labels[i].text = _short_reason(item)
		price_labels[i].add_theme_color_override(
			"font_color", Color("#B8A58A") if blocked else Color("#FFD36E"))
		buttons[i].modulate = Color(1, 1, 1, 0.8) if blocked else Color.WHITE
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
			player.upgrade_attack(item.value)

		ShopItem.Type.SHIELD_UPGRADE:
			player.upgrade_shield(item.value)

	_say("¡Buena compra!", GRASS)
	_refresh()
	_flash(buttons[i])
	_pop(coins_label)
var type_tween: Tween

const TEXT_COLOR := Color(0.96, 0.93, 0.82)
const GOLD := Color(0.98, 0.86, 0.5)
const GRASS := Color(0.65, 0.9, 0.4)


var close_button: Button

func _style_ui() -> void:
	var panel: Control = $Panel

	# Panel centrado horizontalmente, abajo
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)

	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -310
	panel.offset_bottom = -16	
	# Estilo medieval
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#49301F")
	panel_style.border_color = Color("#D9AC58")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(12)

	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10

	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(4, 5)

	panel.add_theme_stylebox_override("panel", panel_style)

	# Tarjetas horizontales
	items_box.add_theme_constant_override("separation", 10)
	items_box.alignment = BoxContainer.ALIGNMENT_CENTER

	dialogue.add_theme_font_size_override("font_size", 20)
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size.y = 52
	dialogue.add_theme_color_override("font_color", Color("#FFE5AE"))

	coins_label.add_theme_font_size_override("font_size", 19)
	coins_label.add_theme_color_override("font_color", Color("#FFD36E"))
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Crear una capa independiente para el botón
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Botón circular
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(42, 42)
	close_button.size = Vector2(42, 42)
	close_button.add_theme_font_size_override("font_size", 30)
	close_button.add_theme_color_override("font_color", Color("#FFF0D0"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#713D2C")
	normal.border_color = Color("#D9AC58")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(24)

	var hover := normal.duplicate()
	hover.bg_color = Color("#A34F37")
	hover.border_color = Color("#FFE09A")

	close_button.add_theme_stylebox_override("normal", normal)
	close_button.add_theme_stylebox_override("hover", hover)
	close_button.add_theme_stylebox_override("pressed", normal)

	close_button.pressed.connect(close)

	overlay.add_child(close_button)
	
func _style_button(b: Button) -> void:

	# Tamaño compacto.
	b.custom_minimum_size = Vector2(115, 125)
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

func _style_card(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#68452C")
	normal.border_color = Color("#B98A4B")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)

	var hover := normal.duplicate()
	hover.bg_color = Color("#92633B")
	hover.border_color = Color("#FFE09A")

	var pressed := normal.duplicate()
	pressed.bg_color = Color("#49301F")
	pressed.border_color = Color("#E8B95E")

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
func _position_close_button() -> void:
	var rect: Rect2 = $Panel.get_global_rect()
	close_button.position = rect.position + Vector2(rect.size.x - 21, -21)
