extends Node
## F7.2 — Protocolo Godot ↔ relé vía HTTP (chain_http.gd).
## Verifica que el mozo HTTP habla el idioma exacto del relé y que la única
## fuente de calidad es el CONTRATO: la calidad que devuelve el relé debe ser
## == Gear.roll_quality(seed) con seed = el "_f{n}" del token (mismo xorshift
## en el contrato Rust, el mock del relé y Godot — ver Fase 4).
##
## Uso (relé levantado aparte, mock o real — el test es agnóstico al modo):
##   cd stellar/relay && npm start                     # terminal 1 (mode mock)
##   $env:CHAIN_BACKEND = "relay"                      # terminal 2
##   godot --headless --path . res://tests/test_chain_http.tscn
## CHAIN_URL opcional (default http://localhost:8787).

const Gear := preload("res://scripts/items.gd")
const RECIPE := "espada_cobre"

var _net: Node
var _errors := 0

func _ready() -> void:
	await get_tree().process_frame

	if Chain.backend != "relay":
		push_error("Chain no está en backend relay: setear CHAIN_BACKEND=relay")
		get_tree().quit(1)
		return
	_net = Chain._net

	# 1) Conexión viva: inventario inicial del relé (mint del backend).
	var inv: Dictionary = await Chain.get_inventory()
	if inv.get("pico_madera", 0) != 1:
		_fail("inventario inicial raro (relé no responde o mint distinto): %s" % str(inv))
		return
	print("conexión ok — inventario inicial: %s" % str(inv))

	# 2) Minar lo que cuesta la receta: 1 madera + 2 cobre.
	var needs := {"madera": 1, "cobre": 2}
	var mined := {}
	for ore in needs:
		for i in int(needs[ore]):
			var r := await Chain.mine(String(ore))
			_check(r.get("ok") == true, "mine %s falló: %s" % [ore, str(r)])
			mined[ore] = int(r.get("balance", -1))
	print("minado: %s" % str(mined))

	# 3) Forjar el arma. El seed va codificado en el token "{receta}_f{n}".
	var cr: Dictionary = await Chain.craft(RECIPE)
	if not cr.get("ok", false):
		_fail("craft %s falló: %s" % [RECIPE, str(cr)])
		return
	var token: String = str(cr.get("token", ""))
	if not token.begins_with(RECIPE + "_f"):
		_fail("token inesperado: %s" % token)
		return
	var seed: int = int(token.substr(token.rfind("_f") + 2))
	var q := int(cr.get("quality", -1))
	var dmg := int(cr.get("dmg", -1))
	var q_ok: bool = (q == int(Gear.roll_quality(seed)))
	var dmg_base: int = int(Gear.FORGE_WEAPONS[RECIPE]["dmg"])
	var dmg_ok: bool = (dmg == dmg_base + int(Chain.QUALITY_BONUS[q]))
	_check(q_ok, "calidad on-chain(%d) != rollQuality(%d)=%d" % [q, seed, Gear.roll_quality(seed)])
	_check(dmg_ok, "dmg on-chain(%d) != %d+bonus[%d]" % [dmg, dmg_base, q])
	print("forja real: %s → calidad=%d dmg=%d (seed %d) hash=%s" % [
		token, q, dmg, seed, cr.get("hash", "?")])

	# 4) El relé quemó los materiales y el token figura en la cartera.
	inv = await Chain.get_inventory()
	_check(inv.get("madera", 0) == 0, "madera no quemada tras forja: %s" % str(inv))
	_check(inv.get("cobre", 0) == 0, "cobre no quemado tras forja: %s" % str(inv))
	_check(inv.get(token, 0) == 1, "token forjado no figura en inventario: %s" % str(inv))

	# 5) get_forged_stats devuelve lo que tiró el contrato.
	var stats := Chain.get_forged_stats(token)
	_check(stats.get("quality", -1) == q, "stats calidad no concuerda: %s" % str(stats))

	# 6) Tesoro y leaderboard (off-chain en el relé).
	var tr: Dictionary = await Chain.add_treasure(10)
	_check(tr.get("ok") == true and Chain.get_treasure() == 10,
		"treasure no sumó: %s" % str(tr))
	var lb: Array = await Chain.get_leaderboard()
	_check(lb.size() >= 2, "leaderboard esperaba >=2: %s" % str(lb))

	if _errors > 0:
		push_error("test_chain_http: %d errores" % _errors)
		get_tree().quit(1)
		return
	print("=== CHAIN HTTP OK: el juego recibe calidad del contrato vía relé ===")
	get_tree().quit()

func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_errors += 1
	push_error("F7: %s" % msg)

func _fail(msg: String) -> void:
	push_error("F7: %s" % msg)
	get_tree().quit(1)