extends CharacterBody3D

# =========================================================
# MÁQUINA DE ESTADOS
# =========================================================
enum Estado { IDLE, COMBATE, CARGANDO, MAREADO }
var estado_actual: Estado = Estado.IDLE

# =========================================================
# CONFIGURACIÓN DEL MAGO
# =========================================================
@export_category("Configuración del Mago")
@export var gravedad: float = 12.0
@export var velocidad_vuelo: float = 4.0
@export var velocidad_rotacion: float = 6.0
@export var distancia_mantener: float = 8.0 

# =========================================================
# VIDA Y COMBATE
# =========================================================
@export_category("Vida y Estado")
@export var vida_maxima: int = 3
var vida_actual: int = 3
var es_invulnerable: bool = false

@export_category("Ataque y Magia")
@export var bola_fuego_escena: PackedScene 
@export var cooldown_disparo: float = 3.0

# =========================================================
# NODOS (REFERENCIAS)
# =========================================================
@onready var timer_ataque: Timer = $TimerAtaque
@onready var anim_player: AnimationPlayer = $magosapo/AnimationPlayer
@onready var zona_deteccion: Area3D = $ZonaDeteccion
@onready var malla_visual: Node3D = $magosapo
@onready var hurtbox_area: Area3D = $HurtBox # El área que escanea los golpes

# =========================================================
# VARIABLES INTERNAS
# =========================================================
var objetivo: Node3D = null
var tiempo_flotacion: float = 0.0
var altura_vuelo_base: float = 0.0
var pos_inicio_malla: float = 0.0

# =========================================================
# FUNCIONES PRINCIPALES
# =========================================================

func _ready() -> void:
	altura_vuelo_base = global_position.y
	if malla_visual:
		pos_inicio_malla = malla_visual.position.y
	
	if anim_player:
		anim_player.play("idle")
		
	if zona_deteccion:
		zona_deteccion.body_entered.connect(_on_jugador_detectado)
		zona_deteccion.body_exited.connect(_on_jugador_perdido)
	
	if timer_ataque:
		timer_ataque.wait_time = cooldown_disparo
		timer_ataque.timeout.connect(_iniciar_carga)

func _physics_process(delta: float) -> void:
	match estado_actual:
		Estado.IDLE:
			_estado_idle(delta)
		Estado.COMBATE:
			_estado_combate(delta)
		Estado.CARGANDO:
			_estado_cargando(delta)
		Estado.MAREADO:
			_estado_mareado(delta)

	# Escaneamos constantemente si nos están pateando
	_check_hitboxes()

	move_and_slide()

# =========================================================
# LÓGICA DE ESTADOS
# =========================================================

func _estado_idle(delta: float) -> void:
	_procesar_flotacion(delta, 1.5, 0.2) 
	
	velocity = Vector3.ZERO
	velocity.y = (altura_vuelo_base - global_position.y) * 4.0

func _estado_combate(delta: float) -> void:
	_procesar_flotacion(delta, 4.0, 0.4)
	
	if not is_instance_valid(objetivo):
		_cambiar_estado(Estado.IDLE, "idle")
		timer_ataque.stop() 
		return
		
	if timer_ataque.is_stopped():
		timer_ataque.start()
		
	_mirar_hacia_objetivo(delta)
	
	var dir_hacia_jugador = global_position.direction_to(objetivo.global_position)
	dir_hacia_jugador.y = 0 
	dir_hacia_jugador = dir_hacia_jugador.normalized()
	
	var distancia = global_position.distance_to(objetivo.global_position)
	var dir_movimiento = Vector3.ZERO
	
	if distancia < distancia_mantener:
		dir_movimiento = -dir_hacia_jugador 
		
	var dir_orbita = dir_hacia_jugador.cross(Vector3.UP).normalized()
	dir_movimiento = (dir_movimiento + (dir_orbita * 0.8)).normalized()
	
	velocity = dir_movimiento * velocidad_vuelo
	global_position.y = lerp(global_position.y, altura_vuelo_base, 2.0 * delta)

func _estado_cargando(delta: float) -> void:
	_procesar_flotacion(delta, 8.0, 0.1) 
	
	velocity = Vector3.ZERO 
	velocity.y = (altura_vuelo_base - global_position.y) * 4.0
	
	if is_instance_valid(objetivo):
		_mirar_hacia_objetivo(delta)

func _estado_mareado(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta
	else:
		velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 8.0 * delta)
		
	if malla_visual:
		malla_visual.position.y = lerp(malla_visual.position.y, pos_inicio_malla, 10.0 * delta)

# =========================================================
# FUNCIONES AUXILIARES
# =========================================================

func _procesar_flotacion(delta: float, velocidad_onda: float, amplitud: float) -> void:
	tiempo_flotacion += delta
	if malla_visual:
		malla_visual.position.y = pos_inicio_malla + (sin(tiempo_flotacion * velocidad_onda) * amplitud)

func _mirar_hacia_objetivo(delta: float) -> void:
	var target_pos = objetivo.global_position
	target_pos.y = global_position.y 
	
	if global_position.is_equal_approx(target_pos): return
	
	var transform_mirada = global_transform.looking_at(target_pos, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(transform_mirada.basis, velocidad_rotacion * delta)

func _cambiar_estado(nuevo_estado: Estado, nombre_animacion: String) -> void:
	estado_actual = nuevo_estado
	if anim_player:
		if anim_player.has_animation(nombre_animacion):
			anim_player.play(nombre_animacion)
		else:
			print("🚨 ERROR VISUAL: El AnimationPlayer no tiene ninguna animación llamada '", nombre_animacion, "'")
		
# =========================================================
# LÓGICA DE ATAQUE
# =========================================================

func _iniciar_carga() -> void:
	if estado_actual != Estado.COMBATE or not is_instance_valid(objetivo):
		return
		
	print("🐸 MAGO: ¡Cargando el ki...!")
	_cambiar_estado(Estado.CARGANDO, "attackcharge ")
	timer_ataque.stop() 
	
	await get_tree().create_timer(2.0).timeout
	
	if estado_actual == Estado.CARGANDO:
		_ejecutar_disparo()

func _ejecutar_disparo() -> void:
	if not is_instance_valid(objetivo):
		_cambiar_estado(Estado.IDLE, "idle")
		return
		
	if bola_fuego_escena == null:
		return
		
	if anim_player and anim_player.has_animation("attack"):
		anim_player.play("attack")
		anim_player.queue("levitate")
	
	await get_tree().create_timer(0.4).timeout
	
	if not is_instance_valid(objetivo) or estado_actual == Estado.MAREADO:
		return
	
	var proyectil = bola_fuego_escena.instantiate()
	get_parent().add_child(proyectil) 
	
	proyectil.global_position = global_position + (global_transform.basis.z * 1.5)
	
	var centro_jugador = objetivo.global_position + Vector3(0, 1.0, 0)
	var dir_disparo = global_position.direction_to(centro_jugador)
	proyectil.direccion = dir_disparo.normalized()
	
	proyectil.objetivo_actual = objetivo
	proyectil.creador = self
	
	estado_actual = Estado.COMBATE
	timer_ataque.start()

# =========================================================
# SISTEMA DE VIDA Y DOLOR
# =========================================================

func _check_hitboxes() -> void:
	if not is_instance_valid(hurtbox_area):
		return
		
	# Escaneamos si Mr. Alpargatas está tocando el área de dolor del Mago
	for body in hurtbox_area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			if body.get("_is_kicking") == true or body.get("_is_crouch_kicking") == true:
				if not es_invulnerable:
					recibir_dano_fisico()
			return

func aturdir() -> void:
	if estado_actual == Estado.MAREADO: 
		return
		
	print("🐸 MAGO: ¡Maldita sea, mi propio ki!")
	_cambiar_estado(Estado.MAREADO, "idle") 
	timer_ataque.stop()
	
	await get_tree().create_timer(4.0).timeout
	if estado_actual == Estado.MAREADO and vida_actual > 0:
		print("🐸 MAGO: Me sacudí el polvo. ¡Voy por ti!")
		_cambiar_estado(Estado.COMBATE, "levitate")

func recibir_dano_fisico() -> void:
	if vida_actual <= 0 or es_invulnerable: 
		return
		
	vida_actual -= 1
	es_invulnerable = true 
	
	if vida_actual <= 0:
		morir()
	else:
		print("🩸 MAGO: ¡Me reventaste la costilla! Me queda ", vida_actual, " de vida.")
		_cambiar_estado(Estado.COMBATE, "levitate")
		
	await get_tree().create_timer(1.0).timeout
	es_invulnerable = false

func morir() -> void:
	print("☠️ MAGO: Me fuí pal hueco...")
	_cambiar_estado(Estado.MAREADO, "dead") 
	timer_ataque.stop()
	if is_instance_valid(zona_deteccion):
		zona_deteccion.queue_free() 
	
	await get_tree().create_timer(3.0).timeout
	queue_free()

# =========================================================
# SEÑALES DEL RADAR
# =========================================================

func _on_jugador_detectado(body: Node3D) -> void:
	if body.is_in_group("Player") and estado_actual != Estado.MAREADO:
		objetivo = body
		print("🐸 MAGO: ¡PREPÁRATE PA'L FUEGO, ALPARGATAS!")
		_cambiar_estado(Estado.COMBATE, "levitate")

func _on_jugador_perdido(body: Node3D) -> void:
	if body == objetivo:
		objetivo = null
		if estado_actual != Estado.MAREADO:
			print("🐸 MAGO: Se fue pal coño...")
			_cambiar_estado(Estado.IDLE, "idle")
