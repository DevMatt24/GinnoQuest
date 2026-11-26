extends CanvasLayer

@export_file("*.tscn") var next_level := ""
@export_file("*.tscn") var menu_scene := "res://Scene/main_menu.tscn"

const WOOD := Color("#49301F")
const GOLD := Color("#D9AC58")
const CREAM := Color("#FFF0D0")

var panel: PanelContainer
var kills_label: Label
var coins_label: Label
var score_label: Label
var buttons_box: HBoxContainer

func _ready() -> void:
	layer = 20
	hide()
	_build()

func _label(text: String, size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#24170F"))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color("#FFE39B"))
	for state in ["normal", "hover", "focus", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#92633B") if state != "normal" else Color("#68452C")
		s.border_color = Color("#FFE09A") if state != "normal" else Color("#B98A4B")
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	return b

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD
	style.border_color = GOLD
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(_label("¡Nivel completo!", 44, Color("#FFD36E")))
	kills_label = _label("", 24)
	coins_label = _label("", 24)
	score_label = _label("", 30, Color("#A5E664"))
	box.add_child(kills_label)
	box.add_child(coins_label)
	box.add_child(score_label)

	buttons_box = HBoxContainer.new()
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_box.add_theme_constant_override("separation", 14)
	if next_level != "":
		buttons_box.add_child(_button("Siguiente nivel", func(): _go(next_level)))
	buttons_box.add_child(_button("Menú", func(): _go(menu_scene)))
	buttons_box.modulate.a = 0.0
	box.add_child(buttons_box)

func show_results(kills: int, coins: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.3)
	await t.finished

	# Los números suben de a uno
	await _count(kills_label, "Enemigos derrotados: %d", kills)
	await _count(coins_label, "Monedas: %d", coins)
	await _count(score_label, "Puntaje: %d", kills * 100 + coins * 10)

	create_tween().tween_property(buttons_box, "modulate:a", 1.0, 0.3)
	if buttons_box.get_child_count() > 0:
		buttons_box.get_child(0).grab_focus()

func _count(label: Label, fmt: String, value: int) -> void:
	var t := create_tween()
	t.tween_method(func(v: float): label.text = fmt % int(v), 0.0, float(value),
		clampf(value * 0.02, 0.2, 1.0))
	await t.finished
	label.text = fmt % value

func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)
