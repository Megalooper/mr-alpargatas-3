extends CharacterBody3D

enum Estado { WANDER, NOTICE, CHASE, ATTACK, STUNNED, DEAD }
var estado_actual = Estado.WANDER

@export_group("Configuración Libélula")
@export var vel_vuelo := 3.0
@export var vel_persecucion := 6.0
@export var radio_vuelo := 5.0 # Qué tan lejos de su casa puede pasear
@export var hp_maximo := 2

# Fíjate que uso minúscula porque tu modelo se llama "libelula" en el árbol
@onready var anim_player: AnimationPlayer = $libelula/AnimationPlayer
@onready var zona_vision: Area3D = $ZonaVision

var hp_actual := 2
var jugador_objetivo: CharacterBody3D = null
var posicion_inicial := Vector3.ZERO
var punto_destino_wander := Vector3.ZERO
var timer_espera := 0.0

func _ready() -> void:
	hp_actual = hp_maximo
	posicion_inicial = global_position # Guarda donde la pusiste en el editor
	anim_player.animation_finished.connect(_on_anim_finished)
	_buscar_nuevo_punto_wander()
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(delta: float) -> void:
	# AQUÍ NO HAY GRAVEDAD, SOMOS LIBRES COMO EL VIENTO
	
	match estado_actual:
		Estado.WANDER:
			_procesar_wander(delta)
		Estado.NOTICE, Estado.STUNNED, Estado.DEAD, Estado.ATTACK:
			# Se frena en el aire suavemente
			velocity = velocity.lerp(Vector3.ZERO, 5.0 * delta)
		Estado.CHASE:
			_procesar_chase(delta)

	move_and_slide()

# --- LÓGICA DE VUELO ---
func _procesar_wander(delta: float) -> void:
	if timer_espera > 0:
		timer_espera -= delta
		velocity = velocity.lerp(Vector3.ZERO, 5.0 * delta)
		return
		
	var direccion = (punto_destino_wander - global_position)
	var distancia = direccion.length()
	
	if distancia < 0.5:
		# Llegó al punto. Se queda quieta unos 2 o 3 segundos haciendo idle
		timer_espera = randf_range(2.0, 3.0)
		_buscar_nuevo_punto_wander()
		anim_player.play("idle")
	else:
		direccion = direccion.normalized()
		velocity = velocity.lerp(direccion * vel_vuelo, 3.0 * delta)
		_rotar_hacia_movimiento(delta)

func _buscar_nuevo_punto_wander() -> void:
	# Elige un punto random en una esfera alrededor de su posición inicial
	var random_dir = Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized()
	punto_destino_wander = posicion_inicial + (random_dir * randf_range(1.0, radio_vuelo))

func _procesar_chase(delta: float) -> void:
	if is_instance_valid(jugador_objetivo):
		var direccion = (jugador_objetivo.global_position - global_position).normalized()
		velocity = velocity.lerp(direccion * vel_persecucion, 4.0 * delta)
		_rotar_hacia_movimiento(delta)

func _rotar_hacia_movimiento(delta: float) -> void:
	if velocity.length() > 0.1:
		# Rotamos asumiendo que el frente es -Z
		var angulo = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo, 8.0 * delta)

# --- SEÑALES DE VISIÓN ---
func _on_zona_vision_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and estado_actual == Estado.WANDER:
		jugador_objetivo = body
		estado_actual = Estado.NOTICE
		anim_player.play("notice")

func _on_zona_vision_body_exited(body: Node3D) -> void:
	if body == jugador_objetivo and (estado_actual == Estado.CHASE or estado_actual == Estado.NOTICE):
		jugador_objetivo = null
		estado_actual = Estado.WANDER
		# Recalculamos un punto para que vuelva a su zona natural
		_buscar_nuevo_punto_wander()
		anim_player.play("idle")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "notice" and estado_actual == Estado.NOTICE:
		estado_actual = Estado.CHASE
		# Si tiene animación de volar, ponla aquí. Por ahora usaremos idle o lo que tengas.
		anim_player.play("idle")
