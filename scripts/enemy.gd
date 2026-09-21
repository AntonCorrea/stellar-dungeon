extends CharacterBody2D
## Enemigo (día 3) + Jefe Capitán (día 5): 3 tipos con stats + boss con 2 fases.
## Tipos LOCKED re-mapeados a sprites 0x72 disponibles:
##   wogol  = "Rata de Alcantarilla" (débil)   · cae monedas + a veces madera
##   skelet = "Esqueleto Guardián" (medio)     · cae más + a veces cobre
##   masked_orc = "Demonio Smith" (medio-duro) · cae mucho + a veces hierro
##   capitan = "Capitán de la Torre" (jefe, 2 fases) · cae tesoro + Tinte Real

const TILE := 16.0
const WOGOL_FRAMES: SpriteFrames = preload("res://assets/sprite_frames/wogol.frames.tres")
const SKELET_FRAMES: SpriteFrames = preload("res://assets/sprite_frames/monster.frames.tres")
const MASKED_ORC_FRAMES: SpriteFrames = preload("res://assets/sprite_frames/masked_orc.frames.tres")
const CAPITAN_FRAMES: SpriteFrames = preload("res://assets/sprite_frames/knight.frames.tres")

const STATS := {
	"wogol": {"hp": 25, "dmg": 4, "speed": 55.0, "aggro": 5.0, "step": 1.5, "atk": 1.6, "coins": 1, "drop_chance": 0.2, "drop": "madera"},
	"skelet": {"hp": 40, "dmg": 8, "speed": 70.0, "aggro": 7.0, "step": 1.0, "atk": 1.2, "coins": 2, "drop_chance": 0.4, "drop": "cobre"},
	"masked_orc": {"hp": 60, "dmg": 12, "speed": 85.0, "aggro": 8.0, "step": 0.8, "atk": 1.0, "coins": 3, "drop_chance": 0.6, "drop": "hierro"},
	"capitan": {"hp": 150, "dmg": 13, "speed": 75.0, "aggro": 9.0, "step": 0.7, "atk": 0.9, "coins": 20, "drop_chance": 1.0, "drop": "tinte_real"},
}

## Umbral (%) de HP donde el Capitán pasa a fase 2 (enfurecido).
const PHASE2_HP_DIV := 2  # a la mitad de vida

@onready var _sprite: AnimatedSprite2D = $Sprite

var type := "wogol"
var level: Node2D
var player: Node2D

var hp := 1
var _to := Vector2.ZERO
var _moving := false
var _step_timer := 0.0
var _atk_timer := 0.0
var _dead := false
## Jefe: fase 2 activada (enfurecido) cuando hp <= max_hp / 2.
var phase := 1
var _max_hp := 1
var _phase2 := false

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	var s: Dictionary = STATS[type]
	hp = int(s["hp"])
	_max_hp = hp
	_sprite.sprite_frames = _frames_for(type)
	_sprite.play("idle")
	if type == "masked_orc":
		_sprite.scale = Vector2(1.25, 1.25)
	elif type == "capitan":
		_sprite.scale = Vector2(1.35, 1.35)
		add_to_group("boss")

func _frames_for(t: String) -> SpriteFrames:
	if t == "wogol":
		return WOGOL_FRAMES
	if t == "masked_orc":
		return MASKED_ORC_FRAMES
	if t == "capitan":
		return CAPITAN_FRAMES
	return SKELET_FRAMES

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _moving:
		global_position = global_position.move_toward(_to, float(STATS[type]["speed"]) * _speed_factor() * delta)
		if global_position.distance_to(_to) < 0.5:
			global_position = _to
			_moving = false
			_sprite.play("idle")
		return
	if player == null or level == null:
		return
	var s: Dictionary = STATS[type]
	var my_cell: Vector2i = level.local_to_cell(global_position)
	var p_cell: Vector2i = level.local_to_cell(player.global_position)
	var gap: Vector2i = p_cell - my_cell
	if absi(gap.x) + absi(gap.y) == 1:
		# adyacente -> atacar (a lo Shattered: cambio por turno ligero)
		_atk_timer -= delta
		if _atk_timer <= 0.0:
			_atk_timer = float(s["atk"])
			_sprite.flip_h = gap.x < 0
			if level != null:
				level.spawn_attack_arc(player.global_position, gap)
			Sfx.play(_sfx_base() + "_atk")
			player.take_damage(_attack_damage())
		return
	_atk_timer = 0.0
	if my_cell.distance_to(p_cell) > float(s["aggro"]):
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	_step_timer = float(s["step"])
	_try_step_toward_player()

func _try_step_toward_player() -> void:
	var my_cell: Vector2i = level.local_to_cell(global_position)
	var p_cell: Vector2i = level.local_to_cell(player.global_position)
	var gap: Vector2i = p_cell - my_cell
	var axes: Array = [Vector2i(signi(gap.x), 0), Vector2i(0, signi(gap.y))]
	if absi(gap.y) > absi(gap.x):
		axes.reverse()
	for dir in axes:
		var target_cell: Vector2i = my_cell + dir
		if level.is_solid(target_cell):
			continue
		_to = level.to_world(target_cell)
		_moving = true
		_sprite.flip_h = dir.x < 0
		_sprite.play("run")
		return

func take_damage(dmg: int) -> void:
	if _dead:
		return
	hp -= dmg
	_flash(Color(2.0, 0.6, 0.6))
	Sfx.play(_sfx_base() + "_damage")
	# Jefe: al llegar a la mitad de vida entra en FASE 2 (enfurecido).
	if type == "capitan" and not _phase2 and _max_hp > 0 and hp <= _max_hp / PHASE2_HP_DIV:
		_enter_phase2()
	if hp <= 0:
		_die()

## Fase 2 del Capitán: más rápido, pega más fuerte y se tiñe de furia.
func _enter_phase2() -> void:
	_phase2 = true
	phase = 2
	_sprite.modulate = Color(1.6, 0.55, 0.4)
	_sprite.scale = Vector2(1.55, 1.55)
	Sfx.play("human_special")
	if level != null:
		level.spawn_text(level.local_to_cell(global_position), "¡FASE 2!")

func _speed_factor() -> float:
	return 1.6 if _phase2 else 1.0

func _attack_damage() -> int:
	var base: int = int(STATS[type]["dmg"])
	return int(base * 1.5) if _phase2 else base

func _die() -> void:
	_dead = true
	Sfx.play(_sfx_base() + "_death")
	if level != null:
		level.on_enemy_killed(self)
	queue_free()

## Prefijo de familia de sonidos según el tipo: el Demonio Smith usa los sonidos
## "orc" del pack y el resto (wogol/skelet/capitán) los "human".
func _sfx_base() -> String:
	return "orc" if type == "masked_orc" else "human"

func _flash(color: Color) -> void:
	var t := create_tween()
	t.tween_property(_sprite, "modulate", color, 0.05)
	t.tween_property(_sprite, "modulate", _base_tint(), 0.15)

## Tinte base: blanco normalmente, rojo furia en la fase 2 del jefe.
func _base_tint() -> Color:
	return Color(1.6, 0.55, 0.4) if _phase2 else Color.WHITE

func drop_coins() -> int:
	return int(STATS[type]["coins"])

func drop_chance() -> float:
	return float(STATS[type]["drop_chance"])

func drop_resource() -> String:
	return STATS[type]["drop"]
