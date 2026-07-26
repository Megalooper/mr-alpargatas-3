extends Area3D

@export var cantidad_cura: int = 2 # 2 = 1 corazón entero, 1 = medio corazón
@export var spin_speed: float = 2.0
@export var float_speed: float = 4.0
@export var float_height: float = 0.2

var start_y: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	# Guardamos la altura inicial para que levite desde ahí
	start_y = global_position.y
	# Conectamos la señal de colisión por código
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Rotación sabrosa
	rotation.y += spin_speed * delta
	
	# Efecto de levitación usando seno
	time_passed += delta
	global_position.y = start_y + (sin(time_passed * float_speed) * float_height)

func _on_body_entered(body: Node3D) -> void:
	# Revisamos que sea Mr. Alpargatas y que le falte vida
	if body.is_in_group("Player") and body.current_hp < body.max_hp:
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
