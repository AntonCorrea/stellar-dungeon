extends CanvasLayer
## HUD día 7: inventario (E) como grilla de iconos con el nombre abajo — los
## objetos que llevás encima. La FORJA es un panel aparte que se abre haciendo
## click sobre el brasero del nivel. Armas forjadas: stats aleatorias (suerte,
## Común/Fina/Superior/Épica) y cada una es un token único de la cartera.
## Día 8: indicador on-chain (cartera/txs/forjadas), brújula hacia el Capitán,
## pausa (Esc), game over con stats y pantalla de victoria al caer el jefe.

const ITEM_NAME := {
	"madera": "Madera", "cobre": "Cobre", "hierro": "Hierro", "plata": "Plata",
	"pico_madera": "Pico de Madera", "pico_cobre": "Pico de Cobre",
	"espada_cobre": "Espada de Cobre", "mandoble_hierro": "Mandoble de Hierro",
	"hacha_plata": "Hacha de Plata", "escudo_cobre": "Escudo de Cobre",
	"coraza_hierro": "Coraza de Hierro", "tinte_real": "Tinte Real",
}

const HEART_FULL: Texture2D = preload("res://assets/frames/ui_heart_full.png")
const HEART_HALF: Texture2D = preload("res://assets/frames/ui_heart_half.png")
const HEART_EMPTY: Texture2D = preload("res://assets/frames/ui_heart_empty.png")
const MAX_HEARTS := 10

## Gear: nombres/daño/calidades/curado de armas, frascos y forja (día 7).
const Gear := preload("res://scripts/items.gd")

## Icono genérico para recursos/items sin sprite propio (misma moneda tintada
## que usa el mundo para los drops de recurso). Se carga lazy (un .get_frame_
## texture() no es constante, así que no puede ir en un const).
var _coin_tex_cache: Texture2D

func _coin_tex() -> Texture2D:
	if _coin_tex_cache == null:
		_coin_tex_cache = preload("res://assets/sprite_frames/coin.frames.tres").get_frame_texture("coin", 0)
	return _coin_tex_cache

const RESOURCE_TINTS := {
	"madera": Color(0.72, 0.52, 0.28),
	"cobre": Color(0.9, 0.5, 0.22),
	"hierro": Color(0.66, 0.68, 0.72),
	"plata": Color(0.86, 0.9, 0.96),
	"tinte_real": Color(1.0, 0.82, 0.3),
}

@onready var _hearts: HBoxContainer = $Hearts
@onready var _treasure: Label = $Treasure
@onready var _inventory: Label = $Inventory
@onready var _inv_panel: PanelContainer = $InventoryPanel
@onready var _inv_grid: GridContainer = $InventoryPanel/VBox/InvGrid
@onready var _status_label: Label = $InventoryPanel/VBox/Status
@onready var _forge_panel: PanelContainer = $ForgePanel
@onready var _forge_res: Label = $ForgePanel/VBox/ForgeRes
@onready var _forge_recipes: VBoxContainer = $ForgePanel/VBox/ForgeRecipes
@onready var _forge_status: Label = $ForgePanel/VBox/ForgeStatus
@onready var _game_over: PanelContainer = $GameOver
@onready var _game_over_stats: Label = $GameOver/VBox/Stats
@onready var _victory_panel: PanelContainer = $VictoryPanel
@onready var _victory_stats: Label = $VictoryPanel/VBox/Stats
@onready var _boss_box: PanelContainer = $BossBox
@onready var _boss_hp: ProgressBar = $BossBox/VBox/BossHp
@onready var _chain_wallet: Label = $ChainBox/VBox/ChainWallet
@onready var _chain_data: Label = $ChainBox/VBox/ChainData
@onready var _compass: PanelContainer = $Compass
@onready var _compass_arrow: TextureRect = $Compass/VBox/ArrowBox/CompassArrow
@onready var _compass_dist: Label = $Compass/VBox/DistLabel
@onready var _pause_panel: PanelContainer = $PausePanel
@onready var _pause_resume: Button = $PausePanel/VBox/ResumeBtn
@onready var _pause_restart: Button = $PausePanel/VBox/RestartBtn

var _player: Node2D
var _heart_rects: Array = []
var _recipe_buttons: Array = []

func _ready() -> void:
	add_to_group("hud")
	for i in MAX_HEARTS:
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.custom_minimum_size = Vector2(16, 16)
		_hearts.add_child(tr)
		_heart_rects.append(tr)
	_pause_resume.pressed.connect(_toggle_pause)
	_pause_restart.pressed.connect(_restart)
	Chain.sync_finished.connect(_on_chain_sync)
	_on_chain_sync()

func _on_chain_sync() -> void:
	_refresh_chain_box()
	await _refresh_summary()
	await _refresh_inv_grid()
	await _refresh_forge()

## Actualiza el indicador on-chain: cartera cortada + txs firmadas + forjadas.
func _refresh_chain_box() -> void:
	var addr: String = Chain.get_wallet_address()
	_chain_wallet.text = "%s…%s" % [addr.substr(0, 6), addr.substr(addr.length() - 4, 4)]
	_chain_data.text = "txs: %d  ·  forjadas: %d" % [Chain.get_tx_count(), Chain.get_forged_count()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Esc: pausar / reanudar (funciona también con el árbol en pausa).
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			return
		# R: reiniciar desde pausa, game over o victoria.
		if event.keycode == KEY_R and (get_tree().paused or _game_over.visible or _victory_panel.visible):
			_restart()
			return
		# Con el juego en pausa no se abren inventario/forja.
		if get_tree().paused:
			return
		# E (o I) abre/cierra el inventario y cierra la forja.
		if event.keycode == KEY_E or event.keycode == KEY_I:
			_forge_panel.visible = false
			_inv_panel.visible = not _inv_panel.visible
			if _inv_panel.visible:
				_refresh_inv_grid()
				if _player_near_forge():
					_status_label.text = "Estás en el brasero: hacé click sobre la forja para abrirla."
				else:
					_status_label.text = "Frasco: click para usarlo. Buscá la forja y hacé click sobre ella."

## Pausa el árbol y muestra/oculta el panel. El HUD corre con process_mode
## ALWAYS, así Esc sigue funcionando mientras todo lo demás está congelado.
func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	_pause_panel.visible = now_paused
	Sfx.play("pickup")

## Reinicia la mazmorra (desde pausa, game over o victoria). La cartera del
## mock Chain es un autoload y se conserva entre partidas.
func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Abre/cierra el panel de forja (lo llama el jugador al hacer click en la
## forja). Abrir la forja cierra el inventario y viceversa.
func open_forge() -> void:
	_inv_panel.visible = false
	_forge_panel.visible = not _forge_panel.visible
	if _forge_panel.visible:
		_refresh_forge()
		_forge_status.text = "Elegí una receta para forjar."
		if not _player_near_forge():
			_forge_status.text = "Te alejaste de la forja: volvé para forjar."

## Mensaje rápido desde el mundo (p. ej. "Acercate a la forja").
func notice(text: String) -> void:
	if _forge_panel.visible:
		_forge_status.text = text
	else:
		_status_label.text = text

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var arr := get_tree().get_nodes_in_group("player")
		if arr.size() > 0:
			_player = arr[0]
	if _player == null:
		return
	var hp: int = int(_player.get("hp"))
	var maxhp: int = int(_player.get("MAX_HP"))
	for i in MAX_HEARTS:
		var tr: TextureRect = _heart_rects[i]
		tr.texture = _heart_tex(hp, maxhp, i)
	if bool(_player.get("is_dead")) and not _game_over.visible:
		_game_over.visible = true
		_game_over_stats.text = _stats_text()
	if _forge_panel.visible:
		var close := _player_near_forge()
		for b in _recipe_buttons:
			b.disabled = not close
	_tick_boss_bar()
	_tick_compass()

## Brújula hacia el Capitán: flecha rotada + distancia en tiles. Se apaga si el
## jefe murió, está lejos del nivel o el jugador cayó.
func _tick_compass() -> void:
	if _player == null or not is_instance_valid(_player) or bool(_player.get("is_dead")):
		_compass.visible = false
		return
	var boss: Node2D = get_tree().get_first_node_in_group("boss") as Node2D
	if boss == null or not is_instance_valid(boss):
		_compass.visible = false
		return
	var lvl: Node2D = boss.get("level")
	if lvl == null:
		_compass.visible = false
		return
	var p_cell: Vector2i = lvl.local_to_cell(_player.global_position)
	var b_cell: Vector2i = lvl.local_to_cell(boss.global_position)
	_compass.visible = true
	_compass_dist.text = "Jefe: %d tiles" % int(round(p_cell.distance_to(b_cell)))
	if _compass_arrow != null:
		var dir := boss.global_position - _player.global_position
		if dir.length() > 0.01:
			_compass_arrow.pivot_offset = _compass_arrow.size / 2.0
			# La textura weapon_arrow.png apunta hacia ARRIBA (-Y): rotar en
			# (dir.angle() + PI/2) la orienta hacia la dirección real del jefe.
			_compass_arrow.rotation = dir.angle() + PI / 2.0

## Resumen de la partida para los paneles de game over / victoria.
func _stats_text() -> String:
	var eq := _equipped_weapon()
	return "Tesoro: %d\nArmas forjadas: %d\nTransacciones firmadas: %d\nEquipo: %s" % [
		Chain.get_treasure(), Chain.get_forged_count(), Chain.get_tx_count(), Gear.pretty(eq)]

## Lo llama level.on_enemy_killed() cuando cae el Capitán: festejo + stats.
func show_victory() -> void:
	if _victory_panel.visible:
		return
	Sfx.play("chest_open")
	_victory_panel.visible = true
	_victory_stats.text = _stats_text()

## Muestra/oculta la barra de HP del Capitán (grupo "boss" en enemy.gd).
func _tick_boss_bar() -> void:
	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null and is_instance_valid(boss) and not bool(boss.get("_dead")):
		_boss_box.visible = true
		_boss_hp.max_value = float(boss.get("_max_hp"))
		_boss_hp.value = float(boss.get("hp"))
	else:
		_boss_box.visible = false

func _heart_tex(hp: int, maxhp: int, index: int) -> Texture2D:
	var step := float(maxhp) / MAX_HEARTS
	var value := hp - float(index) * step
	if value >= step * 0.999:
		return HEART_FULL
	if value >= step * 0.5:
		return HEART_HALF
	return HEART_EMPTY

func _refresh_summary() -> void:
	_treasure.text = "Tesoro: %d" % Chain.get_treasure()
	var inv: Dictionary = await Chain.get_inventory()
	var parts: Array = []
	for key in ["madera", "cobre", "hierro", "plata"]:
		parts.append("%s %d" % [ITEM_NAME[key], inv.get(key, 0)])
	_inventory.text = "Recursos: " + "  ·  ".join(parts)

# ---------- Inventario (grilla de iconos con nombre abajo) ----------

func _refresh_inv_grid() -> void:
	for child in _inv_grid.get_children():
		child.queue_free()
	var inv: Dictionary = await Chain.get_inventory()
	var keys: Array = inv.keys()
	keys.sort()
	var any := false
	for key in keys:
		var n := int(inv[key])
		if n <= 0:
			continue
		any = true
		_inv_grid.add_child(_inv_slot(String(key), n))
	if not any:
		var e := Label.new()
		e.text = "— no llevás nada —"
		e.modulate = Color(0.9, 0.9, 0.9, 0.7)
		_inv_grid.add_child(e)

func _inv_slot(key: String, count: int) -> PanelContainer:
	var forged: Dictionary = Chain.get_forged_stats(key)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(84, 74)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.2, 0.85)
	sb.border_color = Color(0.55, 0.45, 0.3, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(40, 34)
	icon.texture = _icon_for(key, forged)
	if forged == {} and RESOURCE_TINTS.has(key):
		icon.modulate = RESOURCE_TINTS[key]
	vb.add_child(icon)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = _inv_label(key, count, forged)
	vb.add_child(lbl)
	slot.add_child(vb)
	slot.gui_input.connect(_on_slot_click.bind(key))
	return slot

## Textura del icono: sprite propio (weapon_*/flask_*/icono de forja) o, para
## recursos e items sin sprite, la moneda del frame de coin.
func _icon_for(key: String, forged: Dictionary) -> Texture2D:
	var p := ""
	if forged != {}:
		var base := String(forged.get("base", key))
		var icon := String(Gear.FORGE_WEAPONS.get(base, {}).get("icon", "weapon_regular_sword"))
		p = "res://assets/frames/%s.png" % icon
	elif Gear.is_weapon(key) or Gear.is_flask(key):
		p = "res://assets/frames/%s.png" % key
	if p != "":
		var t: Texture2D = load(p)
		if t != null:
			return t
	return _coin_tex()

## Nombre del slot: nombre + calidad (forjada) + ★ si está equipada + xN.
func _inv_label(key: String, count: int, forged: Dictionary) -> String:
	var name := Gear.pretty(key)
	if forged != {}:
		name = "%s %s" % [Gear.pretty(String(forged.get("base", key))),
			Gear.quality_name(int(forged.get("quality", 0)))]
	if _equipped_weapon() == key:
		name += " ★"
	if count > 1:
		name = "%s\nx%d" % [name, count]
	return name

## Click en un slot: los frascos se usan; armas/forjadas muestran su stat.
func _on_slot_click(event: InputEvent, key: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if Gear.is_flask(key):
		_use_flask(key)
		return
	var forged: Dictionary = Chain.get_forged_stats(key)
	if forged != {} or Gear.is_weapon(key):
		var dmg: int = int(forged.get("dmg", Gear.weapon_damage(key)))
		var display := Gear.pretty(key)
		if forged != {}:
			display = "%s %s" % [Gear.pretty(String(forged.get("base", key))),
				Gear.quality_name(int(forged.get("quality", 0)))]
		_status_label.text = "%s · daño %d%s" % [display, dmg,
			" · EQUIPADA" if _equipped_weapon() == key else ""]
	else:
		_status_label.text = Gear.pretty(key)

func _equipped_weapon() -> String:
	if _player == null or not is_instance_valid(_player):
		return ""
	return str(_player.get("equipped_weapon"))

func _use_flask(key: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_status_label.text = "Firmando en Stellar…"
	var res: Dictionary = await Chain.use_item(key)
	if not res.get("ok", false):
		_status_label.text = "✗ " + str(res.get("reason", "sin frascos"))
		await _refresh_inv_grid()
		return
	var healed := int(_player.call("heal", Gear.FLASK_HEAL))
	_status_label.text = "✓ %s · +%d vida (HP %d/%d)" % [
		Gear.pretty(key), healed, int(_player.get("hp")), int(_player.get("MAX_HP")),
	]
	await _refresh_inv_grid()

# ---------- Forja (panel aparte, se abre con click sobre la forja) ----------

func _refresh_forge() -> void:
	var inv: Dictionary = await Chain.get_inventory()
	var rparts: Array = []
	for key in ["madera", "cobre", "hierro", "plata"]:
		rparts.append("%s %d" % [ITEM_NAME[key], inv.get(key, 0)])
	_forge_res.text = "Recursos:  " + "   ".join(rparts)
	_rebuild_recipes(inv)

func _rebuild_recipes(inv: Dictionary) -> void:
	for child in _forge_recipes.get_children():
		child.queue_free()
	_recipe_buttons.clear()
	for recipe_id in Chain.RECIPES:
		var cost: Dictionary = Chain.RECIPES[recipe_id].get("cost", {})
		var cost_parts: Array = []
		for mat in cost:
			cost_parts.append("%s %d" % [ITEM_NAME.get(mat, mat), int(cost[mat])])
		var bt := Button.new()
		if recipe_id in Chain.WEAPON_RECIPES:
			var base_dmg := int(Gear.FORGE_WEAPONS[recipe_id]["dmg"])
			bt.text = "Forjar %s — %s · dmg %d + suerte" % [
				Gear.pretty(String(recipe_id)), " + ".join(cost_parts), base_dmg]
		else:
			bt.text = "Forjar %s — quema %s" % [Gear.pretty(String(recipe_id)),
				" + ".join(cost_parts)]
		bt.pressed.connect(_craft.bind(String(recipe_id)))
		bt.disabled = not _player_near_forge()
		_forge_recipes.add_child(bt)
		_recipe_buttons.append(bt)

func _craft(recipe_id: String) -> void:
	if not _player_near_forge():
		_forge_status.text = "Acercate a la forja."
		return
	_forge_status.text = "Firmando en Stellar…"
	var res: Dictionary = await Chain.craft(recipe_id)
	if res.get("ok", false):
		if res.has("token"):
			var fg: Dictionary = Chain.get_forged_stats(String(res["token"]))
			_forge_status.text = "✓ %s %s · daño %d · hash %s" % [
				Gear.pretty(recipe_id), Gear.quality_name(int(fg.get("quality", 0))),
				int(fg.get("dmg", 0)), str(res.get("hash", "")).substr(0, 8)]
		else:
			_forge_status.text = "✓ %s · hash %s" % [Gear.pretty(recipe_id),
				str(res.get("hash", "")).substr(0, 8)]
	else:
		_forge_status.text = "✗ " + str(res.get("reason", "falló"))
	await _refresh_forge()
	await _refresh_inv_grid()

func _player_near_forge() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	return bool(_player.get("near_forge"))
