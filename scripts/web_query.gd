class_name WebQuery
extends RefCounted
## Helper solo-Web: lee parámetros de la URL (?backend=relay&url=https://…)
## para configurar Chain sin variables de entorno — un build HTML5 exportado
## (itch.io, Render estático, etc.) no tiene entorno de proceso como
## desktop/headless. No-op fuera del navegador.

static func get_param(name: String, default_value: String = "") -> String:
	if not OS.has_feature("web"):
		return default_value
	var search: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(search) != TYPE_STRING or String(search).is_empty():
		return default_value
	var qs := String(search).lstrip("?")
	for pair in qs.split("&"):
		if pair.is_empty():
			continue
		var kv := pair.split("=", true, 1)
		if kv[0].uri_decode() == name:
			return kv[1].uri_decode() if kv.size() > 1 else ""
	return default_value
