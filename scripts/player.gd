extends CharacterBody2D
## Jugador: movimiento en grilla + combate (Espacio/click) + minería (el mismo
## golpe ataca o mina el nodo adyacente) + forja (E cerca del brasero) + HP.

const TILE := 16.0
const SPEED := 110.0
const MAX_HP := 100
const ATTACK_DMG := 12   # daño base (puños / cuchillo inicial)
const ATK_COOLDOWN := 0.35

## Gear: daño por arma y curado de frascos (auto-equip del mejor arma).
const Gear := preload("res://scripts/items.gd")

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _cam: Camera2D = $Camera2D

var level: Node2D
var hp := MAX_HP
var is_dead := false
var mine_power := 2   # 1 manos · 2 pico_madera · 3 pico_cobre (según Chain)
var near_forge := false
## Daño actual del ataque: el mejor arma en cartera (auto-equip).
var attack_damage := ATTACK_DMG
var equipped_weapon := Gear.START_WEAPON

var _to := Vector2.ZERO
var _moving := false
var _atk_cd := 0.0
var _facing := Vector2i(1, 0)
## Cosmético "Tinte Real": aura dorada del jugador cuando está en su cartera.
var _base_tint := Color.WHITE
## Registra las acciones WASD + flechas una sola vez por proceso.
static var _controls_registered := false

func _ready() -> void:
	_register_controls()
	add_to_group("player")
	Chain.sync_finished.connect(_refresh_pick)
	_refresh_pick()
	if level != null and _cam != null:
		_cam.position = Vector2.ZERO
		level.apply_camera_bounds(_cam)

func _refresh_pick() -> void:
	var inv: Dictionary = await Chain.get_inventory()
	mine_power = 1
	if inv.get("pico_madera", 0) > 0:
		mine_power += 1
	if inv.get("pico_cobre", 0) > 0:
		mine_power += 1
	# Auto-equip: el arma (estándar o forjada) con mayor daño de la cartera.
	var best_dmg := ATTACK_DMG
	var best_id := Gear.START_WEAPON
	for key in inv:
		if int(inv[key]) <= 0:
			continue
		if Gear.is_weapon(key) or Chain.get_forged_stats(key) != {}:
			var d: int = Gear.weapon_damage(key)
			var forged: Dictionary = Chain.get_forged_stats(key)
			if forged != {}:
				d = int(forged["dmg"])
			if d > best_dmg:
				best_dmg = d
				best_id = key
	attack_damage = best_dmg
	equipped_weapon = best_id
	# Cosmético: si tenés el Tinte Real en cartera, aura dorada.
	_base_tint = Color(1.0, 0.82, 0.4) if inv.get("tinte_real", 0) > 0 else Color.WHITE
	_sprite.modulate = _base_tint

func _unhandled_input(event: InputEvent) -> void:
	# Click sobre la forja abre su panel (no ataca); si no, click = ataque.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _try_forge_click():
			_try_attack()
	elif event.is_action_pressed("ui_accept"):
		_try_attack()
	if is_dead and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

## Click sobre la forja del nivel: abre el panel de forja (si estás cerca) o
## avisa. Devuelve true si el click se consumió (no ataca).
func _try_forge_click() -> bool:
	if level == null:
		return false
	if level.local_to_cell(get_global_mouse_position()) != level.forge_cell():
		return false
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if hud == null:
		return true
	if not near_forge:
		hud.call("notice", "Acercate a la forja para usarla.")
	else:
		hud.call("open_forge")
	return true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_update_near_forge()
	if _moving:
		global_position = global_position.move_toward(_to, SPEED * delta)
		if global_position.distance_to(_to) < 0.5:
			global_position = _to
			_moving = false
			_sprite.play("idle")
		return

	if level == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return
	_try_step(Vector2i(int(sign(input.x)), int(sign(input.y))))

func _update_near_forge() -> void:
	near_forge = false
	if level == null:
		return
	var my_cell: Vector2i = level.local_to_cell(global_position)
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if my_cell + d == level.forge_cell():
			near_forge = true
			return

func _try_step(dir: Vector2i) -> void:
	var target_cell: Vector2i = level.local_to_cell(global_position) + dir
	if level.is_solid(target_cell) or level.enemy_at(target_cell) != null:
		return
	_facing = dir
	_to = level.to_world(target_cell)
	_moving = true
	_sprite.flip_h = dir.x < 0
	_sprite.play("run")
	Sfx.play("human_walk")

func _try_attack() -> void:
	if is_dead or level == null or _atk_cd > 0.0:
		return
	_atk_cd = ATK_COOLDOWN
	var cell: Vector2i = level.local_to_cell(global_position)
	var dirs: Array = [_facing, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var hit := false
	for d in dirs:
		var enemy: Node2D = level.enemy_at(cell + d)
		if enemy != null:
			_sprite.flip_h = d.x < 0
			enemy.take_damage(attack_damage)
			level.spawn_attack_arc(enemy.global_position, d)
			Sfx.play("sword_hit")
			hit = true
			break
	if not hit:
		for d in dirs:
			var ore: Node2D = level.ore_at(cell + d)
			if ore != null:
				_sprite.flip_h = d.x < 0
				ore.hit(mine_power)
				level.spawn_attack_arc(ore.global_position, d)
				Sfx.play("sword_hit", Vector2(0.8, 0.9))
				hit = true
				break
	if not hit:
		level.spawn_attack_arc(global_position + Vector2(_facing) * 9.0, _facing)
		Sfx.play("sword_miss")
	_flash(Color(1.6, 1.6, 2.0))

func take_damage(dmg: int) -> void:
	if is_dead:
		return
	hp = maxi(hp - dmg, 0)
	_flash(Color(1.8, 0.5, 0.5))
	Sfx.play("human_damage")
	if hp <= 0:
		is_dead = true
		_sprite.play("idle")
		Sfx.play("human_death")

## Curar con frascos. Devuelve cuánta vida recuperó (0 si estás lleno/muerto).
func heal(amount: int) -> int:
	if is_dead:
		return 0
	var before := hp
	hp = mini(hp + amount, MAX_HP)
	if hp > before:
		_flash(Color(0.7, 1.7, 0.8))
		Sfx.play("pickup")
	return hp - before

func _flash(color: Color) -> void:
	var t := create_tween()
	t.tween_property(_sprite, "modulate", color, 0.05)
	t.tween_property(_sprite, "modulate", _base_tint, 0.15)

## Acciones de movimiento (WASD + flechas). Se registran a demanda y de forma
## idempotente; usan physical_keycode para funcionar en cualquier layout.
func _register_controls() -> void:
	if _controls_registered:
		return
	_controls_registered = true
	_add_action_keys("move_up", [KEY_W, KEY_UP])
	_add_action_keys("move_down", [KEY_S, KEY_DOWN])
	_add_action_keys("move_left", [KEY_A, KEY_LEFT])
	_add_action_keys("move_right", [KEY_D, KEY_RIGHT])

func _add_action_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
