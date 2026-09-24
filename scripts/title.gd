extends Control
## Pantalla de título: primer contacto de la demo. Enter/Space empieza,
## Tab conecta al relé hosteado (Render) en vez de jugar en modo mock local,
## Esc cierra la ventana.

## Relé público de demo (Render, plan free — puede tardar ~30-50s en
## despertar si nadie lo usó en un rato). Ver stellar-dungeon-backend/relay
## → README "Hosting gratis (Render)".
const DEFAULT_RELAY_URL := "https://stellar-dungeon-relay.onrender.com"

@onready var _conn_label: Label = $Center/VBox/ConnMode

## true entre pedir la conexión y que boot() del relé resuelva (sync_finished).
var _connecting := false

func _ready() -> void:
	Sfx.play("chest_open")
	if Chain.backend == "relay":
		# Ya viene conectado (CHAIN_BACKEND=relay por env, tests/demo local):
		# no lo pisamos, solo reflejamos el estado mientras resuelve.
		_connecting = true
		Chain.sync_finished.connect(_on_first_sync, CONNECT_ONE_SHOT)
	_update_conn_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
			return
		if event.keycode == KEY_TAB:
			_connect_to_server()
			return
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _connect_to_server() -> void:
	if Chain.backend == "relay":
		return # ya conectado (Tab de nuevo, o CHAIN_BACKEND=relay)
	_connecting = true
	Chain.sync_finished.connect(_on_first_sync, CONNECT_ONE_SHOT)
	Chain.connect_to_relay(DEFAULT_RELAY_URL)
	_update_conn_label()

func _on_first_sync() -> void:
	_connecting = false
	_update_conn_label()

func _update_conn_label() -> void:
	if Chain.backend != "relay":
		_conn_label.text = "Modo: OFFLINE (local) · Tab: conectar al servidor"
	elif _connecting:
		_conn_label.text = "Modo: SERVIDOR — conectando… (puede tardar si estaba dormido)"
	else:
		_conn_label.text = "Modo: SERVIDOR — cartera %s…" % Chain.get_wallet_address().substr(0, 10)