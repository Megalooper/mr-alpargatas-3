extends CharacterBody3D

# ======================
# MOVEMENT SETTINGS
# ======================
@export_group("Movement")
@export var move_speed := 8.0
@export var crouch_waddle_speed := 1.0 
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_velocity := 5.0

@export_group("Special Jumps")
@export var back_crouch_jump_forward_push := 2.5 
@export var back_crouch_movement_nerf := 0.7 
@export var long_jump_velocity := 4.5 
@export var long_jump_forward_velocity := 15.0 
@export var long_jump_movement_nerf := 0.05 
@export var long_jump_lock_frames := 30 

@export_group("Wall Actions")
@export var wall_jump_vertical_force := 7.0    
@export var wall_jump_pushback_force := 7.0   
@export var wall_slide_speed := 2.0
@export var wall_slide_horizontal_speed := 2.0  
@export var wall_jump_decay_factor := 0.5      
@export var fast_jump_decay_reduction := 0.2    
@export var fast_jump_threshold_frames := 29    
@export var wall_jump_lock_frames := 20         
@export var max_wall_jumps := 10                
@export var wall_cling_max_frames := 250        
@export var wall_cling_fast_slide_threshold := 220 

# ======================
# GROUND POUND SETTINGS
# ======================
@export_group("Ground Pound")
@export var gp_min_jump_frames := 15
@export var gp_rise_force := 2.0
@export var gp_fall_multiplier := 3.0
@export var gp_shake_frames := 35
@export var gp_shake_intensity := 0.15
@export var gp_land_lock_frames := 45
@export var gp_end_hop_velocity := 3.0
@export var gp_fail_safe_max_frames := 100 

# ======================
# CAMERA SETTINGS
# ======================
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 8.0

# ======================
# KICK SETTINGS
# ======================
@export_group("Kick")
@export var kick_animation_speed := 1.6   
@export var kick_hop_force := 3.0         
@export var kick_forward_push := 2.0      
@export var wall_kick_pushback := 8.0      
@export var max_wall_kick_refreshes := 4 

# ======================
# INTERNAL STATE
# ======================
var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _was_on_floor := true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _floor_stable_frames := 0
var _floor_stable_required := 3

var _fall_timer := 0.0
var _fall_threshold := -10.0
var _fall_delay := 3.0
var _spawn_position: Vector3

var _respawn_lock_frames := 0
var _respawn_total_frames := 15

var _camera_start_rot := Vector3.ZERO
var _camera_target_rot := Vector3.ZERO

# ======================
# HEALTH & COMBAT
# ======================
var max_hp := 6 # 6 mitades = 3 corazones enteros
var current_hp := 6
var _invulnerability_timer := 0.0

# Wall Jump Internal State
var _last_wall_normal := Vector3.ZERO
var _consecutive_wall_jumps := 0
var _wall_jump_timer := 0 
var _is_wall_sliding := false 
var _left_wall_this_frame := false
var _wall_cling_timer := 0 
var _frames_since_last_wall_jump := 999 

# Exhaustion Logic
var _wall_cling_exhausted := false
var _post_cling_jumps := 0

# Animation state
var _is_air_anim_active := false
var _air_animation_buffer := false  
var _was_wall_sliding := false

# Kick state
var _is_kicking := false
var _is_crouch_kicking := false
var _can_kick := true 
var _wall_kick_refreshes := 0 
var _momentum_kick := false 
var _kick_cooldown_timer := 0 
var _crouch_kick_frames := 0 
var _kick_frames := 0
var _kick_is_from_crouch_cancel := false
var _back_crouch_kick_count := 0 

# Crouch state
var _is_crouching := false
var _crouch_timer := 0
const CROUCH_STOP_FRAMES := 30 
var _original_capsule_height: float
var _original_capsule_pos: Vector3
var _crouch_velocity_start := Vector3.ZERO 

# Special Jump State Tracking
var _is_back_crouch_jumping := false
var _is_long_jumping := false
var _long_jump_lock_timer := 0
var _long_jump_grace_frames := 0 

# Ground Pound Internal State
var _gp_state := 0 
var _gp_timer := 0
var _gp_jump_counter := 0
var _shake_timer := 0
var _gp_fail_safe_timer := 0 

# ======================
# NODES
# ======================
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: Node3D = %Sophia_Skin
@onready var _anim_player: AnimationPlayer = _skin.get_node("AnimationPlayer")
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D 

# ======================
# READY
# ======================
func _ready() -> void:
	if _collision_shape and _collision_shape.shape is CapsuleShape3D:
		_original_capsule_height = _collision_shape.shape.height
		_original_capsule_pos = _collision_shape.position
		
	_spawn_position = global_transform.origin
	_anim_player.animation_finished.connect(_on_animation_finished)
	
	_respawn()

# ======================
# HELPERS
# ======================
func _get_slope_direction(direction: Vector3) -> Vector3:
	if is_on_floor():
		var floor_normal = get_floor_normal()
		return direction.slide(floor_normal).normalized()
	return direction

# ======================
# INPUT
# ======================
func _input(event: InputEvent) -> void:
	if _respawn_lock_frames > 0:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		print("🔄 REINICIANDO EL NIVEL...")
		get_tree().reload_current_scene()
		return
		
	if _respawn_lock_frames > 0:
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if _gp_state > 0:
		return
		
	var long_jump_lockout := _is_long_jumping and _long_jump_lock_timer > (long_jump_lock_frames / 2)
	
	if event.is_action_pressed("kick") and not long_jump_lockout:
		# 1. Cancel logic: Transition from Crouch Kick to Kick
		if _is_crouch_kicking and _crouch_kick_frames >= 15:
			_is_crouch_kicking = false
			_kick_is_from_crouch_cancel = true 
			_start_kick() 
			return
			
		# 2. Crouching Attack: Crouchkick
		if _is_crouching and not _is_kicking and not _is_crouch_kicking:
			_start_crouch_kick()
			return

		# 3. Standard/Multi Kick logic:
		if not _is_kicking and not _is_crouch_kicking and _kick_cooldown_timer <= 0:
			if _is_back_crouch_jumping and not is_on_floor():
				if _back_crouch_kick_count < 3:
					_kick_is_from_crouch_cancel = false
					_start_kick()
			elif _can_kick:
				_kick_is_from_crouch_cancel = false
				_start_kick()
				
	if event.is_action_pressed("crouch"):
		# Cancel kick into ground pound specifically during backcrouchjump after 10 frames
		if _is_back_crouch_jumping and _is_kicking and _kick_frames >= 10:
			_is_kicking = false
			_kick_frames = 0
			_start_ground_pound()
			return

		# Existing cancel logic for crouch-cancel kick sequence
		if _is_kicking and _kick_is_from_crouch_cancel and _kick_frames >= 15:
			_is_kicking = false
			_kick_frames = 0
			_kick_is_from_crouch_cancel = false
			_start_ground_pound()

func _unhandled_input(event: InputEvent) -> void:
	if _respawn_lock_frames > 0:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_input_direction = event.screen_relative * mouse_sensitivity

# ======================
# KICK ACTIONS
# ======================
func _start_kick() -> void:
	_is_kicking = true
	_kick_frames = 0
	_is_crouch_kicking = false 
	
	if _is_back_crouch_jumping and not is_on_floor():
		_back_crouch_kick_count += 1
		_momentum_kick = true
	else:
		_can_kick = false 
		if _is_long_jumping and not is_on_floor():
			_momentum_kick = true
		else:
			_momentum_kick = false
			if is_on_floor() or velocity.y > -1.0:
				velocity.y = kick_hop_force

			var push_dir: Vector3
			if _last_movement_direction.length() > 0.1:
				push_dir = _last_movement_direction.normalized()
			else:
				push_dir = -_camera.global_basis.z
			
			velocity.x = push_dir.x * kick_forward_push
			velocity.z = push_dir.z * kick_forward_push

	_anim_player.speed_scale = kick_animation_speed
	_anim_player.play("kick", 0.05)

func _start_crouch_kick() -> void:
	_is_crouch_kicking = true
	_crouch_kick_frames = 0 
	_kick_is_from_crouch_cancel = false
	
	_anim_player.speed_scale = kick_animation_speed
	_anim_player.play("crouchkick", 0.05)

# ======================
# ANIMATION FINISHED
# ======================
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "kick":
		_is_kicking = false
		_momentum_kick = false
		_kick_frames = 0
		_kick_is_from_crouch_cancel = false
		_kick_cooldown_timer = 4 
		_anim_player.speed_scale = 1.0
		_air_animation_buffer = true
		if not is_on_floor():
			_is_air_anim_active = true
			_anim_player.play("JUMPINGANIMATION_", 0.1)

	if anim_name == "crouchkick":
		_is_crouch_kicking = false
		_crouch_kick_frames = 0
		_anim_player.speed_scale = 1.0
	
	if anim_name == "backcrouchjump" and not is_on_floor():
		_anim_player.play("backcrouchjumpfall", 0.2)
		
	if anim_name == "longjump" and not is_on_floor():
		_is_long_jumping = false 
		_is_air_anim_active = true
		_anim_player.play("JUMPINGANIMATION_", 0.2)
		
	if anim_name == "groundpound1":
		_gp_state = 2 

# ======================
# PHYSICS PROCESS
# ======================
func _physics_process(delta: float) -> void:
	_handle_camera_shake(delta)
	
	if _respawn_lock_frames <= 0:
		_camera_pivot.rotation.x += _camera_input_direction.y * delta
		_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
		_camera_pivot.rotation.y -= _camera_input_direction.x * delta
		_camera_input_direction = Vector2.ZERO
	
	if _gp_state > 0:
		_process_ground_pound(delta)
		return

	_frames_since_last_wall_jump += 1
	
	if _is_crouch_kicking:
		_crouch_kick_frames += 1
	
	if _is_kicking:
		_kick_frames += 1
	
	if _kick_cooldown_timer > 0:
		_kick_cooldown_timer -= 1

	if _respawn_lock_frames > 0:
		_camera_input_direction = Vector2.ZERO 
		var progress := float(_respawn_total_frames - _respawn_lock_frames) / _respawn_total_frames
		progress = clamp(progress, 0.0, 1.0)
		_camera_pivot.rotation = _camera_start_rot.lerp(_camera_target_rot, progress)
		_respawn_lock_frames -= 1
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- Crouch Logic ---
	if Input.is_action_pressed("crouch") and is_on_floor():
		if not _is_crouching:
			_is_crouching = true
			_crouch_timer = 0
			_crouch_velocity_start = Vector3(velocity.x, 0, velocity.z)
			
			if _collision_shape.shape is CapsuleShape3D:
				_collision_shape.shape.height = _original_capsule_height * 0.5
				_collision_shape.position.y = _original_capsule_pos.y - (_original_capsule_height * 0.25)
		
		_crouch_timer = min(_crouch_timer + 1, CROUCH_STOP_FRAMES)
		
		if _crouch_timer < CROUCH_STOP_FRAMES and not _is_crouch_kicking:
			var slide_factor = 1.0 - (float(_crouch_timer) / CROUCH_STOP_FRAMES)
			velocity.x = _crouch_velocity_start.x * slide_factor
			velocity.z = _crouch_velocity_start.z * slide_factor
	else:
		if _is_crouching:
			_is_crouching = false
			if _collision_shape.shape is CapsuleShape3D:
				_collision_shape.shape.height = _original_capsule_height
				_collision_shape.position.y = _original_capsule_pos.y
		_crouch_timer = 0

	# --- Movement Direction ---
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := -_camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := (forward * (-raw_input.y) + right * raw_input.x)
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	if _is_long_jumping and _long_jump_lock_timer > 0:
		_long_jump_lock_timer -= 1
		move_direction = Vector3.ZERO 

	# --- Apply Movement ---
	if _invulnerability_timer > 0:
		# Está aturdido: no lee tus controles, solo se frena poco a poco por la inercia
		velocity.x = lerp(velocity.x, 0.0, 2.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 2.0 * delta)
	elif not _is_kicking and not _is_crouch_kicking:
		if _is_crouching:
			if _crouch_timer >= CROUCH_STOP_FRAMES:
				velocity.x = lerp(velocity.x, move_direction.x * crouch_waddle_speed, acceleration * delta)
				velocity.z = lerp(velocity.z, move_direction.z * crouch_waddle_speed, acceleration * delta)
		else:
			if _wall_jump_timer > 0:
				_wall_jump_timer -= 1
			else:
				var current_target_speed = move_speed
				var current_accel = acceleration
				
				if _is_long_jumping and not is_on_floor():
					current_accel = acceleration * long_jump_movement_nerf
				elif _is_back_crouch_jumping and not is_on_floor():
					current_target_speed *= back_crouch_movement_nerf
				
				if _is_wall_sliding:
					current_target_speed = wall_slide_horizontal_speed
					
				velocity.x = lerp(velocity.x, move_direction.x * current_target_speed, current_accel * delta)
				velocity.z = lerp(velocity.z, move_direction.z * current_target_speed, current_accel * delta)
	elif _is_kicking:
		if not _momentum_kick:
			velocity.x = lerp(velocity.x, 0.0, 2.0 * delta) 
			velocity.z = lerp(velocity.z, 0.0, 2.0 * delta)

	# --- Gravity & Wall Actions ---
	_left_wall_this_frame = false
	_was_wall_sliding = _is_wall_sliding
	_is_wall_sliding = false

	var effective_on_floor = is_on_floor()
	if _long_jump_grace_frames > 0:
		_long_jump_grace_frames -= 1
		effective_on_floor = false

	if not effective_on_floor:
		velocity.y -= gravity * delta
		
		# --- GROUND POUND DETECTION ---
		if _is_back_crouch_jumping:
			_gp_jump_counter += 1
			if _gp_jump_counter >= gp_min_jump_frames and Input.is_action_just_pressed("crouch"):
				if not _is_kicking:
					_start_ground_pound()
		else:
			_gp_jump_counter = 0
		
		if is_on_wall_only():
			var wall_normal = get_wall_normal()
			if velocity.y < 0 and move_direction.dot(-wall_normal) > 0.5:
				if _wall_cling_timer < wall_cling_max_frames:
					_is_wall_sliding = true
					_wall_cling_timer += 1 
					_is_air_anim_active = false
					_is_back_crouch_jumping = false 
					_is_long_jumping = false
					_long_jump_lock_timer = 0
					
					if _wall_cling_timer > (wall_cling_max_frames * 0.75):
						var shake_amount = 0.05
						_skin.position.x = randf_range(-shake_amount, shake_amount)
						_skin.position.z = randf_range(-shake_amount, shake_amount)
					else:
						_skin.position = Vector3.ZERO

					var effective_slide_speed = wall_slide_speed
					if _wall_cling_timer > wall_cling_fast_slide_threshold:
						var slide_progress = float(_wall_cling_timer - wall_cling_fast_slide_threshold) / (wall_cling_max_frames - wall_cling_fast_slide_threshold)
						effective_slide_speed = lerp(wall_slide_speed, 12.0, slide_progress)

					if velocity.y < -effective_slide_speed:
						velocity.y = -effective_slide_speed
					_last_movement_direction = -wall_normal
				else:
					_wall_cling_exhausted = true
					_skin.position = Vector3.ZERO
			
			if Input.is_action_just_pressed("jump") and wall_normal != _last_wall_normal:
				var can_jump = _consecutive_wall_jumps < max_wall_jumps
				if _wall_cling_exhausted:
					if _post_cling_jumps >= 2:
						can_jump = false
				
				if can_jump:
					_consecutive_wall_jumps += 1
					if _wall_cling_exhausted:
						_post_cling_jumps += 1
						
					_wall_jump_timer = wall_jump_lock_frames
					var current_decay = wall_jump_decay_factor
					if _frames_since_last_wall_jump < fast_jump_threshold_frames:
						current_decay = max(0.0, current_decay - fast_jump_decay_reduction)
					
					var jumps_over_threshold = max(0, _consecutive_wall_jumps - 2)
					var jump_force = wall_jump_vertical_force - (jumps_over_threshold * current_decay)
					
					velocity.y = max(jump_force, 1.5) 
					velocity.x = wall_normal.x * wall_jump_pushback_force
					velocity.z = wall_normal.z * wall_jump_pushback_force
					
					_frames_since_last_wall_jump = 0
					_last_wall_normal = wall_normal
					_last_movement_direction = wall_normal
					_is_air_anim_active = true
					_air_animation_buffer = true
					_is_back_crouch_jumping = false
					_is_long_jumping = false
					_long_jump_lock_timer = 0
					_anim_player.play("JUMPINGANIMATION_", 0.1)
					
					if _wall_kick_refreshes < max_wall_kick_refreshes:
						_can_kick = true 
						_wall_kick_refreshes += 1
						
					_skin.position = Vector3.ZERO 
		else:
			_skin.position = Vector3.ZERO 
			if _last_wall_normal != Vector3.ZERO:
				_left_wall_this_frame = true
				_last_wall_normal = Vector3.ZERO
				_is_air_anim_active = true

	elif Input.is_action_just_pressed("jump") and not _is_kicking and not _is_crouch_kicking and _invulnerability_timer <= 0:
		if _is_crouching:
			if raw_input.length() > 0.5 and _crouch_timer < CROUCH_STOP_FRAMES: 
				_is_long_jumping = true
				_is_back_crouch_jumping = false
				_long_jump_lock_timer = long_jump_lock_frames
				_long_jump_grace_frames = 5 
				
				var jump_dir = _get_slope_direction(_last_movement_direction.normalized())
				
				velocity = jump_dir * long_jump_forward_velocity
				velocity.y += long_jump_velocity 
				
				_air_animation_buffer = true
				_is_air_anim_active = true
				_anim_player.play("longjump", 0.1)
				
			else:
				_is_back_crouch_jumping = true
				_is_long_jumping = false
				_back_crouch_kick_count = 0 
				velocity.y = jump_velocity * 2.0
				var push_dir = _last_movement_direction.normalized()
				velocity.x = push_dir.x * back_crouch_jump_forward_push
				velocity.z = push_dir.z * back_crouch_jump_forward_push
				
				_air_animation_buffer = true
				_is_air_anim_active = true
				_anim_player.play("backcrouchjump", 0.1)
				_anim_player.queue("backcrouchjumpfall")
			
		elif not _is_crouching:
			_is_back_crouch_jumping = false
			_is_long_jumping = false
			velocity.y = jump_velocity
			_air_animation_buffer = true
			_is_air_anim_active = true
			_anim_player.play("JUMPINGANIMATION_", 0.1)

	# --- Physics Update ---
	move_and_slide()

	if (_is_kicking or _is_crouch_kicking) and is_on_wall():
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * wall_kick_pushback
		velocity.z = wall_normal.z * wall_kick_pushback
		if not effective_on_floor:
			velocity.y = kick_hop_force * 1.2 
			
			if _wall_kick_refreshes < max_wall_kick_refreshes:
				_can_kick = true 
				_wall_kick_refreshes += 1

	if effective_on_floor and not _was_on_floor:
		_reset_states() 

	if move_direction.length() > 0.2 and not _is_kicking and not _is_crouch_kicking and _wall_jump_timer <= 0 and not _is_wall_sliding:
		if not (_is_long_jumping and _long_jump_lock_timer > 0):
			_last_movement_direction = move_direction

	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, self.rotation_speed * delta)

	_update_animation(move_direction)

	# Efecto de titilar cuando eres invulnerable (Si no lo habías puesto)
	if _invulnerability_timer > 0:
		_invulnerability_timer -= delta
		_skin.visible = Engine.get_frames_drawn() % 6 < 3 
	else:
		_skin.visible = true

	# Caída al vacío (Muerte instantánea, sin timers raros)
	if global_transform.origin.y < _fall_threshold:
		take_damage(max_hp, Vector3.ZERO) 

	_was_on_floor = effective_on_floor

# ======================
# GROUND POUND LOGIC
# ======================
func _start_ground_pound() -> void:
	_gp_state = 1
	_gp_timer = 0
	_gp_fail_safe_timer = 0
	
	velocity = Vector3.ZERO
	velocity.y = gp_rise_force
	
	_anim_player.play("groundpound1", 0.1)

func _process_ground_pound(delta: float) -> void:
	if _gp_state == 1: 
		move_and_slide()
		
	elif _gp_state == 2: 
		if _anim_player.current_animation != "groundpound2":
			_anim_player.play("groundpound2", 0.1)
			
		velocity.x = 0
		velocity.z = 0
		velocity.y -= (gravity * gp_fall_multiplier) * delta
		move_and_slide()
		
		_gp_fail_safe_timer += 1
		if _gp_fail_safe_timer >= gp_fail_safe_max_frames:
			_end_ground_pound()
			return

		if is_on_floor():
			_gp_state = 3
			_gp_timer = 0
			_shake_timer = gp_shake_frames
			_anim_player.play("groundpound3", 0.05)
			
	elif _gp_state == 3: 
		velocity = Vector3.ZERO
		_gp_timer += 1
		if _gp_timer >= gp_land_lock_frames:
			_end_ground_pound()

func _end_ground_pound() -> void:
	_gp_state = 0
	_gp_fail_safe_timer = 0
	velocity.y = gp_end_hop_velocity
	_is_air_anim_active = true
	_anim_player.play("JUMPINGANIMATION_", 0.2)

func _handle_camera_shake(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= 1
		var intensity = (float(_shake_timer) / gp_shake_frames) * gp_shake_intensity
		_camera.h_offset = randf_range(-intensity, intensity)
		_camera.v_offset = randf_range(-intensity, intensity)
	else:
		_camera.h_offset = 0
		_camera.v_offset = 0

func _reset_states() -> void:
	_can_kick = true 
	_wall_kick_refreshes = 0 
	_is_air_anim_active = false
	_air_animation_buffer = false
	_is_back_crouch_jumping = false 
	_is_long_jumping = false
	_long_jump_lock_timer = 0
	_long_jump_grace_frames = 0
	_last_wall_normal = Vector3.ZERO
	_consecutive_wall_jumps = 0 
	_wall_jump_timer = 0
	_floor_stable_frames = 0 
	_wall_cling_timer = 0 
	_frames_since_last_wall_jump = 999
	_wall_cling_exhausted = false
	_post_cling_jumps = 0
	_skin.position = Vector3.ZERO
	_gp_jump_counter = 0
	_gp_fail_safe_timer = 0
	_kick_frames = 0
	_kick_is_from_crouch_cancel = false
	_back_crouch_kick_count = 0

# ======================
# ANIMATION LOGIC
# ======================
func _update_animation(move_direction: Vector3) -> void:
	if _respawn_lock_frames > 0 or _is_kicking or _is_crouch_kicking or _gp_state > 0:
		return

	var cur = _anim_player.current_animation
	if (cur == "backcrouchjump" or cur == "longjump") and not is_on_floor():
		return

	if _is_crouching and is_on_floor():
		if _crouch_timer >= CROUCH_STOP_FRAMES and move_direction.length() > 0.1:
			if _anim_player.current_animation != "crouchwalk":
				_anim_player.play("crouchwalk", 0.2)
		else:
			if _anim_player.current_animation != "crouch" and _anim_player.current_animation != "backcrouchjump":
				_anim_player.play("crouch", 0.1)
		return

	if _is_wall_sliding:
		if _anim_player.current_animation != "wall_cling":
			_anim_player.play("wall_cling", 0.1)
		return

	if _left_wall_this_frame:
		if _anim_player.current_animation != "JUMPINGANIMATION_":
			_anim_player.play("JUMPINGANIMATION_", 0.1)
		return

	var on_floor := is_on_floor()
	var is_moving := move_direction.length() > 0.1

	if not on_floor:
		_floor_stable_frames = 0
		if not _is_air_anim_active:
			_anim_player.play("JUMPINGANIMATION_", 0.2)
			_is_air_anim_active = true
		return

	_floor_stable_frames += 1
	var stable_on_floor := _floor_stable_frames >= _floor_stable_required
	if stable_on_floor:
		if is_moving:
			if _anim_player.current_animation != "RUNNINGANIMATION":
				_anim_player.play("RUNNINGANIMATION", 0.1)
		else:
			if _anim_player.current_animation != "IDLEANIAMTION":
				_anim_player.play("IDLEANIAMTION", 0.1)

# ======================
# RESPAWN
# ======================
func _respawn() -> void:
	_camera_input_direction = Vector2.ZERO
	
	# --- MAGIA DEL CHECKPOINT REPARADA ---
	if Global.hay_checkpoint:
		global_transform.origin = Global.respawn_pos
	else:
		global_transform.origin = _spawn_position
		
	velocity = Vector3.ZERO
	_last_movement_direction = Vector3.BACK
	_fall_timer = 0.0
	_skin.rotation.y = 0.0
	_skin.position = Vector3.ZERO
	_last_wall_normal = Vector3.ZERO
	_consecutive_wall_jumps = 0
	_wall_jump_timer = 0
	_is_wall_sliding = false
	_is_air_anim_active = false
	_air_animation_buffer = false
	_left_wall_this_frame = false
	_wall_cling_timer = 0
	_frames_since_last_wall_jump = 999
	_wall_cling_exhausted = false
	_post_cling_jumps = 0
	_is_crouching = false
	_crouch_timer = 0
	_is_back_crouch_jumping = false
	_is_long_jumping = false
	_long_jump_lock_timer = 0
	_long_jump_grace_frames = 0
	_momentum_kick = false
	_kick_cooldown_timer = 0
	_crouch_kick_frames = 0
	_kick_frames = 0
	_kick_is_from_crouch_cancel = false
	_back_crouch_kick_count = 0
	_gp_state = 0
	_gp_jump_counter = 0
	_gp_fail_safe_timer = 0
	_shake_timer = 0
	
	if _collision_shape and _collision_shape.shape is CapsuleShape3D:
		_collision_shape.shape.height = _original_capsule_height
		_collision_shape.position.y = _original_capsule_pos.y
	
	_camera_start_rot = _camera_pivot.rotation
	_camera_target_rot = Vector3(0.0, _skin.rotation.y + PI, 0)
	
	_respawn_lock_frames = _respawn_total_frames
	_anim_player.play("IDLEANIAMTION", 0.15)
	_was_on_floor = true
	_floor_stable_frames = 0
	_is_kicking = false
	_is_crouch_kicking = false
	_can_kick = true 
	_wall_kick_refreshes = 0 
	current_hp = max_hp
	
	# --- INICIALIZAR EL HUD AL NACER/REVIVIR ---
	if has_node("HUD_Zelda"):
		$HUD_Zelda.esta_parpadeando = false # Por si acaso morimos recibiendo daño
		$HUD_Zelda.actualizar_vida(current_hp, max_hp)
	
# ======================
# SISTEMA DE DAÑO Y VIDA
# ======================

func take_damage(amount: int, push_dir: Vector3) -> void:
	if _invulnerability_timer > 0 or _respawn_lock_frames > 0:
		return

	current_hp -= amount
	
	# Suponiendo que instanciaste el HUD como hijo del player y lo llamaste HUD_Zelda
	if has_node("HUD_Zelda"):
		$HUD_Zelda.reaccionar_al_daño() # <-- Sin nada adentro de los paréntesis
		$HUD_Zelda.actualizar_vida(current_hp, max_hp)
	
	if current_hp <= 0:
		print("☠️ MR ALPARGATAS MURIÓ!")
		_respawn()
	else:
		print("💥 ¡AUCH! Me queda ", current_hp, " de vida.")
		# Modificado: Empujón fuerte hacia atrás, sin irnos a las nubes
		velocity = push_dir * 18.0 
		velocity.y = 1.0 # Solo un toquecito para separarlo del piso
		_invulnerability_timer = 1.0 # 1 segundo aturdido sin poder moverse
