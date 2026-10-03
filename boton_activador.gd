extends StaticBody3D

@export_category("Configuración del Interruptor")
@export var plataformas_asignadas: Array[Node3D] # ¡La lista mágica para el Inspector!
@export var tiempo_activo: float = 5.0 # Segundos que duran las plataformas

@onready var sensor = $SensorPisotada
@onready var timer = $TimerPlataformas

# Aquí guardaremos el tamaño original de cada plataforma antes de desaparecerla
var escalas_originales = {} 
var esta_activado = false

func _ready() -> void:
	print("🚀 ARRANCÓ EL BOTÓN TITIRITERO")
	
	# Revisamos si los nodos existen pa' que no crashee
	if not sensor or not timer:
		print("❌ ERROR: El script no encuentra al SensorPisotada o al TimerPlataformas. ¡Revisa los nombres!")
		return
		
	timer.wait_time = tiempo_activo
	timer.one_shot = true # Seguro de vida para que no haga bucles infinitos
	
	sensor.body_entered.connect(_on_sensor_pisado)
	timer.timeout.connect(_on_timer_timeout)
	
	print("📦 Plataformas en la lista: ", plataformas_asignadas.size())
	
	for plataforma in plataformas_asignadas:
		if plataforma != null:
			print("🪄 Escondiendo a nivel atómico: ", plataforma.name)
			escalas_originales[plataforma] = plataforma.scale
			# Engañamos a Jolt: no es cero absoluto, es un tamaño microscópico
			plataforma.scale = Vector3(0.001, 0.001, 0.001)

func _on_sensor_pisado(body: Node3D) -> void:
	# Si Mr. Alpargatas pisa y el botón NO está activo aún...
	if body is CharacterBody3D and not esta_activado:
		_aparecer_plataformas()

func _aparecer_plataformas() -> void:
	esta_activado = true
	timer.start() # Arranca la cuenta regresiva
	
	# set_parallel(true) hace que todas las animaciones ocurran al mismo tiempo
	var tween_salida = create_tween().set_parallel(true)
	# ¡Recuerda esto para que Jolt y Godot no te manden a volar!
	tween_salida.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) 
	
	for plataforma in plataformas_asignadas:
		if plataforma != null:
			var escala_final = escalas_originales[plataforma]
			tween_salida.tween_property(plataforma, "scale", escala_final, 0.4)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_timer_timeout() -> void:
	print("⏰ TIEMPO AGOTADO: Escondiendo plataformas...")
	var tween_entrada = create_tween().set_parallel(true)
	tween_entrada.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	for plataforma in plataformas_asignadas:
		if plataforma != null:
			# FIX: Usamos la escala microscópica para no infartar a Jolt
			tween_entrada.tween_property(plataforma, "scale", Vector3(0.001, 0.001, 0.001), 0.3)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Esperamos a que terminen de encogerse para resetear el botón
	await tween_entrada.finished
	esta_activado = false
	print("✅ Botón reseteado y listo para otro pisotón.")
