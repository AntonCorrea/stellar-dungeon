extends Node2D
## Nodo de minería: barril (madera) y vetas tintadas (cobre/hierro/plata).
## Se golpea con el mismo ataque (Espacio/click); rompe en N golpes según
## dureza y poder del pico (Chain.tienes pico_madera → 2, pico_cobre → 3).

const CRATE_TEX: Texture2D = preload("res://assets/frames/crate.png")
const GOO_TEX: Texture2D = preload("res://assets/frames/wall_goo.png")

const ORE_STATS := {
	"madera": 3,
	"cobre": 4,
	"hierro": 5,
	"plata": 6,
}

const VEIN_TINTS := {
	"cobre": Color(0.92, 0.55, 0.25),
	"hierro": Color(0.6, 0.62, 0.68),
	"plata": Color(0.82, 0.88, 0.96),
}

@onready var _sprite: Sprite2D = $Sprite

var kind := "madera"
var level: Node2D

var _chips := 0
var _broken := false

func _ready() -> void:
	add_to_group("ores")
	_sprite.texture = CRATE_TEX if kind == "madera" else GOO_TEX
	_sprite.modulate = VEIN_TINTS.get(kind, Color.WHITE)
	_chips = toughness()

func toughness() -> int:
	return int(ORE_STATS[kind])

func hit(power: int) -> bool:
	if _broken:
		return false
	_chips -= power
	_juice()
	if _chips <= 0:
		_break()
		return true
	return false

func _juice() -> void:
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", VEIN_TINTS.get(kind, Color.WHITE), 0.12)

func _break() -> void:
	_broken = true
	Sfx.play("crate_break")
	if level != null:
		level.on_ore_broken(self)
		level.spawn_text(level.local_to_cell(global_position), "+1 %s" % kind)
	await Chain.mine(kind)
	queue_free()