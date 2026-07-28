extends AnimatableBody3D

@export_category("Configuración de Trampa")
@export var tiempo_advertencia: float = 0.8 # Cuánto tiembla antes de caerse
@export var tiempo_respawn: float = 3.0 # Cuánto tarda en reaparecer

@onready var sensor_area: Area3D = $Area3D
@onready var colision_base: CollisionShape3D = $CollisionShape3D

var malla_visual: Node3D 
var posicion_original: Vector3
var trampa_activada: bool = false

func _ready() -> void:
	posicion_original = global_position
	
	# Rutina de ingeniero: Buscamos cuál es el dibujo automáticamente
	for hijo in get_children():
		# Si el hijo no es ni la colisión ni el área, asumimos que es el modelo 3D (Cylinder)
		if not hijo is CollisionShape3D and not hijo is Area3D:
			malla_visual = hijo
			break
			
	# Conectamos la señal de la alfombra sensora por código
	if sensor_area:
		sensor_area.body_entered.connect(_on_sensor_pisado)
	else:
		print("⚠️ TRAMPA: Coño, se te olvidó meterle el Area3D a la plataforma.")

func _on_sensor_pisado(body: Node3D) -> void:
	print("🦶 ALGUIEN PISÓ LA TRAMPA: ", body.name) 
	
	if trampa_activada:
		return
		
	if body is CharacterBody3D:
		print("¡ES MR ALPARGATAS! PREPÁRATE PA' LA CAÍDA...") 
		trampa_activada = true
		_ejecutar_caida()

func _ejecutar_caida() -> void:
	# 1. EL TEMBLOR (Game Feel)
	# Hacemos que la malla vibre hacia los lados rapidito
	var tween_temblor = create_tween().set_loops(int(tiempo_advertencia * 10))
	var shake_offset = 0.1
	tween_temblor.tween_property(malla_visual, "position", Vector3(shake_offset, 0, 0), 0.05)
	tween_temblor.tween_property(malla_visual, "position", Vector3(-shake_offset, 0, 0), 0.05)
	
	# Esperamos a que pase el tiempo de advertencia
	await get_tree().create_timer(tiempo_advertencia).timeout
	
	# Detenemos el temblor y centramos la malla a la fuerza por si quedó chueca
	tween_temblor.kill()
	malla_visual.position = Vector3.ZERO
	
	# 2. LA CAÍDA
	# Apagamos la colisión de la base para que el jugador se vaya por el barranco
	colision_base.set_deferred("disabled", true)
	
	var tween_caida = create_tween()
	# La mandamos 15 metros para abajo rápidamente
	tween_caida.tween_property(self, "global_position", global_position - Vector3(0, 15, 0), 1.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(1.0).timeout
	malla_visual.visible = false # Apagamos el dibujo para que no se vea por allá abajo
	
	# 3. EL RESPAWN
	# Esperamos el tiempo de castigo
	await get_tree().create_timer(tiempo_respawn).timeout
	
	# Devolvemos todo a la normalidad como si nada hubiera pasado
	global_position = posicion_original
	malla_visual.visible = true
	colision_base.set_deferred("disabled", false)
	
	# Reiniciamos la trampa para la próxima víctima
	trampa_activada = false
