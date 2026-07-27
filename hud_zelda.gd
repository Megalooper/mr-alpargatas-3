extends CanvasLayer

# Cambiamos el tipo de nodo a TextureRect para que acepte tu nuevo logo
@onready var icono_alpargatas: TextureRect = $FondoHUD/HUD_Global/CaraAlpargatas
@onready var label_corazones: Label = $FondoHUD/HUD_Global/LabelCorazones

var vida_interna: int = 6 

func actualizar_vida(hp_actual: int, hp_maximo: int) -> void:
	vida_interna = hp_actual 
	
	# Ya no llamamos a la función de cambiar cara, directo a los corazones
	_dibujar_corazones(hp_actual, hp_maximo)
	_latido_hud() 

func reaccionar_al_daño() -> void: 
	# Hacemos que el logo parpadee en rojo súper rápido para el feedback del golpe
	var tween = create_tween()
	tween.tween_property(icono_alpargatas, "modulate", Color(1, 0, 0), 0.1) # Se tiñe de rojo
	tween.tween_property(icono_alpargatas, "modulate", Color(1, 1, 1), 0.2) # Vuelve a su color normal

func _dibujar_corazones(hp_actual: int, hp_maximo: int) -> void:
	var total_corazones = hp_maximo / 2
	var texto_hp = ""
	
	# Evaluamos cada corazón y le metemos el emoji que toca
	for i in range(total_corazones):
		var hp_de_este_corazon = hp_actual - (i * 2)
		
		if hp_de_este_corazon >= 2:
			texto_hp += "❤️"
		elif hp_de_este_corazon == 1:
			texto_hp += "💔" 
		else:
			texto_hp += "🖤"
			
	label_corazones.text = texto_hp

func _latido_hud() -> void:
	# Animación de latido para los emojis
	var tween = create_tween()
	label_corazones.pivot_offset = label_corazones.size / 2
	tween.tween_property(label_corazones, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label_corazones, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
