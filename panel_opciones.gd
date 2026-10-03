extends ColorRect

# Usamos find_child para que encuentre los botones sin importar dónde los muevas
@onready var btn_adelante = find_child("BtnRemapearAdelante", true, false)
@onready var btn_atras = find_child("BtnRemapearAtras", true, false)
@onready var btn_derecha = find_child("BtnRemapearDerecha", true, false)
@onready var btn_izquierda = find_child("BtnRemapearIzquierda", true, false)
@onready var btn_saltar = find_child("BtnRemapearSaltar", true, false)
@onready var btn_patear = find_child("BtnRemapearPatear", true, false)
@onready var btn_kickspin = find_child("BtnRemapearKickspin", true, false) # EL NUEVO KICKSPIN
@onready var btn_agachar = find_child("BtnRemapearAgachar", true, false)

var accion_a_remapear = ""

func _ready() -> void:
	_actualizar_textos_botones()

# --- PARA OCULTAR EL PANEL ---
func _on_boton_volver_pressed() -> void:
	hide()
	accion_a_remapear = ""

# --- SEÑALES DE LOS BOTONES DE REMAPEO ---
func _on_btn_remapear_adelante_pressed() -> void: _preparar_remapeo(btn_adelante, "move_up")
func _on_btn_remapear_atras_pressed() -> void: _preparar_remapeo(btn_atras, "move_down")
func _on_btn_remapear_derecha_pressed() -> void: _preparar_remapeo(btn_derecha, "move_right")
func _on_btn_remapear_izquierda_pressed() -> void: _preparar_remapeo(btn_izquierda, "move_left")
func _on_btn_remapear_saltar_pressed() -> void: _preparar_remapeo(btn_saltar, "jump")
func _on_btn_remapear_patear_pressed() -> void: _preparar_remapeo(btn_patear, "kick")
func _on_btn_remapear_kickspin_pressed() -> void: _preparar_remapeo(btn_kickspin, "kickspin") # SEÑAL KICKSPIN
func _on_btn_remapear_agachar_pressed() -> void: _preparar_remapeo(btn_agachar, "crouch")

func _preparar_remapeo(boton: Button, accion: String) -> void:
	if boton:
		boton.text = "..."
	accion_a_remapear = accion

func _actualizar_textos_botones() -> void:
	if btn_adelante and InputMap.has_action("move_up") and InputMap.action_get_events("move_up").size() > 0: btn_adelante.text = InputMap.action_get_events("move_up")[0].as_text()
	if btn_atras and InputMap.has_action("move_down") and InputMap.action_get_events("move_down").size() > 0: btn_atras.text = InputMap.action_get_events("move_down")[0].as_text()
	if btn_derecha and InputMap.has_action("move_right") and InputMap.action_get_events("move_right").size() > 0: btn_derecha.text = InputMap.action_get_events("move_right")[0].as_text()
	if btn_izquierda and InputMap.has_action("move_left") and InputMap.action_get_events("move_left").size() > 0: btn_izquierda.text = InputMap.action_get_events("move_left")[0].as_text()
	if btn_saltar and InputMap.has_action("jump") and InputMap.action_get_events("jump").size() > 0: btn_saltar.text = InputMap.action_get_events("jump")[0].as_text()
	if btn_patear and InputMap.has_action("kick") and InputMap.action_get_events("kick").size() > 0: btn_patear.text = InputMap.action_get_events("kick")[0].as_text()
	if btn_kickspin and InputMap.has_action("kickspin") and InputMap.action_get_events("kickspin").size() > 0: btn_kickspin.text = InputMap.action_get_events("kickspin")[0].as_text()
	if btn_agachar and InputMap.has_action("crouch") and InputMap.action_get_events("crouch").size() > 0: btn_agachar.text = InputMap.action_get_events("crouch")[0].as_text()

func _input(event: InputEvent) -> void:
	if accion_a_remapear != "":
		if event is InputEventKey or event is InputEventJoypadButton:
			if event.is_pressed():
				var indice = 0 if event is InputEventKey else 2
				var codigo = event.keycode if event is InputEventKey else event.button_index
				
				# Aquí asumo que tu autoload sigue llamándose InputManager
				InputManager.cambiar_boton(accion_a_remapear, indice, codigo)
				_actualizar_textos_botones() 
				
				accion_a_remapear = ""
				get_viewport().set_input_as_handled()
