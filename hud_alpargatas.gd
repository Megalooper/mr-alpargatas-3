extends CanvasLayer

@onready var cara_mocasin = $Margen/CaraMocasin
@onready var contenedor_corazones = $Margen/ContenedorCorazones

# ==========================================
# CARGAMOS LAS TEXTURAS EN MEMORIA
# (Asegúrate de que los nombres coincidan exacto con tus archivos)
# ==========================================
var tex_cara_full = preload("res://Rostro_Full_Vida.png")
var tex_cara_media = preload("res://Rostro_Media_Vida.png")
var tex_cara_poca = preload("res://Rostro_Poca_Vida.png")
var tex_cara_sin = preload("res://Rostro_Sin_Vida.png")

var tex_corazon_lleno = preload("res://Corazon_Completo.png")
var tex_corazon_mitad = preload("res://Corazon_Mitad.png")

func _ready() -> void:
	# Apenas arranca, limpiamos cualquier corazón de prueba que hayas dejado en el editor
	for hijo in contenedor_corazones.get_children():
		hijo.queue_free()

# ==========================================
# LA MATEMÁTICA DE LA VIDA
# ==========================================
func actualizar_vida(vida_actual: int, vida_maxima: int) -> void:
	
	# 1. ACTUALIZAR LA CARA (Calculamos el porcentaje de vida)
	var porcentaje_vida = float(vida_actual) / float(vida_maxima)
	
	if porcentaje_vida > 0.6:
		cara_mocasin.texture = tex_cara_full
	elif porcentaje_vida > 0.3:
		cara_mocasin.texture = tex_cara_media
	elif porcentaje_vida > 0.1:
		cara_mocasin.texture = tex_cara_poca
	else:
		cara_mocasin.texture = tex_cara_sin
		
	# 2. ACTUALIZAR LOS CORAZONES
	# Primero borramos los corazones viejos
	for hijo in contenedor_corazones.get_children():
		hijo.queue_free()
		
	# Como tu vida máxima es 6 (3 corazones enteros), la división entre 2 nos da los enteros.
	var corazones_enteros = vida_actual / 2
	var tiene_mitad = vida_actual % 2 != 0
	
	# Parimos los corazones enteros
	for i in range(corazones_enteros):
		_crear_corazon(tex_corazon_lleno)
		
	# Parimos el medio corazón si quedó un número impar
	if tiene_mitad:
		_crear_corazon(tex_corazon_mitad)

# ==========================================
# FUNCIONES AUXILIARES
# ==========================================
func _crear_corazon(textura: Texture2D) -> void:
	var nuevo_corazon = TextureRect.new()
	nuevo_corazon.texture = textura
	nuevo_corazon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nuevo_corazon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# ¡OJO AQUÍ! Cambia este 50, 50 por el tamaño que te haya gustado a ti en el editor
	nuevo_corazon.custom_minimum_size = Vector2(50, 50) 
	contenedor_corazones.add_child(nuevo_corazon)
	
func reaccionar_al_daño() -> void:
	# Un detallito visual: La cara se pone roja por una fracción de segundo cuando te pegan
	var tween = create_tween()
	cara_mocasin.modulate = Color(1, 0, 0) 
	tween.tween_property(cara_mocasin, "modulate", Color(1, 1, 1), 0.3)
