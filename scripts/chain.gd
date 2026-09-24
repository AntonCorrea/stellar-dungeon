extends Node
## Chain — capa Stellar. SPEC CONGELADA (21/9).
## Interfaz de contrato on-chain: ver `../stellar-dungeon-backend/chain-spec.md`.
## NO cambiar firmas: el backend real (relé Node + contrato Rust forge_ledger)
## se enchufa contra ESTA misma interfaz.
##
## Dos backends detrás de la misma puerta (F7):
##   "mock"  (default) → imitación local, jugable sin red.
##   "relay"           → HTTP al relé (scripts/chain_http.gd), que forja
##                       contra el contrato en testnet. La calidad la tira
##                       el CONTRATO, no el juego.
## Se elige con la variable de entorno CHAIN_BACKEND (tests/demo headless);
## URL opcional con CHAIN_URL (default http://localhost:8787).

signal sync_finished

## Backend activo. Default "mock": el juego sigue siendo 100% jugable offline.
var backend := "mock"
## Mozo HTTP (instancia de chain_http.gd) cuando backend == "relay".
var _net: Node

func _ready() -> void:
	## Desktop/headless (tests, demo local): variables de entorno.
	## Build Web (itch.io, etc.): no hay entorno de proceso → se leen de la
	## URL (?backend=relay&url=https://tu-relay.onrender.com), ver web_query.gd.
	var want := OS.get_environment("CHAIN_BACKEND")
	if want.is_empty():
		want = WebQuery.get_param("backend")
	if want.to_lower() == "relay":
		backend = "relay"
		_net = preload("res://scripts/chain_http.gd").new()
		add_child(_net)
		var url := OS.get_environment("CHAIN_URL")
		if url.is_empty():
			url = WebQuery.get_param("url")
		if not url.is_empty():
			_net.relay_url = url
		# El HUD sigue escuchando SOLO a Chain.sync_finished: re-emitimos.
		_net.sync_finished.connect(sync_finished.emit)

## Gear: metadata de armas/frascos. Solo para leer constantes;
## el contrato sigue sin abrirse: se agrega el verbo use_item() abajo.
const Gear := preload("res://scripts/items.gd")

const FAKE_LATENCY := 0.2
const HASH_CHARS := "0123456789abcdef"

# 8 items LOCKED: 2 picos · 3 armas · 2 armaduras · 1 cosmético
const ITEMS := [
	"pico_madera", "pico_cobre", "espada_cobre", "mandoble_hierro",
	"hacha_plata", "escudo_cobre", "coraza_hierro", "tinte_real",
]

# 4 recetas LOCKED (queman recursos → mintean el item)
const RECIPES := {
	"pico_cobre": {"cost": {"madera": 1, "cobre": 1}},
	"espada_cobre": {"cost": {"madera": 1, "cobre": 2}},
	"mandoble_hierro": {"cost": {"hierro": 3}},
	"hacha_plata": {"cost": {"hierro": 2, "plata": 2}},
}

## Recetas de armas: al forjarlas se mintea un token ÚNICO con stats
## deterministas (la calidad la tira el mismo xorshift del contrato, ver Fase 4).
## El resto (picos) mintea el id plano.
const WEAPON_RECIPES := ["espada_cobre", "mandoble_hierro", "hacha_plata"]

# Calidades: bonus de daño según el index de tiro aleatorio (ver _roll_quality).
const QUALITY_BONUS := [0, 2, 4, 8]

# El jugador nace con un pico_madera, un arma simple (cuchillo) y un frasco
# rojo en su cartera (mint inicial del backend).
var _inventory := {"pico_madera": 1, Gear.START_WEAPON: 1, Gear.START_FLASK: 1}
var _treasure := 0
## Armas forjadas: token_id -> {"base":, "quality": int, "dmg": int}.
## Cada token es único (escritura inmutable del contrato, como un NFT).
var _forged := {}
var _next_weapon := 0
var _leaderboard := [
	{"name": "Sir Ganso", "treasure": 120},
	{"name": "Doña Pulga", "treasure": 95},
	{"name": "Vos ?", "treasure": 0},
]

## Cartera del mock: dirección testnet (Stellar: empieza con G) para que el HUD
## muestre "prueba on-chain viva" en la demo. El relé real la reemplaza.
const WALLET_ADDR := "GBAY3NQ5WQM6YZD2LM5DT2Q4O7ZFHQGQ"
## Transacciones firmadas por el mock: cada escritura (mine/claim/craft/use/
## transfer/treasure) suma 1 al txn counter que ve la UI.
var _tx_count := 0

# ---------- escrituras (en producción las firma el relé) ----------

## Mintear 1 recurso al romper un nodo de minería.
func mine(ore_id: String) -> Dictionary:
	if backend == "relay":
		return await _net.mine(ore_id)
	await _latency()
	_inventory[ore_id] = _inventory.get(ore_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "mine", "ore_id": ore_id, "balance": _inventory[ore_id]})

## Drop de recurso desde un enemigo vencido (mismo verbo minteo que mine).
func claim_drop(ore_id: String) -> Dictionary:
	if backend == "relay":
		return await _net.claim_drop(ore_id)
	await _latency()
	_inventory[ore_id] = _inventory.get(ore_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "claim_drop", "ore_id": ore_id, "balance": _inventory[ore_id]})

## Forjar: quema recursos. Las armas (WEAPON_RECIPES) mintean un token ÚNICO
## con stats deterministas (calidad = xorshift(seed), seed = contador de forja)
## que el contrato forge_ledger replica con la MISMA seed; el resto (picos)
## mintea el id plano. {ok:false} si falta material.
func craft(recipe_id: String) -> Dictionary:
	if backend == "relay":
		return await _net.craft(recipe_id)
	await _latency()
	if not RECIPES.has(recipe_id):
		return {"ok": false, "reason": "receta inexistente"}
	var cost: Dictionary = RECIPES[recipe_id].get("cost", {})
	for mat in cost:
		if _inventory.get(mat, 0) < int(cost[mat]):
			return {"ok": false, "reason": "falta %s" % mat}
	for mat in cost:
		_inventory[mat] -= int(cost[mat])
	if recipe_id in WEAPON_RECIPES:
		# Arma forjada: token único. La calidad la tira el MISMO xorshift del
		# contrato forge_ledger con seed = contador de forja (Fase 4: cruce
		# Godot↔Rust). El relé real usa exactamente esta seed para el mint.
		var token := "%s_f%d" % [recipe_id, _next_weapon]
		var q := Gear.roll_quality(_next_weapon)
		_next_weapon += 1
		var dmg: int = int(Gear.FORGE_WEAPONS[recipe_id]["dmg"]) + int(QUALITY_BONUS[q])
		_forged[token] = {"base": recipe_id, "quality": q, "dmg": dmg}
		_inventory[token] = 1
		sync_finished.emit()
		return _signed({"action": "craft", "recipe": recipe_id, "burned": cost,
			"token": token, "quality": q, "dmg": dmg})
	_inventory[recipe_id] = _inventory.get(recipe_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "craft", "recipe": recipe_id, "burned": cost})

func transfer(item_id: String, to_player: String) -> Dictionary:
	if backend == "relay":
		return await _net.transfer(item_id, to_player)
	await _latency()
	if _inventory.get(item_id, 0) <= 0:
		return {"ok": false, "reason": "no tenes ese item"}
	_inventory[item_id] -= 1
	sync_finished.emit()
	return _signed({"action": "transfer", "item_id": item_id, "to": to_player})

## Usar un consumible (frascos): lo descuenta de la cartera. En producción el
## relé firma el consumo y emite el evento heal al cliente.
func use_item(item_id: String) -> Dictionary:
	if backend == "relay":
		return await _net.use_item(item_id)
	await _latency()
	if _inventory.get(item_id, 0) <= 0:
		return {"ok": false, "reason": "no tenes ese item"}
	_inventory[item_id] -= 1
	var balance: int = _inventory.get(item_id, 0)
	if balance <= 0:
		_inventory.erase(item_id)
	sync_finished.emit()
	return _signed({"action": "use", "item": item_id, "balance": balance})

## Monedas recolectadas → suman al tesoro del leaderboard.
func add_treasure(amount: int) -> Dictionary:
	if backend == "relay":
		return await _net.add_treasure(amount)
	await _latency()
	_treasure += amount
	_leaderboard[2]["treasure"] += amount
	sync_finished.emit()
	return _signed({"action": "treasure", "amount": amount, "total": _treasure})

# ---------- lecturas (sin firma) ----------

func get_inventory() -> Dictionary:
	if backend == "relay":
		return await _net.get_inventory()
	await _latency()
	return _inventory.duplicate()

## Stats del arma forjada (vacío si el id no es un token forjado).
func get_forged_stats(token_id: String) -> Dictionary:
	if backend == "relay":
		return _net.get_forged_stats(token_id)
	return _forged.get(token_id, {})

func get_leaderboard() -> Array:
	if backend == "relay":
		return await _net.get_leaderboard()
	await _latency()
	return _leaderboard.duplicate(true)

func get_treasure() -> int:
	if backend == "relay":
		return _net.get_treasure()
	return _treasure

## Dirección pública de la cartera (mock testnet). El HUD la muestra cortada.
func get_wallet_address() -> String:
	if backend == "relay":
		return _net.get_wallet_address()
	return WALLET_ADDR

## Cantidad de transacciones firmadas por el mock (una por escritura).
func get_tx_count() -> int:
	if backend == "relay":
		return _net.tx_count
	return _tx_count

## Cantidad de armas forjadas (tokens únicos) en la cartera.
func get_forged_count() -> int:
	if backend == "relay":
		return _net.get_forged_count()
	return _forged.size()

# ---------- utilidades mock ----------

func _signed(data: Dictionary) -> Dictionary:
	data["ok"] = true
	data["hash"] = _fake_hash()
	_tx_count += 1
	return data

func _fake_hash() -> String:
	var h := ""
	for i in 64:
		h += HASH_CHARS[randi() % HASH_CHARS.length()]
	return h

func _latency() -> void:
	await get_tree().create_timer(FAKE_LATENCY).timeout
