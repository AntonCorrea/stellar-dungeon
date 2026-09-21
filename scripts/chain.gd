extends Node
## Chain — MOCK de la capa Stellar. SPEC CONGELADA (21/9).
## Interfaz de contrato con el Integrante B: ver `../stellar/chain-spec.md`.
## NO cambiar firmas: el backend real (relé Node + contrato Rust forge_ledger)
## se enchufa el día 5 contra ESTA misma interfaz.

signal sync_finished

## Gear: metadata de armas/frascos (apéndice día 6). Solo para leer constantes;
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

## Recetas de armas: al forjarlas se mintea un token ÚNICO con stats aleatorios
## (suerte: Común/Fina/Superior/Épica). El resto (picos) mintea el id plano.
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

# ---------- escrituras (en producción las firma el relé) ----------

## Mintear 1 recurso al romper un nodo de minería.
func mine(ore_id: String) -> Dictionary:
	await _latency()
	_inventory[ore_id] = _inventory.get(ore_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "mine", "ore_id": ore_id, "balance": _inventory[ore_id]})

## Drop de recurso desde un enemigo vencido (mismo verbo minteo que mine).
func claim_drop(ore_id: String) -> Dictionary:
	await _latency()
	_inventory[ore_id] = _inventory.get(ore_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "claim_drop", "ore_id": ore_id, "balance": _inventory[ore_id]})

## Forjar: quema recursos. Las armas (WEAPON_RECIPES) mintean un token único
## con stats aleatorios (suerte); el resto (picos) mintea el id plano.
## {ok:false} si falta material.
func craft(recipe_id: String) -> Dictionary:
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
		# Arma forjada con suerte: token único, stats aleatorios.
		var token := "%s_f%d" % [recipe_id, _next_weapon]
		_next_weapon += 1
		var q := _roll_quality()
		var dmg: int = int(Gear.FORGE_WEAPONS[recipe_id]["dmg"]) + int(QUALITY_BONUS[q])
		_forged[token] = {"base": recipe_id, "quality": q, "dmg": dmg}
		_inventory[token] = 1
		sync_finished.emit()
		return _signed({"action": "craft", "recipe": recipe_id, "burned": cost,
			"token": token, "quality": q, "dmg": dmg})
	_inventory[recipe_id] = _inventory.get(recipe_id, 0) + 1
	sync_finished.emit()
	return _signed({"action": "craft", "recipe": recipe_id, "burned": cost})

## Tiro de calidad con suerte: 55% Común · 25% Fina · 14% Superior · 6% Épica.
func _roll_quality() -> int:
	var r := randf()
	if r < 0.55:
		return 0
	if r < 0.80:
		return 1
	if r < 0.94:
		return 2
	return 3

func transfer(item_id: String, to_player: String) -> Dictionary:
	await _latency()
	if _inventory.get(item_id, 0) <= 0:
		return {"ok": false, "reason": "no tenes ese item"}
	_inventory[item_id] -= 1
	sync_finished.emit()
	return _signed({"action": "transfer", "item_id": item_id, "to": to_player})

## Usar un consumible (frascos): lo descuenta de la cartera. En producción el
## relé firma el consumo y emite el evento heal al cliente.
func use_item(item_id: String) -> Dictionary:
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
	await _latency()
	_treasure += amount
	_leaderboard[2]["treasure"] += amount
	sync_finished.emit()
	return _signed({"action": "treasure", "amount": amount, "total": _treasure})

# ---------- lecturas (sin firma) ----------

func get_inventory() -> Dictionary:
	await _latency()
	return _inventory.duplicate()

## Stats del arma forjada (vacío si el id no es un token forjado).
func get_forged_stats(token_id: String) -> Dictionary:
	return _forged.get(token_id, {})

func get_leaderboard() -> Array:
	await _latency()
	return _leaderboard.duplicate(true)

func get_treasure() -> int:
	return _treasure

# ---------- utilidades mock ----------

func _signed(data: Dictionary) -> Dictionary:
	data["ok"] = true
	data["hash"] = _fake_hash()
	return data

func _fake_hash() -> String:
	var h := ""
	for i in 64:
		h += HASH_CHARS[randi() % HASH_CHARS.length()]
	return h

func _latency() -> void:
	await get_tree().create_timer(FAKE_LATENCY).timeout
