extends CanvasLayer

@onready var cara_rect: ColorRect = $FondoHUD/HUD_Global/CaraAlpargatas
@onready var label_corazones: Label = $FondoHUD/HUD_Global/LabelCorazones

@export_category("Colores de Mr. Alpargatas")
@export var color_normal := Color(0.2, 0.8, 0.2) # Verde
@export var color_1_morado := Color(0.8, 0.8, 0.2) # Amarillo
@export var color_2_morados := Color(0.8, 0.5, 0.2) # Naranja
@export var color_llorando := Color(0.8, 0.2, 0.2) # Rojo
@export var color_dolor := Color(1.0, 1.0, 1.0) # Blanco flash

var esta_parpadeando: bool = false
var vida_interna: int = 6 

func actualizar_vida(hp_actual: int, hp_maximo: int) -> void:
	vida_interna = hp_actual 
	
	if not esta_parpadeando:
		_cambiar_cara_por_vida(hp_actual)
		
	_dibujar_corazones(hp_actual, hp_maximo)
	_latido_hud() 

func _cambiar_cara_por_vida(hp: int) -> void:
	if hp >= 5:
		cara_rect.color = color_normal
	elif hp >= 3:
		cara_rect.color = color_1_morado
	elif hp == 2:
		cara_rect.color = color_2_morados
	else:
		cara_rect.color = color_llorando

func reaccionar_al_daño() -> void: 
	esta_parpadeando = true
	cara_rect.color = color_dolor
	
	await get_tree().create_timer(0.3).timeout
	
	esta_parpadeando = false
	_cambiar_cara_por_vida(vida_interna) 

func _dibujar_corazones(hp_actual: int, hp_maximo: int) -> void:
	var total_corazones = hp_maximo / 2
	var texto_hp = ""
	
	# Evaluamos cada corazón y le metemos el emoji que toca
	for i in range(total_corazones):
		var hp_de_este_corazon = hp_actual - (i * 2)
		
		if hp_de_este_corazon >= 2:
			texto_hp += "❤️"
		elif hp_de_este_corazon == 1:
			texto_hp += "💔" # Puedes cambiarlo por "🤍" si prefieres
		else:
			texto_hp += "🖤"
			
	label_corazones.text = texto_hp

func _latido_hud() -> void:
	# El latido ahora se lo aplicamos directo al texto de los corazones
	var tween = create_tween()
	label_corazones.pivot_offset = label_corazones.size / 2
	tween.tween_property(label_corazones, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label_corazones, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
