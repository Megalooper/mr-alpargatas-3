extends CanvasLayer

@onready var btn_checkpoint: Button = $ColorRect/VBoxContainer/BtnCheckpoint

func _ready() -> void:
	hide()

func mostrar() -> void:
	show()
	# Congelamos el tiempo y liberamos el ratón
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Lógica del checkpoint
	if Global.hay_checkpoint:
		btn_checkpoint.show()
	else:
		btn_checkpoint.hide()

# --- SEÑALES DE LOS BOTONES ---

func _on_btn_checkpoint_pressed() -> void:
	get_tree().paused = false # Quitamos la pausa antes de recargar
	get_tree().reload_current_scene()

func _on_btn_inicio_pressed() -> void:
	get_tree().paused = false
	Global.hay_checkpoint = false # Borramos la memoria del nivel
	get_tree().reload_current_scene()

func _on_btn_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu_principal.tscn")
