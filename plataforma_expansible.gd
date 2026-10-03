extends AnimatableBody3D

@export var escala_expandida := Vector3(2.0, 1.0, 2.0) # Qué tan grande se pone (Modifícalo en el Inspector)
@export var tiempo_transicion := 0.5 # Velocidad de la animación
@export var tiempo_espera := 5.0 # Los 5 segundos de gracia

var escala_original: Vector3
var tween_actual: Tween

@onready var area_detector: Area3D = $AreaDetector
@onready var timer_colapso: Timer = $TimerColapso

func _ready() -> void:
	# Guardamos el tamaño con el que la pusiste en el nivel
	escala_original = scale
	
	# Configuramos el Timer por código para que no tengas que tocarlo en el editor
	timer_colapso.wait_time = tiempo_espera
	timer_colapso.one_shot = true
	
	# Conectamos las señales por código
	area_detector.body_entered.connect(_on_jugador_pisa)
	area_detector.body_exited.connect(_on_jugador_sale)
	timer_colapso.timeout.connect(_on_timer_timeout)

func _on_jugador_pisa(body: Node3D) -> void:
	# Copiamos la lógica de la plataforma trampa: ¡Si es un CharacterBody3D, para adentro!
	if body is CharacterBody3D: 
		timer_colapso.stop() 
		_animar_escala(escala_expandida)

func _on_jugador_sale(body: Node3D) -> void:
	if body is CharacterBody3D:
		timer_colapso.start()

func _on_timer_timeout() -> void:
	_animar_escala(escala_original) # Se encoge de nuevo al tamaño original

func _animar_escala(escala_objetivo: Vector3) -> void:
	if tween_actual and tween_actual.is_running():
		tween_actual.kill()
		
	tween_actual = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# FIX: Obligamos al Tween a correr en el mismo reloj que las físicas
	tween_actual.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) 
	
	tween_actual.tween_property(self, "scale", escala_objetivo, tiempo_transicion)
