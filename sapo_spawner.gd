extends Marker3D

@export_category("Configuración del Nido")
@export var enemigo_escena: PackedScene 
@export var tiempo_spawn: float = 4.0 
@export var max_enemigos: int = 3 
@export var jugador: Node3D 
@export var distancia_activacion: float = 30.0 

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
		nuevo_sapo.global_position = self.global_position
		
		enemigos_vivos += 1
		print("🥚 SPAWNER: ¡Ha nacido un nuevo sapo! Vivos: ", enemigos_vivos)
		
		nuevo_sapo.tree_exited.connect(_on_sapo_muerto)

func _on_sapo_muerto() -> void:
	enemigos_vivos -= 1
	print("☠️ SPAWNER: Un sapo estiró la pata. Vivos: ", enemigos_vivos)
