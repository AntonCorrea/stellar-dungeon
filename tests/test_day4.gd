extends Node
## Test: minar un barril de madera → recurso on-chain; forjar pico_cobre
## quema los materiales y lo mintea; el player sube su poder de mina con el pico.
## Uso: godot --headless --path . res://tests/test_day4.tscn

func _ready() -> void:
	await get_tree().process_frame
	print("[1] instanciando main…")
	var scene = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	print("[2] frames OK")
	await get_tree().process_frame

	var level = scene
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_error("no hay player")
		get_tree().quit(1)
		return
	var player: CharacterBody2D = players[0]
	print("[3] player hallado; buscando barril de madera…")

	var ore = _find_ore(level, "madera")
	if ore == null:
		push_error("no hay barril de madera")
		get_tree().quit(1)
		return
	var ore_cell: Vector2i = level.local_to_cell(ore.global_position)
	print("[4] barril en %s; colocando player al lado…" % str(ore_cell))
	if not _place_adjacent(player, level, ore_cell):
		push_error("no hay celda libre al lado del barril")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	print("[5] minando… dureza=%d poder=%d" % [ore.toughness(), player.mine_power])

	var guardas := 0
	while is_instance_valid(ore) and guardas < 20:
		player._try_attack()
		await get_tree().create_timer(0.4).timeout
		guardas += 1

	print("[6] minado: %d swings" % guardas)

	var inv: Dictionary = await Chain.get_inventory()
	print("madera en cartera tras minar: %d" % inv.get("madera", 0))
	if inv.get("madera", 0) < 1:
		push_error("no se minteó madera")
		get_tree().quit(1)
		return

	# forjar pico_cobre (quema 1 madera + 1 cobre; el cobre llega por drop de enemigo)
	await Chain.claim_drop("cobre")
	var res: Dictionary = await Chain.craft("pico_cobre")
	print("craft pico_cobre: ok=%s hash=%s" % [res.get("ok"), str(res.get("hash", "")).substr(0, 10)])
	if not res.get("ok", false):
		push_error("la forja falló: " + str(res.get("reason")))
		get_tree().quit(1)
		return
	inv = await Chain.get_inventory()
	print("inventario: %s" % str(inv))
	if inv.get("pico_cobre", 0) != 1:
		push_error("la forja no minteó el pico_cobre")
		get_tree().quit(1)
		return
	if inv.get("madera", 0) != 0 or inv.get("cobre", 0) != 0:
		push_error("la receta no quemó los materiales (madera/cobre deben ser 0)")
		get_tree().quit(1)
		return

	await player._refresh_pick()
	print("mine_power: %d (esperado 3 con pico_cobre)" % player.mine_power)
	if player.mine_power != 3:
		push_error("no mejoró el poder de mina")
		get_tree().quit(1)
		return
	print("=== TEST 4 OK ===")
	get_tree().quit()

func _find_ore(level, kind: String):
	for cell in level._ore_cells:
		var o = level._ore_cells[cell]
		if o.kind == kind:
			return o
	return null

func _place_adjacent(player: Node2D, level, ore_cell: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d in dirs:
		var c: Vector2i = ore_cell + d
		if level.is_solid(c):
			continue
		if level.enemy_at(c) != null:
			continue
		if level.ore_at(c) != null:
			continue
		player.global_position = level.to_world(c)
		return true
	return false