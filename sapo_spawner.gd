extends Marker3D

@export_category("Configuración del Nido")
@export var enemigo_escena: PackedScene 
@export var tiempo_spawn: float = 4.0 
@export var max_enemigos: int = 3 
@export var jugador: Node3D 
@export var distancia_activacion: float = 50.0 

var enemigos_vivos: int = 0
var timer_interno: Timer

func _ready() -> void:
	visible = false
	
	timer_interno = Timer.new()
	timer_interno.wait_time = tiempo_spawn
	timer_interno.autostart = true
	timer_interno.timeout.connect(_on_timer_timeout)
	add_child(timer_interno)

func _on_timer_timeout() -> void:
	if enemigo_escena == null:
		print("⚠️ SPAWNER: ¡Epa! No me has puesto la escena del sapo en el Inspector.")
		return
		
	# --- LÓGICA DE NERFEO ANTI-EXPLOSIONES ---
	if jugador == null:
		print("⚠️ SPAWNER: ¡Falta asignar a Mr. Alpargatas en el Inspector del Spawner!")
		return
		
	var distancia = global_position.distance_to(jugador.global_position)
	
	# Si el jugador está más lejos que el radio de activación, no hacemos un coño
	if distancia > distancia_activacion:
		return
	# -----------------------------------------
		
	if enemigos_vivos < max_enemigos:
		var nuevo_sapo = enemigo_escena.instantiate()
		
		get_parent().add_child(nuevo_sapo)
		
		# --- FASE 1: EL SALTO DEL SAPITO ---
		# 1. Lo parimos 2 metros bajo tierra
		var pos_subterranea = self.global_position - Vector3(0, 2.0, 0)
		# 2. Calculamos el pico del salto (2 metros por encima del suelo)
		var pos_aire = self.global_position + Vector3(0, 4.0, 0)
		# 3. La posición final en el piso
		var pos_piso = self.global_position
		
		# Arranca escondido
		nuevo_sapo.global_position = pos_subterranea
		
		# Creamos la animación por código (Tween)
		var tween = get_tree().create_tween()
		
		# Animación 1: Sube rápido de la tierra al aire (Ease Out para que frene arriba)
		tween.tween_property(nuevo_sapo, "global_position", pos_aire, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		# Animación 2: Cae del aire al piso (Ease In para que agarre velocidad cayendo)
		tween.tween_property(nuevo_sapo, "global_position", pos_piso, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# -----------------------------------
		
		enemigos_vivos += 1
		print("🥚 SPAWNER: ¡Ha nacido un nuevo sapo saltarín! Vivos: ", enemigos_vivos)
		
		nuevo_sapo.tree_exited.connect(_on_sapo_muerto)

func _on_sapo_muerto() -> void:
	enemigos_vivos -= 1
	print("☠️ SPAWNER: Un sapo estiró la pata. Vivos: ", enemigos_vivos)
