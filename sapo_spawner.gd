extends Marker3D

@export_category("Configuración del Nido")
@export var enemigo_escena: PackedScene 
@export var tiempo_spawn: float = 4.0 
@export var max_enemigos: int = 3 
@export var jugador: Node3D 
@export var distancia_activacion: float = 50.0 
@export var distancia_despawn: float = 80.0 # ¡Fase 3! Distancia para borrar a los rezagados

var enemigos_vivos: int = 0
var timer_interno: Timer
var sapos_paridos: Array[Node3D] = [] # Aquí anotamos a los chamos para el control de plagas

func _ready() -> void:
	visible = false
	
	timer_interno = Timer.new()
	timer_interno.wait_time = tiempo_spawn
	timer_interno.autostart = false # FASE 2: Lo apagamos por defecto
	timer_interno.timeout.connect(_on_timer_timeout)
	add_child(timer_interno)

func _physics_process(_delta: float) -> void:
	if jugador == null:
		return
		
	var distancia = global_position.distance_to(jugador.global_position)
	
	# --- FASE 2: AHORRO DE ENERGÍA ---
	if distancia <= distancia_activacion:
		# Si está cerca y el timer dormía, lo prendemos
		if timer_interno.is_stopped():
			timer_interno.start()
	else:
		# Si se aleja, apagamos la fábrica
		if not timer_interno.is_stopped():
			timer_interno.stop()
			
	# --- FASE 3: EL THANOS SNAP ---
	if distancia > distancia_despawn and enemigos_vivos > 0:
		_limpiar_sapos_huerfanos()

func _limpiar_sapos_huerfanos() -> void:
	print("🧹 SPAWNER: Jugador muy lejos. ¡Thanos Snap a los sapos!")
	for sapo in sapos_paridos:
		if is_instance_valid(sapo):
			sapo.queue_free()
	
	# No hace falta resetear "enemigos_vivos" aquí, porque el queue_free() 
	# activa el "tree_exited" y la función de abajo hace la matemática sola.

func _on_timer_timeout() -> void:
	if enemigo_escena == null:
		print("⚠️ SPAWNER: ¡Epa! No me has puesto la escena del sapo en el Inspector.")
		return
		
	if enemigos_vivos < max_enemigos:
		var nuevo_sapo = enemigo_escena.instantiate()
		get_parent().add_child(nuevo_sapo)
		
		# Anotamos al sapo en nuestra lista negra
		sapos_paridos.append(nuevo_sapo)
		
		# --- EL SALTO DEL SAPITO ---
		var pos_subterranea = self.global_position - Vector3(0, 2.0, 0)
		var pos_aire = self.global_position + Vector3(0, 4.0, 0)
		var pos_piso = self.global_position
		
		nuevo_sapo.global_position = pos_subterranea
		var tween = get_tree().create_tween()
		tween.tween_property(nuevo_sapo, "global_position", pos_aire, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(nuevo_sapo, "global_position", pos_piso, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		enemigos_vivos += 1
		print("🥚 SPAWNER: ¡Ha nacido un nuevo sapo saltarín! Vivos: ", enemigos_vivos)
		
		# Lambda de ingeniero: Le pasamos el propio sapo a la función para saber cuál borrar
		nuevo_sapo.tree_exited.connect(func(): _on_sapo_muerto(nuevo_sapo))

func _on_sapo_muerto(sapo_fallecido: Node3D) -> void:
	enemigos_vivos -= 1
	sapos_paridos.erase(sapo_fallecido) # Lo borramos del registro
	print("☠️ SPAWNER: Un sapo estiró la pata. Vivos: ", enemigos_vivos)
