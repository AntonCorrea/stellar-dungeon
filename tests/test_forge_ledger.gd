extends Node
## Test Fase 4 — CRUZADO Godot↔Rust (forge_ledger).
## Verifica que la tirada de calidad del juego (Gear.roll_quality, el mismo
## xorshift32 del contrato) produce EXACTAMENTE la misma tabla que el contrato
## Rust (fixture generado en contracts/forge_ledger/src/test.rs con
## quality_known_seeds_fixture) y la misma cobertura 55/25/14/6.
## También confirma que Chain.craft mintea usando seed = contador de forja.
## Uso: godot --headless --path . res://tests/test_forge_ledger.tscn

const Gear := preload("res://scripts/items.gd")

## Tabla seed -> quality generada por el CONTRATO (quality_known_seeds_fixture
## en Rust). Si esto o el test de Godot cambia, la tirada dejó de ser idéntica.
const FIXTURE := [
	[0, 1], [1, 1], [2, 0], [3, 0], [4, 1], [5, 0], [6, 0], [7, 2],
	[8, 0], [9, 0], [10, 2], [11, 1], [12, 0], [13, 3], [14, 1], [15, 0],
]

func _ready() -> void:
	await get_tree().process_frame

	# 1) Fixture cruzado: Godot == contrato, seed por seed.
	for pair in FIXTURE:
		var seed: int = int(pair[0])
		var expected: int = int(pair[1])
		var got := Gear.roll_quality(seed)
		if got != expected:
			push_error("roll_quality(%d): Godot=%d, contrato=%d" % [seed, got, expected])
			get_tree().quit(1)
			return
	print("fixture cruzado OK: 16 seeds idénticas al contrato")

	# 2) Cobertura sobre 2000 seeds (igual tolerancia que el test Rust).
	var counts := [0, 0, 0, 0]
	for seed in 2000:
		counts[Gear.roll_quality(seed)] += 1
	var p := [counts[0] / 2000.0, counts[1] / 2000.0, counts[2] / 2000.0, counts[3] / 2000.0]
	if p[0] < 0.49 or p[0] > 0.61 or p[1] < 0.19 or p[1] > 0.31 \
		or p[2] < 0.08 or p[2] > 0.20 or p[3] > 0.12:
		push_error("cobertura fuera de rango: %s" % str([p[0], p[1], p[2], p[3]]))
		get_tree().quit(1)
		return
	print("cobertura OK: Común %.3f · Fina %.3f · Superior %.3f · Épica %.3f" % p)

	# 3) Chain.craft usa seed = contador de forja (cruce de integración):
	#    primera forja (contador 0) → calidad == roll_quality(0).
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	var cr := await Chain.craft("mandoble_hierro")
	if not cr.get("ok", false):
		push_error("craft mandoble_hierro falló: %s" % str(cr))
		get_tree().quit(1)
		return
	var token: String = str(cr.get("token", ""))
	var q := int(cr.get("quality", -1))
	if token != "mandoble_hierro_f0" or q != Gear.roll_quality(0):
		push_error("craft no usó seed=contador: token=%s q=%d esperado=%d" % [
			token, q, Gear.roll_quality(0)])
		get_tree().quit(1)
		return
	var fg: Dictionary = Chain.get_forged_stats(token)
	if fg == {} or int(fg.get("quality", -1)) != q:
		push_error("forged stats no coinciden con craft: %s" % str(fg))
		get_tree().quit(1)
		return
	print("craft determinista OK: %s calidad %d (== contrato seed %d)" % [token, q, 0])

	# 4) Segunda forja → seed 1 (contador avanza).
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	await Chain.claim_drop("hierro")
	var cr2 := await Chain.craft("mandoble_hierro")
	if not cr2.get("ok", false) or int(cr2.get("quality", -1)) != Gear.roll_quality(1):
		push_error("segunda forja no usó seed 1: %s" % str(cr2))
		get_tree().quit(1)
		return
	print("segunda forja OK: calidad %d (== contrato seed 1)" % int(cr2["quality"]))

	print("=== TEST FORGE_LEDGER OK ===")
	get_tree().quit()