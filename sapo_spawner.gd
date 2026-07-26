extends Marker3D

@export_category("Configuración del Nido")
# Aquí es donde vas a arrastrar tu sapito.tscn en el editor
@export var enemigo_escena: PackedScene 
@export var tiempo_spawn: float = 4.0 # Cada cuántos segundos sale un sapo
@export var max_enemigos: int = 3 # Límite para que no se te crashee la PC

var enemigos_vivos: int = 0
var timer_interno: Timer

func _ready() -> void:
	# Escondemos la cruceta por si acaso
	visible = false
	
	# Creamos un relojito por código para no tener que agregar más nodos
	timer_interno = Timer.new()
	timer_interno.wait_time = tiempo_spawn
	timer_interno.autostart = true
	timer_interno.timeout.connect(_on_timer_timeout)
	add_child(timer_interno)

func _on_timer_timeout() -> void:
	# Si falta el archivo del enemigo, no hacemos nada
	if enemigo_escena == null:
		print("⚠️ SPAWNER: ¡Epa! No me has puesto la escena del sapo en el Inspector.")
		return
		
	# Solo parimos un sapo nuevo si no hemos llegado al límite
	if enemigos_vivos < max_enemigos:
		var nuevo_sapo = enemigo_escena.instantiate()
		
		# Lo agregamos al mapa (al padre de este spawner)
		get_parent().add_child(nuevo_sapo)
		
		# Lo ponemos exactamente donde está la cruceta del spawner
		nuevo_sapo.global_position = self.global_position
		
		enemigos_vivos += 1
		print("🥚 SPAWNER: ¡Ha nacido un nuevo sapo! Vivos: ", enemigos_vivos)
		
		# ¡LA MAGIA! Conectamos la muerte del sapo para llevar la cuenta
		nuevo_sapo.tree_exited.connect(_on_sapo_muerto)

func _on_sapo_muerto() -> void:
	enemigos_vivos -= 1
	print("☠️ SPAWNER: Un sapo estiró la pata. Vivos: ", enemigos_vivos)
