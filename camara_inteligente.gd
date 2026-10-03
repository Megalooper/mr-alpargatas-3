extends Node3D

@export_group("Sensibilidad")
@export_range(0.0, 1.0) var mouse_sens := 0.25
@export var joy_sens := 2.5

@export_group("Límites")
@export var pitch_min_deg := -60.0
@export var pitch_max_deg := 60.0

@export_group("Soft Follow")
## Peso bajo: tarda ~1.5–2 s en acomodarse 180°. Sube para más agresivo.
@export var yaw_follow_speed := 1.35
@export var pitch_follow_speed := 1.8
@export var move_deadzone := 0.15
@export var camera_stick_deadzone := 0.1
## Pitch al cruzar por encima cuando caminas hacia la lente.
@export var overhead_pitch_deg := 42.0
@export var altura_pivote := 1.5

var _input_dir := Vector2.ZERO
var _user_pitch := 0.2
var _seguir_jugador := true
var _is_centering := false

@onready var player: Node3D = get_parent()
@onready var skin: Node3D = %Sophia_Skin
@onready var camera_3d: Camera3D = $SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	top_level = true
	global_position = player.global_position + Vector3.UP * altura_pivote
	_user_pitch = rotation.x

	if player is CollisionObject3D:
		spring_arm.add_excluded_object(player.get_rid())

	spring_arm.collision_mask = 1
	spring_arm.margin = 0.2


func soltar() -> void:
	_seguir_jugador = false


func atar() -> void:
	_seguir_jugador = true
	if is_instance_valid(player):
		global_position = player.global_position + Vector3.UP * altura_pivote


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("center_camera"):
		_is_centering = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_input_dir = event.relative * mouse_sens


func _physics_process(delta: float) -> void:
	if _seguir_jugador and is_instance_valid(player):
		global_position = player.global_position + Vector3.UP * altura_pivote

	var pitch_min := deg_to_rad(pitch_min_deg)
	var pitch_max := deg_to_rad(pitch_max_deg)

	# 2. CONTROL MANUAL: ratón y stick derecho ganan siempre y cancelan el auto-follow.
	var joy := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var mouse_cam := _input_dir != Vector2.ZERO
	var stick_cam := joy.length() > camera_stick_deadzone

	if mouse_cam or stick_cam:
		_is_centering = false
		if stick_cam:
			rotation.x += joy.y * joy_sens * delta
			rotation.y -= joy.x * joy_sens * delta
		if mouse_cam:
			rotation.x += _input_dir.y * delta
			rotation.y -= _input_dir.x * delta
			_input_dir = Vector2.ZERO
		rotation.x = clampf(rotation.x, pitch_min, pitch_max)
		_user_pitch = rotation.x
		return

	_input_dir = Vector2.ZERO

	# Recentrar es opt-in (V/C). También se cancela con input de cámara.
	if _is_centering and is_instance_valid(skin):
		var center_yaw := skin.rotation.y
		var w := 1.0 - exp(-6.0 * delta)
		rotation.y = lerp_angle(rotation.y, center_yaw, w)
		rotation.x = lerpf(rotation.x, _user_pitch, w)
		rotation.x = clampf(rotation.x, pitch_min, pitch_max)
		if absf(angle_difference(rotation.y, center_yaw)) < 0.04:
			_is_centering = false
		return

	# 1. MODO ESTÁTICO: sin input de movimiento, la rotación no se toca.
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() < move_deadzone:
		return

	# 3. SOFT FOLLOW: solo con stick/WASD. Yaw hacia la espalda; si vas a la lente, cruza por encima.
	if not is_instance_valid(camera_3d):
		return

	var cam_basis := camera_3d.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length() < 0.001 or right.length() < 0.001:
		return
	forward = forward.normalized()
	right = right.normalized()

	var move_world := (forward * (-move_input.y) + right * move_input.x)
	move_world.y = 0.0
	if move_world.length() < 0.001:
		return
	move_world = move_world.normalized()

	# Misma convención que el skin: espalda del personaje = dirección de marcha.
	var target_yaw: float = Vector3.BACK.signed_angle_to(move_world, Vector3.UP)
	var yaw_remain: float = absf(angle_difference(rotation.y, target_yaw))
	
	# Revisamos la dirección: ¿Va hacia el fondo o viene hacia la pantalla?
	var dot_fwd := move_world.dot(forward)
	var toward_lens := dot_fwd < -0.2
	var moving_away := dot_fwd > 0.1 # Si es mayor a 0.1, se está alejando hacia el fondo

	var yaw_w := 1.0 - exp(-yaw_follow_speed * delta)
	var pitch_w := 1.0 - exp(-pitch_follow_speed * delta)

	# LA REGLA DE ORO AAA: Solo auto-seguimos la espalda si corre hacia el fondo
	if moving_away:
		rotation.y = lerp_angle(rotation.y, target_yaw, yaw_w)

	# Si viene hacia la lente, hacemos el efecto de asomarnos por encima (overhead) sin rotar
	if toward_lens and yaw_remain > deg_to_rad(55.0):
		var overhead: float = deg_to_rad(overhead_pitch_deg)
		var arc: float = sin(yaw_remain)
		var pitch_target: float = lerpf(_user_pitch, overhead, arc)
		rotation.x = lerpf(rotation.x, pitch_target, pitch_w)
	elif absf(rotation.x - _user_pitch) > 0.01:
		rotation.x = lerpf(rotation.x, _user_pitch, pitch_w)

	rotation.x = clampf(rotation.x, pitch_min, pitch_max)
