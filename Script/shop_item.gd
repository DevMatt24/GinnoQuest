class_name ShopItem
extends Resource

enum Type { HEAL, WEAPON_UPGRADE }

@export var item_name := "Poción"
@export_multiline var description := ""
@export var type: Type = Type.HEAL
@export var value := 1            # puntos de vida, o daño extra
@export var price := 5
@export var price_step := 0       # cuánto sube el precio por cada nivel (solo arma)
@export var max_level := 3        # solo arma
@export var icon: Texture2D
