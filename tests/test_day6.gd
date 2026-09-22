extends Node
## Test: inventario inicial (cuchillo + frasco rojo), auto-equip (mejor
## arma sube el daño), frasco que cura y consume, atlas de muros OK y drops de
## arma/frasco con textura propia.
## Uso: godot --headless --path . res://tests/test_day6.tscn

const Gear := preload("res://scripts/items.gd")

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
	var player: Node2D = players[0]

	# 1) Inventario inicial: arma simple + frasco rojo.
	var inv: Dictionary = await Chain.get_inventory()
	if inv.get("weapon_knife", 0) != 1 or inv.get("flask_red", 0) != 1:
		push_error("inventario inicial sin arma/frasco: %s" % str(inv))
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.3).timeout  # espera el _refresh_pick post-sync
	var dmg := int(player.get("attack_damage"))
	print("ataque inicial: %d (esperado 12)" % dmg)
	if dmg != 12 or str(player.get("equipped_weapon")) != "weapon_knife":
		push_error("auto-equip inicial mal: dmg=%d eq=%s" % [dmg, player.get("equipped_weapon")])
		get_tree().quit(1)
		return

	# 2) Llegar un arma mejor → auto-equip y sube el daño.
	var made: Dictionary = await Chain.claim_drop("weapon_regular_sword")
	if not made.get("ok", false):
		push_error("claim_drop weapon falló")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.3).timeout
	dmg = int(player.get("attack_damage"))
	print("ataque con espada común: %d (esperado 15)" % dmg)
	if dmg != 15 or str(player.get("equipped_weapon")) != "weapon_regular_sword":
		push_error("auto-equip mejor arma mal: dmg=%d eq=%s" % [dmg, player.get("equipped_weapon")])
		get_tree().quit(1)
		return

	# 3) Frasco rojo: consume 1 y cura 25 (40 -> 65).
	player.set("hp", 40)
	var used: Dictionary = await Chain.use_item("flask_red")
	if not used.get("ok", false):
		push_error("use_item frasco falló: %s" % str(used))
		get_tree().quit(1)
		return
	var healed := int(player.call("heal", Gear.FLASK_HEAL))
	print("hp 40 -> %d (curado %d)" % [int(player.get("hp")), healed])
	if int(player.get("hp")) != 65 or healed != 25:
		push_error("curado mal: hp=%d healed=%d" % [int(player.get("hp")), healed])
		get_tree().quit(1)
		return
	var inv2: Dictionary = await Chain.get_inventory()
	if inv2.get("flask_red", 0) != 0:
		push_error("el frasco no se consumió: %s" % str(inv2))
		get_tree().quit(1)
		return

	# 4) Atlas: muros (WALL_MID) se construyen sin problema.
	var atlas_tex: Texture2D = level._build_atlas()
	print("atlas ok: %s (8x2 tiles)" % (atlas_tex != null))
	if atlas_tex == null:
		push_error("atlas no se construyó")
		get_tree().quit(1)
		return

	# 5) Drops de arma y frasco muestran su textura propia.
	level.spawn_drop(level.local_to_cell(player.global_position) + Vector2i(0, 3), "weapon_knife", 1)
	level.spawn_drop(level.local_to_cell(player.global_position) + Vector2i(2, 3), "flask_red", 1)
	await get_tree().create_timer(0.1).timeout
	var with_tex := 0
	for d in get_tree().get_nodes_in_group("drops"):
		var sf: AnimatedSprite2D = d.get_node("Sprite")
		if String(sf.animation) == "idle" and sf.sprite_frames.get_frame_texture("idle", 0) != null:
			with_tex += 1
	print("drops con textura propia: %d/2" % with_tex)
	if with_tex < 2:
		push_error("los drops de arma/frasco no cargan textura")
		get_tree().quit(1)
		return

	# 6) Pociones tiradas en el piso: cantidad controlada por potions_on_floor.
	var floor_pots := get_tree().get_nodes_in_group("floor_drops")
	var expected := int(level.get("potions_on_floor"))
	print("pociones en el piso: %d (variable=%d)" % [floor_pots.size(), expected])
	if expected <= 0:
		push_error("variable potions_on_floor debería estar configurada")
		get_tree().quit(1)
		return
	if floor_pots.size() != expected:
		push_error("se sembraron %d pociones en vez de %d" % [floor_pots.size(), expected])
		get_tree().quit(1)
		return

	# 7) Forja con suerte: mandoble_hierro (base 18) → token único con stats
	#    aleatorias dentro de [18..26]. Siempre supera a la espada común (15),
	#    así que el auto-equip tiene que tomarla.
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	var cr: Dictionary = await Chain.craft("mandoble_hierro")
	if not cr.get("ok", false):
		push_error("craft mandoble_hierro falló: %s" % str(cr))
		get_tree().quit(1)
		return
	var token: String = str(cr.get("token", ""))
	if not token.begins_with("mandoble_hierro_f"):
		push_error("no se creó token forjado: %s" % str(cr))
		get_tree().quit(1)
		return
	var fg: Dictionary = Chain.get_forged_stats(token)
	var cdmg := int(cr.get("dmg", 0))
	var cq := int(fg.get("quality", 0))
	if fg == {} or cdmg < 18 or cdmg > 26:
		push_error("stats forjadas fuera de rango: %s" % str(cr))
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.3).timeout  # _refresh_pick post-sync
	if str(player.get("equipped_weapon")) != token or int(player.get("attack_damage")) != cdmg:
		push_error("auto-equip no tomó la forjada: eq=%s dmg=%d vs %d" % [
			player.get("equipped_weapon"), player.get("attack_damage"), cdmg])
		get_tree().quit(1)
		return
	print("forja: %s dmg %d (%s)" % [token, cdmg, Gear.quality_name(cq)])

	print("=== TEST 6 OK ===")
	get_tree().quit()