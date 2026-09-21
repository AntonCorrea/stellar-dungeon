extends Node2D
## GFX de ataque: arco de espada procedural (medialuna) dibujado con _draw().
## El padre lo posiciona y rota según la dirección del ataque; el nodo crece,
## gira y se desvanece en ~0.16 s. Sin texturas ni materiales: CanvasItem._draw()
## renderiza igual en GL Compatibility, imposible que no se vea.

const R0 := 5.0
const R1 := 14.0
const HALF_SWEEP := PI / 3.0   # ±60° -> barrido de 120°
const ARC_STEPS := 12
const LIFETIME := 0.16

func _ready() -> void:
	z_index = 100  # efímero: por encima de todo mientras dura
	var base := rotation
	var t := create_tween()
	t.tween_property(self, "rotation", base + 0.22, LIFETIME)
	t.parallel().tween_property(self, "scale", Vector2(1.25, 1.25), LIFETIME).from(Vector2(0.5, 0.5))
	t.parallel().tween_property(self, "modulate:a", 0.0, LIFETIME)
	t.tween_callback(queue_free)
	queue_redraw()

func _draw() -> void:
	var c := Color(1.0, 0.96, 0.72, modulate.a)
	draw_colored_polygon(_arc_points(), c)
	# filo más brillante en el borde exterior para dar cuerpo al arco
	var edge := _arc_points()
	edge.remove_at(0)          # quita el punto interior A
	edge.remove_at(0)          # quita el punto interior B
	draw_polyline(edge, Color(1.0, 1.0, 0.95, modulate.a), 1.5)

## Sector de corona: borde interior (R0) + borde exterior (R1) entre
## -HALF_SWEEP y +HALF_SWEEP, apuntando a +X (el padre rota con la dirección).
## Los vértices se recorren en orden de perímetro (cuerda interior + arco
## exterior descendente) para que la triangulación siempre funcione.
func _arc_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(R0, 0).rotated(-HALF_SWEEP))   # cuerda interior: esquina A
	pts.append(Vector2(R0, 0).rotated(HALF_SWEEP))    # cuerda interior: esquina B
	for i in ARC_STEPS + 1:
		var a := HALF_SWEEP - (HALF_SWEEP * 2.0) * float(i) / ARC_STEPS  # +60° -> -60°
		pts.append(Vector2(R1, 0).rotated(a))
	return pts