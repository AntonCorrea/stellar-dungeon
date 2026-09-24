extends Node
## Chain over HTTP — el "mozo" (F7). Traduce los MISMOS verbos que el mock
## Chain.gd a llamadas HTTP contra el relé Node (stellar/relay). El relé a su
## vez forja contra el contrato forge_ledger en testnet; la calidad la tira el
## CONTRATO, no este script ni el juego.
##
## La interfaz la define chain.gd (spec congelada) y NO cambia acá; este archivo
## solo implementa el transporte. Shapes de respuesta idénticos a los del mock
## (relay/src/routes.js):
##   escrituras → {ok:true, action, …, hash}  |  {ok:false, reason}
##   lecturas   → datos directo (inventory → dict, leaderboard → array…)
##
## Identidad: el relé real expone dev_player en /health (la keypair que el relé
## puede firmar). En modo mock del relé usamos la dirección local del mock.

signal sync_finished

## Semáforo interno: se emite al liberar el HTTPRequest (ver _send).
signal _released

## Dirección de respaldo cuando el relé corre en modo mock (no expone
## dev_player): la misma del mock de chain.gd para que el store coincida.
const FALLBACK_PLAYER := "GBAY3NQ5WQM6YZD2LM5DT2Q4O7ZFHQGQ"

var relay_url := "http://localhost:8787"
## Jugador con el que se juega (definido por /health en modo real).
var player := FALLBACK_PLAYER
## Contador local de escrituras iniciadas por este cliente (el relé mantiene
## el oficial por jugador en /wallet/{addr}).
var tx_count := 0

## Tokens forjados VISTOS: token -> {base, quality, dmg}. Se puebla con el
## craft de la sesión y con las forjas on-chain del jugador (boot).
var _forged := {}
## Cache del tesoro (GET /treasure/{addr} al boot; POST /treasure al sumar).
var _treasure := 0

var _http: HTTPRequest
var _token_re := RegEx.new()

# Semáforo: HTTPRequest de Godot no encola pedidos, así que serializamos.
var _busy := false
## True apenas boot() resolvió player (los verbos esperan esto).
var _identity_ready := false

func _ready() -> void:
	var env_url := OS.get_environment("CHAIN_URL")
	if not env_url.is_empty():
		relay_url = env_url
	_token_re.compile("_f\\d+$")
	_http = HTTPRequest.new()
	add_child(_http)
	# Fire-and-forget: Godot sigue la coroutine aunque se ignore el retorno.
	boot()

## Handshake: descubre la identidad y precarga cartera + tesoro on-chain.
func boot() -> void:
	var health: Variant = await _http_get("/health")
	if health is Dictionary and health.get("ok") == true:
		var dev: String = str(health.get("dev_player", ""))
		if not dev.is_empty():
			player = dev
	# Identidad lista: los verbos pueden salir a la red con una dirección que
	# el relé real sepa interpretar (la fake GBAY… del mock no existe on-chain
	# y playerWeapons respondería 500).
	_identity_ready = true
	# Precarga (no bloquea los verbos): inventario y stats de tokens on-chain.
	var inv := await get_inventory()
	for key in inv:
		if _token_re.search(String(key)) != null:
			var stats := await _fetch_forge_stats(String(key))
			if not stats.is_empty():
				_forged[String(key)] = stats
	var treasure: Variant = await _http_get("/treasure/" + player)
	if treasure is int:
		_treasure = treasure
	sync_finished.emit()

## Espera (máx. 5 s) a que boot resuelva la identidad.
func _await_identity() -> void:
	var waited := 0.0
	while not _identity_ready and waited < 5.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05

# ---------- escrituras (una por verbo del mock) ----------

## Mintear 1 recurso al romper un nodo de minería.
func mine(ore_id: String) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/mine", {"player": player, "ore_id": ore_id})
	_bump(res)
	return res

## Drop de recurso desde un enemigo vencido.
func claim_drop(ore_id: String) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/claim_drop", {"player": player, "ore_id": ore_id})
	_bump(res)
	return res

## Forjar: el relé quema los materiales SOLO si el forge on-chain tuvo éxito y
## devuelve la calidad que tiró el CONTRATO ({token, quality, dmg}).
func craft(recipe_id: String) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/craft", {"player": player, "recipe": recipe_id})
	if res.get("ok") == true:
		tx_count += 1
		if res.has("token"):
			_forged[String(res.token)] = {
				"base": recipe_id, "quality": res.quality, "dmg": res.dmg,
			}
	sync_finished.emit()
	return res

## Usar un consumible (frascos): lo descuenta el relé (off-chain).
func use_item(item_id: String) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/use_item", {"player": player, "item_id": item_id})
	_bump(res)
	return res

## Transferir: el relé decide si el ítem es token on-chain (contrato) o plano.
func transfer(item_id: String, to_player: String) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/transfer",
		{"player": player, "item_id": item_id, "to_player": to_player})
	_bump(res)
	return res

## Monedas → tesoro del leaderboard.
func add_treasure(amount: int) -> Dictionary:
	await _await_identity()
	var res := await _http_post("/treasure", {"player": player, "amount": amount})
	if res.get("ok") == true:
		tx_count += 1
		_treasure = int(res.get("total", _treasure))
	sync_finished.emit()
	return res

# ---------- lecturas ----------

## Inventario compuesto: recursos/ítems del relé + tokens forjados (on-chain).
func get_inventory() -> Dictionary:
	await _await_identity()
	var res: Variant = await _http_get("/inventory/" + player)
	if res is Dictionary and not res.has("ok"):
		return res
	return {}

## Stats del arma forjada (cache; vacío si el token no se vio).
func get_forged_stats(token_id: String) -> Dictionary:
	return _forged.get(token_id, {})

## Leaderboard del relé (NPC + jugadores reales), top 10.
func get_leaderboard() -> Array:
	await _await_identity()
	var res: Variant = await _http_get("/leaderboard")
	return res if res is Array else []

func get_treasure() -> int:
	return _treasure

## Dirección pública de la cartera con la que se juega.
func get_wallet_address() -> String:
	return player

func get_forged_count() -> int:
	return _forged.size()

# ---------- transporte ----------

func _bump(res: Dictionary) -> void:
	if res.get("ok") == true:
		tx_count += 1
	sync_finished.emit()

func _http_post(path: String, body: Dictionary) -> Dictionary:
	return await _send(HTTPClient.METHOD_POST, path, JSON.stringify(body))

func _http_get(path: String) -> Variant:
	return await _send(HTTPClient.METHOD_GET, path, "")

## Fetch de metadata de un token forjado directo al relé (puebla el cache).
func _fetch_forge_stats(token: String) -> Dictionary:
	var res: Variant = await _http_get("/forge-stats/" + token)
	if res is Dictionary and res.get("ok") != false:
		return res
	return {}

## Un pedido por vez: espera a que el HTTPRequest esté libre.
func _send(method: HTTPClient.Method, path: String, body: String) -> Variant:
	while _busy:
		await _released
	_busy = true
	var err: int = _http.request(relay_url + path,
		["Content-Type: application/json"], method, body)
	if err != OK:
		_busy = false
		_released.emit()
		return {"ok": false, "reason": "http error %d" % err}
	var result: Array = await _http.request_completed
	_busy = false
	_released.emit()
	var status: int = result[1]
	if status != 200:
		return {"ok": false, "reason": "http %d" % status}
	return JSON.parse_string(result[3].get_string_from_utf8())