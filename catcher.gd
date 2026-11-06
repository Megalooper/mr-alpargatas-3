extends CharacterBody3D

enum Estado { WANDER, NOTICE, CHASE, GRAB_ATTEMPT, HOLDING, THROWING, STUNNED }
var estado_actual = Estado.WANDER

@export_group("Configuración del Catcher")
@export var vel_caminar := 2.0
@export var vel_persecucion := 5.5
@export var vel_secuestro := 4.5
@export var gravedad := 15.0
@export var hp_maximo := 3


# Ojo con la ruta del AnimationPlayer. Ajustala si es necesario.
@onready var anim_player: AnimationPlayer = $catcher/AnimationPlayer 
@onready var area_agarre: Area3D = $AreaAgarre
@onready var rayo_abismo: RayCast3D = $RayCastAbismo
@onready var punto_agarre: Marker3D = $PuntoAgarre 

var jugador_objetivo: CharacterBody3D = null
var direccion_wander := Vector3.ZERO
var timer_wander := 0.0
var direccion_huida := Vector3.ZERO
var hp_actual := 3

func _ready() -> void:
	hp_actual = hp_maximo
	rayo_abismo.target_position = Vector3(0, -2.0, 0)
	
	# Conectamos la señal para saber cuándo termina el Notice
	anim_player.animation_finished.connect(_on_anim_finished)
	
	# Nombre corregido según tu imagen
	if anim_player.has_animation("walk"):
		anim_player.play("walk")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta

	match estado_actual:
		Estado.WANDER:
			_procesar_wander(delta)
		Estado.NOTICE:
			# Se queda quieto, pero gira para mirarte asustado/sorprendido
			velocity.x = 0
			velocity.z = 0
			if is_instance_valid(jugador_objetivo):
				var direccion = (jugador_objetivo.global_position - global_position).normalized()
				var angulo = atan2(-direccion.x, -direccion.z)
				rotation.y = lerp_angle(rotation.y, angulo, 10.0 * delta)
		Estado.CHASE:
			_procesar_chase(delta)
		Estado.HOLDING:
			_procesar_holding(delta)
		Estado.STUNNED:
			velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		Estado.THROWING, Estado.GRAB_ATTEMPT:
			velocity.x = 0
			velocity.z = 0

	move_and_slide()

# --- LÓGICA DE ESTADOS ---
func _procesar_wander(delta: float) -> void:
	timer_wander -= delta
	
	# Si se le acaba el tiempo O el rayo detecta que se acabó el piso
	if timer_wander <= 0 or not rayo_abismo.is_colliding():
		timer_wander = randf_range(2.0, 4.0)
		
		if not rayo_abismo.is_colliding():
			# Si hay barranco, date la vuelta 180 grados de una
			direccion_wander = -direccion_wander
		else:
			direccion_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	
	velocity.x = direccion_wander.x * vel_caminar
	velocity.z = direccion_wander.z * vel_caminar
	
	if velocity.length() > 0.1:
		# FIX: Los signos negativos le dicen que "adelante" es -Z
		var angulo = atan2(-velocity.x, -velocity.z) 
		rotation.y = lerp_angle(rotation.y, angulo, 5.0 * delta)

func _procesar_chase(delta: float) -> void:
	if is_instance_valid(jugador_objetivo):
		var direccion = (jugador_objetivo.global_position - global_position)
		direccion.y = 0 
		direccion = direccion.normalized()
		
		# FRENO DE EMERGENCIA: Solo corre si hay piso adelante
		if rayo_abismo.is_colliding():
			velocity.x = direccion.x * vel_persecucion
			velocity.z = direccion.z * vel_persecucion
		else:
			# Si hay barranco, se frena en el borde pero te sigue mirando
			velocity.x = 0
			velocity.z = 0
		
		# Rotamos usando la dirección objetivo
		var angulo = atan2(-direccion.x, -direccion.z) # FIX AQUÍ TAMBIÉN
		rotation.y = lerp_angle(rotation.y, angulo, 10.0 * delta)

func _procesar_holding(delta: float) -> void:
	# FIX SUICIDIO: Obligamos al rayo a actualizar su posición física antes de preguntar
	rayo_abismo.force_raycast_update()
	
	if is_instance_valid(jugador_objetivo):
		jugador_objetivo.global_position = punto_agarre.global_position
		jugador_objetivo.rotation.x = 0
		jugador_objetivo.rotation.z = 0
		jugador_objetivo.rotation.y = rotation.y

	if is_on_wall():
		var normal_pared = get_wall_normal()
		direccion_huida = direccion_huida.bounce(normal_pared).normalized()
		direccion_huida.y = 0

	velocity.x = direccion_huida.x * vel_secuestro
	velocity.z = direccion_huida.z * vel_secuestro
	
	if velocity.length() > 0.1:
		var angulo = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, angulo, 8.0 * delta)

	if not rayo_abismo.is_colliding():
		estado_actual = Estado.THROWING
		anim_player.play("throw")
		velocity.x = 0
		velocity.z = 0

# --- SEÑALES DE VISIÓN ---
func _on_zona_vision_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and estado_actual == Estado.WANDER:
		jugador_objetivo = body
		estado_actual = Estado.NOTICE # Pasamos a Notice primero
		anim_player.play("notice") # Animación de tu lista
		
func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "notice" and estado_actual == Estado.NOTICE:
		estado_actual = Estado.CHASE
		anim_player.play("run")
	
	elif anim_name == "grab" and estado_actual == Estado.GRAB_ATTEMPT:
		estado_actual = Estado.HOLDING
		anim_player.play("hold")
		direccion_huida = -global_transform.basis.z.normalized()
		
		# Ya lo secuestramos al chocar, solo le decimos al rayo que lo ignore
		if is_instance_valid(jugador_objetivo):
			rayo_abismo.add_exception(jugador_objetivo)
			
	elif anim_name == "throw" and estado_actual == Estado.THROWING:
		if is_instance_valid(jugador_objetivo) and jugador_objetivo.has_method("ser_lanzado"):
			# FIX TRAYECTORIA: Mucha fuerza hacia adelante (25.0) y solo un saltito vertical (4.0)
			var arco_lanzamiento = (-global_transform.basis.z * 50.0) + (Vector3.UP * 8.0)
			jugador_objetivo.ser_lanzado(arco_lanzamiento)
			jugador_objetivo = null
			
		estado_actual = Estado.WANDER
		anim_player.play("walk")
		
	elif anim_name == "realese" and estado_actual == Estado.STUNNED:
		estado_actual = Estado.WANDER
		anim_player.play("walk")
	
	elif (anim_name == "hit1" or anim_name == "hit2") and estado_actual == Estado.STUNNED:
		# Se soba el golpe y vuelve a buscar pelea
		estado_actual = Estado.CHASE
		anim_player.play("run")

func _on_zona_vision_body_exited(body: Node3D) -> void:
	if body == jugador_objetivo and (estado_actual == Estado.CHASE or estado_actual == Estado.NOTICE):
		jugador_objetivo = null
		estado_actual = Estado.WANDER
		anim_player.play("walk") # Regresa a patrullar

func _on_area_agarre_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and estado_actual == Estado.CHASE:
		estado_actual = Estado.GRAB_ATTEMPT
		anim_player.play("grab")
		jugador_objetivo = body
		
		# FIX STUN INMEDIATO: Le apagamos los ataques a Mr. Alpargatas APENAS lo toca, 
		# así no puede hacerle daño al Catcher durante la animación de agarre.
		if body.has_method("ser_secuestrado"):
			body.ser_secuestrado(self)

func soltar_por_forcejeo() -> void:
	# FIX MASHEO: Ahora puedes zafarte tanto si ya te lleva corriendo (HOLDING) 
	# como si apenas te está agarrando (GRAB_ATTEMPT)
	if estado_actual == Estado.HOLDING or estado_actual == Estado.GRAB_ATTEMPT:
		estado_actual = Estado.STUNNED
		anim_player.play("realese") 
		
		if is_instance_valid(jugador_objetivo) and jugador_objetivo.has_method("ser_lanzado"):
			var arquito_escape = (global_transform.basis.z * 5.0) + (Vector3.UP * 5.0)
			jugador_objetivo.ser_lanzado(arquito_escape)
			jugador_objetivo = null
			
# ======================
# SISTEMA DE DAÑO
# ======================
func recibir_dano_fisico() -> void:
	if hp_actual <= 0: return # Ya está muerto, déjalo en paz
	
	hp_actual -= 1
	
	# Si te tenía agarrado y por algún milagro le pegas (o le pega un rebote), te suelta
	if estado_actual == Estado.HOLDING:
		soltar_por_forcejeo()
		
	if hp_actual <= 0:
		# Se murió el secuestrador
		_morir()
	else:
		# Le duele, cancela lo que esté haciendo y entra en Stun
		estado_actual = Estado.STUNNED
		velocity.x = 0
		velocity.z = 0
		
		# Ruleta rusa de animaciones de daño
		if randi() % 2 == 0:
			anim_player.play("hit1")
		else:
			anim_player.play("hit2")

func _morir() -> void:
	# Apagamos las físicas y colisiones para que no estorbe
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	$HurtBox/CollisionShape3D.set_deferred("disabled", true)
	$ZonaVision/CollisionShape3D.set_deferred("disabled", true)
	$AreaAgarre/CollisionShape3D.set_deferred("disabled", true)
	
	# Si tienes una animación de muerte, la pones aquí. 
	# Por ahora, lo destruimos después de medio segundo
	await get_tree().create_timer(0.5).timeout
	queue_free()
