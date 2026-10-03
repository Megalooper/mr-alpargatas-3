extends CanvasLayer

@onready var panel_opciones = $PanelOpciones

func _ready() -> void:
	hide()
	if panel_opciones:
		panel_opciones.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pausa()

func _toggle_pausa() -> void:
	var esta_pausado = get_tree().paused
	get_tree().paused = not esta_pausado 
	
	if get_tree().paused:
		show() 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		hide() 
		if panel_opciones:
			panel_opciones.hide() # Por si quitaron la pausa con el panel abierto
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ==========================================
# SEÑALES DE LOS BOTONES
# ==========================================

func _on_btn_reanudar_pressed() -> void:
	_toggle_pausa()

func _on_btn_opciones_pressed() -> void:
	if panel_opciones:
		panel_opciones.show()

func _on_btn_volver_menu_pressed() -> void:
	_toggle_pausa() # ¡IMPORTANTE! Quitamos la pausa antes de salir para no romper el motor
	get_tree().change_scene_to_file("res://menu_principal.tscn")
