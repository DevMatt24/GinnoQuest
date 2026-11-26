extends Node2D

@onready var arena_trigger: Area2D = $BossTrigger
@onready var arena_tl: Marker2D = $ArenaTopLeft
@onready var arena_br: Marker2D = $ArenaBottomRight
@onready var boss: CharacterBody2D = $Boss
@onready var portal: Area2D = $Portal
@onready var complete_screen: CanvasLayer = $Portal/LevelComplete

var total_enemies := 0
var killed := 0
var boss_dead := false
var arena_active := false
var completed := false
var saved_bounds := Rect2()
var saved_limits := {}
var boss_bar: ProgressBar
@onready var player: CharacterBody2D = $Player
@onready var limit_top_left: Marker2D = $LimitTopLeft
@onready var limit_bottom_right: Marker2D = $LimitBottomRight
@onready var hud: CanvasLayer = $HUD

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var kill_zone: Area2D = $KillZone
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = int(limit_top_left.global_position.x)
	cam.limit_right = int(limit_bottom_right.global_position.x)
	player.bounds = Rect2(
		limit_top_left.global_position,
		limit_bottom_right.global_position - limit_top_left.global_position
	)
	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.update_health)
	hud.update_health(player.health, player.MAX_HEALTH)
	player.coins_changed.connect(hud.update_coins)
	hud.update_coins(player.coins)
	player.respawn_position = spawn_point.global_position
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	for e in get_tree().get_nodes_in_group("enemy"):
		total_enemies += 1
		e.died.connect(_on_enemy_died)
	boss.died.connect(_on_boss_died)
	boss.health_changed.connect(_on_boss_health)

	arena_trigger.body_entered.connect(_on_trigger_entered)
	portal.entered.connect(_on_portal_entered)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	print("KillZone tocó a: ", body.name)
	if body.has_method("fall_into_void"):
		body.fall_into_void(1)

# ---------- Arena ----------

func _on_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_lock_arena()

func _lock_arena() -> void:
	if arena_active or boss_dead:
		return
	arena_active = true
	arena_trigger.set_deferred("monitoring", false)

	var cam: Camera2D = player.get_node("Camera2D")
	saved_bounds = player.bounds
	saved_limits = {
		"left": cam.limit_left, "right": cam.limit_right,
		"top": cam.limit_top, "bottom": cam.limit_bottom,
	}

	var rect := Rect2(arena_tl.global_position, arena_br.global_position - arena_tl.global_position)
	player.bounds = rect

	# Los límites verticales cambian de golpe; los horizontales, con una transición suave
	cam.limit_top = int(rect.position.y)
	cam.limit_bottom = int(rect.end.y)
	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "limit_left", int(rect.position.x), 0.8)
	t.tween_property(cam, "limit_right", int(rect.end.x), 0.8)

	_show_boss_bar()
	boss.activate()

func _unlock_arena() -> void:
	if not arena_active:
		return
	arena_active = false
	var cam: Camera2D = player.get_node("Camera2D")
	player.bounds = saved_bounds
	cam.limit_top = saved_limits["top"]
	cam.limit_bottom = saved_limits["bottom"]
	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "limit_left", saved_limits["left"], 0.8)
	t.tween_property(cam, "limit_right", saved_limits["right"], 0.8)

# ---------- Barra de vida del jefe ----------

func _show_boss_bar() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	boss_bar = ProgressBar.new()
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.health
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(420, 18)
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.position = Vector2(-210, 24)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#C9412F")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#24170F")
	bg.border_color = Color("#D9AC58")
	bg.set_border_width_all(2)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_bar.add_theme_stylebox_override("background", bg)
	layer.add_child(boss_bar)

func _on_boss_health(current: int, _maximum: int) -> void:
	if boss_bar:
		create_tween().tween_property(boss_bar, "value", float(current), 0.2)

# ---------- Fin del nivel ----------

func _on_enemy_died() -> void:
	killed += 1
	_check_completion()

func _on_boss_died() -> void:
	boss_dead = true
	if boss_bar:
		boss_bar.get_parent().queue_free()
	_unlock_arena()
	_check_completion()
	portal.appear()

func _check_completion() -> void:
	if completed or not boss_dead:
		return
	if killed >= total_enemies:
		completed = true
		await get_tree().create_timer(1.5).timeout
		portal.appear()

func _on_portal_entered(body: Node2D) -> void:
	if body != player:
		return

	if completed:
		return

	completed = true

	if complete_screen == null:
		push_error("LevelComplete no existe. Revisa su ruta.")
		completed = false
		return

	# Detener al jugador.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.animated_sprite.play("idle")

	if player.has_node("WalkSound"):
		player.get_node("WalkSound").stop()

	# Mostrar pantalla de victoria.
	complete_screen.show_results(killed, player.coins_collected)
func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	if arena_active and not boss_dead:
		_unlock_arena()
		boss.reset()
		if boss_bar:
			boss_bar.get_parent().queue_free()
			boss_bar = null
		arena_trigger.monitoring = true
	player.respawn()
