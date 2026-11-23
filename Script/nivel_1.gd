extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var limit_top_left: Marker2D = $LimitTopLeft
@onready var limit_bottom_right: Marker2D = $LimitBottomRight

func _ready() -> void:
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = int(limit_top_left.global_position.x)
	cam.limit_top = int(limit_top_left.global_position.y)
	cam.limit_right = int(limit_bottom_right.global_position.x)
	cam.limit_bottom = int(limit_bottom_right.global_position.y)
	player.bounds = Rect2(
		limit_top_left.global_position,
		limit_bottom_right.global_position - limit_top_left.global_position
	)
