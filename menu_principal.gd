extends Control

@onready var panel_opciones = $PanelOpciones

# --- CÁMARA 3D DE FONDO ---
@onready var camara_menu = $SubViewportContainer/SubViewport/PivoteCamara/Camera3D
@onready var sub_viewport = $SubViewportContainer/SubViewport
@onready var pivote_camara = $SubViewportContainer/SubViewport/PivoteCamara

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel_opciones.hide()

	# 1. EL JEFE SOY YO:
	if is_instance_valid(camara_menu):
		camara_menu.make_current()
		
	# 2. EXORCISMO SUPREMO: Borramos al jugador Y al menú de pausa del fondo
	var jugador = sub_viewport.find_child("Player3D", true, false)
	if jugador: jugador.queue_free()
		
	var menu_pausa_fondo = sub_viewport.find_child("MenuPausa", true, false)
	if menu_pausa_fondo: menu_pausa_fondo.queue_free()
		
	# 3. DESPEJANDO EL CIELO:
	var entorno = sub_viewport.find_child("WorldEnvironment", true, false)
	if entorno and entorno.environment:
		entorno.environment.fog_enabled = false
		entorno.environment.volumetric_fog_enabled = false

	# 4. MAGIA NEGRA PARA EL HOVER (Sin usar imágenes extra)
	# Asegúrate de que los nombres de los nodos coincidan exactamente en tu escena
	var botones = [$VBoxContainer/BtnInicio, $VBoxContainer/BtnOpciones, $BtnSalir]
	
	for boton in botones:
		boton.mouse_entered.connect(func(): boton.modulate = Color(0.8, 0.8, 0.8))
		boton.mouse_exited.connect(func(): boton.modulate = Color(1.0, 1.0, 1.0))
		boton.button_down.connect(func(): boton.modulate = Color(0.5, 0.5, 0.5))
		boton.button_up.connect(func(): boton.modulate = Color(0.8, 0.8, 0.8))

func _process(delta: float) -> void:
	# Rotamos la cámara de fondo suavecito
	if is_instance_valid(pivote_camara):
		pivote_camara.rotation.y += 0.15 * delta

# ==========================================
# BOTONES DEL MENÚ PRINCIPAL
# ==========================================

func _on_btn_inicio_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn") 

func _on_btn_opciones_pressed() -> void:
	panel_opciones.show() 

func _on_btn_salir_pressed() -> void:
	get_tree().quit()
