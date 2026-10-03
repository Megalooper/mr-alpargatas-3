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

@export_category("Loot y Drops")
@export var escena_corazon: PackedScene
@export_range(0.0, 1.0) var probabilidad_drop: float = 0.3

var move_dir: Vector3 = Vector3.BACK 
var flip_cooldown: float = 0.0

var attack_distance: float = 2.0 
var attack_jump_force: float = 3.0 
var attack_forward_force: float = 7.0 
var attack_cooldown: float = 0.0 
var is_squashed: bool = false 
var projectile_timer: float = 0.0 

# ======================
# REFERENCIAS A TUS NODOS
# ======================
@onready var anim_player: AnimationPlayer = $sapito/AnimationPlayer 
@onready var sensor_piso: RayCast3D = $SensorPiso
@onready var sensor_pared: RayCast3D = $SensorPared
@onready var decision_timer: Timer = $DecisionTimer

func _ready() -> void:
	print("🐸 SAPO INICIADO: Mente fría, movimientos suaves.")
	decision_timer.timeout.connect(_on_decision_timer_timeout)

func _physics_process(delta: float) -> void:
	if global_position.y < -10.0: 
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
			velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
		State.HURT:
			projectile_timer -= delta
			velocity.x = lerp(velocity.x, 0.0, 1.5 * delta)
			velocity.z = lerp(velocity.z, 0.0, 1.5 * delta)
			
			if projectile_timer <= 0:
				_soltar_loot() 
				queue_free()
				
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				
				if collider != self and collider.is_in_group("Enemigo") and collider.has_method("_morir"):
					if collider.current_state != State.HURT:
						print("⚽ ¡GOLAZO! Un sapo eliminó a otro.")
						collider._morir("hit", global_position.direction_to(collider.global_position))

	_check_hitboxes() 
	
	if current_state != State.HURT and move_dir.length() > 0.1:
		var target_angle := Vector3.BACK.signed_angle_to(move_dir, Vector3.UP)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	move_and_slide()

# ======================
# COMBATE Y DAÑO
# ======================
func _check_hitboxes() -> void:
	# 1. Pisotón (Mantenemos esto para detectar si el jugador cae encima)
	if current_state != State.HURT:
		for body in $HitboxCabeza.get_overlapping_bodies():
			if body.is_in_group("Player"):
				if body.velocity.y <= 0.1 or body.get("_gp_state") > 0:
					body.velocity.y = body.jump_velocity * 0.8 
					_morir("stomp", Vector3.ZERO)
					return 

	# 2. Daño al Jugador
	for body in $HitboxDaño.get_overlapping_bodies():
		if body.is_in_group("Player"):
			if current_state == State.HURT and projectile_timer > 0:
				# AUTO-PATADA: Si eres balón y te tocan sin atacar
				if not body.get("_is_kicking") and not body.get("_is_crouch_kicking") and not body.get("_is_long_jumping"):
					print("🌟 ¡AUTO-PATADA GALAXY ACTIVADA!")
					if body.has_method("_start_kick"):
						body._start_kick() 
			elif body.get("_invulnerability_timer") <= 0 and current_state != State.HURT:
				# El sapo te lastima
				var empujon = global_position.direction_to(body.global_position)
				empujon.y = 0 
				if body.has_method("take_damage"):
					body.take_damage(1, empujon)

# --- NUEVA FUNCIÓN: RECIBIR DAÑO DESDE LAS HITBOXES ---
func recibir_dano_fisico() -> void:
	if projectile_timer < 1.8: 
		print("⚽ ¡PATEADO POR HITBOX!")
		var knockback = Vector3.BACK
		
		# Buscamos al jugador para calcular hacia dónde salir volando
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			var body = players[0]
			knockback = body.global_position.direction_to(global_position)
			knockback.y = 0 
			
		_morir("hit", knockback)

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
		
	if flip_cooldown <= 0.0:
		if sensor_pared.is_colliding() or not sensor_piso.is_colliding():
			move_dir = -move_dir
			flip_cooldown = 0.5 
			velocity.x = 0
			velocity.z = 0
			
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

func _process_chase(delta: float) -> void:
	if target_player:
		var distance = global_position.distance_to(target_player.global_position)
		var dir_to_player = global_position.direction_to(target_player.global_position)
		dir_to_player.y = 0 
		move_dir = dir_to_player.normalized()

		if not sensor_piso.is_colliding():
			velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
			velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
			if anim_player.current_animation != "idle":
				anim_player.play("idle")
			return 

		if attack_cooldown > 0:
			if anim_player.current_animation != "walk":
				anim_player.play("walk")
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
		else:
			if distance < attack_distance:
				current_state = State.ATTACK
				anim_player.play("attack")
				velocity.y = attack_jump_force
				velocity.x = move_dir.x * attack_forward_force
				velocity.z = move_dir.z * attack_forward_force
				return 
				
			if anim_player.current_animation != "run":
				anim_player.play("run")
			velocity.x = move_dir.x * chase_speed
			velocity.z = move_dir.z * chase_speed
		
func _process_attack(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.1:
		attack_cooldown = 2.5 
		velocity.x = 0
		velocity.z = 0
		if target_player != null:
			current_state = State.CHASE
		else:
			current_state = State.IDLE

# ======================
# EVENTOS Y MUERTE
# ======================
func _on_decision_timer_timeout() -> void:
	if current_state == State.IDLE or current_state == State.WANDER:
		var random_choice = randi() % 2 
		if random_choice == 0:
			current_state = State.IDLE
		else:
			current_state = State.WANDER
			if randf() > 0.5:
				move_dir = -move_dir
		decision_timer.start(randf_range(1.0, 3.0))

func _on_zona_vision_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and current_state != State.HURT and current_state != State.CHASE:
		target_player = body
		_ejecutar_notice()

func _ejecutar_notice() -> void:
	current_state = State.NOTICE
	anim_player.play("notice")
	await anim_player.animation_finished
	if current_state == State.NOTICE and target_player != null:
		current_state = State.CHASE

func _on_zona_vision_body_exited(body: Node3D) -> void:
	if body == target_player and current_state != State.HURT:
		target_player = null
		current_state = State.IDLE
		decision_timer.start(1.0)

func _morir(animacion_muerte: String, knockback_dir: Vector3) -> void:
	if animacion_muerte == "stomp":
		current_state = State.HURT
		velocity = Vector3.ZERO 
		is_squashed = true 
		$HitboxDaño/CollisionShape3D.set_deferred("disabled", true)
		$HitboxCabeza/CollisionShape3D.set_deferred("disabled", true)
		anim_player.play(animacion_muerte)
		await get_tree().create_timer(2.0).timeout
		_soltar_loot() 
		queue_free()
		
	elif animacion_muerte == "hit":
		current_state = State.HURT
		projectile_timer = 2.0 
		velocity = knockback_dir * 11.0 
		velocity.y = 1.2 
		if anim_player.current_animation != "hit":
			anim_player.play("hit")

func _soltar_loot() -> void:
	if escena_corazon != null and randf() <= probabilidad_drop:
		var botiquin = escena_corazon.instantiate()
		botiquin.global_position = global_position + Vector3(0, 0.5, 0)
		get_tree().current_scene.add_child(botiquin)
