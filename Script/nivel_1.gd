extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var limit_top_left: Marker2D = $LimitTopLeft
@onready var limit_bottom_right: Marker2D = $LimitBottomRight
@onready var hud: CanvasLayer = $HUD

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var kill_zone: Area2D = $KillZone
func _ready() -> void:
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
func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()

func _on_kill_zone_body_entered(body: Node2D) -> void:
	print("KillZone tocó a: ", body.name)
	if body.has_method("fall_into_void"):
		body.fall_into_void(1)
