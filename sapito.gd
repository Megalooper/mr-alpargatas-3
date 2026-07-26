extends CharacterBody3D

# ======================
# LA MÁQUINA DE ESTADOS
# ======================
enum State { IDLE, WANDER, CHASE, ATTACK, HURT, NOTICE }
var current_state: State = State.IDLE

# ======================
# CONFIGURACIÓN
# ======================
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed: float = 2.0
var chase_speed: float = 4.5
var turn_speed: float = 10.0 
var target_player: Node3D = null
# --- NUEVAS VARIABLES DE LOOT ---
@export_category("Loot y Drops")
@export var escena_corazon: PackedScene
@export_range(0.0, 1.0) var probabilidad_drop: float = 1.0

# Dirección de movimiento (Iniciamos en Z positivo porque así lo exportó Alejandro)
var move_dir: Vector3 = Vector3.BACK 
var flip_cooldown: float = 0.0

# --- NUEVAS VARIABLES DE ATAQUE ---
var attack_distance: float = 2.0 # A cuántos metros de distancia activa el salto
var attack_jump_force: float = 3.0 # Altura del brinco
var attack_forward_force: float = 7.0 # Qué tan duro se lanza hacia adelante
var attack_cooldown: float = 0.0 # Temporizador de descanso
var is_squashed: bool = false # Para saber si es un sticker en el piso
var projectile_timer: float = 0.0 # Temporizador de muerte por patada

# ======================
# REFERENCIAS A TUS NODOS
# ======================
@onready var anim_player: AnimationPlayer = $sapito/AnimationPlayer 
@onready var sensor_piso: RayCast3D = $SensorPiso
@onready var sensor_pared: RayCast3D = $SensorPared
@onready var decision_timer: Timer = $DecisionTimer

func _ready() -> void:
	print("🐸 SAPO INICIADO: Mente fría, movimientos suaves, y viendo pal frente de Alejandro.")
	decision_timer.timeout.connect(_on_decision_timer_timeout)

func _physics_process(delta: float) -> void:
	# --- MUERTE POR CAÍDA AL VACÍO ---
	if global_position.y < -10.0: # Ajusta este -10.0 si tu abismo es más profundo
		queue_free()
		return
	
	if is_squashed:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		else:
			$CollisionShape3D.set_deferred("disabled", true)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state != State.HURT:
		if flip_cooldown > 0: flip_cooldown -= delta
		if attack_cooldown > 0: attack_cooldown -= delta

	match current_state:
		State.IDLE: _process_idle(delta)
		State.WANDER: _process_wander(delta)
		State.CHASE: _process_chase(delta)
		State.ATTACK: _process_attack(delta)
		State.NOTICE:
			# Frena suavemente mientras hace la animación de asombro
			velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
		State.HURT:
			# --- LÓGICA DE BALÓN DE FÚTBOL ---
			projectile_timer -= delta
			
			velocity.x = lerp(velocity.x, 0.0, 1.5 * delta)
			velocity.z = lerp(velocity.z, 0.0, 1.5 * delta)
			
			if projectile_timer <= 0:
				_soltar_loot() # <--- ¡LO METEMOS AQUÍ!
				queue_free()
				
			# Escáner de choques masivos
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				
				# Si el proyectil choca con otro pana del grupo Enemigo...
				if collider != self and collider.is_in_group("Enemigo") and collider.has_method("_morir"):
					if collider.current_state != State.HURT:
						print("⚽ ¡GOLAZO! Un sapo eliminó a otro.")
						# Le pasamos la inercia del choque para que también salga volando
						collider._morir("hit", global_position.direction_to(collider.global_position))

	# Siempre escaneamos las hitboxes para que puedas repatearlo en el aire
	_check_hitboxes() 
	
	if current_state != State.HURT and move_dir.length() > 0.1:
		var target_angle := Vector3.BACK.signed_angle_to(move_dir, Vector3.UP)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	move_and_slide()

# ======================
# COMBATE: ESCÁNER CONTINUO
# ======================
func _check_hitboxes() -> void:
	# 1. Pisotón (Solo si no es un balón)
	if current_state != State.HURT:
		for body in $HitboxCabeza.get_overlapping_bodies():
			if body.is_in_group("Player"):
				if body.velocity.y <= 0.1 or body._gp_state > 0:
					body.velocity.y = body.jump_velocity * 0.8 
					_morir("stomp", Vector3.ZERO)
					return 

	# 2. Daño y Patadas
	for body in $HitboxDaño.get_overlapping_bodies():
		if body.is_in_group("Player"):
			
			# --- MAGIA GALAXY: AUTO-PATADA ---
			# Si el sapo es un balón y el player lo toca sin estar atacando...
			if current_state == State.HURT and projectile_timer > 0:
				if not body._is_kicking and not body._is_crouch_kicking and not body._is_long_jumping:
					print("🌟 ¡AUTO-PATADA GALAXY ACTIVADA!")
					body._start_kick() # Obligamos a Mr. Alpargatas a patear

			# Lógica normal de recibir la patada
			if body._is_kicking or body._is_crouch_kicking or body._is_long_jumping:
				# El timer < 1.8 evita que la misma patada se lea 60 veces por segundo
				if projectile_timer < 1.8: 
					print("⚽ ¡PATEADO!")
					var knockback = body.global_position.direction_to(global_position)
					knockback.y = 0 
					_morir("hit", knockback)
				return 
			elif body._invulnerability_timer <= 0 and current_state != State.HURT:
				# Solo te hace daño si el bicho NO está en modo balón
				var empujon = global_position.direction_to(body.global_position)
				empujon.y = 0 
				body.take_damage(1, empujon)

# ======================
# LÓGICA DE CADA ESTADO
# ======================
func _process_idle(delta: float) -> void:
	if anim_player.current_animation != "idle":
		anim_player.play("idle")
		
	velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

func _process_wander(delta: float) -> void:
	if anim_player.current_animation != "walk":
		anim_player.play("walk")
		
	# Solo leemos los sensores si el cooldown está en cero
	if flip_cooldown <= 0.0:
		if sensor_pared.is_colliding() or not sensor_piso.is_colliding():
			print("🐸 SAPO PIENSA: Obstáculo. Dando la vuelta.")
			move_dir = -move_dir
			flip_cooldown = 0.5 
			# --- FRENAMOS EN SECO PARA NO RESBALAR ---
			velocity.x = 0
			velocity.z = 0
			
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

func _process_chase(delta: float) -> void:
	if target_player:
		var distance = global_position.distance_to(target_player.global_position)
		
		# Calculamos el misil teledirigido siempre para no perderte de vista
		var dir_to_player = global_position.direction_to(target_player.global_position)
		dir_to_player.y = 0 
		move_dir = dir_to_player.normalized()

		# --- LA MAGIA DE LA FASE 2: IA ANTI-SUICIDIO ---
		# Si el sensor no detecta suelo al frente, frenamos en seco
		if not sensor_piso.is_colliding():
			# Le metemos el freno de mano
			velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
			
			# Que se quede quieto mirándote desde el borde
			if anim_player.current_animation != "idle":
				anim_player.play("idle")
				
			return # Cortamos la función aquí para que NO salte ni corra hacia la muerte

		# --- FASE 1: DESCANSO TÁCTICO (Caminando) ---
		if attack_cooldown > 0:
			if anim_player.current_animation != "walk":
				anim_player.play("walk")
				
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
			
		# --- FASE 2: PERSECUCIÓN A MUERTE (Corriendo y Saltando) ---
		else:
			# Si está a distancia de salto... ¡BUM!
			if distance < attack_distance:
				print("🐸 SAPO PIENSA: ¡Se acabó el descanso, toma tu coñazo!")
				current_state = State.ATTACK
				anim_player.play("attack")
				
				velocity.y = attack_jump_force
				velocity.x = move_dir.x * attack_forward_force
				velocity.z = move_dir.z * attack_forward_force
				return # Salimos para que el salto se ejecute
				
			# Si no está a distancia de salto, corre
			if anim_player.current_animation != "run":
				anim_player.play("run")
				
			velocity.x = move_dir.x * chase_speed
			velocity.z = move_dir.z * chase_speed
		
func _process_attack(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.1:
		attack_cooldown = 2.5 # 2.5 segundos caminando agotado hacia ti
		velocity.x = 0
		velocity.z = 0
		
		if target_player != null:
			print("🐸 SAPO PIENSA: ¡Aterricé! Voy a caminar un ratico pa' agarrar aire.")
			current_state = State.CHASE
		else:
			current_state = State.IDLE

# ======================
# EVENTOS (SEÑALES Y TIMERS)
# ======================
func _on_decision_timer_timeout() -> void:
	if current_state == State.IDLE or current_state == State.WANDER:
		var random_choice = randi() % 2 
		
		if random_choice == 0:
			current_state = State.IDLE
		else:
			current_state = State.WANDER
			# 50% de probabilidad de cambiar de dirección al empezar a caminar
			if randf() > 0.5:
				move_dir = -move_dir
				
		decision_timer.start(randf_range(1.0, 3.0))

func _on_zona_vision_body_entered(body: Node3D) -> void:
	# Verificamos que no estemos ya persiguiéndolo o muertos
	if body.is_in_group("Player") and current_state != State.HURT and current_state != State.CHASE:
		print("🐸 SAPO PIENSA: ¡Ahí está Mr. Alpargatas!")
		target_player = body
		_ejecutar_notice()

func _ejecutar_notice() -> void:
	current_state = State.NOTICE
	anim_player.play("notice")
	
	# Esperamos a que la animación termine automáticamente
	await anim_player.animation_finished
	
	# Si el sapo no se murió mientras se sorprendía y el player sigue ahí
	if current_state == State.NOTICE and target_player != null:
		print("🐸 SAPO PIENSA: ¡Ahora sí, voy por ti!")
		current_state = State.CHASE

func _on_zona_vision_body_exited(body: Node3D) -> void:
	if body == target_player and current_state != State.HURT:
		print("🐸 SAPO PIENSA: Se me escapó... Vuelvo a lo mío.")
		target_player = null
		current_state = State.IDLE
		decision_timer.start(1.0)

# ======================
# MUERTE
# ======================
func _morir(animacion_muerte: String, knockback_dir: Vector3) -> void:
	if animacion_muerte == "stomp":
		current_state = State.HURT
		velocity = Vector3.ZERO 
		is_squashed = true 
		$HitboxDaño/CollisionShape3D.set_deferred("disabled", true)
		$HitboxCabeza/CollisionShape3D.set_deferred("disabled", true)
		anim_player.play(animacion_muerte)
		await get_tree().create_timer(2.0).timeout
		_soltar_loot() # <--- ¡Y LO METEMOS AQUÍ TAMBIÉN!
		queue_free()
		
	elif animacion_muerte == "hit":
		current_state = State.HURT
		projectile_timer = 2.0 
		
		# --- KNOCKBACK NERFEADO ---
		velocity = knockback_dir * 11.0 # Antes era 18.0 (Más fácil de alcanzar)
		velocity.y = 1.2 # Antes era 2.0 (Rebote más bajito)
		
		if anim_player.current_animation != "hit":
			anim_player.play("hit")
# ======================
# LOOT
# ======================
func _soltar_loot() -> void:
	if escena_corazon != null and randf() <= probabilidad_drop:
		var botiquin = escena_corazon.instantiate()
		
		# 1. PRIMERO le decimos dónde va a nacer (altura correcta)
		botiquin.global_position = global_position + Vector3(0, 0.5, 0)
		
		# 2. LUEGO lo metemos al nivel para que su _ready() lea bien la posición
		get_tree().current_scene.add_child(botiquin)
