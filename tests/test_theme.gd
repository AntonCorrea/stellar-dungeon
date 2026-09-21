extends Node
## Test de los selectores de tema de nivel.gd (floor_theme + wall_theme combinables).
## Uso: godot --headless --path . res://tests/test_theme.tscn

func _ready() -> void:
	await get_tree().process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.floor_theme = "jungle"   # pisos: jungle
	scene.wall_theme = "dessert"   # muros: dessert (combina)
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var level = scene
	var tex_floor: Texture2D = level._tex("floor_1")
	var tex_stairs: Texture2D = level._tex("floor_stairs")
	var tex_wall: Texture2D = level._tex("wall_mid")
	print("=== THEME TEST (floor jungle / wall dessert) ===")
	print("floor_1     -> %s" % tex_floor.resource_path)
	print("floor_stairs-> %s" % tex_stairs.resource_path)
	print("wall_mid    -> %s" % tex_wall.resource_path)
	if tex_floor == null or not tex_floor.resource_path.begins_with("res://assets/frames/jungle/"):
		push_error("floor jungle cargo floor_1 fuera de la carpeta jungle")
		get_tree().quit(1)
		return
	if tex_stairs == null or not tex_stairs.resource_path.begins_with("res://assets/frames/jungle/"):
		push_error("floor_stairs no sigue al tema de piso (jungle)")
		get_tree().quit(1)
		return
	if tex_wall == null or not tex_wall.resource_path.begins_with("res://assets/frames/dessert/"):
		push_error("wall_mid no sigue al tema de muro (dessert)")
		get_tree().quit(1)
		return
	print("=== THEME TEST OK (pisos y muros combinados) ===")
	get_tree().quit()