extends Node2D
## Texto flotante (+1 recurso) con fade ascenso (día 4).

func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 14.0, 0.9)
	tween.tween_property($Label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(queue_free)