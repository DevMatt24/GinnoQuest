
class_name ShopItem
extends Resource

enum Type {
	HEAL,
	WEAPON_UPGRADE,
	SHIELD_UPGRADE
}

@export var item_name := "Poción"
@export_multiline var description := ""
@export var type: Type = Type.HEAL

@export var value := 1
@export var price := 5
@export var price_step := 0
@export var max_level := 3

@export var icon: Texture2D
