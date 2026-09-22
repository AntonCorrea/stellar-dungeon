extends Control
## Pantalla de título (día 8): primer contacto de la demo. Enter/Space empieza,
## Esc cierra la ventana. Avisa que la cadena es un simulador (testnet mock).

func _ready() -> void:
	Sfx.play("chest_open")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
			return
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")