extends Node
## Sfx: autoload de audio. Los SFX del pack Leohpaz "Minifantasy Dungeon SFX"
## (uso libre, CC0) se agrupan en familias por evento del juego. play() elige
## una variante al azar y le cambia un poco el tono para que no se sienta
## repetitivo. Cada familia tiene varias voces para poder solaparse.
##
## Uso: Sfx.play("sword_hit") o Sfx.play("sword_hit", Vector2(0.8, 0.9)).

const SFX_PATH := "res://assets/Minifantasy_Dungeon_SFX/"

## familia -> {variants: [archivos sin extensión], vol: dB, pitch: [min, max]}
const FAMILIES := {
	"sword_hit":   { "variants": ["26_sword_hit_1", "26_sword_hit_2", "26_sword_hit_3"], "vol": -6.0, "pitch": [0.9, 1.1] },
	"sword_miss":  { "variants": ["27_sword_miss_1", "27_sword_miss_2", "27_sword_miss_3"], "vol": -10.0, "pitch": [0.9, 1.1] },
	"human_atk":   { "variants": ["07_human_atk_sword_1", "07_human_atk_sword_2", "07_human_atk_sword_3"], "vol": -8.0, "pitch": [0.92, 1.08] },
	"human_damage":{ "variants": ["11_human_damage_1", "11_human_damage_2", "11_human_damage_3"], "vol": -6.0, "pitch": [0.85, 1.15] },
	"human_death": { "variants": ["14_human_death_spin"], "vol": -6.0, "pitch": [0.9, 1.1] },
	"human_walk":  { "variants": ["16_human_walk_stone_1", "16_human_walk_stone_2", "16_human_walk_stone_3"], "vol": -16.0, "pitch": [0.9, 1.1] },
	"human_special": { "variants": ["10_human_special_atk_1", "10_human_special_atk_2"], "vol": -4.0, "pitch": [0.9, 1.1] },
	"orc_atk":     { "variants": ["17_orc_atk_sword_1", "17_orc_atk_sword_2", "17_orc_atk_sword_3"], "vol": -8.0, "pitch": [0.92, 1.08] },
	"orc_damage":  { "variants": ["21_orc_damage_1", "21_orc_damage_2", "21_orc_damage_3"], "vol": -6.0, "pitch": [0.85, 1.15] },
	"orc_death":   { "variants": ["24_orc_death_spin"], "vol": -6.0, "pitch": [0.9, 1.1] },
	"chest_open":  { "variants": ["01_chest_open_1", "01_chest_open_2", "01_chest_open_3", "01_chest_open_4"], "vol": -8.0, "pitch": [0.95, 1.05] },
	"crate_break": { "variants": ["03_crate_open_1", "03_crate_open_2", "03_crate_open_3"], "vol": -6.0, "pitch": [0.85, 1.15] },
	"pickup":      { "variants": ["04_sack_open_1", "04_sack_open_2", "04_sack_open_3"], "vol": -8.0, "pitch": [0.9, 1.1] },
}

## Voces por familia para que los sonidos puedan solaparse.
const VOICES := 3

var _voices: Dictionary = {}   # familia -> Array[AudioStreamPlayer]
var _streams: Dictionary = {}  # familia -> Array[AudioStream]
var _cursor: Dictionary = {}   # familia -> int (round-robin de robo de voz)

func _ready() -> void:
	for family: String in FAMILIES:
		var cfg: Dictionary = FAMILIES[family]
		var streams: Array = []
		for file: String in cfg["variants"]:
			streams.append(load(SFX_PATH + file + ".wav"))
		_streams[family] = streams
		var pool: Array = []
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.volume_db = float(cfg["vol"])
			add_child(p)
			pool.append(p)
		_voices[family] = pool
		_cursor[family] = 0

## Reproduce una familia. pitch_range multiplica el rango base de tono (útil
## para golpes a mineral, más graves). Devuelve el player (por si se quiere
## esperar su señal finished).
func play(family: String, pitch_range := Vector2(1.0, 1.0)) -> AudioStreamPlayer:
	if not _voices.has(family):
		return null
	var cfg: Dictionary = FAMILIES[family]
	var streams: Array = _streams[family]
	var pool: Array = _voices[family]
	# Voz libre si hay; si no, roba la del round-robin.
	var p: AudioStreamPlayer = null
	for v in pool:
		if not v.playing:
			p = v
			break
	if p == null:
		var c: int = _cursor[family]
		p = pool[c]
		_cursor[family] = (c + 1) % pool.size()
	p.stream = streams[randi() % streams.size()]
	var pr: Array = cfg["pitch"]
	p.pitch_scale = randf_range(pr[0], pr[1]) * randf_range(pitch_range.x, pitch_range.y)
	p.play()
	return p