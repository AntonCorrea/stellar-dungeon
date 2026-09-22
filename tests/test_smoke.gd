extends Node
## Smoke test (modo escena): CORRE CON AUTOLOADS.
## Uso: godot --headless --path . res://tests/test_smoke.tscn

func _ready() -> void:
	await get_tree().process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var level = scene

	# HUD montado en main.tscn (CanvasLayer con corazones/tesoro/recursos)
	var hud: Node = scene.get_node_or_null("HUD")
	if hud == null:
		push_error("falta el HUD en main.tscn")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var heart_rects: Array = hud.get("_heart_rects")
	var heart_tex: Texture2D = heart_rects[0].get("texture")
	print("HUD OK: corazones con textura: %s" % (heart_tex != null))

	var players := get_tree().get_nodes_in_group("player")
	var enemies := get_tree().get_nodes_in_group("enemies")
	if players.size() == 0:
		push_error("no hay player")
		get_tree().quit(1)
		return
	var player: Node2D = players[0]

	var by_type := {}
	for e in enemies:
		var t: String = e.type
		by_type[t] = by_type.get(t, 0) + 1

	print("=== SMOKE TEST ===")
	print("rooms: %d | floor tiles: %d | enemies: %d (%s) | ores: %d | forge: %s" % [level._rooms.size(), level._floor.size(), enemies.size(), str(by_type), level._ore_cells.size(), level._forge_cell])
	player.take_damage(5)
	await get_tree().process_frame
	print("player hp tras golpe: %d/100 (dead=%s)" % [int(player.get("hp")), player.get("is_dead")])
	var inv: Dictionary = await Chain.get_inventory()
	print("inventario mock: %s" % str(inv))
	print("tesoro: %d" % Chain.get_treasure())
	print("=== SMOKE TEST OK ===")
	get_tree().quit()