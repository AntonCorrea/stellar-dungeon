extends Node
## F8 — cola offline: mine/craft se aplican LOCAL cuando no hay red, se
## encolan, y se sincronizan solos (mismo op_id, sin duplicar) al volver la
## señal. Simula el corte apuntando relay_url a un puerto que no escucha —
## no hace falta cortar la red de verdad.
##
## Uso (relé real recién arrancado, mock alcanza — igual que test_chain_http):
##   cd stellar-dungeon-backend/relay && npm start      # terminal 1
##   $env:CHAIN_BACKEND = "relay"                       # terminal 2
##   godot --headless --path . res://tests/test_offline_sync.tscn

var _net: Node
var _errors := 0

func _ready() -> void:
	await get_tree().process_frame

	if Chain.backend != "relay":
		push_error("seteá CHAIN_BACKEND=relay (con el relé real levantado, ver README)")
		get_tree().quit(1)
		return
	_net = Chain._net
	var good_url: String = _net.relay_url

	# 1) Cortamos la red: apuntamos a un puerto que no escucha.
	_net.relay_url = "http://127.0.0.1:9"

	var m := await Chain.mine("madera")
	_check(m.get("ok") == true and m.get("pending") == true, "mine offline debería aplicarse local: %s" % str(m))
	_check(_net.get_pending_count() == 1, "esperaba 1 acción encolada, hay %d" % _net.get_pending_count())
	_check(_net.is_online() == false, "is_online() debería ser false sin red")

	await Chain.mine("cobre")
	await Chain.mine("cobre")
	var c := await Chain.craft("espada_cobre")
	_check(c.get("ok") == true and c.get("pending") == true, "craft offline debería aplicarse local: %s" % str(c))
	_check(String(c.get("token", "")).find("_local") != -1, "el token offline debería llevar sufijo _local: %s" % str(c))
	_check(_net.get_pending_count() == 4, "esperaba 4 acciones encoladas (3 mine + 1 craft), hay %d" % _net.get_pending_count())

	var inv_offline := await Chain.get_inventory()
	_check(inv_offline.get("madera", -1) == 0, "madera debería estar quemada en la cartera offline: %s" % str(inv_offline))
	_check(inv_offline.get("cobre", -1) == 0, "cobre debería estar quemado en la cartera offline: %s" % str(inv_offline))

	# 2) Vuelve la red: mismo op_id encolado, no debería duplicar nada.
	_net.relay_url = good_url
	await _net._sync_pending()
	_check(_net.get_pending_count() == 0, "la cola debería vaciarse al sincronizar")
	_check(_net.is_online() == true, "is_online() debería ser true tras sincronizar")

	var inv_synced := await Chain.get_inventory()
	_check(inv_synced.get("madera", -1) == 0, "madera debería seguir en 0 tras sync (no duplicó el mine): %s" % str(inv_synced))
	_check(inv_synced.get("cobre", -1) == 0, "cobre debería seguir en 0 tras sync (no duplicó el mine): %s" % str(inv_synced))

	if _errors > 0:
		push_error("test_offline_sync: %d errores" % _errors)
		get_tree().quit(1)
		return
	print("=== OFFLINE SYNC OK: cola local -> relé real, sin duplicar al reconectar ===")
	get_tree().quit()

func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_errors += 1
	push_error("F8: %s" % msg)
