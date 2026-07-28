extends AnimatableBody3D

@export_category("Comportamiento en el Mapa")
@export var distancia_movimiento: Vector3 = Vector3.ZERO 
@export var tiempo_viaje: float = 2.0 
@export var tiempo_espera: float = 1.0 

@export_category("Rotación")
@export var grados_rotacion: Vector3 = Vector3.ZERO 
@export var tiempo_rotacion: float = 3.0 

var posicion_inicial: Vector3

func _ready() -> void:
	# FIX: Guardamos la posición LOCAL, no la global.
	posicion_inicial = position
	
	if distancia_movimiento != Vector3.ZERO:
		_activar_movimiento()
		
	if grados_rotacion != Vector3.ZERO:
		_activar_rotacion()

func _activar_movimiento() -> void:
	var posicion_destino = posicion_inicial + distancia_movimiento
	
	var tween = get_tree().create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_loops()
	
	# FIX: Cambiamos "global_position" a "position"
	tween.tween_property(self, "position", posicion_destino, tiempo_viaje).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(tiempo_espera) 
	
	# FIX: Cambiamos "global_position" a "position"
	tween.tween_property(self, "position", posicion_inicial, tiempo_viaje).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(tiempo_espera) 

func _activar_rotacion() -> void:
	var tween = get_tree().create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_loops()
	
	var rotacion_destino = Vector3(deg_to_rad(grados_rotacion.x), deg_to_rad(grados_rotacion.y), deg_to_rad(grados_rotacion.z))
	tween.tween_property(self, "rotation", rotacion_destino, tiempo_rotacion).as_relative()
