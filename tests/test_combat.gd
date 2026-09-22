extends Node
## Test end-to-end: ataque del player → daño, muerte → drops,
## pickup del drop → tesoro registrado en el mock Chain (on-chain).
## Uso: godot --headless --path . res://tests/test_combat.tscn

func _ready() -> void:
	await get_tree().process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var level = scene
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_error("no hay player")
		get_tree().quit(1)
		return
	var player: CharacterBody2D = players[0]

	# Enemigo controlado al lado del player
	var cell: Vector2i = level.local_to_cell(player.global_position) + Vector2i.RIGHT
	if level.is_solid(cell) or level.enemy_at(cell) != null:
		push_error("celda de prueba ocupada")
		get_tree().quit(1)
		return
	var enemy = load("res://scenes/enemy.tscn").instantiate()
	enemy.level = level
	enemy.type = "wogol"
	enemy.position = level.to_world(cell)
	level.add_child(enemy)
	level._enemies.append(enemy)
	await get_tree().process_frame

	var hp_start: int = enemy.hp
	player._try_attack()
	await get_tree().process_frame
	print("ataque: hp %d -> %d" % [hp_start, enemy.hp])
	if enemy.hp >= hp_start:
		push_error("el ataque no hizo daño")
		get_tree().quit(1)
		return

	# Matar → drops
	enemy.take_damage(999)
	await get_tree().process_frame
	var drops := get_tree().get_nodes_in_group("drops")
	print("drops tras matar: %d" % drops.size())
	if drops.size() == 0:
		push_error("no hubo drops")
		get_tree().quit(1)
		return

	# Pisar el drop (teleport al centro de su celda)
	player.global_position = level.to_world(level.local_to_cell(drops[0].global_position))
	await get_tree().create_timer(0.6).timeout
	var inv: Dictionary = await Chain.get_inventory()
	print("tesoro: %d | inventario: %s" % [Chain.get_treasure(), str(inv)])
	if Chain.get_treasure() < 1:
		push_error("el drop no sumó tesoro")
		get_tree().quit(1)
		return
	print("=== TEST COMBATE OK ===")
	get_tree().quit()