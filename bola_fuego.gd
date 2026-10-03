extends Area3D

@export_category("Configuración del Proyectil")
@export var velocidad: float = 12.0
@export var tiempo_vida: float = 5.0
@export var fuerza_homing: float = 3.0 

var direccion: Vector3 = Vector3.ZERO
var reflejada: bool = false 

var objetivo_actual: Node3D = null 
var creador: Node3D = null 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered) # NUEVO: Escuchamos si nos toca un área (Hitbox)
	await get_tree().create_timer(tiempo_vida).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if is_instance_valid(objetivo_actual):
		var centro_objetivo = objetivo_actual.global_position + Vector3(0, 1.0, 0)
		var dir_ideal = global_position.direction_to(centro_objetivo)
		direccion = direccion.lerp(dir_ideal, fuerza_homing * delta).normalized()
		
	global_position += direccion * velocidad * delta

# --- NUEVO: REBOTE CON HITBOXES ---
func _on_area_entered(area: Area3D) -> void:
	# Si el área que nos tocó es la Hitbox del jugador
	if area.name == "HitboxGolpe" and not reflejada:
		print("🎾 BOLA: ¡Ping-Pong! Mr. Alpargatas devolvió la bola a punta de coñazos.")
		reflejada = true
		direccion = -direccion 
		velocidad *= 1.5 
		fuerza_homing *= 6.0 
		objetivo_actual = creador 

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		# Le damos un pequeñísimo frame de gracia por si la hitbox la pateó al mismo tiempo
		await get_tree().process_frame
		if is_instance_valid(self) and not reflejada:
			print("🔥 BOLA: ¡Te quemaste el bozo, Alpargatas!")
			if body.has_method("take_damage"):
				body.take_damage(1, direccion)
			queue_free()
		
	elif body == creador and reflejada:
		print("💥 BOLA: ¡Headshot! El sapo se tragó su propio fuego.")
		if body.has_method("aturdir"):
			body.aturdir()
		queue_free()
		
	elif not body.is_in_group("Player") and body != creador:
		queue_free()
