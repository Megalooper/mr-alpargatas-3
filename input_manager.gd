extends Node

# =========================================================
# DICCIONARIO DE CONTROLES (El mapa maestro)
# =========================================================
var controles_por_defecto = {
	"move_left": [KEY_A, KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
	"move_right": [KEY_D, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
	"move_up": [KEY_W, KEY_UP, JOY_BUTTON_DPAD_UP],
	"move_down": [KEY_S, KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
	"jump": [KEY_SPACE, MOUSE_BUTTON_LEFT, JOY_BUTTON_A],
	"crouch": [KEY_CTRL, MOUSE_BUTTON_MIDDLE, JOY_BUTTON_RIGHT_SHOULDER],
	"kick": [KEY_J, MOUSE_BUTTON_RIGHT, JOY_BUTTON_X],
	"kickspin": [KEY_K, KEY_E, JOY_BUTTON_Y],
	"pause": [KEY_ENTER, KEY_P, JOY_BUTTON_START],
	"center_camera": [KEY_V, KEY_C, JOY_BUTTON_RIGHT_STICK]
}

var controles_actuales = {}
const RUTA_ARCHIVO = "user://controles.cfg" # La partitura donde guardamos todo

# --- RADAR DE MANDOS ---
var mando_conectado: bool = false
var tipo_mando: String = "teclado"

func _ready() -> void:
	# En vez de copiar los de defecto de una, leemos el archivo de guardado
	cargar_controles()
	
	# Activamos el radar de mandos
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_revisar_mandos_conectados()

# =========================================================
# SISTEMA DE GUARDADO (MEMORIA DEL MOCASÍN)
# =========================================================

func guardar_controles() -> void:
	var config = ConfigFile.new()
	
	# Guardamos cada acción en la sección "Input"
	for accion in controles_actuales.keys():
		config.set_value("Input", accion, controles_actuales[accion])
		
	var error = config.save(RUTA_ARCHIVO)
	if error == OK:
		print("💾 MOCASÍN: Controles guardados con éxito en ", RUTA_ARCHIVO)
	else:
		print("🚨 ERROR: No se pudieron guardar los controles.")

func cargar_controles() -> void:
	var config = ConfigFile.new()
	var error = config.load(RUTA_ARCHIVO)
	
	if error == OK:
		print("📂 MOCASÍN: Archivo de controles encontrado. Cargando...")
		controles_actuales.clear()
		
		# Leemos lo que está en el archivo y si el jugador borró algo sin querer, 
		# usamos el de defecto por seguridad para que el juego no crashee
		for accion in controles_por_defecto.keys():
			if config.has_section_key("Input", accion):
				controles_actuales[accion] = config.get_value("Input", accion)
			else:
				controles_actuales[accion] = controles_por_defecto[accion]
	else:
		print("📝 MOCASÍN: No hay archivo previo. Cargando controles de fábrica.")
		controles_actuales = controles_por_defecto.duplicate(true)
		
	_aplicar_controles_al_motor()

# =========================================================
# EL INYECTOR (Pasa el diccionario al InputMap de Godot)
# =========================================================
func _aplicar_controles_al_motor() -> void:
	for accion in controles_actuales.keys():
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)

		InputMap.action_erase_events(accion)
		var botones = controles_actuales[accion]

		_anadir_evento(accion, botones[0], "teclado_raton")
		_anadir_evento(accion, botones[1], "teclado_raton")
		_anadir_evento(accion, botones[2], "mando")

	# --- INYECCIÓN DE PALANCAS ANALÓGICAS ---
	_anadir_eje("move_left", JOY_AXIS_LEFT_X, -1.0)
	_anadir_eje("move_right", JOY_AXIS_LEFT_X, 1.0)
	_anadir_eje("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_anadir_eje("move_down", JOY_AXIS_LEFT_Y, 1.0)

	_anadir_eje("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	_anadir_eje("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	_anadir_eje("camera_up", JOY_AXIS_RIGHT_Y, -1.0)
	_anadir_eje("camera_down", JOY_AXIS_RIGHT_Y, 1.0)

# =========================================================
# FUNCIONES AUXILIARES
# =========================================================
func _anadir_evento(accion: String, codigo_boton, tipo_dispositivo: String) -> void:
	if codigo_boton == null:
		return

	var evento
	match tipo_dispositivo:
		"teclado_raton":
			if codigo_boton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				evento = InputEventMouseButton.new()
				evento.button_index = codigo_boton
			else:
				evento = InputEventKey.new()
				evento.keycode = codigo_boton
		"mando":
			evento = InputEventJoypadButton.new()
			evento.button_index = codigo_boton
			evento.device = 0 

	if evento:
		InputMap.action_add_event(accion, evento)

func _anadir_eje(accion: String, eje: int, direccion: float) -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	var evento = InputEventJoypadMotion.new()
	evento.axis = eje
	evento.axis_value = direccion 
	InputMap.action_add_event(accion, evento)

# Función pública para los menús
func cambiar_boton(accion: String, indice: int, nuevo_codigo) -> void:
	if controles_actuales.has(accion):
		controles_actuales[accion][indice] = nuevo_codigo
		_aplicar_controles_al_motor()
		guardar_controles() # ¡NUEVO: Guarda automáticamente al hacer un cambio!

# =========================================================
# DETECTOR DE PEROLES
# =========================================================
func _revisar_mandos_conectados() -> void:
	var mandos = Input.get_connected_joypads()
	if mandos.size() > 0:
		_on_joy_connection_changed(mandos[0], true)
	else:
		mando_conectado = false
		tipo_mando = "teclado"

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		mando_conectado = true
		var nombre = Input.get_joy_name(device_id).to_lower()
		
		if "ps" in nombre or "playstation" in nombre or "dualshock" in nombre or "dualsense" in nombre:
			tipo_mando = "playstation"
		elif "nintendo" in nombre or "switch" in nombre or "pro controller" in nombre:
			tipo_mando = "nintendo"
		else:
			tipo_mando = "xbox" 
			
		print("🎮 MANDO DETECTADO: ", Input.get_joy_name(device_id), " | Clasificado como: ", tipo_mando)
	else:
		if Input.get_connected_joypads().size() == 0:
			mando_conectado = false
			tipo_mando = "teclado"
			print("⌨️ MANDO DESCONECTADO. Volviendo al teclado de toda la vida.")
