extends Node2D

@export_file("*.tscn") var game_scene := "res://Scene//nivel_1.tscn"
@export var banner: Texture2D
@export var banner_margins := Vector4i(24, 12, 24, 12)   # izq, arriba, der, abajo

const TEXT_COLOR := Color(0.96, 0.93, 0.82)
const OUTLINE_COLOR := Color(0.07, 0.17, 0.23)
const GOLD := Color(0.98, 0.86, 0.5)
const HOVER_TINT := Color(1.25, 1.2, 1.0)
const SETTINGS_PATH := "user://settings.cfg"

@onready var hero: AnimatedSprite2D = $Stage/Hero
@onready var ui: CanvasLayer = $UI
@onready var title: Label = $UI/Root/Title
@onready var menu_box: VBoxContainer = $UI/Root/MenuBox
@onready var options_box: VBoxContainer = $UI/Root/OptionsBox
@onready var play_button: Button = $UI/Root/MenuBox/PlayButton
@onready var options_button: Button = $UI/Root/MenuBox/OptionsButton
@onready var quit_button: Button = $UI/Root/MenuBox/QuitButton
@onready var back_button: Button = $UI/Root/OptionsBox/BackButton
@onready var music_slider: HSlider = $UI/Root/OptionsBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $UI/Root/OptionsBox/SfxRow/SfxSlider
@onready var fullscreen_check: CheckButton = $UI/Root/OptionsBox/FullscreenCheck
@onready var menu_music: AudioStreamPlayer = $MenuMusic
var buttons: Array[Button] = []
var tweens := {}
var fade: ColorRect
var busy := false


func _ready() -> void:
	menu_music.volume_db = -45
	menu_music.play()
	Input.set_custom_mouse_cursor(
		load("res://Sprite/UI/Cursor_01.png"),
		Input.CURSOR_ARROW,
		Vector2(2, 2)
	)
	get_tree().paused = false

	buttons = [play_button, options_button, quit_button, back_button]

	# Primero mostramos el menú principal.
	menu_box.show()
	menu_box.modulate.a = 1.0

	# Las opciones comienzan ocultas.
	options_box.hide()
	options_box.modulate.a = 0.0

	_layout()
	_style_all()
	_create_fade()
	_load_settings()
	_connect_signals()

	if OS.has_feature("web"):
		quit_button.hide()

	# Animación del personaje.
	hero.play("idle")
	_hero_loop()

	# Animación inicial del menú.
	_play_intro()
	play_button.text = "JUGAR"
	options_button.text = "OPCIONES"
	quit_button.text = "SALIR"
# ---------- Layout ----------


func _layout() -> void:
	var root: Control = $UI/Root

	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0

	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Título centrado en la parte superior.
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -420
	title.offset_right = 420
	title.offset_top = 35
	title.offset_bottom = 155

	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# Menú principal centrado.
	menu_box.set_anchors_preset(Control.PRESET_CENTER)

	menu_box.offset_left = -175
	menu_box.offset_right = 175
	menu_box.offset_top = -120
	menu_box.offset_bottom = 120

	menu_box.add_theme_constant_override("separation", 18)
	# PANEL DE OPCIONES.
	options_box.set_anchors_preset(Control.PRESET_CENTER)

	options_box.offset_left = -200
	options_box.offset_right = 200
	options_box.offset_top = -180
	options_box.offset_bottom = 180
		
	options_box.add_theme_constant_override("separation", 16)

	# Los botones ocupan el ancho disponible.
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
# ---------- Estilos ----------

func _style_label(l: Label, size: int, outline: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	l.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	l.add_theme_constant_override("outline_size", outline)

func _banner_style() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = banner
	s.texture_margin_left = banner_margins.x
	s.texture_margin_top = banner_margins.y
	s.texture_margin_right = banner_margins.z
	s.texture_margin_bottom = banner_margins.w
	s.content_margin_left = banner_margins.x
	s.content_margin_right = banner_margins.z
	return s

func _style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(300, 68)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if banner:
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, _banner_style())

func _style_all() -> void:
	_style_label(title, 84, 14)
	_style_label($UI/Root/OptionsBox/OptionsTitle, 40, 8)
	_style_label($UI/Root/OptionsBox/MusicRow/Label, 22, 5)
	_style_label($UI/Root/OptionsBox/SfxRow/Label, 22, 5)
	fullscreen_check.add_theme_font_size_override("font_size", 22)
	fullscreen_check.add_theme_color_override("font_color", TEXT_COLOR)
	$UI/Root/OptionsBox/OptionsTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in buttons:
		_style_button(b)
	# Organización de los controles de opciones.

	music_slider.custom_minimum_size = Vector2(150, 25)
	sfx_slider.custom_minimum_size = Vector2(150, 25)

	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Título de opciones.
	$UI/Root/OptionsBox/OptionsTitle.add_theme_font_size_override(
		"font_size", 46
	)

# Botón volver.
	back_button.text = "VOLVER"

func _create_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0.05, 0.1, 0.15, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)   # último hijo: se dibuja encima de todo

# ---------- Señales ----------

func _connect_signals() -> void:
	for b in buttons:
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_hover.bind(b, true))
		b.focus_exited.connect(_hover.bind(b, false))

	play_button.pressed.connect(func(): _click(play_button, _start_game))
	options_button.pressed.connect(func(): _click(options_button, _open_options))
	quit_button.pressed.connect(
		func(): _click(quit_button, _quit_game)
	)
	back_button.pressed.connect(func(): _click(back_button, _close_options))

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

# ---------- Efectos de botones ----------

func _hover(b: Button, on: bool) -> void:
	if tweens.has(b):
		tweens[b].kill()
	b.pivot_offset = b.size / 2.0
	var t := b.create_tween().set_parallel(true)
	tweens[b] = t
	t.tween_property(b, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "self_modulate", HOVER_TINT if on else Color.WHITE, 0.12)

func _click(b: Button, action: Callable) -> void:
	if busy:
		return
	if tweens.has(b):
		tweens[b].kill()
	b.pivot_offset = b.size / 2.0
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06)
	t.tween_property(b, "scale", Vector2(1.08, 1.08), 0.1)
	t.tween_callback(action)

# ---------- Intro: título y botones ----------

func _play_intro() -> void:
	await get_tree().process_frame   # espera a que los contenedores calculen tamaños

	# Botones: la caja entra deslizando y cada botón aparece en cascada
	var box_x := menu_box.position.x
	menu_box.position.x = box_x + 420.0
	var slide := create_tween()
	slide.tween_property(menu_box, "position:x", box_x, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5)

	var i := 0
	for b in [play_button, options_button, quit_button]:
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.3).set_delay(0.5 + i * 0.12)
		i += 1

	# Título: cae con rebote
	var base := title.position
	title.pivot_offset = title.size / 2.0
	title.position = base + Vector2(0, -300)
	title.modulate.a = 0.0
	var drop := create_tween().set_parallel(true)
	drop.tween_property(title, "position:y", base.y, 0.9) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(title, "modulate:a", 1.0, 0.4)
	await drop.finished

	_title_loop(base)
	play_button.grab_focus()

func _title_loop(base: Vector2) -> void:
	# Flotación
	var float_t := create_tween().set_loops()
	float_t.tween_property(title, "position:y", base.y - 8.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_t.tween_property(title, "position:y", base.y, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Latido de tamaño
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "scale", Vector2(1.04, 1.04), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(title, "scale", Vector2.ONE, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Brillo dorado
	var shine := create_tween().set_loops()
	shine.tween_property(title, "self_modulate", Color(1.0, 0.93, 0.65), 1.5)
	shine.tween_property(title, "self_modulate", Color.WHITE, 1.5)

# ---------- Héroe ----------

func _hero_loop() -> void:
	# De vez en cuando hace su ataque y vuelve a idle
	while true:
		await get_tree().create_timer(randf_range(4.0, 7.0)).timeout
		if hero.sprite_frames.has_animation("attack"):
			hero.play("attack")
			await hero.animation_finished
			hero.play("idle")

# ---------- Navegación ----------

func _start_game() -> void:
	busy = true

	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.5)
	t.tween_callback(
		func(): get_tree().change_scene_to_file(game_scene)
	)

func _open_options() -> void:
	_swap(menu_box, options_box, music_slider)

func _close_options() -> void:
	_swap(options_box, menu_box, play_button)

func _swap(from: Control, to: Control, focus: Control) -> void:

	var t := create_tween()

	# Ocultar el panel actual.
	t.tween_property(from, "modulate:a", 0.0, 0.15)

	t.tween_callback(func():
		from.hide()

		to.modulate.a = 0.0
		to.show()
	)

	# Mostrar el nuevo panel.
	t.tween_property(to, "modulate:a", 1.0, 0.2)

	# Dar el foco al control correspondiente.
	t.tween_callback(focus.grab_focus)
# ---------- Opciones ----------

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = 0   # si no existe el bus, usa Master
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)

func _on_music_changed(v: float) -> void:
	_set_bus("Music", v)
	_save_settings()

func _on_sfx_changed(v: float) -> void:
	_set_bus("SFX", v)
	_save_settings()

func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # si el archivo no existe, se usan los valores por defecto
	music_slider.set_value_no_signal(cfg.get_value("audio", "music", 0.8))
	sfx_slider.set_value_no_signal(cfg.get_value("audio", "sfx", 0.8))
	fullscreen_check.set_pressed_no_signal(cfg.get_value("video", "fullscreen", false))
	_set_bus("Music", music_slider.value)
	_set_bus("SFX", sfx_slider.value)
	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _quit_game() -> void:
	get_tree().quit()
