extends Node2D
## Drop: moneda (tesoro, va al leaderboard on-chain) o
## drop de recurso (minteado en el mock Chain). Se recoge al pisar la celda.

const COIN_FRAMES: SpriteFrames = preload("res://assets/sprite_frames/coin.frames.tres")

const RESOURCE_TINTS := {
	"madera": Color(0.72, 0.52, 0.28),
	"cobre": Color(0.9, 0.5, 0.22),
	"hierro": Color(0.66, 0.68, 0.72),
	"plata": Color(0.86, 0.9, 0.96),
	## Cosmético del jefe: Tinte Real (cae 100% del Capitán).
	"tinte_real": Color(1.0, 0.82, 0.3),
}

@onready var _sprite: AnimatedSprite2D = $Sprite

var kind := "coin"       # "coin" o id de recurso ("madera", "cobre", ...)
var amount := 1
var level: Node2D
## true = poción tirada en el piso al generar (grupo "floor_drops", aparte de
## los drops de combate "drops" para no pisar las expectativas de los tests).
var scatter := false

var _player: Node2D
var _taken := false
var _frames_cache := {}  # Texture2D -> SpriteFrames de un solo frame

func _ready() -> void:
	add_to_group("floor_drops" if scatter else "drops")
	_player = get_tree().get_first_node_in_group("player")
	if kind == "coin" or RESOURCE_TINTS.has(kind):
		_sprite.sprite_frames = COIN_FRAMES
		_sprite.animation = "coin"
		if RESOURCE_TINTS.has(kind):
			_sprite.modulate = RESOURCE_TINTS[kind]
	else:
		# Armas y frascos: sprite propio (weapon_*.png / flask_*.png).
		var tex: Texture2D = load("res://assets/frames/%s.png" % kind)
		if tex == null:
			_sprite.sprite_frames = COIN_FRAMES
			_sprite.animation = "coin"
		else:
			_sprite.sprite_frames = _static_frames(tex)
			_sprite.animation = "idle"
	_sprite.play()

## SpriteFrames estático cacheado para un sprite de un solo frame.
func _static_frames(tex: Texture2D) -> SpriteFrames:
	if _frames_cache.has(tex):
		return _frames_cache[tex]
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", false)
	sf.set_animation_speed("idle", 1.0)
	sf.add_frame("idle", tex)
	_frames_cache[tex] = sf
	return sf

func _physics_process(_delta: float) -> void:
	if _taken or level == null or _player == null or not is_instance_valid(_player):
		return
	if level.local_to_cell(global_position) == level.local_to_cell(_player.global_position):
		_collect()

func _collect() -> void:
	_taken = true
	Sfx.play("chest_open" if kind == "coin" else "pickup")
	if kind == "coin":
		await Chain.add_treasure(amount)
	else:
		await Chain.claim_drop(kind)
	queue_free()