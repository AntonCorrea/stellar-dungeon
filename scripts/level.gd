extends Node2D
## Mazmorra procedural + enemigos y drops + minería y forja.
## API: is_solid() / to_world() / local_to_cell() / apply_camera_bounds() /
## enemy_at() / ore_at() / forge_cell() / spawn_drop() / spawn_text() / on_*.

const TILE := 16.0
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DROP_SCENE := preload("res://scenes/drop.tscn")
const ORE_SCENE := preload("res://scenes/ore_node.tscn")
const FORGE_SCENE := preload("res://scenes/forge.tscn")
const FLOAT_TEXT_SCENE := preload("res://scenes/floating_text.tscn")
const ATTACK_ARC := preload("res://scripts/attack_arc.gd")

const FLOOR_COUNT := 8
const ROOM_TARGET := 8
const ROOM_ATTEMPTS := 180
## Entidades por DELANTE de la capa de muros (wall_layer.z_index = 6).
const ENTITY_Z := 10

@export_enum("base", "jungle", "dessert") var floor_theme := "base"
@export_enum("base", "jungle", "dessert") var wall_theme := "base"
@export var width := 84
@export var height := 48
## Prevalencia de floor_1 en el piso: cuántas de cada 12 celdas caen en floor_1
## (0 = nunca, 11 = casi todo). Las demás variantes reparten el resto por igual.
@export_range(0, 11) var floor_1_weight := 5

## Pociones rojas tiradas en el piso al generar el nivel (0 = no hay ninguna).
## Se recogen al pisarlas como cualquier drop; no bloquean ni reaparecen.
@export_range(0, 24) var potions_on_floor := 4

var _tile_tex := {}  # clave "grupo/nombre" -> Texture2D (cache)

const WALL_TILE_NAMES := ["wall_mid", "wall_top_mid"]

## Tema al que pertenece un tile: los muros usan wall_theme y el resto floor_theme
## (pisos, escaleras y escalera de mano van con el piso).
func _theme_for(name: String) -> String:
	if name in WALL_TILE_NAMES:
		return wall_theme
	return floor_theme

## Carga la textura de un tile usando el tema de su grupo (piso o muro). Si el
## tema de ese grupo no tiene el tile, hace fallback al tema base.
func _tex(name: String) -> Texture2D:
	var group := _theme_for(name)
	var key := group + "/" + name
	if _tile_tex.has(key):
		return _tile_tex[key]
	var p := "res://assets/frames/%s/%s.png" % [group, name] if group != "base" else "res://assets/frames/%s.png" % name
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p)
	if t == null and group != "base":
		p = "res://assets/frames/%s.png" % name
		if ResourceLoader.exists(p):
			t = load(p)
	_tile_tex[key] = t
	return t

var map_rect := Rect2()

var _rooms: Array[Rect2i] = []
var _floor := {}        # Vector2i -> true (pisable)
var _enemies: Array = []
var _ore_cells := {}    # Vector2i -> Nodo ore (bloquea hasta romperse)
var _used_cells := {}   # celda -> true (enemigos/minerales/forja)
var _forge_cell := Vector2i(-10000, -10000)
var _boss: Node2D = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_generate()

## Sala santuario del jefe: la sala con el centro MÁS LEJANO al spawn (diseño
## previsto). Si algún layout queda compacto, el mejor intento es reforzado con
## la celda de piso más lejana a >= 14 tiles.
func _boss_cell() -> Vector2i:
	var spawn: Vector2i = _rooms[0].get_center()
	var best: Vector2i = spawn
	var best_d := -1.0
	# 1) prioridad: el centro de la sala más lejana al spawn (alcanzable, hay
	#    pasillos hacia todas las salas).
	for i in range(1, _rooms.size()):
		var c: Vector2i = _rooms[i].get_center()
		if not _floor.has(c):
			continue
		var d := c.distance_to(spawn)
		if d > best_d:
			best_d = d
			best = c
	# 2) refuerzo: si hay alguna celda de piso a >= 14 tiles y más lejana, el
	#    jefe espera ahí (evita layouts demasiado compactos donde la sala más
	#    lejana todavía queda cerca).
	for cell in _floor:
		var c: Vector2i = cell
		var d := c.distance_to(spawn)
		if d >= 14.0 and d > best_d:
			best_d = d
			best = c
	return best

# ---------- API ----------

func is_solid(cell: Vector2i) -> bool:
	return not _floor.has(cell) or _ore_cells.has(cell) or cell == _forge_cell

func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE / 2.0)

func local_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / TILE), floori(world.y / TILE))

func apply_camera_bounds(cam: Camera2D) -> void:
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_rect.size.x)
	cam.limit_bottom = int(map_rect.size.y)

func enemy_at(cell: Vector2i) -> Node2D:
	for e in _enemies:
		if e != null and is_instance_valid(e):
			if local_to_cell(e.global_position) == cell:
				return e
	return null

func ore_at(cell: Vector2i) -> Node2D:
	return _ore_cells.get(cell)

func forge_cell() -> Vector2i:
	return _forge_cell

# ---------- generador ----------

func _generate() -> void:
	_rng.randomize()
	_enemies.clear()
	_ore_cells.clear()
	_used_cells.clear()
	_forge_cell = Vector2i(-10000, -10000)
	map_rect = Rect2(0.0, 0.0, float(width) * TILE, float(height) * TILE)

	# Reintenta el layout hasta que el santuario del jefe pueda quedar a >= 14
	# tiles del spawn (los layouts compactos dejarían el jefe demasiado cerca).
	for attempt in 40:
		_build_layout()
		if _layout_spread() >= 14.0:
			break

	_render()

	_spawn_player()
	_spawn_enemies()
	_spawn_boss()
	_spawn_forge()
	_spawn_ores()
	_scatter_potions()

## Siembra pociones tiradas en el piso: flask_red en celdas libres a cierta
## distancia del spawn. La cantidad la controla `potions_on_floor`.
func _scatter_potions() -> void:
	if potions_on_floor <= 0:
		return
	var spawn: Vector2i = _rooms[0].get_center()
	var boss_cell: Vector2i = _boss_cell()
	var cells: Array[Vector2i] = []
	for raw in _floor:
		var cell: Vector2i = raw
		if _used_cells.has(cell) or cell == boss_cell:
			continue
		if cell.distance_to(spawn) < 6.0:
			continue
		cells.append(cell)
	cells.shuffle()
	var placed := 0
	for cell in cells:
		if placed >= potions_on_floor:
			break
		spawn_drop(cell, "flask_red", 1, true)
		placed += 1

## Limpia y regenera salas + pasillos (layout procedural compartido).
func _build_layout() -> void:
	_floor.clear()
	_rooms.clear()
	_carve_rooms()
	_connect_rooms()

## Mayor distancia entre el centro del spawn y el centro de cualquier otra sala.
func _layout_spread() -> float:
	if _rooms.size() < 2:
		return 0.0
	var spawn: Vector2i = _rooms[0].get_center()
	var spread := 0.0
	for i in range(1, _rooms.size()):
		var d: float = _rooms[i].get_center().distance_to(spawn)
		if d > spread:
			spread = d
	return spread

func _carve_rooms() -> void:
	var attempts := ROOM_ATTEMPTS
	while _rooms.size() < ROOM_TARGET and attempts > 0:
		attempts -= 1
		var size := Vector2i(_rng.randi_range(5, 9), _rng.randi_range(4, 7))
		var pos := Vector2i(_rng.randi_range(2, width - size.x - 3), _rng.randi_range(2, height - size.y - 3))
		var rect := Rect2i(pos, size)
		if _overlaps_any(rect):
			continue
		_rooms.append(rect)
		for x in rect.size.x:
			for y in rect.size.y:
				_floor[rect.position + Vector2i(x, y)] = true

func _overlaps_any(r: Rect2i) -> bool:
	var grown := Rect2i(r.position - Vector2i.ONE, r.size + Vector2i(2, 2))
	for other in _rooms:
		if grown.intersects(other):
			return true
	return false

func _connect_rooms() -> void:
	var horiz_first := _rng.randi() % 2 == 0
	for i in range(1, _rooms.size()):
		var a: Vector2i = _rooms[i - 1].get_center()
		var b: Vector2i = _rooms[i].get_center()
		if horiz_first:
			_carve_h(a.x, b.x, a.y)
			_carve_v(a.y, b.y, b.x)
		else:
			_carve_v(a.y, b.y, a.x)
			_carve_h(a.x, b.x, b.y)

func _carve_h(x0: int, x1: int, y: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		_floor[Vector2i(x, y)] = true

func _carve_v(y0: int, y1: int, x: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		_floor[Vector2i(x, y)] = true

func _render() -> void:
	var ts := _build_tileset()

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floors"
	floor_layer.tile_set = ts
	add_child(floor_layer)

	var wall_layer := TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = ts
	wall_layer.z_index = 6
	add_child(wall_layer)

	for raw in _floor:
		var cell: Vector2i = raw
		floor_layer.set_cell(cell, 0, Vector2i(_floor_variant(cell), 0))

	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			if _floor.has(cell):
				continue
			if not _touches_floor(cell):
				continue
			# Solo WALL_MID por ahora (sin WALL_TOP): look de muro corrido.
			wall_layer.set_cell(cell, 0, Vector2i(0, 1))

## Variante de piso para una celda. Determinística (misma celda → mismo tile en
## cada corrida) y con floor_1 (índice 0) más prevalente según floor_1_weight.
## Las otras 7 variantes reparten el resto por igual.
func _floor_variant(cell: Vector2i) -> int:
	var r := (cell.x * 7 + cell.y * 13) % 12
	if r < floor_1_weight:
		return 0
	return (r - floor_1_weight) % 7 + 1

func _touches_floor(cell: Vector2i) -> bool:
	return _floor.has(cell + Vector2i.LEFT) or _floor.has(cell + Vector2i.RIGHT) or _floor.has(cell + Vector2i.UP) or _floor.has(cell + Vector2i.DOWN)

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = _build_atlas()
	src.texture_region_size = Vector2i(16, 16)
	for i in 8:
		src.create_tile(Vector2i(i, 0))
	for c in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]:
		src.create_tile(c)
	ts.add_source(src, 0)
	return ts

func _build_atlas() -> ImageTexture:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for i in FLOOR_COUNT:
		var src: Image = _tex("floor_%d" % (i + 1)).get_image()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	var walls := ["wall_mid", "wall_top_mid", "floor_stairs", "floor_ladder"]
	for i in walls.size():
		var src: Image = _tex(walls[i]).get_image()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 16))
	return ImageTexture.create_from_image(img)

# ---------- entidades ----------

func _spawn_player() -> void:
	var p := PLAYER_SCENE.instantiate()
	p.level = self
	p.z_index = ENTITY_Z
	p.position = to_world(_rooms[0].get_center())
	add_child(p)

func _spawn_enemies() -> void:
	var pool := ["goblin", "goblin", "wogol", "wogol", "wogol", "imp", "skelet", "skelet", "skelet", "pumpkin_dude", "masked_orc", "masked_orc", "orc_warrior", "big_zombie", "ogre", "big_demon"]
	var spawn: Vector2i = _rooms[0].get_center()
	var boss_cell: Vector2i = _boss_cell()
	var free: Array[Vector2i] = []
	for raw in _floor:
		var cell: Vector2i = raw
		if cell.distance_to(spawn) >= 8.0 and cell != boss_cell:
			free.append(cell)
	for t in pool:
		for tries in 60:
			var cell: Vector2i = free[_rng.randi_range(0, free.size() - 1)]
			if _used_cells.has(cell):
				continue
			_used_cells[cell] = true
			var e := ENEMY_SCENE.instantiate()
			e.level = self
			e.type = t
			e.z_index = ENTITY_Z
			e.position = to_world(cell)
			add_child(e)
			_enemies.append(e)
			break

## El Capitán de la Torre (2 fases) espera en la sala santuario, la más lejana
## al spawn. Muerto, no reaparece. Sus drops van por on_enemy_killed().
func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return
	var cell: Vector2i = _boss_cell()
	if not _floor.has(cell):
		return
	var e := ENEMY_SCENE.instantiate()
	e.level = self
	e.type = "capitan"
	e.z_index = ENTITY_Z
	e.position = to_world(cell)
	add_child(e)
	_enemies.append(e)
	_boss = e
	_used_cells[cell] = true

func _spawn_forge() -> void:
	var r: Rect2i = _rooms[0]
	_forge_cell = r.position + Vector2i(r.size.x - 2, 1)
	var f := FORGE_SCENE.instantiate()
	f.position = to_world(_forge_cell)
	add_child(f)
	_used_cells[_forge_cell] = true

func _spawn_ores() -> void:
	var spawn: Vector2i = _rooms[0].get_center()
	var free: Array[Vector2i] = []
	for raw in _floor:
		var cell: Vector2i = raw
		if not _used_cells.has(cell) and cell != _forge_cell:
			free.append(cell)
	var tiers := [
		{"kind": "madera", "count": 5, "min_dist": 4.0},
		{"kind": "cobre", "count": 3, "min_dist": 6.0},
		{"kind": "hierro", "count": 2, "min_dist": 8.0},
		{"kind": "plata", "count": 1, "min_dist": 10.0},
	]
	for tier in tiers:
		var placed := 0
		for tries in 200:
			if placed >= int(tier["count"]):
				break
			var cell: Vector2i = free[_rng.randi_range(0, free.size() - 1)]
			if _used_cells.has(cell) or cell.distance_to(spawn) < float(tier["min_dist"]):
				continue
			var o := ORE_SCENE.instantiate()
			o.kind = tier["kind"]
			o.level = self
			o.position = to_world(cell)
			add_child(o)
			_ore_cells[cell] = o
			_used_cells[cell] = true
			placed += 1

## Loot adicional por tipo de enemigo: armas y frascos. Cada entrada es
## [id, probabilidad]; el jefe (capitan) siempre suelta su espada + un frasco.
## Las armas nuevas (Lanza, Arco, Machete, Martillo, Hacha doble, Báculos, etc.)
## vienen de los frames del pack y son completamente equipables desde el drop.
const ENEMY_LOOT := {
	"wogol": {"weapons": [["weapon_knife", 0.05]], "flasks": [["flask_red", 0.12]]},
	"goblin": {"weapons": [["weapon_throwing_axe", 0.06], ["weapon_knife", 0.04]], "flasks": [["flask_red", 0.1]]},
	"imp": {"weapons": [["weapon_knife", 0.05]], "flasks": [["flask_blue", 0.08]]},
	"skelet": {"weapons": [["weapon_rusty_sword", 0.12], ["weapon_axe", 0.05]], "flasks": [["flask_red", 0.15]]},
	"pumpkin_dude": {"weapons": [["weapon_machete", 0.1], ["weapon_bow", 0.08]], "flasks": [["flask_yellow", 0.08]]},
	"masked_orc": {"weapons": [["weapon_mace", 0.12], ["weapon_katana", 0.08]], "flasks": [["flask_red", 0.2], ["flask_blue", 0.05]]},
	"orc_warrior": {"weapons": [["weapon_waraxe", 0.15], ["weapon_saw_sword", 0.1]], "flasks": [["flask_blue", 0.15]]},
	"big_zombie": {"weapons": [["weapon_hammer", 0.12], ["weapon_cleaver", 0.08]], "flasks": [["flask_red", 0.18]]},
	"ogre": {"weapons": [["weapon_big_hammer", 0.2], ["weapon_double_axe", 0.12]], "flasks": [["flask_red", 0.22]]},
	"big_demon": {"weapons": [["weapon_knight_sword", 0.15], ["weapon_red_gem_sword", 0.1]], "flasks": [["flask_yellow", 0.15]]},
	"capitan": {"weapons": [["weapon_golden_sword", 1.0]], "flasks": [["flask_red", 1.0]]},
}

func on_enemy_killed(enemy: Node2D) -> void:
	_enemies.erase(enemy)
	var was_boss := enemy == _boss
	if enemy == _boss:
		_boss = null
	var cell: Vector2i = local_to_cell(enemy.global_position)
	spawn_drop(cell, "coin", enemy.drop_coins())
	if randf() < enemy.drop_chance():
		spawn_drop(cell, enemy.drop_resource(), 1)
	# Loot nuevo: armas y frascos según el tipo de enemigo vencido.
	var loot: Dictionary = ENEMY_LOOT.get(enemy.type, {})
	for table_key in ["weapons", "flasks"]:
		var table: Array = loot.get(table_key, [])
		for entry in table:
			if randf() < float(entry[1]):
				spawn_drop(cell, String(entry[0]), 1)
	# Si el que cayó fue el Capitán, la mazmorra está ganada → festejo.
	if was_boss:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("show_victory")

func on_ore_broken(node: Node2D) -> void:
	var cell: Vector2i = local_to_cell(node.global_position)
	_ore_cells.erase(cell)
	_used_cells.erase(cell)

func spawn_drop(cell: Vector2i, kind: String, amount: int, scatter := false) -> void:
	var d := DROP_SCENE.instantiate()
	d.level = self
	d.kind = kind
	d.amount = amount
	d.scatter = scatter
	d.position = to_world(cell)
	add_child(d)

func spawn_text(cell: Vector2i, text: String) -> void:
	var t := FLOAT_TEXT_SCENE.instantiate()
	t.position = to_world(cell)
	t.get_node("Label").text = text
	add_child(t)

## GFX de ataque: arco de espada en world centrado en `world` y orientado según
## la dirección `dir` (celda adyacente atacada). El nodo se auto-elimina.
func spawn_attack_arc(world: Vector2, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var arc := ATTACK_ARC.new()
	arc.global_position = world
	arc.rotation = Vector2(dir).angle()
	add_child(arc)
