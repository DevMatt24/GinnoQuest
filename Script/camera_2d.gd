extends Camera2D

@onready var player: Node2D = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player:
		global_position = player.global_position
