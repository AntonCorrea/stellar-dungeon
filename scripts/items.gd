extends RefCounted
## Loot: armas y flasks que soltaron los enemigos. Metadata
## compartida: nombres en español, daño por arma y curado de frascos.
## Los ids se guardan en la cartera on-chain (mock Chain); el relé real
## debe soportarlos (ver chain-spec.md).

const START_WEAPON := "weapon_knife"   # el jugador nace con este
const START_FLASK := "flask_red"       # ... y con un frasco rojo
const FLASK_HEAL := 25                 # vida que recupera cada frasco rojo

## Daño por arma (auto-equip del mejor arma en cartera). Las armas del pack que
## no figuren acá quedan con BASE_WEAPON_DMG.
const WEAPON_DMG := {
	"weapon_knife": 12,
	"weapon_rusty_sword": 13,
	"weapon_axe": 14,
	"weapon_spear": 13,
	"weapon_throwing_axe": 13,
	"weapon_bow": 13,
	"weapon_anime_sword": 14,
	"weapon_cleaver": 14,
	"weapon_regular_sword": 15,
	"weapon_hammer": 15,
	"weapon_baton_with_spikes": 15,
	"weapon_machete": 15,
	"weapon_red_magic_staff": 15,
	"weapon_mace": 16,
	"weapon_saw_sword": 16,
	"weapon_big_hammer": 16,
	"weapon_bow_2": 16,
	"weapon_katana": 17,
	"weapon_green_magic_staff": 17,
	"weapon_duel_sword": 18,
	"weapon_double_axe": 18,
	"weapon_waraxe": 18,
	"weapon_knight_sword": 19,
	"weapon_lavish_sword": 20,
	"weapon_red_gem_sword": 20,
	"weapon_golden_sword": 21,
}
const BASE_WEAPON_DMG := 12

const WEAPON_NAMES := {
	"weapon_knife": "Cuchillo",
	"weapon_rusty_sword": "Espada oxidada",
	"weapon_axe": "Hacha",
	"weapon_spear": "Lanza",
	"weapon_throwing_axe": "Hacha arrojadiza",
	"weapon_bow": "Arco corto",
	"weapon_anime_sword": "Espada anime",
	"weapon_cleaver": "Cuchilla",
	"weapon_regular_sword": "Espada común",
	"weapon_hammer": "Martillo",
	"weapon_baton_with_spikes": "Porra con púas",
	"weapon_machete": "Machete",
	"weapon_red_magic_staff": "Báculo rojo",
	"weapon_mace": "Maza",
	"weapon_saw_sword": "Espada serrucho",
	"weapon_big_hammer": "Martillo grande",
	"weapon_bow_2": "Arco largo",
	"weapon_katana": "Katana",
	"weapon_green_magic_staff": "Báculo verde",
	"weapon_duel_sword": "Espada de duelo",
	"weapon_double_axe": "Hacha doble",
	"weapon_waraxe": "Hacha de guerra",
	"weapon_knight_sword": "Espada de caballero",
	"weapon_lavish_sword": "Espada suntuosa",
	"weapon_red_gem_sword": "Espada de gema roja",
	"weapon_golden_sword": "Espada dorada",
	"espada_cobre": "Espada de cobre",
	"mandoble_hierro": "Mandoble de hierro",
	"hacha_plata": "Hacha de plata",
}

const FLASK_NAMES := {
	"flask_red": "Frasco rojo",
	"flask_blue": "Frasco azul",
	"flask_green": "Frasco verde",
	"flask_yellow": "Frasco amarillo",
}

## Calidades de las armas forjadas (suerte): +bonus al daño base de la receta.
const QUALITY := [
	{"name": "Común", "bonus": 0},
	{"name": "Fina", "bonus": 2},
	{"name": "Superior", "bonus": 4},
	{"name": "Épica", "bonus": 8},
]

## Recetas de armas de la forja: daño base + icono para la grilla.
## Al forjarlas, Chain mintea un token único con stats deterministas (calidad
## = xorshift(seed), ver roll_quality abajo).
const FORGE_WEAPONS := {
	"espada_cobre": {"dmg": 14, "icon": "weapon_rusty_sword"},
	"mandoble_hierro": {"dmg": 18, "icon": "weapon_duel_sword"},
	"hacha_plata": {"dmg": 22, "icon": "weapon_waraxe"},
}

# ---------------------------------------------------------------------------
# Tirada de calidad ON-CHAIN (Fase 4, test cruzado Godot↔Rust).
# Port EXACTO del contrato forge_ledger (xorshift32, mismo que
# runa/contracts/medicion). La calidad es función pura del seed: reproducirla
# acá permite verificar en tests que Godot y el contrato dan el mismo resultado
# para el mismo seed. NUNCA usar randf() acá ni env.prng() en el contrato.
# ---------------------------------------------------------------------------

## xorshift32 (bitwise idéntico al wasm u32; GDScript usa int64 → mascaras).
static func xorshift_next(rng: int) -> int:
	var x := rng & 0xFFFFFFFF
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = (x ^ (x >> 17)) & 0xFFFFFFFF
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	return x & 0xFFFFFFFF

## Calidad: 55% Común · 25% Fina · 14% Superior · 6% Épica (misma cobertura
## que el contrato). El relé real usa la misma seed que acá (contador de forja).
static func roll_quality(seed: int) -> int:
	var rng := 1 if seed == 0 else seed
	var roll := xorshift_next(rng)
	var p := roll % 100
	if p < 55:
		return 0
	if p < 80:
		return 1
	if p < 94:
		return 2
	return 3

static func pretty(id: String) -> String:
	if WEAPON_NAMES.has(id):
		return WEAPON_NAMES[id]
	if FLASK_NAMES.has(id):
		return FLASK_NAMES[id]
	return id.trim_prefix("weapon_").trim_prefix("flask_").replace("_", " ").capitalize()

static func quality_name(q: int) -> String:
	if q >= 0 and q < QUALITY.size():
		return String(QUALITY[q]["name"])
	return ""

static func weapon_damage(id: String) -> int:
	return int(WEAPON_DMG.get(id, BASE_WEAPON_DMG))

static func is_weapon(id: String) -> bool:
	return id.begins_with("weapon_")

static func is_flask(id: String) -> bool:
	return id.begins_with("flask_")