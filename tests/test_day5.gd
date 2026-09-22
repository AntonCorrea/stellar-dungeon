extends Node
## Test: el Capitán de la Torre aparece en una sala lejana, entra en
## FASE 2 al llegar al 50% de HP, y al morir suelta el cosmético Tinte Real
## (on-chain). Con el Tinte en cartera, el jugador queda teñido de dorado.
## Uso: godot --headless --path . res://tests/test_day5.tscn

func _ready() -> void:
	await get_tree().process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var level = scene
	var boss: Node2D = level.get("_boss")
	if boss == null or not is_instance_valid(boss):
		push_error("no hay jefe (level._boss es null)")
		get_tree().quit(1)
		return
	if boss.type != "capitan":
		push_error("el jefe no es capitan: %s" % boss.type)
		get_tree().quit(1)
		return

	var spawn: Vector2i = level.local_to_cell(level._rooms[0].get_center())
	var boss_cell: Vector2i = level.local_to_cell(boss.global_position)
	var dist: float = spawn.distance_to(boss_cell)
	print("=== TEST 5 ===")
	print("jefe: %s hp=%d/%d en celda %s (a %.1f tiles del spawn)" % [boss.type, boss.hp, boss._max_hp, boss_cell, dist])
	if dist < 14.0:
		push_error("el jefe spawn demasiado cerca del spawn (%.1f)" % dist)
		get_tree().quit(1)
		return

	var max_hp: int = boss._max_hp
	boss.take_damage(int(max_hp / 2) - 1)
	print("tras -%d dmg: hp=%d phase=%s" % [int(max_hp / 2) - 1, boss.hp, boss.phase])
	if boss.phase != 1:
		push_error("no debería entrar en fase 2 aún (missed by 1)")
		get_tree().quit(1)
		return

	boss.take_damage(10)
	print("tras otro golpe: hp=%d phase=%s" % [boss.hp, boss.phase])
	if boss.phase != 2:
		push_error("no entró en FASE 2 al cruzar el 50% de HP")
		get_tree().quit(1)
		return

	# Matarlo → suelta 20 monedas + Tinte Real (drop_chance 1.0)
	boss.take_damage(999)
	await get_tree().create_timer(0.6).timeout
	var drops := get_tree().get_nodes_in_group("drops")
	print("drops tras matar el jefe: %d" % drops.size())
	var found_tinte := false
	var drop: Node2D = null
	for d in drops:
		if d.kind == "tinte_real":
			found_tinte = true
			drop = d
	if not found_tinte:
		push_error("el jefe no soltó el Tinte Real")
		get_tree().quit(1)
		return

	# Recogerlo: pisar la celda → Chain.claim_drop mint el cosmético.
	var players := get_tree().get_nodes_in_group("player")
	var player: Node2D = players[0]
	player.global_position = level.to_world(level.local_to_cell(drop.global_position))
	await get_tree().create_timer(0.8).timeout
	var inv: Dictionary = await Chain.get_inventory()
	print("inventario: %s" % str(inv))
	if inv.get("tinte_real", 0) != 1:
		push_error("el Tinte Real no llegó a la cartera")
		get_tree().quit(1)
		return

	print("tesoro: %d (monedas del jefe)" % Chain.get_treasure())
	if Chain.get_treasure() < 20:
		push_error("las monedas del jefe no sumaron tesoro")
		get_tree().quit(1)
		return
	print("=== TEST 5 OK ===")
	get_tree().quit()