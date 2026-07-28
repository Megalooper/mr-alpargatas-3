extends Area3D

@export_category("Configuración del Corazón")
@export var cantidad_cura: int = 2 # 2 = 1 corazón entero, 1 = medio corazón
@export var spin_speed: float = 2.0
@export var float_speed: float = 4.0
@export var float_height: float = 0.2

@export_category("Optimización y Limpieza")
@export var tiempo_vida: float = 12.0 # Segundos totales de existencia
@export var tiempo_parpadeo: float = 3.0 # Segundos titilando antes de morir

# OJO AQUÍ: Asegúrate de que este sea el nombre de tu malla o sprite visual
@onready var malla_visual: Node3D = $heart

var start_y: float = 0.0
var time_passed: float = 0.0
var recogiendose: bool = false # Bandera antibugs

func _ready() -> void:
	# Guardamos la altura inicial para que levite desde ahí
	start_y = global_position.y
	# Conectamos la señal de colisión por código
	body_entered.connect(_on_body_entered)
	
	# Arrancamos la cuenta regresiva hacia la muerte
	_iniciar_autodestruccion()

func _process(delta: float) -> void:
	# Rotación sabrosa
	rotation.y += spin_speed * delta
	
	# Efecto de levitación usando seno
	time_passed += delta
	global_position.y = start_y + (sin(time_passed * float_speed) * float_height)

func _iniciar_autodestruccion() -> void:
	# 1. Modo chill: Existe tranquilamente casi todo su tiempo de vida
	await get_tree().create_timer(tiempo_vida - tiempo_parpadeo).timeout
	
	# Si justo lo acaban de agarrar, abortamos la misión de limpieza
	if recogiendose: return 
	
	# 2. Modo pánico: Titila escalando el dibujo rapidísimo
	var tween = create_tween().set_loops()
	tween.tween_property(malla_visual, "scale", Vector3.ZERO, 0.1)
	tween.tween_property(malla_visual, "scale", Vector3(1, 1, 1), 0.1)
	
	# 3. La ejecución
	await get_tree().create_timer(tiempo_parpadeo).timeout
	
	# Última verificación por si el jugador lo agarró en el último milisegundo
	if not recogiendose:
		print("🧹 LIMPIEZA: Un corazón caducó y fue borrado de la memoria.")
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	# Revisamos que sea Mr. Alpargatas y que le falte vida
	if body.is_in_group("Player") and body.current_hp < body.max_hp:
		recogiendose = true # Levantamos la bandera de seguridad
		print("❤️ ¡Agarraste un botiquín!")
		
		# Le sumamos la vida
		body.current_hp += cantidad_cura
		
		# Nos aseguramos de no pasarnos de la vida máxima (6 mitades)
		if body.current_hp > body.max_hp:
			body.current_hp = body.max_hp
			
		# Le avisamos al HUD que actualice las caras y los emojis
		if body.has_node("HUD_Zelda"):
			body.get_node("HUD_Zelda").actualizar_vida(body.current_hp, body.max_hp)
			
		# Destruimos el corazón del mapa
		queue_free()
