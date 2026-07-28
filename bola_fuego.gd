extends Area3D

@export_category("Configuración del Proyectil")
@export var velocidad: float = 12.0
@export var tiempo_vida: float = 5.0
@export var fuerza_homing: float = 3.0 # ¡NUEVO! Qué tan rápido gira la bola en el aire

var direccion: Vector3 = Vector3.ZERO
var reflejada: bool = false 

var objetivo_actual: Node3D = null # A quién persigue
var creador: Node3D = null # El sapo que la vomitó

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(tiempo_vida).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	# --- LÓGICA TELEDIRIGIDA ---
	if is_instance_valid(objetivo_actual):
		# Apuntamos 1 metro más arriba de los pies (al pecho)
		var centro_objetivo = objetivo_actual.global_position + Vector3(0, 1.0, 0)
		var dir_ideal = global_position.direction_to(centro_objetivo)
		
		# Curvamos la dirección actual hacia la ideal de forma suave
		direccion = direccion.lerp(dir_ideal, fuerza_homing * delta).normalized()
		
	# Movemos la bola
	global_position += direccion * velocidad * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and not reflejada:
		if body.get("_is_kicking") == true or body.get("_is_crouch_kicking") == true:
			print("🎾 BOLA: ¡Ping-Pong! Mr. Alpargatas devolvió la bola.")
			reflejada = true
			
			# Invertimos la dirección de coñazo inicial
			direccion = -direccion 
			# Le metemos nitro
			velocidad *= 1.5 
			
			# ¡LA CURA PARA LA ÓRBITA! Le metemos dirección hidráulica al misil
			fuerza_homing *= 6.0 
			
			# Ahora el objetivo del misil es el propio sapo
			objetivo_actual = creador 
		else:
			print("🔥 BOLA: ¡Te quemaste el bozo, Alpargatas!")
			if body.has_method("take_damage"):
				body.take_damage(1, direccion)
			queue_free()
		
	# Cambiamos "body.name" por "creador" para que sea más exacto
	elif body == creador and reflejada:
		print("💥 BOLA: ¡Headshot! El sapo se tragó su propio fuego.")
		if body.has_method("aturdir"):
			body.aturdir()
		queue_free()
		
	elif not body.is_in_group("Player") and body != creador:
		queue_free()
