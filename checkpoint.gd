extends Area3D

func _ready() -> void:
	# Conectamos la señal por código para que no tengas que usar el editor
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		# Guardamos la posición exacta del checkpoint en el cerebro global
		Global.respawn_pos = global_position
		Global.hay_checkpoint = true
		print("🚩 ¡CHECKPOINT GUARDADO PAPÁ! Posición: ", Global.respawn_pos)
