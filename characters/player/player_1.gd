extends RigidBody3D

func _PlayerVariables():
	pass

@onready var player_rigidbody: RigidBody3D = get_node(".")
@onready var player_rigidbody_mesh: MeshInstance3D = get_node("PlayerMI3D")
@onready var player_rigidbody_collision: CollisionShape3D = get_node("PlayerCS3D")

var state
var previousState
var direction
var previousDirection


func _PlayerCameraVariables():
	pass

@onready var first_person_view = get_node("FirstPersonViewC3D")
@onready var third_person_view = get_node("FirstPersonViewC3D/ThirdPersonViewSA3D/ThirdPersonViewC3D")

@export var default_fov: float = 110.0
@export var custom_zoom_fov: float = 110
@export var zoom_speed: float = 10.0
var scroll_speed: float = 1.0

var target_fov: float = 110.0
var mouse_sensitivity = 0.125

var mouse_horizontal_movement: float = 0.0
var mouse_vertical_movement: float = 0.0

var helmet_hud: bool = true
var thrusters: bool = false

@onready var helmet_hud_mesh: MeshInstance3D = get_node("FirstPersonViewC3D/HelmetHudMI3D")

func _input(event):
	# MOUSE CAPTURE LOGIC
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		#ZoomLogic(event)
		
		MouseLookLogic(event)
		
		CameraChangeLogic()
		
		#GrappleOnHookLogic()
		
		#GrappleOffHookLogic()


func _unhandled_input(_event: InputEvent):
	pass


func ZoomLogic(event: InputEvent):
	if event is InputEventMouseButton:
		if custom_zoom_fov <= 5:
			scroll_speed = 0.1
			mouse_sensitivity = 0.8
		elif custom_zoom_fov <= 25:
			scroll_speed = 1.0
			mouse_sensitivity = 0.5
		else:
			scroll_speed = 5.0
			mouse_sensitivity = 0.125
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			custom_zoom_fov -= scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			custom_zoom_fov += scroll_speed
		
		custom_zoom_fov = clamp(custom_zoom_fov, 1, 92)
		
		if Input.is_action_pressed("RightClick"):
			target_fov = custom_zoom_fov
		else:
			target_fov = default_fov


var mouse_move: bool = false

func MouseLookLogic(event: InputEvent):
	if event is InputEventMouseMotion:
		var zoom_factor = first_person_view.fov / default_fov
		mouse_move = true
		
		# Apply that factor so sensitivity slows down when zoomed in
		mouse_horizontal_movement = -event.relative.x * mouse_sensitivity * zoom_factor
		mouse_vertical_movement = -event.relative.y * mouse_sensitivity * zoom_factor
	else:
		mouse_move = false


func UpdateGrabLogic() -> void:
	grab_point = Vector3.ZERO

	if Input.is_action_pressed("LeftClick"):
		left_grab = true
	elif not Input.is_action_pressed("LeftClick"):
		left_grab = false
	
	if Input.is_action_pressed("RightClick"):
		right_grab = true
	elif not Input.is_action_pressed("RightClick"):
		right_grab = false


	if false:
		var space_state := get_world_3d().direct_space_state
		if not space_state:
			return

		var camera_basis = first_person_view.global_transform.basis
		
		var ray_start = first_person_view.global_position + camera_basis.y * 0.5
		var ray_end = ray_start - camera_basis.z * grab_distance + camera_basis.y * 0.5
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)

		query.exclude = [player_rigidbody.get_rid()]

		var result = space_state.intersect_ray(query)

		if not result.is_empty():
			grab_point = result.position


func CameraChangeLogic():
	if Input.is_action_just_pressed("CameraChange"):
		if first_person_view.current == true:
			first_person_view.current = false
			third_person_view.current = true
		else:
			first_person_view.current = true
			third_person_view.current = false


func GrappleOnHookLogic():
	if Input.is_action_just_pressed("LeftClick"):
		var space_state = get_world_3d().direct_space_state
		
		if not space_state:
			return
		
		var cam_basis = first_person_view.global_transform.basis
		var ray_start = first_person_view.global_transform.origin
		var ray_end = ray_start + (-cam_basis.z * 100.0)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [player_rigidbody.get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result:
			rope_anchors = [result.position]
			rope_length = player_rigidbody.global_transform.origin.distance_to(result.position)
			is_grappling = true


func GrappleOffHookLogic():
	if Input.is_action_just_pressed("RightClick"):
		if debug_objects.has("Test Line"):
					var rope = debug_objects["Test Line"]
					rope.global_position += Vector3(0, 5, 0) # Lift the whole rope up
					rope.rotate_y(deg_to_rad(45)) # Rotate the whole thing
		if is_grappling:
			is_grappling = false
			rope_anchors.clear()
			# Note: The visual cleanup happens automatically in GrappleLogic
			# because we check (not is_grappling) there.



func _ready():
	# OVERRIDE GODOT'S DEFAULT AIR RESISTANCE
	player_rigidbody.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	player_rigidbody.linear_damp = 0.0
	
	debug_objects.clear()
	
	player_rigidbody.can_sleep = false
	
	# 1. HUD Setup
	var viewport = get_node("FirstPersonViewC3D/SubViewportContainer/SubViewport")
	viewport.transparent_bg = true
	
	# 2. Safety Check: Did we find the nodes?
	if not viewport:
		print("HUD Error: SubViewport not found at path!")
		return
	
	if not helmet_hud_mesh:
		print("HUD Error: HelmetHudMesh not found at path!")
		return

	# 3. Explicitly get the texture
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tex = viewport.get_texture()
	
	# 4. Get the material (checking both override and base material)
	var mat = helmet_hud_mesh.get_surface_override_material(0)
	if mat == null:
		# If no override, try the material inside the mesh resource itself
		mat = helmet_hud_mesh.mesh.surface_get_material(0)
	
	# 5. Apply the texture
	if mat is ShaderMaterial:
		mat.set_shader_parameter("hud_texture", tex)
		print("HUD Success: Texture linked to shader.")
	else:
		print("HUD Error: Material is not a ShaderMaterial!")



func _process(delta):
		# Set the limit to 60 FPS
	Engine.max_fps = 65
	
	ZoomLevelsLogic(delta)
	
	ThrustersLogic()
	
	HelmetHudLogic()



func ZoomLevelsLogic(delta):
	if Input.is_action_pressed("RightClick") and first_person_view.fov <= 5:
		first_person_view.near = 10.0
		first_person_view.far = 900000.0
		
	elif Input.is_action_pressed("RightClick") and first_person_view.fov <= 8:
		first_person_view.near = 1.0
		first_person_view.far = 600000.0
		
	elif Input.is_action_pressed("RightClick") and first_person_view.fov <= 15:
		first_person_view.near = 0.1
		first_person_view.far = 300000.0
		
	elif Input.is_action_pressed("RightClick"):
		first_person_view.near = 0.01
		first_person_view.far = 200000.0
	else:
		first_person_view.near = 0.01
		first_person_view.far = 100000.0
	
	first_person_view.fov = lerp(first_person_view.fov, target_fov, zoom_speed * delta)


func ThrustersLogic():
	if Input.is_action_pressed("Crouch") and Input.is_action_just_pressed("RightClick"):
		if not thrusters:
			space_modifier = 0.6
			thrusters = true
		else:
			space_modifier = 0.0
			thrusters = false


func HelmetHudLogic():
	if Input.is_action_just_pressed("HelmetHud"):
		if helmet_hud == true:
			helmet_hud = false
			helmet_hud_mesh.visible = false
		else:
			helmet_hud = true
			helmet_hud_mesh.visible = true


func _integrate_forces(grappling_state: PhysicsDirectBodyState3D):
	if is_grappling and rope_anchors.size() > 0:
		var active_anchor = rope_anchors.back()
		var p_pos = grappling_state.transform.origin
		var to_anchor = active_anchor - p_pos
		var current_dist = to_anchor.length()
		
		if current_dist > rope_length:
			# 1. Positional Snap
			var correction = to_anchor.normalized() * (current_dist - rope_length)
			var xform = grappling_state.transform
			xform.origin += correction
			grappling_state.transform = xform
			
			# 2. Velocity Dampening (keep momentum sideways, kill it outward)
			var dir_to_anchor = to_anchor.normalized()
			var v_along_rope = grappling_state.linear_velocity.dot(dir_to_anchor)
			if v_along_rope < 0:
				grappling_state.linear_velocity -= dir_to_anchor * v_along_rope



@onready var hud_2d = get_node("FirstPersonViewC3D/SubViewportContainer/SubViewport/Control")

func _physics_process(delta):
	#Direction the player wants to move
	DirectionMachine()
	
	#Direction of the local gravity
	UpdateSmoothedUp(delta)
	
	#How the player lifts himself
	SelfLiftingLogic(delta)
	
	#Where and How the player jumps
	JumpingLogic(delta)
	
	#How the player balances and rotates himself
	SelfBalanceLogic(delta)
	
	#How the player can dash
	DashMachine(delta)
	
	#How the player moves himself
	MovementPhysicsLogic(delta)
	
	#What and How the player collides with
	CollisionLogic()
	
	#2D curved hud for the player
	HelmetHudInfo()
	
	#3D Compass hud for player orientation
	Compass3D(helmet_hud)
	
	#3D player fall prediction visualization logic
	#if helmet_hud:
	#	if (movementState == "moving" or !grounded) or player_rigidbody.linear_velocity.length() > 1.0:
	#		PredictFallPath(true)
	#	else:
	#		PredictFallPath(false)
	#else:
	#	PredictFallPath(false)
	
	#Grappling Hook Logic
	#GrappleLogic(delta)
	
	LeggiesLogic(delta, player_rigidbody.linear_velocity)
	
	WalkingLogic(delta)
	
	ArmatureRenderingLogic(delta)


var input_dir: Vector2
var last_input_dir: Vector2

var player_direction: Vector3
var movementState

var direction_rotation = 0
var old_direction_rotation = 0.0

func DirectionMachine():
	# 1. Get a normalized 2D vector directly from the Input map.
	# The order is: Negative X, Positive X, Negative Y, Positive Y
	input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	last_input_dir = input_dir
	# Apply to the 3D player direction
	player_direction = Vector3(input_dir.x, 0, input_dir.y)
	
	# 2. Update the main movement state
	if player_direction.length_squared() > 0:
		movementState = "moving"
		direction = "none"
		direction_rotation = 0
		
		# 3. Determine specific direction strings
		# We round the input values to ensure clean 1, 0, or -1 checks, 
		# which is especially helpful if you ever test with an analog stick.
		var rounded_x = round(input_dir.x)
		var rounded_y = round(input_dir.y)
		
		if rounded_y == 1 and rounded_x == 0:
			direction = "backward"
			direction_rotation = 0
			
		elif rounded_y == -1 and rounded_x == 0:
			direction = "forward"
			direction_rotation = 0
			
		elif rounded_y == 0 and rounded_x == 1:
			direction = "right"
			direction_rotation = -65
			
		elif rounded_y == 0 and rounded_x == -1:
			direction = "left"
			direction_rotation = 65
			
		# Diagonals
		elif rounded_y == 1 and rounded_x == 1:
			direction = "backward right"
			direction_rotation = 32
			
		elif rounded_y == 1 and rounded_x == -1:
			direction = "backward left"
			direction_rotation = -32
			
		elif rounded_y == -1 and rounded_x == 1:
			direction = "forward right" 
			direction_rotation = -32
			
		elif rounded_y == -1 and rounded_x == -1:
			direction = "forward left"
			direction_rotation = 32
		
	else:
		movementState = "standing"
		direction = "none"
		
		if not grounded:
			direction_rotation = 0
	
	direction_rotation = old_direction_rotation + (direction_rotation - old_direction_rotation) * 0.1
	hips.global_transform.basis = player_rigidbody.global_transform.basis.rotated(player_rigidbody.global_transform.basis.y, deg_to_rad(direction_rotation)).orthonormalized()
	old_direction_rotation = direction_rotation


@onready var ground_raycast: RayCast3D = get_node("HipsN3D/GroundRC3D")
@onready var gravity_raycast: RayCast3D = get_node("HipsN3D/GravityRC3D")

@onready var default_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var default_gravity_direction: Vector3 = Vector3.DOWN 

var current_gravity: float = default_gravity
var current_gravity_direction: Vector3 = default_gravity_direction

@export var upside_down_enter := -0.15
@export var upside_down_exit := 0.15

@export var UP_SMOOTH_SPEED: float = 3.0
var smoothed_up: Vector3 = Vector3.UP
var is_in_deep_space = false
var is_near_ground = false

@export_group("Air Friction")
@export var air_drag: float = 2.00
@export var air_drag_vertical: float = 2.00

@export_group("Rubber Sole")
@export var ground_stop_friction: float = 14.0
@export var ground_move_friction: float = 6.5
@export var ground_max_friction_force: float = 120000.0

func UpdateSmoothedUp(delta: float) -> void:
	var overlapping_areas = get_node("GravityDetectorA3D").get_overlapping_areas()
	var player_pos = player_rigidbody.global_position

	if overlapping_areas.size() > 0:
		var combined_gravity_vec = Vector3.ZERO
		var total_weight = 0.0
		var average_strength = 0.0

		for area in overlapping_areas:
			var dir: Vector3

			if area.gravity_point:
				dir = (area.global_position - player_pos).normalized()
			else:
				dir = area.gravity_direction.normalized()

			var strength = area.gravity
			var distance_priority = 1.0 / max(player_pos.distance_to(area.global_position) ** 2, 0.001)
			var weight = strength * distance_priority

			combined_gravity_vec += dir * weight
			total_weight += weight
			average_strength += strength

		if total_weight > 0:
			current_gravity_direction = combined_gravity_vec.normalized()
			current_gravity = average_strength / overlapping_areas.size()
			player_rigidbody.angular_damp = 0.0

			if not is_in_deep_space:
				smoothed_up = smoothed_up.lerp(-current_gravity_direction, min(1.0, UP_SMOOTH_SPEED * delta)).normalized()
	else:
		is_in_deep_space = true
		current_gravity = lerp(current_gravity, 0.0, 8.0 * delta)
		current_gravity_direction = lerp(
			current_gravity_direction,
			-player_rigidbody.global_transform.basis.y,
			min(1.0, UP_SMOOTH_SPEED * 4 * delta)
		)
		player_rigidbody.angular_damp = 0.0


func ApplyAirFriction(_delta: float) -> void:
	var gravity_axis_velocity = relative_velocity.project(current_gravity_direction)
	var air_velocity = relative_velocity - gravity_axis_velocity
	
	# Drag sideways through the air
	var drag_force = -air_velocity * air_drag * player_rigidbody.mass
	
	# A little drag along the gravity axis too
	drag_force += -gravity_axis_velocity * air_drag_vertical * player_rigidbody.mass
	
	player_rigidbody.apply_central_force(drag_force)


var relative_velocity := Vector3.ZERO

@export_group("Suspension")
@export var suspension_stiffness := 2400.0
@export var suspension_damping := 2600.0
@export var suspension_max_force: float = 40000.0

var support_grace_timer := 0.0
@export var support_grace_time := 3.0
@export var support_max_distance := 10.0

# Below this, consider the player "exactly standing".
@export var suspension_deadzone: float = 0.008

# Vertical velocity small enough to count as stationary.
@export var suspension_velocity_deadzone: float = 0.08

@export var max_ground_slope_degrees := 60.0
var walkable_surface := true

var left_grab := false
var right_grab := false
var grab_point := Vector3.ZERO
@export var grab_distance := 6.0

var grounded := false
var grounded_enter_distance := 0.05
var grounded_exit_distance := 0.08

var was_grounded: bool = false
var just_landed: bool = false
var just_left_ground: bool = false

@export var player_body_height: float = 0.6
var true_floor_distance = gravity_max_detection_range

var pid_state_hover = { "last_error": 0.0, "last_velocity": 0.0, "integral": 0.0, "first": true, "deriv_filt": 0.0 }
var pid_gains_hover = { "p": 1400.0, "i": 1.0, "d": 220.0, "integral_limit": 100.0 }


var is_body_touching: bool = false
var ground_indicator: MeshInstance3D

var ground_max_detection_range := 1.2
var gravity_max_detection_range := 20.0

var crouching_leg_length := 0.02
var standing_leg_length := 0.9
var running_leg_length := 0.9

var height_transition_speed := 2.0

var target_leg_length := standing_leg_length
var current_target_leg_length := target_leg_length
var current_leg_length := target_leg_length

var ground_collider: Node3D = null
var ground_point: Vector3 = Vector3.ZERO
var ground_normal: Vector3 = Vector3.UP

@export_group("Surface Grip & Friction")
## Friction coefficient when standing still or stopping
@export var ground_grip_friction: float = 30.0 
## Max force grip can apply per frame to prevent physics explosions
@export var max_grip_force: float = 8000.0

var previous_support_point_world: Vector3 = Vector3.ZERO

func SelfLiftingLogic(delta: float) -> void:
	relative_velocity = player_rigidbody.linear_velocity
	
	if Input.is_action_pressed("Run"):
		target_leg_length = running_leg_length 
	elif Input.is_action_pressed("Crouch"):
		target_leg_length = crouching_leg_length 
	else:
		target_leg_length = standing_leg_length
	
	if movementState == "moving":
		if grounded:
			if Input.is_action_pressed("Run"):
				height_transition_speed = 1.0
			elif Input.is_action_pressed("Crouch"):
				height_transition_speed = 2.0
			else:
				height_transition_speed = 2.2
		else:
			height_transition_speed = 1.8
	else:
		if grounded:
			if Input.is_action_pressed("Run"):
				height_transition_speed = 1.0
			elif Input.is_action_pressed("Crouch"):
				height_transition_speed = 3.0
			else:
				height_transition_speed = 3.2
		else:
			height_transition_speed = 1.8
	
	current_target_leg_length = lerp(current_target_leg_length, target_leg_length, height_transition_speed * delta)
	
	var local_gravity = gravity_raycast.global_transform.basis.inverse() * current_gravity_direction
	gravity_raycast.target_position = local_gravity.normalized() * gravity_max_detection_range
	gravity_raycast.force_raycast_update()
	
	var local_ground = ground_raycast.global_transform.basis.inverse() * current_gravity_direction
	ground_raycast.target_position = local_ground.normalized() * ground_max_detection_range
	ground_raycast.force_raycast_update()
	
	if gravity_raycast.is_colliding():
		is_near_ground = true
	else:
		is_near_ground = false
		
	if not ground_raycast.is_colliding():
		grounded = false
		was_grounded = false
		_handle_airborne_state(delta)

	if is_near_ground:
		is_in_deep_space = false
		ground_collider = gravity_raycast.get_collider()
		ground_point = gravity_raycast.get_collision_point()
		ground_normal = gravity_raycast.get_collision_normal()
	else:
		is_in_deep_space = true
	
	if ground_raycast.is_colliding():
		ground_collider = ground_raycast.get_collider()
		ground_point = ground_raycast.get_collision_point()
		ground_normal = ground_raycast.get_collision_normal()
	
	if is_near_ground:
		var to_ground := ground_point - ground_raycast.global_position
		true_floor_distance = abs(to_ground.dot(relative_up))
		
		if ground_raycast.is_colliding() or true_floor_distance <= current_leg_length + grounded_enter_distance:
			grounded = true
			support_grace_timer = 0.0
			
			if not was_grounded:
				was_grounded = true
			
			current_leg_length = min(min(true_floor_distance, current_target_leg_length), standing_leg_length)
			
			var v_tangent = relative_velocity - relative_up * relative_velocity.dot(relative_up)
			var friction_strength = ground_stop_friction if player_direction.length_squared() == 0 else ground_move_friction
			player_rigidbody.apply_central_force((-v_tangent * friction_strength * player_rigidbody.mass).limit_length(ground_max_friction_force))
			
			var height_error = current_target_leg_length - true_floor_distance
			var vertical_velocity := relative_velocity.dot(relative_up)
			var correction_force := 0.0
			
			if abs(height_error) > suspension_deadzone or abs(vertical_velocity) > suspension_velocity_deadzone:
				correction_force = height_error * pid_gains_hover.p - vertical_velocity * pid_gains_hover.d
			
			var lift_force = clamp(player_rigidbody.mass * current_gravity + correction_force, 0.0, suspension_max_force)
			player_rigidbody.apply_central_force(relative_up * lift_force)
			
			smoothed_up = smoothed_up.lerp(ground_normal.normalized(), min(1.0, walking_target_lerp * 2 * delta)).normalized()
			relative_up = smoothed_up
			ApplyAirFriction(delta)
			
		elif not ground_raycast.is_colliding() and true_floor_distance > current_target_leg_length + grounded_exit_distance:
			grounded = false
			was_grounded = false
			
			relative_up = relative_up.lerp(player_rigidbody.global_transform.basis.y, walking_target_lerp * delta).normalized()
			
			_handle_airborne_state(delta)


func _handle_airborne_state(delta: float) -> void:
	previous_support_point_world = Vector3.ZERO
	
	support_grace_timer += delta
	
	if support_grace_timer >= support_grace_time:
		support_grace_timer = 0.0

	current_leg_length = current_target_leg_length
	
	pid_state_hover["integral"] = 0.0
	pid_state_hover["last_error"] = 0.0
	pid_state_hover["deriv_filt"] = 0.0
	pid_state_hover["first"] = true


func UpdateSelfLiftingPID(error: float, delta: float, pid_state: Dictionary, gains: Dictionary) -> float:
	# 1. P-TERM
	var p_term = gains.p * error
	
	# 2. SNAPPY I-TERM (with Anti-Windup)
	# We only build Integral if we are close to the target. 
	# If we are too far, P-term should do the work.
	if abs(error) < 0.01:
		error = 0.0
		pid_state_hover["integral"] = move_toward(pid_state_hover["integral"], 0.0, delta * 20.0)
		
		#pid_state.integral += error * delta
		# Constrain the integral so it doesn't "over-charge"
		#pid_state.integral = clamp(pid_state.integral, -gains.integral_limit, gains.integral_limit)
	else:
		# If far away, bleed the integral so it's fresh when we arrive
		pid_state.integral = move_toward(pid_state.integral, 0.0, delta * 2.0)

	# The "Snap" back to center:
	# We add a tiny decay even when active to prevent "perpetual hunting"
	pid_state.integral = move_toward(pid_state.integral, 0.0, delta * 0.5)
	
	var i_term = gains.i * pid_state.integral
	
	# 3. D-TERM (The Shock Absorber)
	var d_term = 0.0
	if not pid_state.first:
		var error_rate = (error - pid_state.last_error) / delta
		# 0.8 Alpha = Very snappy, very little lag.
		pid_state.deriv_filt = lerp(pid_state.deriv_filt, error_rate, 0.8) 
		d_term = gains.d * pid_state.deriv_filt
	else:
		pid_state.first = false
	
	pid_state.last_error = error
	return p_term + i_term + d_term


var max_jump_force: float = 700.0
var min_jump_force: float = 180.0 
var jump_charge_time: float = 0.18

var current_jump_charge: float = 0.0
var is_charging_jump: bool = false

var max_thruster_force: float = 40000.0
var min_thruster_force: float = 200.0
var thruster_ramp_time: float = 0.2

var current_thruster_charge: float = 0.0

var double_tap_window: float = 0.25
var jump_tap_timer: float = 0.0
var crouch_tap_timer: float = 0.0

func JumpingLogic(delta: float) -> void:
	jump_tap_timer = max(jump_tap_timer - delta, 0.0)
	crouch_tap_timer = max(crouch_tap_timer - delta, 0.0)
	
	if thrusters:
		#if Input.is_action_just_pressed("Jump"):
		#	if jump_tap_timer > 0.0:
		#		player_rigidbody.apply_central_impulse(smoothed_up * 2000.0)
		#	jump_tap_timer = double_tap_window

		if Input.is_action_pressed("Jump"):
			current_thruster_charge = clamp(current_thruster_charge + delta / thruster_ramp_time, 0.0, 1.0)
			
			var thruster_force = lerp(min_thruster_force, max_thruster_force, current_thruster_charge)
			var arrow_length = 0.1
			var arrow_size_bottom = 0.0001
			var arrow_size_top_3 = 0.001
			
			var gravity_3d_origin = GetCurvedHUDWorldPosition(-0.88, -0.25, 0.105)
			
			var thrust_dir := player_rigidbody.global_transform.basis.y.normalized()
			var jet_start_offset := -0.011
			var jet_origin = gravity_3d_origin + thrust_dir * jet_start_offset
			var line_end = jet_origin + thrust_dir * arrow_length
			
			CreateLine("Player_Pulse_Jet_2", line_end - 2 * (thrust_dir * arrow_length * 0.52), line_end - (thrust_dir * arrow_length * 0.999), arrow_size_bottom, arrow_size_top_3 * 2.0, Color.DIM_GRAY, 1)
			
			CreateLine("Player_Pulse_Front_2", jet_origin - (thrust_dir * arrow_length / 12), line_end - (thrust_dir * arrow_length), arrow_size_bottom, arrow_size_top_3 * 2.5, Color.DARK_ORANGE, 0.5)
			CreateLine("Player_Pulse_Inner_Front_2", jet_origin - (thrust_dir * arrow_length / 12), line_end - (thrust_dir * arrow_length * 1.0), arrow_size_bottom, arrow_size_top_3 * 1.6, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Inner_Back_2", line_end - 2 * (thrust_dir * arrow_length * 0.61), line_end - (thrust_dir * arrow_length * 1.085), arrow_size_top_3 * 1.6, arrow_size_bottom, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Back_2", line_end - 2 * (thrust_dir * arrow_length * 0.63), line_end - (thrust_dir * arrow_length * 1.085), arrow_size_top_3 * 2.5, arrow_size_bottom, Color.DARK_ORANGE, 0.5)
			
			player_rigidbody.apply_central_force(thrust_dir * thruster_force)
		 
		#if Input.is_action_just_pressed("Crouch"):
		#	if crouch_tap_timer > 0.0:
		#		player_rigidbody.apply_central_impulse(-smoothed_up * 5000.0)	
		#	crouch_tap_timer = double_tap_window
		
		if Input.is_action_pressed("Crouch"):
			current_thruster_charge = clamp(current_thruster_charge + delta / thruster_ramp_time, 0.0, 1.0)
			
			var thruster_force = lerp(min_thruster_force, max_thruster_force, current_thruster_charge)
			var arrow_length = 0.006
			var arrow_size_bottom = 0.00008
			var arrow_size_top_3 = 0.0007
			
			var gravity_3d_origin = GetCurvedHUDWorldPosition(-0.88, -0.25, 0.105)
			
			var thrust_dir := -player_rigidbody.global_transform.basis.y.normalized()
			var jet_start_offset := -0.011
			var jet_origin = gravity_3d_origin + thrust_dir * jet_start_offset
			var line_end = jet_origin + thrust_dir * arrow_length
			
			CreateLine("Player_Pulse_Jet_2", line_end - 2 * (thrust_dir * arrow_length * 0.5), line_end - (thrust_dir * arrow_length * 1.6), arrow_size_top_3 * 2.8, arrow_size_bottom, Color.DIM_GRAY, 1)
			
			CreateLine("Player_Pulse_Front_2", jet_origin - 2.5 * (thrust_dir * arrow_length * 0.4), line_end - (thrust_dir * arrow_length), arrow_size_bottom, arrow_size_top_3 * 2.8, Color.DARK_ORANGE, 0.5)
			CreateLine("Player_Pulse_Inner_Front_2", jet_origin - 2.5 * (thrust_dir * arrow_length * 0.4), line_end - (thrust_dir * arrow_length * 1.0), arrow_size_bottom, arrow_size_top_3 * 1.8, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Inner_Back_2", line_end - 6.5 * (thrust_dir * arrow_length * 0.52), line_end - (thrust_dir * arrow_length * 2.0), arrow_size_top_3 * 1.8, arrow_size_bottom, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Back_2", line_end - 6.5 * (thrust_dir * arrow_length * 0.6), line_end - (thrust_dir * arrow_length * 2.0), arrow_size_top_3 * 2.6, arrow_size_bottom, Color.DARK_ORANGE, 0.5)
			
			player_rigidbody.apply_central_force(thrust_dir * thruster_force)

		else:
			current_thruster_charge = 0.0
	else:
		if Input.is_action_pressed("Jump"):
			is_charging_jump = true
			current_jump_charge = clamp(current_jump_charge + (delta / jump_charge_time), 0.0, 1.0)
		else:
			current_jump_charge = clamp(current_jump_charge - (delta / jump_charge_time), 0.0, 1.0)
		
		if is_charging_jump and Input.is_action_just_released("Jump"):
			if grounded:
				var final_jump_force = lerp(min_jump_force, max_jump_force, current_jump_charge)
				player_rigidbody.apply_central_impulse(relative_up * final_jump_force)
			is_charging_jump = false
			current_jump_charge = 0.0


var ideal_basis = Basis()

# PID states (one per axis)
var pid_state_y = { "last_error": 0.0, "last_velocity": 0.0, "integral": 0.0, "first": true, "deriv_filt": 0.0 }
var pid_state_x = { "last_error": 0.0, "last_velocity": 0.0, "integral": 0.0, "first": true, "deriv_filt": 0.0 }
var pid_state_z = { "last_error": 0.0, "last_velocity": 0.0, "integral": 0.0, "first": true, "deriv_filt": 0.0 }

# PID gains
var pid_gains_y = { "p": 1.0, "i": 0.6, "d": 0.9, "integral_limit": 1.6 }
var pid_gains_x = { "p": 1.0, "i": 0.6, "d": 0.9, "integral_limit": 1.6 }
var pid_gains_z = { "p": 1.0, "i": 0.6, "d": 0.9, "integral_limit": 1.6 }

# Increase torso strength to handle the snappier PID
var torso_strength = 1400
var torso_pid_limit = 2500.0

var neck_strength = 900
var neck_pid_limit = 1600.0

# Target look angles in radians
var target_rot = Vector3.ZERO # x=pitch, y=yaw (Note: y is no longer used, but kept for compatibility)
var yaw_basis: Basis = Basis.IDENTITY # THE NEW TRACKER

var reticle_pos = Vector3.ZERO
var smoothed_target_basis: Basis = Basis.IDENTITY
var last_valid_target_dir: Vector3 = Vector3.FORWARD
var is_reticle_snapped: bool = false
var visual_reticle_dir: Vector3 = Vector3.FORWARD

var smoothed_lerp_speed = 0.0
var smoothed_lean_strength: float = 0.0
var max_lean_angle: float = 0.0

var roll_input: float = 0.0
var current_roll: float = 0.0

var current_quaternion: Quaternion

var is_upside_down
var is_roll_upside_down

var was_in_deep_space: bool = false
var transition_blend = 1.0

func SelfBalanceLogic(delta):
	var current_transform = player_rigidbody.global_transform
	var current_basis = current_transform.basis.orthonormalized()
	current_quaternion = current_transform.basis.get_rotation_quaternion()
	
	var just_left_deep_space = was_in_deep_space and !is_in_deep_space
	was_in_deep_space = is_in_deep_space
	
	if just_left_deep_space:
		# --- Rebuild yaw_basis aligned to gravity ---
		var forward = -current_basis.z
		forward = forward - relative_up * forward.dot(relative_up)
		
		if forward.length_squared() < 0.001:
			forward = -current_basis.z
		
		forward = forward.normalized()
		
		var right = forward.cross(relative_up)
		
		if right.length_squared() < 0.001:
			right = current_basis.x
		
		right = right.normalized()
		
		forward = relative_up.cross(right).normalized()
		yaw_basis = Basis(right, relative_up, -forward).orthonormalized()
		
		# --- Extract pitch ---
		var local_forward = yaw_basis.inverse() * forward
		target_rot.x = atan2(local_forward.y, -local_forward.z)
		
		# --- Extract roll ---
		#var basis_no_roll = yaw_basis.rotated(yaw_basis.x, target_rot.x)
		#var roll_basis = basis_no_roll.inverse() * current_basis
		#var roll_q = roll_basis.get_rotation_quaternion()
		
		#var roll_axis = roll_q.get_axis()
		#var roll_angle = roll_q.get_angle()
		# Ensure sign is correct relative to forward axis
		#if roll_axis.dot(-basis_no_roll.z) < 0.0:
		#	roll_angle *= -1.0
		
		
		transition_blend = 0.0
		current_roll = 0.0
	
	# --- 1. MOUSE & ROLL INPUT ---
	mouse_horizontal_movement = lerp(mouse_horizontal_movement, 0.0, 10.0 * delta)
	mouse_vertical_movement = lerp(mouse_vertical_movement, 0.0, 10.0 * delta)
	
	var roll_dir = Input.get_axis("TopLeft", "TopRight")
	var roll_speed
	var roll_reset_speed = 0.4
	
	if grounded:
		torso_strength = 1400
		neck_strength = 900
		roll_speed = 2.2
		
		if Input.is_action_pressed("Run"):
			torso_strength = 1300
			neck_strength = 800
	
	elif is_in_deep_space:
		torso_strength = 1000
		neck_strength = 800
		roll_speed = 4.0
	
	else:
		torso_strength = 800
		neck_strength = 600
		roll_speed = 4.2
	
	roll_speed = lerp(roll_speed, 0.0, 0.3 * delta)
	
	current_roll += roll_dir * roll_speed * delta
	
	if roll_dir == 0:
		current_roll = move_toward(current_roll, 0.0, roll_reset_speed * delta)
	
	# --- 2. THE ROTATION ENGINE ---
	if grounded:
		# --- MODE A: PLANETARY (reworked 6-DOF - free full aligned Yaw, free limited Roll, free limited Pitch) ---
		# --- 3. YAW-BASED UPSIDE DOWN DETECTION ---
		if yaw_basis == Basis.IDENTITY:
			yaw_basis = current_basis
		
		transition_blend = min(transition_blend + delta * 2.0, 1.0)
		
		var up_dot = current_basis.y.dot(relative_up)
		
		if not is_upside_down and up_dot < upside_down_enter:
			is_upside_down = true
		elif is_upside_down and up_dot > upside_down_exit:
			is_upside_down = false
		
		var horizontal_input = mouse_horizontal_movement
		if is_upside_down:
			horizontal_input *= -1.0
		
		# --- ROLL-BASED UPSIDE DOWN DETECTION ---
		var vertical_input = mouse_vertical_movement
		var roll_limit = 0.90
		
		if abs(current_roll) > roll_limit:
			is_roll_upside_down = true
		else:
			is_roll_upside_down = false
			
		if is_roll_upside_down:
			vertical_input *= -1.0
		
		var yaw_delta = deg_to_rad(horizontal_input) * transition_blend
		var pitch_delta = deg_to_rad(vertical_input) * transition_blend
		
		var up_dot_yaw = clamp(yaw_basis.y.dot(relative_up), -1.0, 1.0)
		var align_quaternion := Quaternion.IDENTITY
		
		if up_dot_yaw < -0.999:
			align_quaternion = Quaternion(yaw_basis.x.normalized(), PI)
		elif up_dot_yaw < 0.999:
			align_quaternion = Quaternion(yaw_basis.y.normalized(), relative_up)
		
		var aligned_basis = (Basis(align_quaternion) * yaw_basis).orthonormalized()
		
		if not grounded:
			yaw_basis = yaw_basis.slerp(aligned_basis, transition_blend * 0.5).orthonormalized()
		else:
			yaw_basis = yaw_basis.slerp(aligned_basis, transition_blend).orthonormalized()
		
		yaw_basis = yaw_basis.rotated(yaw_basis.y, yaw_delta).orthonormalized()
		
		# --- 3. ACCUMULATE PITCH ---
		target_rot.x += pitch_delta
		
		# --- 4. CLAMPING (ONLY WHEN GROUNDED) ---
		if grounded:
			current_roll = clamp(current_roll, deg_to_rad(-70), deg_to_rad(70))
			target_rot.x = clamp(target_rot.x, deg_to_rad(-160), deg_to_rad(160))
		else:
			current_roll = SimpleWrapAngle(current_roll)
			target_rot.x = SimpleWrapAngle(target_rot.x)
	
		# --- 5. BUILD BASE (yaw + pitch) ---
		var basis_no_roll = yaw_basis.rotated(yaw_basis.x, target_rot.x)
		
		# --- 6. APPLY CONTROLLED ROLL ---
		var forward_no_roll = -basis_no_roll.z
		var roll_q = Quaternion(forward_no_roll.normalized(), current_roll)
		
		var target_basis = (Basis(roll_q) * basis_no_roll).orthonormalized()
		
		current_quaternion = current_quaternion.slerp(target_basis.get_rotation_quaternion(), transition_blend)
		ideal_basis = Basis(current_quaternion)
		
	else:
		# --- MODE B: DEEP SPACE (Pure 6-DOF - free full Yaw, free full Roll, free Full Pitch) ---
		# In space, Yaw is local to your body (Roll becomes Yaw if you're on your side)
		var local_right = current_quaternion * Vector3.RIGHT
		var local_up = current_quaternion * Vector3.UP
		var local_forward = current_quaternion * Vector3.FORWARD
		
		var up_dot = abs(local_up.dot(relative_up))
		var blend = smoothstep(0.2, 0.8, up_dot)
		var yaw_axis = relative_up.slerp(local_up, 1.0 - blend).normalized()
		
		var q_yaw = Quaternion(yaw_axis.normalized(), deg_to_rad(mouse_horizontal_movement))
		var q_pitch = Quaternion(local_right, deg_to_rad(mouse_vertical_movement))
		var q_roll = Quaternion(local_forward, current_roll)
		
		current_quaternion = (q_yaw * q_pitch * q_roll * current_quaternion).normalized()
		current_roll = 0.0 
		ideal_basis = Basis(current_quaternion)
		
	if grounded:
		ideal_basis = ideal_basis.slerp(LeaningLogic(delta, ideal_basis), 40.0 * delta)
	
	# --- 3. SOFT MANUAL ALIGNMENT OVERRIDE ---
	if not is_in_deep_space and Input.is_action_pressed("TopLeft") and Input.is_action_pressed("TopRight"):
		var align_q = Quaternion(ideal_basis.y, relative_up)
		var soft_align = Quaternion.IDENTITY.slerp(align_q, 1.0 * delta)
		ideal_basis = (Basis(soft_align) * ideal_basis).orthonormalized()
		current_roll = lerp(current_roll, 0.0, roll_speed * delta)
	
	# --- 5. TORQUE/PID CALCULATIONS ---
	var rel_basis = current_basis.inverse() * ideal_basis
	var q_error = rel_basis.get_rotation_quaternion()
	var angle = q_error.get_angle()
	
	var axis = Vector3.ZERO
	if angle > 0.00001:
		axis = q_error.get_axis()
	
	var error_vector = Vector3.ZERO
	if angle > 0.00001: 
		error_vector = axis * angle
	
	var out_x = clamp(UpdateSelfBalancePID(error_vector.x, delta, pid_state_x, pid_gains_x), -torso_pid_limit, torso_pid_limit)
	var out_y = clamp(UpdateSelfBalancePID(error_vector.y, delta, pid_state_y, pid_gains_y), -neck_pid_limit, neck_pid_limit)
	var out_z = clamp(UpdateSelfBalancePID(error_vector.z, delta, pid_state_z, pid_gains_z), -torso_pid_limit, torso_pid_limit)
	
	# --- 6. STABILIZATION & JITTER KILLER ---
	var deadzone = 0.001 
	var soft_zone = 0.06 
	var power_factor = smoothstep(deadzone, soft_zone, angle)
	
	var torque_local = Vector3(
		out_x * power_factor * torso_strength,
		out_y * power_factor * neck_strength,
		out_z * power_factor * torso_strength
	)
	
	var b = current_transform.basis
	var torque_world = b.x * torque_local.x + b.y * torque_local.y + b.z * torque_local.z
	
	# --- 7. ADAPTIVE DAMPING ---
	var final_damping = 15.0 
	if angle < soft_zone:
		final_damping *= remap(angle, soft_zone, deadzone, 1.0, 4.0)
	
	# Apply final torque
	player_rigidbody.apply_torque(torque_world - (player_rigidbody.get_angular_velocity() * final_damping))


func UpdateSelfBalancePID(error: float, delta: float, pid_state: Dictionary, gains: Dictionary) -> float:
	# 1. Kill the Integral when stopped
	# If the error is tiny, don't just leak it—kill it.
	if abs(error) < 0.005:
		pid_state.integral = 0.0
	else:
		pid_state.integral = clamp(pid_state.integral + error * delta, -gains.integral_limit, gains.integral_limit)

	var p_term = gains.p * error
	var i_term = gains.i * pid_state.integral
	
	var d_term = 0.0
	if not pid_state.first:
		var error_rate = (error - pid_state.last_error) / delta
		
		# LOWER this alpha (0.1 - 0.2) if the jitter is high-frequency "buzzing"
		# HIGHER this alpha (0.5 - 0.8) if the jitter is slow "bouncing"
		pid_state.deriv_filt = lerp(pid_state.deriv_filt, error_rate, 0.15) 
		d_term = gains.d * pid_state.deriv_filt
	
	pid_state.last_error = error
	return p_term + i_term + d_term


# --- LEANING PHYSICS STATE ---
# We store the lean as a single vector. The length is the strength, the normalized vector is the direction.
var current_lean_vec: Vector3 = Vector3.ZERO
var lean_velocity_vec: Vector3 = Vector3.ZERO 

# --- LEANING TUNING PROFILES ---
# str = target strength, stiff = spring stiffness, damp = spring damping
# Lower damping = more bounciness/overshoot. Higher = stiff and snappy.
var max_allowed_lean = 0.50
var lean_profiles = {
	"idle":   { "str": 0.0,  "stiff": 60.0,  "damp": 12.0 },
	"walk":   { "str": 0.08, "stiff": 100.0, "damp": 9.5 },
	"run":    { "str": 0.40, "stiff": 150.0, "damp": 12.5 },  # Very bouncy
	"crouch": { "str": 0.16, "stiff": 80.0,  "damp": 14.0 }  # Very stiff
}

func LeaningLogic(delta: float, current_ideal_basis: Basis) -> Basis:
	var current_profile = lean_profiles["idle"]
	var intent_dir: Vector3 = Vector3.ZERO
	
	# 1. Determine Intent based on Input
	if movementState == "moving":
		intent_dir = -player_direction.normalized()
		if Input.is_action_pressed("Crouch"):
			current_profile = lean_profiles["crouch"]
		elif Input.is_action_pressed("Run"):
			current_profile = lean_profiles["run"]
		else:
			current_profile = lean_profiles["walk"]
	else:
		current_profile = lean_profiles["idle"]
	
	var target_lean_vec = intent_dir * current_profile["str"]
	
	# 3. Spring-Damper System
	var spring_force = (target_lean_vec - current_lean_vec) * current_profile["stiff"]
	var damping_force = lean_velocity_vec * current_profile["damp"]
	var acceleration = spring_force - damping_force
	
	lean_velocity_vec += acceleration * delta
	current_lean_vec += lean_velocity_vec * delta
	
	# 4. Clamp Maximum Lean
	if current_lean_vec.length() > max_allowed_lean:
		current_lean_vec = current_lean_vec.normalized() * max_allowed_lean
	
	# 5. Apply Lean Rotations to the Ideal Basis
	var lean_basis = current_ideal_basis
	lean_basis = lean_basis.rotated(current_ideal_basis.x, -current_lean_vec.z)
	lean_basis = lean_basis.rotated(current_ideal_basis.z, current_lean_vec.x)
	
	return lean_basis.orthonormalized()


@export var dash_impulse := 20000.0
@export var dash_tap_time := 0.18
@export var dash_cooldown := 0.15

var shift_held := false
var shift_press_time := 0.0
var dash_direction := Vector3.ZERO
var dash_cooldown_timer := 0.0


func DashMachine(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if Input.is_action_just_pressed("Run") and thrusters:
		shift_held = true
		shift_press_time = 0.0
		if shift_press_time <= dash_tap_time and dash_cooldown_timer <= 0.0:
				ExecuteDash(player_rigidbody.global_transform.basis)
	if Input.is_action_pressed("Run"):
		shift_press_time += delta
	
	if Input.is_action_just_released("Run"):
		shift_held = false

func ExecuteDash(movement_basis: Basis) -> void:
	var forward = -movement_basis.z.normalized()
	var right = movement_basis.x.normalized()
	
	if grounded:
		forward = forward - relative_up * forward.dot(relative_up)
		right = right - relative_up * right.dot(relative_up)
		
		forward = forward.normalized()
		right = right.normalized()
		dash_cooldown = 0.20
		dash_impulse = 1200.0
	else:
		dash_cooldown = 0.15
		dash_impulse = 2000.0
	
	dash_direction = right * player_direction.x + forward * -player_direction.z
	
	if dash_direction.length_squared() < 0.01:
		dash_direction = forward
	
	dash_direction = dash_direction.normalized()
	
	player_rigidbody.apply_central_impulse(dash_direction * dash_impulse)
	
	dash_cooldown_timer = dash_cooldown


var current_intensity: float = 0.0
var movement_power = 3000.0
var movement_lerp = 8.0

var ground_cling_degrees: float = 60.0

var speed_modifier = 0.0
var crouching_modifier = 0.18
var walking_modifier = 0.4
var running_modifier = 2.1
var space_modifier = 0.0

func MovementPhysicsLogic(delta: float) -> void:
	var body_up = player_rigidbody.global_transform.basis.y
	
	# --- 1. MINIMAL FIX: CONDITIONAL INPUT COMPENSATION ---
	# We only invert horizontal input when grounded. 
	# In space, cam_basis naturally handles the inversion.
	var adjusted_direction = player_direction
	if grounded and relative_up.dot(body_up) < 0.0:
		adjusted_direction.x *= -1.0
	
	var cam_basis = first_person_view.global_transform.basis
	var movement_basis: Basis
	
	# 2. Movement Basis Calculation
	if grounded:
		# Grounded: Project View to Surface (Basis is world-locked to Gravity)
		var look_dir = -cam_basis.z 
		var forward_tangent = (look_dir - relative_up * look_dir.dot(relative_up)).normalized()
		
		if forward_tangent.length_squared() < 0.01:
			forward_tangent = -cam_basis.y
			forward_tangent = (forward_tangent - relative_up * forward_tangent.dot(relative_up)).normalized()
		
		var right_tangent = forward_tangent.cross(relative_up).normalized()
		movement_basis = Basis(right_tangent, relative_up, -forward_tangent)
	else:
		# Space/Air: Free 3D Movement (Basis is head-locked)
		movement_basis = cam_basis
	
	# 3. Speed Transitions Logic
	if grounded:
		if movementState == "moving":
			if Input.is_action_pressed("Run"):
				speed_modifier = running_modifier
				movement_lerp = 12
			elif Input.is_action_pressed("Crouch"):
				speed_modifier = crouching_modifier
				movement_lerp = 6
			else:
				speed_modifier = walking_modifier
				movement_lerp = 8
		else:
			speed_modifier = 0.0
			movement_lerp = 20.0
	else:
		# Orbit/Air modifiers
		speed_modifier = space_modifier if movementState == "moving" else 0.0
		movement_lerp = 8.0 if movementState == "moving" else 20.0

	# 4. Force Application
	var movement_intensity = movement_power * speed_modifier
	current_intensity = lerp(current_intensity, movement_intensity, movement_lerp * delta)
	
	# Snapping logic for precision
	if movement_intensity == 0 and current_intensity < 0.1:
		current_intensity = 0.0
	elif abs(current_intensity - movement_intensity) < 0.1:
		current_intensity = movement_intensity
	
	var movement_force = movement_basis * (adjusted_direction * current_intensity)
	
	# --- STABLE GROUND GLUE (Project & Push) ---
	if grounded and movement_force.length_squared() > 0.0:
		# 1. Flatten the movement force onto the ground plane
		# This removes the energy that would otherwise "launch" you off the top of ramps.
		var vertical_push = movement_force.dot(relative_up)
		movement_force -= relative_up * vertical_push
		
		# 2. Apply a dedicated downward "Glue" force
		# We use -relative_up so it always points directly into the floor.
		# We discard the "rotated energy" and just apply a specific downward push.
		var intensity_ratio = clamp((current_intensity / movement_power) * 0.035, 0.0, 1.0)
		
		# We calculate how much downward force to apply based on your cling settings
		var glue_strength = movement_force.length() * tan(deg_to_rad(ground_cling_degrees))
		var final_glue = -relative_up * (glue_strength * intensity_ratio)
		
		movement_force += final_glue
	
	# 5. Friction Logic
	var friction_force := Vector3.ZERO
	var friction_coefficient
	
	if grounded:
		var v_vertical = relative_up * relative_velocity.dot(relative_up)
		var v_horizontal = relative_velocity - v_vertical
		
		if player_direction.length_squared() == 0:
			friction_coefficient = 8.0
		else:
			friction_coefficient = 6.0
		
		friction_force = -v_horizontal * friction_coefficient * player_rigidbody.mass
		
		if grounded and (   (left_foot_step_progress >= 1.0 or right_foot_step_progress >= 1.0) or (left_leg_distance <= standing_leg_length or right_leg_distance <= standing_leg_length)    ) and ( (left_foot_state == FootState.STABLE or right_foot_state == FootState.STABLE) or Input.is_action_pressed("Run") ):
			player_rigidbody.apply_central_force(movement_force + friction_force)
		
	elif not grounded:
		player_rigidbody.apply_central_force(movement_force)


var player_collisions = []

func CollisionLogic() -> bool:
	# Returns all bodies currently touching the shape
	var bodies = player_rigidbody.get_colliding_bodies()
	player_collisions = bodies # Keep it as an array
	return bodies.size() > 0


# ============================================================
# ARMATURE STATE
# ============================================================
var armature_basis := Basis.IDENTITY

var left_foot_heel := Vector3.ZERO
var left_foot_ball := Vector3.ZERO

var right_foot_heel := Vector3.ZERO
var right_foot_ball := Vector3.ZERO

var left_foot_heel_normal := Vector3.UP
var left_foot_ball_normal := Vector3.UP

var right_foot_heel_normal := Vector3.UP
var right_foot_ball_normal := Vector3.UP

var left_foot_normal := Vector3.UP
var right_foot_normal := Vector3.UP

var averaged_ground_normal := Vector3.UP
var ground_center := Vector3.ZERO

@onready var torso_height = player_rigidbody_collision.shape.height
@onready var torso_width = player_rigidbody_collision.shape.radius

@onready var hips_height_offset = player_rigidbody.global_transform.basis.y * -torso_height/2
@onready var hips_middle = player_rigidbody.global_transform.origin + hips_height_offset

@onready var left_hip = player_rigidbody.global_transform.origin + hips_height_offset + (player_rigidbody.global_transform.basis.x * -torso_width * 0.7)
@onready var right_hip = player_rigidbody.global_transform.origin + hips_height_offset + (player_rigidbody.global_transform.basis.x * torso_width * 0.7)

enum FootMode { PLANTIGRADE, DIGITIGRADE }

@export var left_foot_mode: FootMode = FootMode.DIGITIGRADE
@export var right_foot_mode: FootMode = FootMode.DIGITIGRADE

@onready var hips = get_node("HipsN3D")
#@onready var hips_mesh : MeshInstance3D = get_node("")

#@onready var raycast_left_forward : RayCast3D = $GravityDetectorArea/Hips/RayCastLF
#@onready var raycast_right_forward : RayCast3D = $GravityDetectorArea/Hips/RayCastRF
#@onready var raycast_left_backward : RayCast3D = $GravityDetectorArea/Hips/RayCastLB
#@onready var raycast_right_backward : RayCast3D = $GravityDetectorArea/Hips/RayCastRB

# Add this to your class variables to store the result for your balance logic
var ground_balance_basis: Basis = Basis.IDENTITY

var relative_up = Vector3.UP

func LeggiesLogic(_delta, _velocity):
	var player_basis = player_rigidbody.global_transform.basis

	var use_body_basis = false

	if not grounded and is_near_ground:
		if left_foot_state == FootState.STABLE and right_foot_state == FootState.STABLE:
			use_body_basis = true
		elif left_foot_state == FootState.STEPPING and right_foot_state == FootState.STABLE:
			use_body_basis = true
		elif right_foot_state == FootState.STEPPING and left_foot_state == FootState.STABLE:
			use_body_basis = true

	var armature_up = -current_gravity_direction

	if is_in_deep_space:
		armature_up = player_basis.y

	elif use_body_basis:
		armature_up = player_basis.y

	var hips_forward = -hips.global_transform.basis.z
	hips_forward = hips_forward - armature_up * hips_forward.dot(armature_up)

	if hips_forward.length_squared() < 0.001:
		hips_forward = -player_basis.z
		hips_forward = hips_forward - armature_up * hips_forward.dot(armature_up)

	if hips_forward.length_squared() < 0.001:
		hips_forward = armature_basis.z

	hips_forward = hips_forward.normalized()

	var hips_right = hips_forward.cross(armature_up).normalized()
	hips_forward = armature_up.cross(hips_right).normalized()

	armature_basis = Basis(hips_right, armature_up, -hips_forward).orthonormalized()

	hips_middle = ground_raycast.global_transform.origin
	left_hip = hips_middle - hips_right * torso_width * 0.78
	right_hip = hips_middle + hips_right * torso_width * 0.78

	var heel_offset = armature_basis.z * 0.036
	var ball_offset = -armature_basis.z * 0.036

	var left_heel_origin = left_hip + heel_offset
	var left_ball_origin = left_hip + ball_offset
	var right_heel_origin = right_hip + heel_offset
	var right_ball_origin = right_hip + ball_offset

	#raycast_left_backward.global_position = left_heel_origin
	#raycast_left_forward.global_position = left_ball_origin
	#raycast_right_backward.global_position = right_heel_origin
	#raycast_right_forward.global_position = right_ball_origin
#
	#UpdateFootRay(raycast_left_backward, left_foot)
	#UpdateFootRay(raycast_left_forward, left_foot)
	#UpdateFootRay(raycast_right_backward, right_foot)
	#UpdateFootRay(raycast_right_forward, right_foot)
#
	#raycast_left_backward.force_raycast_update()
	#raycast_left_forward.force_raycast_update()
	#raycast_right_backward.force_raycast_update()
	#raycast_right_forward.force_raycast_update()

	left_foot_heel = left_heel_origin + armature_up * current_leg_length
	left_foot_ball = left_ball_origin + armature_up * current_leg_length
	right_foot_heel = right_heel_origin + armature_up * current_leg_length
	right_foot_ball = right_ball_origin + armature_up * current_leg_length

	left_foot_heel_normal = armature_up
	left_foot_ball_normal = armature_up
	right_foot_heel_normal = armature_up
	right_foot_ball_normal = armature_up

	#if raycast_left_backward.is_colliding():
	#	left_foot_heel = raycast_left_backward.get_collision_point()
	#	left_foot_heel_normal = raycast_left_backward.get_collision_normal()
#
	#if raycast_left_forward.is_colliding():
	#	left_foot_ball = raycast_left_forward.get_collision_point()
	#	left_foot_ball_normal = raycast_left_forward.get_collision_normal()
#
	#if raycast_right_backward.is_colliding():
	#	right_foot_heel = raycast_right_backward.get_collision_point()
	#	right_foot_heel_normal = raycast_right_backward.get_collision_normal()
#
	#if raycast_right_forward.is_colliding():
	#	right_foot_ball = raycast_right_forward.get_collision_point()
	#	right_foot_ball_normal = raycast_right_forward.get_collision_normal()

	left_foot_normal = (left_foot_heel_normal + left_foot_ball_normal).normalized()
	right_foot_normal = (right_foot_heel_normal + right_foot_ball_normal).normalized()

	averaged_ground_normal = AveragedGroundTriangleNormals() if grounded else armature_up


# ============================================================
# WALKING
# ============================================================

@export_group("Walking Targets")

@export var walk_target_forward := 0.4
@export var walk_target_side := 0.78

# How far a foot may move from its target before demanding a step.
@export var walk_target_radius := 0.62

# Radius while the player is not giving movement input.
# Small = encourages feet to return underneath the body.
@export var idle_target_radius := 0.15

# How quickly the target follows the desired body position.
@export var walking_target_lerp := 20.0
@export var running_target_lerp := 60.0
@export var space_target_lerp := 100.0

@export var walk_gait_separation := 0.5

@export_group("Walking Steps")

@export var foot_step_time := 0.4
@export var foot_step_clearance := 0.2


@export_group("Walking Ground Detection")

# Length of the small programmed target raycast.
@export var target_ray_length := 2.0

# 89 degrees from the ground plane.
# This is almost vertical, but has a tiny forward component so
# it isn't mathematically perpendicular to the surface.
@export var target_ray_angle := 89.0


enum FootState {
	UNSTABLE,
	STABLE,
	STEPPING
}

# ============================================================
# FOOT STATE
# ============================================================

var left_foot_state := FootState.UNSTABLE
var right_foot_state := FootState.UNSTABLE

var left_foot := Vector3.ZERO
var right_foot := Vector3.ZERO

var left_foot_target := Vector3.ZERO
var right_foot_target := Vector3.ZERO

var left_foot_target_normal := Vector3.UP
var right_foot_target_normal := Vector3.UP

var left_foot_step_start := Vector3.ZERO
var right_foot_step_start := Vector3.ZERO

var left_foot_step_progress := 1.0
var right_foot_step_progress := 1.0


# Whose turn it is.
var next_step_left := true

var walk_initialized := false

# Useful for movement physics.
# True means the feet currently permit body movement.
var feet_allow_movement := false


# Debug values
var left_distance := 0.0
var right_distance := 0.0
var left_leg_distance := 0.0
var right_leg_distance := 0.0

var foot_length = 0.0

var texture_shadows = true

func ArmatureRenderingLogic(_delta):
	UpdateGrabLogic()

	var body_basis = player_rigidbody.global_transform.basis.orthonormalized()
	var body_pos = player_rigidbody.global_position
	var body_up = body_basis.y
	var body_right = body_basis.x
	var body_forward = -body_basis.z

	var left_leg_color = Color.RED
	var right_leg_color = Color.BLUE
	var left_arm_color = Color.BLUE
	var right_arm_color = Color.RED
	var boots_color = Color.DARK_SLATE_GRAY
	var glove_radius = 0.041 if left_grab or right_grab else 0.042
	
	# ==========================
	# FEET ALIGNMENT
	# ==========================

	var left_foot_fwd = hips.global_transform.basis.z * -1.0
	var left_foot_right = left_foot_fwd.cross(left_foot_normal).normalized()
	left_foot_fwd = left_foot_normal.cross(left_foot_right).normalized()

	var right_foot_fwd = hips.global_transform.basis.z * -1.0
	var right_foot_right = right_foot_fwd.cross(right_foot_normal).normalized()
	right_foot_fwd = right_foot_normal.cross(right_foot_right).normalized()

	# ==========================
	# LEGS
	# ==========================

	var left_ankle_pos = left_foot
	var right_ankle_pos = right_foot

	_draw_adv_point("left_hip", left_hip + left_hip.direction_to(hips_middle) * 0.019, 0.094, left_leg_color, 1.0)
	_draw_adv_point("right_hip", right_hip + right_hip.direction_to(hips_middle) * 0.019, 0.094, right_leg_color, 1.0)

	var left_knee = GetFakeKnee(left_hip, left_ankle_pos, -1.0, left_foot_step_progress < 1.0)
	var right_knee = GetFakeKnee(right_hip, right_ankle_pos, 1.0, right_foot_step_progress < 1.0)

	_draw_adv_point("left_knee", left_knee, 0.045, left_leg_color, 1.0)
	_draw_adv_point("right_knee", right_knee, 0.045, right_leg_color, 1.0)

	CreateAdvancedLine("left_thigh", left_hip, left_knee, Vector3.ZERO, 1, 0.045, 0.075, left_leg_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	CreateAdvancedLine("right_thigh", right_hip, right_knee, Vector3.ZERO, 1, 0.045, 0.075, right_leg_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	CreateAdvancedLine("left_shin", left_knee, left_ankle_pos, Vector3.ZERO, 1, 0.022, 0.045, left_leg_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	CreateAdvancedLine("right_shin", right_knee, right_ankle_pos, Vector3.ZERO, 1, 0.022, 0.045, right_leg_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	CreateAdvancedLine("left_boot", left_ankle_pos + left_ankle_pos.direction_to(left_knee) * 0.18, left_ankle_pos + left_knee.direction_to(left_ankle_pos) * 0.01, Vector3.ZERO, 1, 0.022, 0.042, boots_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	CreateAdvancedLine("right_boot", right_ankle_pos + right_ankle_pos.direction_to(right_knee) * 0.016, right_ankle_pos + right_knee.direction_to(right_ankle_pos) * 0.01, Vector3.ZERO, 1, 0.022, 0.026, Color.GHOST_WHITE, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	_draw_adv_point("left_boot_ankle", left_ankle_pos + left_knee.direction_to(left_ankle_pos) * 0.001, 0.025, Color.DARK_SLATE_GRAY, 1.0)
	_draw_adv_point("right_boot_ankle", right_ankle_pos + right_knee.direction_to(right_ankle_pos) * 0.001, 0.025, Color.GHOST_WHITE, 1.0)

	# ==========================
	# FEET & CLAWS
	# ==========================

	var claw_len = 0.12
	var claw_spacing = 0.05
	var left_ball = left_ankle_pos + left_foot_fwd * foot_length
	var right_ball = right_ankle_pos + right_foot_fwd * foot_length

	for i in range(3):
		var offset = left_foot_right * (i - 1) * claw_spacing
		CreateAdvancedLine("left_claw_" + str(i), left_ball + left_foot_fwd * 0.02, left_ball + offset + left_foot_fwd * claw_len, Vector3.ZERO, 1, 0.00001, 0.025, boots_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

		offset = right_foot_right * (i - 1) * claw_spacing
		CreateAdvancedLine("right_claw_" + str(i), right_ball + right_foot_fwd * 0.02, right_ball + offset + right_foot_fwd * claw_len, Vector3.ZERO, 1, 0.00001, 0.025, Color.GHOST_WHITE, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	# ==========================
	# ARMS
	# ==========================

	var shoulder_center = body_pos + body_up * torso_height * 0.16
	var left_shoulder = shoulder_center - body_right * torso_width * 0.86
	var right_shoulder = shoulder_center + body_right * torso_width * 0.86
	
	var left_elbow: Vector3
	var right_elbow: Vector3
	var left_hand: Vector3
	var right_hand: Vector3
	
	if left_grab:
		left_elbow = left_shoulder + body_forward * 0.25
		left_hand = left_shoulder + body_forward * 0.46
	else:
		left_elbow = left_shoulder - body_right * 0.07 - body_up * 0.25
		left_hand = left_elbow - body_right * 0.05 - body_up * 0.36
	
	if right_grab:
		right_elbow = right_shoulder + body_forward * 0.25
		right_hand = right_shoulder + body_forward * 0.46
	else:
		right_elbow = right_shoulder + body_right * 0.07 - body_up * 0.25
		right_hand = right_elbow + body_right * 0.05 - body_up * 0.36
	
	_draw_adv_point("left_shoulder", left_shoulder, 0.052, left_arm_color, 1.0)
	_draw_adv_point("right_shoulder", right_shoulder, 0.052, right_arm_color, 1.0)
	
	_draw_adv_point("left_elbow", left_elbow, 0.036, left_arm_color, 1.0)
	_draw_adv_point("right_elbow", right_elbow, 0.036, right_arm_color, 1.0)
	
	CreateAdvancedLine("left_upper_arm", left_shoulder, left_elbow, Vector3.ZERO, 1, 0.029, 0.044, left_arm_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	#CreateAdvancedLine("right_upper_arm", right_shoulder, right_elbow, Vector3.ZERO, 1, 0.029, 0.044, right_arm_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	
	CreateAdvancedLine("left_forearm", left_elbow, left_hand, Vector3.ZERO, 1, 0.020, 0.036, left_arm_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	#CreateAdvancedLine("right_forearm", right_elbow, right_hand, Vector3.ZERO, 1, 0.020, 0.036, right_arm_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	
	var left_glove_color = Color.HOT_PINK if left_grab else Color.WHITE_SMOKE
	var right_glove_color = Color.HOT_PINK if right_grab else Color.WHITE_SMOKE
	
	
	CreateAdvancedLine("left_glove_cuff", left_hand - left_elbow.direction_to(left_hand) * 0.07, left_hand, Vector3.ZERO, 1, 0.018, 0.028, left_glove_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	#CreateAdvancedLine("right_glove_cuff", right_hand - right_elbow.direction_to(right_hand) * 0.07, right_hand, Vector3.ZERO, 1, 0.018, 0.028, right_glove_color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	
	_draw_adv_point("left_hand", left_hand, glove_radius, left_glove_color, 1.0)
	_draw_adv_point("right_hand", right_hand, glove_radius, right_glove_color, 1.0)
	
	# ==========================
	# WALK TARGET DEBUG
	# ==========================

	texture_shadows = false

	var target_marker_size = 0.001

	CreateAdvancedLine("left_walk_target_line", left_foot, left_foot_target, Vector3.ZERO, 1, 0.008, 0.008, Color.RED, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	CreateAdvancedLine("right_walk_target_line", right_foot, right_foot_target, Vector3.ZERO, 1, 0.008, 0.008, Color.BLUE, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	left_distance = (left_foot_target - left_foot).slide(relative_up).length()
	right_distance = (right_foot_target - right_foot).slide(relative_up).length()

	left_leg_distance = left_ankle_pos.distance_to(left_hip)
	right_leg_distance = right_ankle_pos.distance_to(right_hip)

	CreateAdvancedLine("left_target_normal", left_foot_target - left_foot_normal * target_marker_size, left_foot_target + left_foot_normal * target_marker_size, Vector3.ZERO, 1, 0.04, 0.04, Color.RED, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)
	CreateAdvancedLine("right_target_normal", right_foot_target - right_foot_normal * target_marker_size, right_foot_target + right_foot_normal * target_marker_size, Vector3.ZERO, 1, 0.04, 0.04, Color.BLUE, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)

	texture_shadows = true


func GetFakeKnee(
	hip: Vector3,
	ankle: Vector3,
	_side: float,
	is_swing: bool
) -> Vector3:

	var thigh_len := standing_leg_length / 2.0
	var shin_len := standing_leg_length / 2.0

	var hip_to_ankle := ankle - hip
	var distance := hip_to_ankle.length()

	if distance < 0.001:
		return hip

	var leg_dir := hip_to_ankle / distance

	# ============================================================
	# KNEE BEND DIRECTION
	# ============================================================

	var forward = -hips.global_transform.basis.z
	forward = forward - relative_up * forward.dot(relative_up)

	if forward.length_squared() < 0.001:
		forward = armature_basis.z

	forward = forward.normalized()

	var knee_dir = forward - leg_dir * forward.dot(leg_dir)

	if knee_dir.length_squared() < 0.001:
		knee_dir = hips.global_transform.basis.x

	knee_dir = knee_dir.normalized()

	# ============================================================
	# 2-BONE IK
	# ============================================================

	var max_len := thigh_len + shin_len
	distance = min(distance, max_len - 0.001)

	var along := (
		thigh_len * thigh_len
		- shin_len * shin_len
		+ distance * distance
	) / (2.0 * distance)

	var bend_sq := thigh_len * thigh_len - along * along
	var bend := sqrt(max(bend_sq, 0.0))

	var knee := hip + leg_dir * along

	knee += knee_dir * bend

	# ============================================================
	# SWING LEG BEND
	#
	# The planted leg remains almost straight.
	# The moving leg gets a strong forward knee bend.
	# ============================================================

	if is_swing:
		var swing_bend := 0.18

		# Maximum extra bend around mid-swing.
		var progress := (
			left_foot_step_progress
			if ankle == left_foot
			else right_foot_step_progress
		)

		swing_bend *= sin(progress * PI)

		knee += knee_dir * swing_bend

	return knee


func WalkingLogic(delta: float) -> void:
	left_leg_distance = left_foot.distance_to(left_hip)
	right_leg_distance = right_foot.distance_to(right_hip)
	
	UpdateFootTargets()
	
	if not grounded:
		UpdateAirborneFeet(delta)
		
		
		UpdateFootTargets()
		return
	elif not walk_initialized:
		InitializeWalking()
		UpdateFootTargets()
		return
	
	
	UpdateFootTargets()
	UpdateFootStability()
	UpdateFootTargets()
	
	if left_foot_state != FootState.STEPPING and right_foot_state != FootState.STEPPING and grounded:
		TryFootSteps()
	
	UpdateFootStep(delta, true)
	UpdateFootStep(delta, false)
	
	UpdateFeetMovementPermission()


func UpdateFootTargets() -> void:
	UpdateWalkingMode()
	
	var move_direction := GetWalkingMoveDirection()
	var has_input := move_direction.length_squared() > 0.001
	
	if not grounded:
		UpdateAirFootTargets(move_direction, has_input)
	else:
		UpdateGroundFootTargets(move_direction, has_input)


func UpdateWalkingMode() -> void:
	if Input.is_action_pressed("Run"):
		walk_target_forward = -0.4
		walk_gait_separation = 0.8
		walk_target_radius = 0.8
		idle_target_radius = 0.15
		foot_step_time = 0.18
		foot_step_clearance = 0.35

	elif Input.is_action_pressed("Crouch"):
		walk_target_forward = 0.1
		walk_gait_separation = 0.4
		walk_target_radius = 0.1
		idle_target_radius = 0.18
		foot_step_time = 0.9
		foot_step_clearance = 0.1

	else:
		walk_target_forward = 0.0
		walk_gait_separation = 0.4
		walk_target_radius = 1.0
		idle_target_radius = 0.15
		foot_step_time = 0.3
		foot_step_clearance = 0.12


func GetWalkingMoveDirection() -> Vector3:
	var input := Vector2(
		player_direction.x,
		-player_direction.z
	).limit_length(1.0)

	if input.length_squared() < 0.001:
		return Vector3.ZERO

	var player_basis := player_rigidbody.global_transform.basis
	var player_direction_temp := player_basis.x * input.x - player_basis.z * input.y

	player_direction_temp -= relative_up * player_direction_temp.dot(relative_up)

	if player_direction_temp.length_squared() < 0.001:
		return Vector3.ZERO

	return player_direction_temp.normalized()


func UpdateFeetMovementPermission() -> void:
		if left_foot_state == FootState.STABLE or right_foot_state == FootState.STABLE:
			feet_allow_movement = true


func UpdateAirborneFeet(delta: float) -> void:
	if is_near_ground:
		left_foot = left_foot.lerp(left_foot_target, min(1.0, running_target_lerp/2 * delta))
		right_foot = right_foot.lerp(right_foot_target, min(1.0, running_target_lerp/2 * delta))
	elif is_in_deep_space:
		left_foot = left_foot.lerp(left_foot_target, min(1.0, space_target_lerp * delta))
		right_foot = right_foot.lerp(right_foot_target, min(1.0, space_target_lerp * delta))
	else:
		left_foot = left_foot.lerp(left_foot_target, min(1.0, running_target_lerp * delta))
		right_foot = right_foot.lerp(right_foot_target, min(1.0, running_target_lerp * delta))
	
	left_foot_step_progress = 1.0
	right_foot_step_progress = 1.0
	
	if is_in_deep_space:
		left_foot_state = FootState.UNSTABLE
		right_foot_state = FootState.UNSTABLE
	else:
		left_foot_state = FootState.STABLE
		right_foot_state = FootState.STABLE
	
	feet_allow_movement = true


func UpdateAirFootTargets(move_direction: Vector3, has_input: bool) -> void:
	var forward_distance = walk_target_forward if has_input else 0.0
	var gait_distance := walk_gait_separation if has_input else 0.0
	
	var air_forward = forward_distance + gait_distance * 0.5 + player_rigidbody.linear_velocity.slide(relative_up).length() * 0.05
	air_forward = forward_distance + gait_distance * 0.5

	if thrusters:
		left_foot_target = hips_middle + -move_direction * (air_forward + gait_distance * 0.5) - armature_basis.x * torso_width * walk_target_side - relative_up * current_target_leg_length
		right_foot_target = hips_middle + -move_direction * (air_forward + gait_distance * 0.5) + armature_basis.x * torso_width * walk_target_side - relative_up * current_target_leg_length
	else:
		left_foot_target = hips_middle + move_direction * (air_forward + gait_distance * 0.5) - armature_basis.x * torso_width * walk_target_side - player_rigidbody.global_transform.basis.y * current_target_leg_length
		right_foot_target = hips_middle + move_direction * (air_forward + gait_distance * 0.5) + armature_basis.x * torso_width * walk_target_side - player_rigidbody.global_transform.basis.y * current_target_leg_length
	
	right_foot_target_normal = relative_up
	
	return


func UpdateGroundFootTargets(move_direction: Vector3, has_input: bool) -> void:
	var target_radius = walk_target_radius if has_input else idle_target_radius
	var forward_distance = walk_target_forward if has_input else 0.0
	var target_center = hips_middle + move_direction * forward_distance
	
	var gait = GetGaitOffsets(has_input)

	var left_target_position = target_center \
		+ move_direction * gait["left"] \
		- armature_basis.x * torso_width * walk_target_side

	var right_target_position = target_center \
		+ move_direction * gait["right"] \
		+ armature_basis.x * torso_width * walk_target_side

	var left_ground = GetWalkingTargetGround(left_target_position, move_direction)
	var right_ground = GetWalkingTargetGround(right_target_position, move_direction)

	var current_target_lerp
	
	if is_in_deep_space:
		current_target_lerp = space_target_lerp
	elif Input.is_action_pressed("Run"):
		current_target_lerp = running_target_lerp
	else:
		current_target_lerp = walking_target_lerp
	
	if left_ground["valid"]:
		left_foot_target = left_foot_target.lerp(left_ground["position"], current_target_lerp * get_physics_process_delta_time())
		left_foot_target_normal = left_ground["normal"]

	if right_ground["valid"]:
		right_foot_target = right_foot_target.lerp(right_ground["position"], current_target_lerp * get_physics_process_delta_time())
		right_foot_target_normal = right_ground["normal"]
		
	texture_shadows = false
	CreateCircleLine("left_walk_radius", left_foot_target, target_radius, Color.RED, relative_up)
	CreateCircleLine("right_walk_radius", right_foot_target, target_radius, Color.BLUE, relative_up)
	texture_shadows = true


func GetGaitOffsets(has_input: bool) -> Dictionary:
	var gait_angle := 0.0 if next_step_left else PI
	var phase := cos(gait_angle)
	var distance := walk_gait_separation if has_input else 0.0
	
	return {
		"left": distance * phase,
		"right": distance * -phase
	}


func InitializeWalking() -> void:
	left_foot = left_foot.lerp(left_foot_target, min(1.0, walking_target_lerp * get_physics_process_delta_time()))
	right_foot = right_foot.lerp(right_foot_target, min(1.0, walking_target_lerp * get_physics_process_delta_time()))
	
	left_foot_step_progress = 1.0
	right_foot_step_progress = 1.0
	left_foot_state = FootState.STABLE
	right_foot_state = FootState.STABLE
	
	next_step_left = true
	walk_initialized = true


func GetWalkingTargetGround(
	origin: Vector3,
	move_direction: Vector3
) -> Dictionary:
	# ============================================================
	# BUILD RAY DIRECTION
	# ============================================================

	var ray_direction = -relative_up

	# Tiny directional tilt.
	#
	# At 89 degrees from the ground plane this is almost vertical,
	# but not mathematically perpendicular.
	if move_direction.length_squared() > 0.001:
		var angle := deg_to_rad(90.0 - target_ray_angle)

		ray_direction = (
			-relative_up * cos(angle)
			+
			move_direction.normalized() * sin(angle)
		).normalized()


	# ============================================================
	# PHYSICS RAYCAST
	# ============================================================

	var space_state := player_rigidbody.get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(
		origin + relative_up * 0.05,
		origin + ray_direction * target_ray_length
	)

	query.exclude = [player_rigidbody]


	var result := space_state.intersect_ray(query)


	if result.is_empty():
		return {
			"valid": false,
			"position": origin,
			"normal": relative_up
		}


	return {
		"valid": true,
		"position": result.position,
		"normal": result.normal
	}


func UpdateFootStability() -> void:
	# ============================================================
	# DO NOT MODIFY A FOOT THAT IS CURRENTLY STEPPING
	# ============================================================

	#if left_foot_step_progress >= 1.0:
	#	if raycast_left_backward.is_colliding() or raycast_left_forward.is_colliding():
	#		left_foot_state = FootState.STABLE
	#	elif not grounded and left_leg_distance > standing_leg_length:
	#		left_foot_state = FootState.UNSTABLE
#
	#if right_foot_step_progress >= 1.0:
	#	if raycast_right_backward.is_colliding() or raycast_right_forward.is_colliding():
	#		right_foot_state = FootState.STABLE
	#	elif not grounded and right_leg_distance > standing_leg_length:
	#		right_foot_state = FootState.UNSTABLE


	# Explicitly preserve stepping state.
	if left_foot_step_progress < 1.0:
		left_foot_state = FootState.STEPPING

	if right_foot_step_progress < 1.0:
		right_foot_state = FootState.STEPPING


func TryFootSteps() -> void:
	if next_step_left and CanStep(true):
		StartFootStep(true)
	elif not next_step_left and CanStep(false):
		StartFootStep(false)


func StartFootStep(left: bool) -> void:
	if left:
		left_foot_state = FootState.STEPPING
		left_foot_step_progress = 0.0
		left_foot_step_start = left_foot
	else:
		right_foot_state = FootState.STEPPING
		right_foot_step_progress = 0.0
		right_foot_step_start = right_foot


func UpdateFootStep(delta: float, left: bool) -> void:
	var progress := (
		left_foot_step_progress
		if left
		else
		right_foot_step_progress
	)

	if progress >= 1.0:
		return


	# ============================================================
	# STEP PROGRESS
	# ============================================================

	progress += delta / max(foot_step_time, 0.001)
	progress = min(progress, 1.0)


	# ============================================================
	# STEP DATA
	# ============================================================

	var start := (
		left_foot_step_start
		if left
		else
		right_foot_step_start
	)

	var target := (
		left_foot_target
		if left
		else
		right_foot_target
	)


	# ============================================================
	# SMOOTH STEP
	# ============================================================

	var t := progress * progress * (3.0 - 2.0 * progress)

	var foot_position := start.lerp(target, t)


	# ============================================================
	# FOOT LIFT
	# ============================================================

	foot_position += (
		relative_up
		* sin(progress * PI)
		* foot_step_clearance
	)


	# ============================================================
	# APPLY
	# ============================================================

	if left:
		left_foot = foot_position
		left_foot_step_progress = progress

		if progress >= 1.0:
			left_foot = left_foot_target
			left_foot_state = FootState.STABLE
			next_step_left = false

	else:
		right_foot = foot_position
		right_foot_step_progress = progress

		if progress >= 1.0:
			right_foot = right_foot_target
			right_foot_state = FootState.STABLE
			next_step_left = true


func SolveRenderedFoot(_foot, heel, ball, normal):
	var forward = ball - heel
	forward = forward - normal * forward.dot(normal)

	if forward.length_squared() < 0.001:
		forward = armature_basis.z # Fixed inversion here too!
		forward = forward - normal * forward.dot(normal)

	forward = forward.normalized()
	var center = (heel + ball) * 0.5
	heel = center - forward * foot_length * 0.5
	ball = center + forward * foot_length * 0.5

	return {
		"heel": heel,
		"ball": ball,
		"center": center,
		"forward": forward,
		"normal": normal
	}


func GetFootSurface(
	heel_ray: RayCast3D,
	ball_ray: RayCast3D
) -> Dictionary:

	var heel := heel_ray.get_collision_point() if heel_ray.is_colliding() else heel_ray.global_position
	var ball := ball_ray.get_collision_point() if ball_ray.is_colliding() else ball_ray.global_position

	var heel_normal = heel_ray.get_collision_normal() if heel_ray.is_colliding() else relative_up
	var ball_normal = ball_ray.get_collision_normal() if ball_ray.is_colliding() else relative_up

	var normal := (heel_normal + ball_normal).normalized()

	if normal.length_squared() < 0.001:
		normal = relative_up

	var center := (heel + ball) * 0.5

	return {
		"center": center,
		"normal": normal
	}


func AveragedGroundTriangleNormals() -> Vector3:
	var center_point = ground_raycast.get_collision_point() if ground_raycast.is_colliding() else hips_middle

	var left_triangle_a = left_foot_heel - center_point
	var left_triangle_b = left_foot_ball - center_point
	var right_triangle_a = right_foot_heel - center_point
	var right_triangle_b = right_foot_ball - center_point
	
	var left_triangle_normal = left_triangle_a.cross(left_triangle_b).normalized()
	var right_triangle_normal = right_triangle_a.cross(right_triangle_b).normalized()
	
	if left_triangle_normal.length_squared() < 0.001:
		left_triangle_normal = relative_up
	
	if right_triangle_normal.length_squared() < 0.001:
		right_triangle_normal = relative_up
	
	if left_triangle_normal.dot(relative_up) < 0.0:
		left_triangle_normal = -left_triangle_normal
	
	if right_triangle_normal.dot(relative_up) < 0.0:
		right_triangle_normal = -right_triangle_normal
	
	var averaged_normal = (left_triangle_normal + right_triangle_normal).normalized()
	
	if averaged_normal.length_squared() < 0.001:
		averaged_normal = relative_up
	
	ground_center = (center_point + left_foot + right_foot) / 3.0
	
	return averaged_normal


func UpdateFootRay(ray: RayCast3D, foot: Vector3) -> void:
	var foot_direction := foot - ray.global_position

	if foot_direction.length_squared() < 0.001:
		foot_direction = -relative_up
	else:
		foot_direction = foot_direction.normalized()


	ray.target_position = ray.to_local(
		ray.global_position + foot_direction * current_leg_length
	)


func CanStep(left: bool) -> bool:
	var opposite_state = right_foot_state if left else left_foot_state

	if opposite_state != FootState.STABLE:
		return false

	return FootTargetDistance(left) > GetFootTargetRadius()


func GetFootTargetRadius() -> float:
	var input := Vector2(
		player_direction.x,
		-player_direction.z
	)

	return (
		walk_target_radius
		if input.length_squared() > 0.001
		else idle_target_radius
	)


func FootTargetDistance(left: bool) -> float:
	var foot := left_foot if left else right_foot
	var target := left_foot_target if left else right_foot_target

	# Only measure distance along the ground.
	var difference := target - foot
	difference -= relative_up * difference.dot(relative_up)

	return difference.length()


var display_dir: Vector3
var compass_keys = [
		"World_Y", "World_X", "World_Z", 
		"-World_Y", "-World_X", "-World_Z", 
		"Player_Direction", "Player_Velocity", 
		"Player_Orientation", "Gravity_Direction",
		"Player_Pulse_Jet_1", "Player_Pulse_Front_1",
		"Player_Pulse_Inner_Front_1", "Player_Pulse_Inner_Back_1",
		"Player_Pulse_Back_1","Player_Pulse_Jet_2", "Player_Pulse_Front_2",
		"Player_Pulse_Inner_Front_2", "Player_Pulse_Inner_Back_2",
		"Player_Pulse_Back_2"
	]

func Compass3D(is_turned_on: bool):
	
	
	# --- LIFECYCLE MANAGEMENT: CLEANUP ---
	if not is_turned_on:
		for key in compass_keys:
			if debug_objects.has(key):
				var node = debug_objects[key]
				if is_instance_valid(node):
					node.queue_free()
				debug_objects.erase(key)
		return # Exit after cleaning up

	# --- CONSTANTS & PARAMETERS ---
	var arrow_length = 0.01
	var arrow_size_top_1 = 0.004
	var arrow_size_bottom = 0.0001
	
	var compass_3d_origin = GetCurvedHUDWorldPosition(-0.88, 0.25, 0.105)
	
	CreateLine("World_Y", compass_3d_origin, compass_3d_origin + Vector3.UP * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.GREEN, 1.0)
	CreateLine("World_X", compass_3d_origin, compass_3d_origin + Vector3.RIGHT * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.RED, 1.0)
	CreateLine("World_Z", compass_3d_origin, compass_3d_origin + Vector3.BACK * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.BLUE, 1.0)
	
	CreateLine("-World_Y", compass_3d_origin, compass_3d_origin + Vector3.DOWN * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.LIGHT_GREEN, 1.0)
	CreateLine("-World_X", compass_3d_origin, compass_3d_origin + Vector3.LEFT * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.INDIAN_RED, 1.0)
	CreateLine("-World_Z", compass_3d_origin, compass_3d_origin + Vector3.FORWARD * arrow_length, arrow_size_bottom, arrow_size_top_1, Color.ROYAL_BLUE, 1.0)
	
	
	var player_3d_origin = GetCurvedHUDWorldPosition(-0.88, -0.25, 0.105)
	var arrow_size_top_2 = 0.003
	var arrow_size_top_3 = 0.001
	
	# --- SCALE LOGIC FOR INTENSITY ---
	var intensity_hud_scale = arrow_length / movement_power
	var arrow_intensity_length = current_intensity * intensity_hud_scale
	
	var temp_speed_modifier = 0.0
	
	if movementState == "moving":
		if Input.is_action_pressed("Run"):
			temp_speed_modifier = running_modifier
		elif Input.is_action_pressed("Crouch"):
			temp_speed_modifier = crouching_modifier
		else:
			temp_speed_modifier = walking_modifier
	else:
		temp_speed_modifier = 0.0
	
	arrow_intensity_length = movement_power * 1.0 * temp_speed_modifier * intensity_hud_scale
	
	# --- THE SPRING_GREEN or ORANGE_RED LINE: Player Direction and GROUNDED STATUS ---
	var state_color = Color.SPRING_GREEN if grounded else Color.DEEP_PINK
	# 
	if is_near_ground or grounded:
		var world_dir = player_rigidbody.global_transform.basis * player_direction
		display_dir = world_dir - (world_dir.dot(current_gravity_direction) * current_gravity_direction)
	else:
		display_dir = player_rigidbody.global_transform.basis * player_direction 
		
	var gravity_3d_origin = GetCurvedHUDWorldPosition(-0.88, -0.25, 0.105)
	
	# --- THE SPRING_GREEN or ORANGE_RED LINE: Scales with arrow_intensity_length ---
	var line_end = gravity_3d_origin + (display_dir.normalized() * arrow_intensity_length)
	
	if speed_modifier > 0.0:
		CreateLine("Player_Direction", gravity_3d_origin, line_end, arrow_size_bottom, arrow_size_top_3, state_color, 0.6)
	else:
		CreateLine("Player_Direction", gravity_3d_origin, line_end, arrow_size_bottom, arrow_size_top_3, Color.AZURE, 0.2)
	
	var jet_start_offset := -0.0035
	var jet_offset := (line_end - gravity_3d_origin).normalized() * jet_start_offset

	if Input.is_action_pressed("Run"):
		if not grounded and thrusters:
			CreateLine("Player_Pulse_Jet_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.54) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 2.0, Color.DIM_GRAY, 1)
			
			CreateLine("Player_Pulse_Front_1", gravity_3d_origin - (display_dir.normalized() * arrow_intensity_length / 6) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 2.5, Color.DEEP_SKY_BLUE, 0.5)
			CreateLine("Player_Pulse_Inner_Front_1", gravity_3d_origin - (display_dir.normalized() * arrow_intensity_length / 6) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.0) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 1.5, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Inner_Back_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.63) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.17) + jet_offset, arrow_size_top_3 * 1.5, arrow_size_bottom, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Back_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.63) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.17) + jet_offset, arrow_size_top_3 * 2.5, arrow_size_bottom, Color.DEEP_SKY_BLUE, 0.5)
			
	else:
		if not grounded and thrusters:
			CreateLine("Player_Pulse_Jet_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.56) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 2.0, Color.DIM_GRAY, 1)
			
			CreateLine("Player_Pulse_Front_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.63) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 2.5, Color.DARK_ORANGE, 0.5)
			CreateLine("Player_Pulse_Inner_Front_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.63) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.0) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 1.5, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Inner_Back_1", line_end - 2 * (display_dir.normalized() * arrow_intensity_length * 0.63) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.72) + jet_offset, arrow_size_bottom, arrow_size_top_3 * 1.5, Color.WHITE, 1.0)
			CreateLine("Player_Pulse_Back_1", line_end - (display_dir.normalized() * arrow_intensity_length * 1.9) + jet_offset, line_end - (display_dir.normalized() * arrow_intensity_length * 1.25) + jet_offset, arrow_size_top_3 * 2.5, arrow_size_bottom, Color.DARK_ORANGE, 0.5)
			
			
	# --- THE RED or BLUE LINE: Player Velocity ---
	var velocity_vector = player_rigidbody.linear_velocity * 0.0025
	if grounded:
		CreateLine("Player_Velocity", gravity_3d_origin, gravity_3d_origin + velocity_vector, arrow_size_bottom, 0.00125, color_hit, 0.9)
	else:
		CreateLine("Player_Velocity", gravity_3d_origin, gravity_3d_origin + velocity_vector, arrow_size_bottom, 0.00125, color_no_hit, 0.9)
	
	# --- THE PURPLE LINE: Player Orientation & Upside-Down Detection ---
	var player_orientation = player_rigidbody.global_transform.basis.y
	
	if (!is_roll_upside_down and !is_upside_down) or is_in_deep_space:
		# UPRIGHT
		CreateLine("Player_Orientation", player_3d_origin, player_3d_origin + player_orientation * arrow_length, arrow_size_bottom, arrow_size_top_2, Color.PURPLE, 0.8)
	elif is_roll_upside_down and !is_upside_down:
		# ROLL UPSIDE DOWN
		CreateLine("Player_Orientation", player_3d_origin, player_3d_origin + player_orientation * arrow_length, arrow_size_bottom, arrow_size_top_2, Color.MEDIUM_VIOLET_RED, 0.6)
	elif is_roll_upside_down and is_upside_down:
		# ROLL UPSIDE DOWN and UPSIDE DOWN
		CreateLine("Player_Orientation", player_3d_origin, player_3d_origin + player_orientation * arrow_length, arrow_size_bottom, arrow_size_top_2, Color.ORANGE_RED, 0.6)
	else:
		# UPSIDE DOWN
		CreateLine("Player_Orientation", player_3d_origin, player_3d_origin + player_orientation * arrow_length, arrow_size_bottom, arrow_size_top_2, Color.MIDNIGHT_BLUE, 0.6)
	
	# --- THE YELLOW LINE: Gravity Direction ---
	var hud_scale = 0.0078
	var arrow_leg_length = current_leg_length * hud_scale
	
	if grounded:
		CreateLine("Gravity_Direction", player_3d_origin, player_3d_origin + current_gravity_direction * arrow_leg_length, arrow_size_bottom, arrow_size_top_2, Color.YELLOW, 0.8)
	elif not is_in_deep_space:
		CreateLine("Gravity_Direction", player_3d_origin, player_3d_origin + -ground_raycast.global_transform.basis.y * arrow_leg_length, arrow_size_bottom, arrow_size_top_2, Color.ORANGE, 0.6)
	else:
		CreateLine("Gravity_Direction", player_3d_origin, player_3d_origin + current_gravity_direction * arrow_leg_length, arrow_size_bottom, arrow_size_top_2, Color.WEB_PURPLE, 0.6)



func _Tools():
	pass

# helper: wrap to [-PI, PI]
func SimpleWrapAngle(a: float) -> float:
	a = fmod(a + PI, TAU)
	if a < 0.0:
		a += TAU
	return a - PI


func SimpleWrapAngle2(a: float) -> float:
	return wrapf(a, -PI, PI)


func RoundToDecimal(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)


func AlignWithNormal(xform: Transform3D, normal: Vector3) -> Transform3D:
	var target_up = normal.normalized()
	var current_up = xform.basis.y
	
	# If already aligned, skip to prevent micro-jitters
	if current_up.is_equal_approx(target_up):
		return xform
		
	# Calculate the rotation from where we are to where the gravity is
	var quat = Quaternion(current_up, target_up)
	
	# Apply only that tilt to the existing basis. 
	# This preserves your "Yaw" (where you're looking) perfectly.
	var result = xform
	result.basis = (Basis(quat) * xform.basis).orthonormalized()
	return result


func ShortestAngleDifference(a: float, b: float) -> float:
	var diff = fmod((a - b + 360 + 180), 360.0) - 180
	
	return diff


func ShortestRadianAngleDifference(a: float, b: float) -> float:
	var diff = fmod((a - b + PI), TAU) - PI
	return diff # already in radians


func SignChecker(p_value):
	if p_value < 0: 
		return -1 #negative
	elif p_value > 0: 
		return 1 #positive
	else:
		return 0 # zero 


func CameraViewAimPoint(camera: Camera3D, max_distance: float = 1000.0) -> Vector3:
	# 1. Get the 3D physics space
	var space_state = camera.get_world_3d().direct_space_state
	
	# 2. Find the exact center of the screen/viewport
	var viewport = camera.get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2.0
	
	# 3. Project the ray from the camera through the center of the screen
	var origin = camera.project_ray_origin(screen_center)
	var camera_direction = camera.project_ray_normal(screen_center)
	var end_point = origin + (camera_direction * max_distance)
	
	if not space_state:
		return end_point
	
	# 4. Set up the physics query
	var query = PhysicsRayQueryParameters3D.create(origin, end_point)
	
	# Optional: Exclude the player so the camera doesn't hit the back of their head
	# query.exclude = [player_rigidbody.get_rid()] 
	
	# 5. Cast the ray
	var result = space_state.intersect_ray(query)
	
	# 6. Return the hit point, or the max distance point if the sky/air was hit
	if result:
		return result.position
	else:
		return end_point


var debug_objects: Dictionary = {}

func CreatePoint(key: String, pos: Vector3, size: float, color: Color, transparency: float = 1.0, is_point_active: bool = true):
	# --- 1. THE CLEANUP THINGY ---
	if not is_point_active:
		if key in debug_objects:
			var obj = debug_objects[key]
			if is_instance_valid(obj):
				obj.queue_free()
			debug_objects.erase(key)
		return

	var mi: MeshInstance3D
	
	# --- 2. REUSE OR CREATE ---
	if key in debug_objects and is_instance_valid(debug_objects[key]):
		mi = debug_objects[key]
	else:
		mi = MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		
		# Use StandardMaterial3D for simple points
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.disable_receive_shadows = true
		mi.material_override = mat
		
		debug_objects[key] = mi
		get_tree().root.add_child(mi)

	# --- 3. UPDATE PROPERTIES ---
	mi.visible = true
	mi.global_position = pos
	
	# Update Mesh (Radius is half of the total width)
	if mi.mesh is SphereMesh:
		mi.mesh.radius = size
		mi.mesh.height = size * 2.0
	
	# Update Color
	if mi.material_override is StandardMaterial3D:
		mi.material_override.albedo_color = Color(color, transparency)
		mi.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparency < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	

func CreateLine(
	line_name: String,
	pos1: Vector3,
	pos2: Vector3,
	top_radius: float,
	bottom_radius: float,
	color: Color,
	transparency: float = 1.0,
	use_depth_test: bool = true,
	roll: float = 0.0 # Added for Rope/Chain rotation
) -> Node3D:
	var container: Node3D
	var mi: MeshInstance3D
	
	if line_name in debug_objects and is_instance_valid(debug_objects[line_name]):
		container = debug_objects[line_name]
		mi = container.get_child(0)
	else:
		container = Node3D.new()
		mi = MeshInstance3D.new()
		mi.mesh = CylinderMesh.new()
		mi.material_override = ORMMaterial3D.new()
		mi.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi)
		debug_objects[line_name] = container
		
		# FIX: Add to root ONLY once upon creation
		get_tree().root.add_child(container)
	
	var mat: ORMMaterial3D = mi.material_override
	mat.no_depth_test = !use_depth_test
	mat.albedo_color = Color(color, transparency)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparency < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	
	var dir = pos2 - pos1
	var dist = dir.length()
	if dist < 0.001: 
		container.visible = false
		return container
	
	container.visible = true
	mi.mesh.height = dist
	mi.mesh.top_radius = top_radius
	mi.mesh.bottom_radius = bottom_radius
	
	var y_axis = dir.normalized()
	var check_dir = Vector3.UP if abs(y_axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x_axis = check_dir.cross(y_axis).normalized()
	var z_axis = y_axis.cross(x_axis).normalized()
	
	# Apply the Basis and then the roll for the "Chain" look
	var line_basis = Basis(x_axis, y_axis, z_axis)
	if roll != 0:
		line_basis = line_basis.rotated(y_axis, roll)
		
	mi.global_transform = Transform3D(line_basis, (pos1 + pos2) / 2.0)
	return container


enum LineStyle { LASER, ROPE }
enum LineRenderMode { 
	SEGMENT_SEGMENT, 
	SEGMENT_POINT, 
	SEGMENT_NOTHING, 
	SEGMENT_ROTATED_CHAIN 
}

func CreateAdvancedLine(
	base_name: String,
	start: Vector3,
	end: Vector3,
	sag_vector: Vector3, # Direction AND magnitude (e.g. Vector3(0, -2, 0))
	segments_count: int,
	top_radius: float,
	bottom_radius: float,
	color: Color,
	style: LineStyle,
	mode: LineRenderMode,
	transparency: float = 1.0
):
	# 1. GENERATE PATH POINTS (The Sag Math)
	var points: Array[Vector3] = []
	for i in range(segments_count + 1):
		var t = float(i) / segments_count
		var pos = start.lerp(end, t)
		# Parabolic sag applied in the direction of sag_vector
		var sag_factor = 4.0 * t * (1.0 - t)
		pos += sag_vector * sag_factor
		points.append(pos)
	
	# 2. DRAWING LOOP (The Pattern Logic)
	# We use a while loop because some modes (like SEGMENT_POINT) 
	# need to skip or jump indices to make segments "2x long"
	var i = 0
	while i < segments_count:
		var l_name = base_name + "_" + str(i)
		var p1 = points[i]
		var p2 = points[i+1]
		
		match mode:
			LineRenderMode.SEGMENT_SEGMENT:
				_draw_adv_mesh(l_name, p1, p2, top_radius, bottom_radius, color, style, i, transparency)
				i += 1
				
			LineRenderMode.SEGMENT_NOTHING:
				# Draw a segment, then skip the next slot to create a gap the size of a segment
				if i % 2 == 0:
					_draw_adv_mesh(l_name, p1, p2, top_radius, bottom_radius, color, style, i, transparency)
				else:
					if l_name in debug_objects: debug_objects[l_name].visible = false
				i += 1
				
			LineRenderMode.SEGMENT_POINT:
				# Even index: Draw a segment that spans TWO segment lengths
				# Odd index: Draw a point at the start of that segment
				if i % 2 == 0:
					var p_long = points[i+2] if i + 2 <= segments_count else p2
					_draw_adv_mesh(l_name, p1, p_long, top_radius, bottom_radius, color, style, i, transparency)
				else:
					_draw_adv_point(l_name, p1, top_radius * 2.5, color, transparency)
				i += 1
	
			LineRenderMode.SEGMENT_ROTATED_CHAIN:
				# Force alternating rotations for that rectangular chain look
				_draw_adv_mesh(l_name, p1, p2, top_radius, bottom_radius, color, style, i, transparency, true)
				i += 1
	
	# Cleanup any old segments if the segments_count was higher last frame
	_hide_unused_rope_nodes(base_name, i)


func CreateCircleLine(circle_name: String, center: Vector3, radius: float, color: Color, up_direction: Vector3) -> void:
	var segments := 32
	
	for i in range(segments):
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		
		var right := up_direction.cross(Vector3.FORWARD).normalized()
		var forward := right.cross(up_direction).normalized()
		
		var p0 := center + (right * cos(a0) + forward * sin(a0)) * radius
		var p1 := center + (right * cos(a1) + forward * sin(a1)) * radius
		
		CreateAdvancedLine(circle_name + "_" + str(i), p0, p1, Vector3.ZERO, 1, 0.008, 0.008, color, LineStyle.LASER, LineRenderMode.SEGMENT_SEGMENT, 1.0)


func _draw_adv_mesh(n, p1, p2, mesh_tr, br, col, style, idx, alpha, force_chain = false):
	var container = _get_or_create_debug_node(n, "cylinder")
	var mi: MeshInstance3D = container.get_child(0)
	
	var dir = p2 - p1
	var dist = dir.length()
	if dist < 0.001: 
		container.visible = false
		return
	
	container.visible = true
	mi.mesh.height = dist
	
	# RECTANGULAR/FLAT LOGIC
	# A proper chain needs flat faces, so we squeeze X and Z differently
	if style == LineStyle.ROPE or force_chain:
		mi.mesh.top_radius = mesh_tr * 2.0
		mi.mesh.bottom_radius = br * 2.0
		mi.scale.x = 0.3  # Squeezed flat
		mi.scale.z = 1.0  # Kept wide
	else:
		mi.mesh.top_radius = mesh_tr
		mi.mesh.bottom_radius = br
		mi.scale = Vector3.ONE
	
	# ALIGNMENT
	var y_axis = dir.normalized()
	var check_dir = Vector3.UP if abs(y_axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x_axis = check_dir.cross(y_axis).normalized()
	var z_axis = y_axis.cross(x_axis).normalized()
	var b = Basis(x_axis, y_axis, z_axis)
	
	# Rotation flip
	if (style == LineStyle.ROPE or force_chain) and idx % 2 == 1:
		b = b.rotated(y_axis, PI/2.0)
		
	mi.global_transform = Transform3D(b, (p1 + p2) / 2.0)
	_apply_mat(mi, col, alpha, texture_shadows)


func _draw_adv_point(n, pos, radius, col, alpha):
	var container = _get_or_create_debug_node(n, "sphere")
	var mi: MeshInstance3D = container.get_child(0)
	container.visible = true
	mi.global_position = pos
	mi.mesh.radius = radius
	mi.mesh.height = radius * 2.0
	_apply_mat(mi, col, alpha, texture_shadows)


func _get_or_create_debug_node(n, type):
	if n in debug_objects and is_instance_valid(debug_objects[n]):
		return debug_objects[n]
	
	var container = Node3D.new()
	var mi = MeshInstance3D.new()
	if type == "cylinder":
		mi.mesh = CylinderMesh.new()
	else:
		mi.mesh = SphereMesh.new()
	
	mi.material_override = ORMMaterial3D.new()
	mi.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	container.add_child(mi)
	debug_objects[n] = container
	get_tree().root.add_child(container)
	return container


func _apply_mat(mi, col, alpha, is_texture_shadowed):
	var mat: ORMMaterial3D = mi.material_override
	
	mat.albedo_color = Color(col, alpha)
	mat.roughness = 0.7
	mat.metallic = 0.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	
	if is_texture_shadowed:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _hide_unused_rope_nodes(prefix, start_idx):
	var i = start_idx
	while true:
		var n = prefix + "_" + str(i)
		if n in debug_objects:
			debug_objects[n].visible = false
			i += 1
		else:
			break


# Keep a persistent reference to the drawing node
var trajectory_line: MeshInstance3D = null

func DrawTrajectoryImmediate(points: Array[Vector3], color: Color):
	# 1. Initialization (Run only once)
	if not is_instance_valid(trajectory_line):
		trajectory_line = MeshInstance3D.new()
		trajectory_line.mesh = ImmediateMesh.new()
		trajectory_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var mat = ORMMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true # Allows us to change color per-segment
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trajectory_line.material_override = mat
		
		add_child(trajectory_line)

	var imm_mesh: ImmediateMesh = trajectory_line.mesh
	imm_mesh.clear_surfaces() # Wipe previous frame's drawing

	if points.size() < 2: return

	# 2. DRAWING LOOP
	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for i in range(points.size() - 1):
		# Calculate fade/alpha logic
		var t = float(i) / points.size()
		var segment_color = color
		segment_color.a *= (1.0 - t) # Fade out towards the end
		
		imm_mesh.surface_set_color(segment_color)
		imm_mesh.surface_add_vertex(to_local(points[i])) # Points must be local to the drawer
		
		imm_mesh.surface_set_color(segment_color)
		imm_mesh.surface_add_vertex(to_local(points[i+1]))
		
	imm_mesh.surface_end()


# Internal helper to keep CreateLine clean
func _add_debug_sphere(parent: Node, pos: Vector3, radius: float, mat: Material):
	var mi = MeshInstance3D.new()
	var m = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2
	m.material = mat
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos


func CreateRaycast(n: String, global_pos: Vector3, relative_target: Vector3) -> RayCast3D:
	var r: RayCast3D
	
	if n in debug_objects and is_instance_valid(debug_objects[n]):
		r = debug_objects[n]
	else:
		r = RayCast3D.new()
		r.name = n
		r.enabled = true
		r.add_exception(player_rigidbody)
		get_tree().root.add_child(r)
		debug_objects[n] = r
	
	
	r.global_transform.basis = Basis.IDENTITY
	r.global_position = global_pos
	
	if relative_target.is_zero_approx():
		r.target_position = Vector3(0, -0.01, 0) # Raycasts hate zero length
	else:
		var dir = relative_target.normalized()
		r.target_position = dir * relative_target.length()
	
	r.force_raycast_update() 
	
	return r


func CleanupKeys(keys_to_clean: Array):
	for key in keys_to_clean:
		if debug_objects.has(key):
			var obj = debug_objects[key]
			if is_instance_valid(obj):
				obj.queue_free()
			debug_objects.erase(key)


func shoot_zig_zag_laserOG(x,y,z):
	var space_state := get_world_3d().direct_space_state
	
	if not space_state:
		return
	
	var origin = player_rigidbody.global_transform.origin + x + y + z
	# Ensure we are using the global direction
	var laser_direction = -player_rigidbody.global_transform.basis.z.normalized()
	
	var max_zig_zag_segments := 12
	var max_distance := 80.0
	var zig_zag_angle := 8.0 
	var thickness := 0.05 # Smaller default for better visuals
	var speed := 3.0 # Increased speed for better "laser" feel
	
	var traveled := 0.0
	var current_pos = origin
	var current_dir = laser_direction
	
	for i in range(max_zig_zag_segments):
		var remaining_dist := max_distance - traveled
		if remaining_dist <= 0:
			break
		
		# Calculate random deviation
		var yaw := deg_to_rad(randf_range(-zig_zag_angle, zig_zag_angle))
		var pitch := deg_to_rad(randf_range(-zig_zag_angle, zig_zag_angle))
		
		# Apply rotation to the direction vector
		current_dir = current_dir.rotated(Vector3.UP, yaw)
		# Use a cross product to find the "right" vector for pitch to avoid gimbal lock
		var right_vec = current_dir.cross(Vector3.UP).normalized()
		current_dir = current_dir.rotated(right_vec, pitch).normalized()
		
		var segment_length = min(remaining_dist, 6.0)
		var target_pos = current_pos + current_dir * segment_length
		
		var query := PhysicsRayQueryParameters3D.create(current_pos, target_pos)
		query.exclude = [player_rigidbody.get_rid()] # Use RID for exclusion
		
		var result := space_state.intersect_ray(query)
		
		var end_pos = target_pos
		var hit_something = false
		
		if result:
			end_pos = result.position
			hit_something = true
		
		# Draw the segment
		_draw_laser_segment(current_pos, end_pos, thickness, speed, i * 0.05)
		
		if hit_something:
			# _spawn_impact_particles(result.position, result.normal)
			break
		
		# Update for next iteration
		current_pos = end_pos
		traveled += (current_pos - origin).length()
		thickness *= 0.8
		speed *= 2
		zig_zag_angle *= 0.9


func _draw_laser_segment(from: Vector3, to: Vector3, thickness: float, _speed: float, delay: float):
	var dist = from.distance_to(to)
	if dist < 0.01: return
	
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness * 0.5
	mesh.bottom_radius = thickness
	mesh.height = dist
	
	# Create a bright material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.165, 1.27, 1.251, 1.0) # Overbright for Glow/HDR
	mat.emission_enabled = true
	mat.emission = Color(0.61, 1.0, 0.993, 1.0)
	mesh.material = mat
	
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	
	# Position it at the midpoint
	instance.global_position = (from + to) / 2.0
	
	# Point the Y-axis (height) toward the 'to' position
	instance.look_at(to, Vector3.UP)
	instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	
	# Animation: Scale it in or Fade it out
	instance.scale = Vector3.ZERO
	var tween := create_tween()
	tween.set_parallel(false)
	# Wait for the "bolt" to reach this segment
	tween.tween_interval(delay)
	# Appear
	tween.tween_property(instance, "scale", Vector3.ONE, 0.05)
	# Disappear after a short lifetime based on speed
	tween.tween_property(instance, "scale", Vector3.ZERO, 0.2).set_delay(0.1)
	tween.tween_callback(instance.queue_free)


enum LightningPattern { BRANCHING_TREE, MUSCLE_CONVERGING }

func shoot_zigzag_laser(x: Vector3, y: Vector3, z: Vector3, pattern: LightningPattern = LightningPattern.BRANCHING_TREE): #MUSCLE_CONVERGING
	var space_state := get_world_3d().direct_space_state
	
	if not space_state:
		return
	
	var origin = player_rigidbody.global_transform.origin + x + y + z
	var laser_direction = -player_rigidbody.global_transform.basis.z.normalized()
	
	var max_distance := 80.0
	
	# Raycast once to find the absolute end point immediately
	var query := PhysicsRayQueryParameters3D.create(origin, origin + laser_direction * max_distance)
	query.exclude = [player_rigidbody.get_rid()]
	var result := space_state.intersect_ray(query)
	
	var end_pos = origin + laser_direction * max_distance
	if result:
		end_pos = result.position
		# _spawn_impact_particles(result.position, result.normal) # Uncomment if you have this
	
	var distance = origin.distance_to(end_pos)
	
	if pattern == LightningPattern.BRANCHING_TREE:
		_shoot_branching_tree(origin, laser_direction, distance)
	else:
		_shoot_muscle_converging(origin, end_pos)


func _shoot_branching_tree(start_pos: Vector3, main_dir: Vector3, total_length: float):
	# Pattern 1: Spreads like a tree. Strands travel forward but branch outward, dying off randomly.
	var branches = [{"pos": start_pos, "dir": main_dir, "length_left": total_length, "thickness": 0.08}]
	var branch_speed = 3.0
	
	while branches.size() > 0:
		var new_branches = []
		for b in branches:
			if b.length_left <= 0: continue
			
			var seg_len = min(b.length_left, randf_range(2.0, 5.0))
			
			# Wobble the direction
			var yaw = deg_to_rad(randf_range(-15.0, 15.0))
			var pitch = deg_to_rad(randf_range(-15.0, 15.0))
			var dir = b.dir.rotated(Vector3.UP, yaw)
			var right_vec = dir.cross(Vector3.UP).normalized()
			if right_vec.length_squared() > 0.001:
				dir = dir.rotated(right_vec, pitch).normalized()
				
			var target = b.pos + dir * seg_len
			
			# Delay makes it look like it's traveling away from the player
			var delay = (total_length - b.length_left) * 0.015
			_draw_laser_segment(b.pos, target, b.thickness, branch_speed, delay)
			
			# Add the core branch for the next loop iteration
			new_branches.append({"pos": target, "dir": dir, "length_left": b.length_left - seg_len, "thickness": b.thickness * 0.85})
			
			# Randomly spawn a sub-branch (like roots spreading)
			if randf() > 0.65 and b.length_left > 10.0:
				var split_dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(20, 50) * (1 if randf() > 0.5 else -1)))
				new_branches.append({"pos": target, "dir": split_dir, "length_left": b.length_left * 0.4, "thickness": b.thickness * 0.5})
				
		branches = new_branches


func _shoot_muscle_converging(start_pos: Vector3, end_pos: Vector3):
	# Pattern 2: Starts thin -> explodes into many paths in the middle -> convergences back to single point
	var strands = 6
	var dist = start_pos.distance_to(end_pos)
	var main_dir = start_pos.direction_to(end_pos)
	
	# Determine right and up vectors to bulge the "muscle" outward
	var right = main_dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001: right = main_dir.cross(Vector3.RIGHT).normalized()
	var up = right.cross(main_dir).normalized()
	
	for s in range(strands):
		var current_pos = start_pos
		var segments = int(dist / 3.0) + 1 # Number of zigzag bends per strand
		var seg_len = dist / float(segments)
		
		# Give each strand a distinct outward trajectory relative to the main laser line
		var strand_offset_dir = (right * randf_range(-1, 1) + up * randf_range(-1, 1)).normalized()
		var max_bulge = randf_range(1.0, 3.5) # How "fat" the muscle shape gets
		
		var base_thickness = randf_range(0.01, 0.04)
		
		for i in range(1, segments + 1):
			var t = float(i) / segments
			
			# The Magic Formula: sin(t * PI)
			# When t = 0 (start), sin is 0. 
			# When t = 0.5 (middle), sin is 1. 
			# When t = 1 (end), sin is 0. 
			var bulge = sin(t * PI) * max_bulge
			
			# Small electrical jitter on top of the smooth muscle curve
			var jitter = (right * randf_range(-0.6, 0.6) + up * randf_range(-0.6, 0.6)) * bulge
			
			var target = start_pos.lerp(end_pos, t) + (strand_offset_dir * bulge) + jitter
			
			# Force absolute convergence at the tip
			if i == segments: target = end_pos 
			
			# The line gets thicker in the middle with the bulge modifier
			_draw_laser_segment(current_pos, target, base_thickness * (1.0 + bulge), 3.0, (i * seg_len) * 0.005)
			current_pos = target


# --- PREDICTION SETTINGS ---
@export_group("Prediction Visuals")
@export var segment_step_time: float = 0.07    # How 'long' each segment is in time (dt)
@export var max_segments: int = 200             # Total number of segments
@export var dash_ratio: int = 5     # 2 = every other segment is a dot

@export var line_thickness_start: float = 0.08 # Thickness near player
@export var line_thickness_end: float = 0.01   # Thickness at the end of the line
@export var near_fade_dist: float = 0.5        # Segments closer than this fade out
@export var min_collision_dist: float = 1.2    # Don't check collisions for the first X meters

@export_group("Trajectory Colors")
@export var color_hit: Color = Color(1.0, 0.0, 0.0, 0.2)      # Red (Will collide)
@export var color_no_hit: Color = Color(0.0, 0.0, 1.0, 0.2)   # Blue (Airborne)

var last_max_segments = 0

# Store instances to avoid constant Dictionary lookups and String concatenation
var path_segments: Array[Node3D] = []
# Keep track of labels separately for easy cleanup
var distance_labels: Array[Label3D] = []

func PredictFallPath(is_path_active: bool):
	# 1. TOTAL HIDE LOGIC
	if not is_path_active:
		for key in debug_objects:
			if key.begins_with("FallPath_") or key == "Landing_Pill" or key.begins_with("DistLabel_"):
				if is_instance_valid(debug_objects[key]):
					debug_objects[key].visible = false
		return
	
	var start_pos = player_rigidbody.global_transform.origin
	var pos = start_pos
	var vel = player_rigidbody.linear_velocity
	var space_state = get_world_3d().direct_space_state
	
	if not space_state:
		return
	
	
	var points: Array[Vector3] = [pos]
	var hit_pos = Vector3.ZERO
	var hit_normal = Vector3.UP
	var will_hit = false
	var first_contact_captured = false # GATE: Prevents overwriting the first hit
	
	var g_data_start = GetGravityData(start_pos)
	var up_vector = -g_data_start.direction # Up is away from gravity
	
	vel = vel - up_vector * vel.dot(up_vector)
	
	# 2. SIMULATION LOOP
	for i in range(max_segments):
		var g_data = GetGravityData(pos)
		vel += (g_data.direction * g_data.strength) * segment_step_time
		var next_pos = pos + vel * segment_step_time
		
		# GEOMETRY FOLLOWING: Check for ground hugging
		var ground_query_dist = current_leg_length * 1.5 
		var down_query = PhysicsRayQueryParameters3D.create(next_pos, next_pos + (g_data.direction * ground_query_dist))
		down_query.exclude = [player_rigidbody.get_rid()]
		var ground_res = space_state.intersect_ray(down_query)
		
		if ground_res:
			next_pos = ground_res.position + (ground_res.normal * 0.05)
			points.append(next_pos) # Add the final point
			
			if not first_contact_captured:
				will_hit = true
				hit_pos = ground_res.position
				hit_normal = ground_res.normal
				first_contact_captured = true
				
			break
	
		# WALL COLLISION
		if pos.distance_to(start_pos) > min_collision_dist:
			var query = PhysicsRayQueryParameters3D.create(pos, next_pos)
			query.exclude = [player_rigidbody.get_rid()]
			var wall_res = space_state.intersect_ray(query)
			if wall_res:
				points.append(wall_res.position)
				
				# CAPTURE FIRST CONTACT (Wall)
				if not first_contact_captured:
					will_hit = true
					hit_pos = wall_res.position
					hit_normal = wall_res.normal
					first_contact_captured = true
				
				break # Wall hits always stop the simulation
		
		if next_pos.distance_to(pos) < 0.01: continue
		points.append(next_pos)
		pos = next_pos
	
	# 3. RENDER LOGIC
	var base_color = color_hit if will_hit else color_no_hit
	var total_dist = 0.0
	var marker = 2.0
	var next_marker = 2.0
	
	for i in range(max_segments):
		var l_name = "FallPath_" + str(i)
		
		if i < points.size() - 1 and i % dash_ratio == 0:
			var p1 = points[i]
			var p2 = points[i+1]
			var dist_from_start = p1.distance_to(start_pos)
			
			# HIDE Logic: Don't render if it's inside the player's immediate space
			# This cleans up the "first collision space" mess
			if dist_from_start < 0.8: # Adjust this value based on player width
				if l_name in debug_objects: debug_objects[l_name].visible = false
				continue
	
			total_dist += p1.distance_to(p2)
			var t_ratio = float(i) / max_segments
			var proximity_alpha = clamp((dist_from_start - 0.5) / near_fade_dist, 0.0, 1.0)
			var final_color = base_color
			final_color.a *= (proximity_alpha * (1.0 - t_ratio))
			
			# PASS 'true' for Depth Testing so walls/ground hide the line
			var line = CreateLine(l_name, p1, p2, line_thickness_end, line_thickness_start, final_color, final_color.a, true)
			if line: line.visible = true
			
			if total_dist >= next_marker:
				_update_dist_label(str(int(next_marker)) + "m", p2, Color.WHITE)
				next_marker += marker
		else:
			if l_name in debug_objects:
				debug_objects[l_name].visible = false
	
	_hide_unused_labels(next_marker)
	
	# 4. LANDING PILL (Now stays at the first contact point)
	if will_hit:
		var pill = CreateLine("Landing_Pill", hit_pos, hit_pos + (hit_normal * 0.5), 0.15, 0.15, Color.YELLOW, 0.5)
		if pill: pill.visible = true
	elif "Landing_Pill" in debug_objects:
		debug_objects["Landing_Pill"].visible = false


# Helper to manage the Label3D nodes with culling and parent-safety
func _update_dist_label(text: String, pos: Vector3, color: Color):
	var l_name = "DistLabel_" + text
	var label: Label3D
	
	if l_name in debug_objects and is_instance_valid(debug_objects[l_name]):
		label = debug_objects[l_name]
	else:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		
		# VIEW CULLING FIX: Set to false so the ground/walls hide the label
		label.no_depth_test = false 
		
		label.font_size = 32
		label.outline_size = 8
		
		debug_objects[l_name] = label
	
	# --- PARENT-SAFETY FIX (World Space) ---
	# We ensure the label is attached to the scene root, NOT the player.
	if label.get_parent() == null:
		get_tree().root.add_child(label)
	elif label.get_parent() != get_tree().root:
		label.reparent(get_tree().root)
	
	label.text = text
	label.modulate = color
	
	# Since it's in the tree safely, global_position works perfectly
	label.global_position = pos + (Vector3.UP * 0.3) 
	label.visible = true


func _hide_unused_labels(current_threshold: float):
	for key in debug_objects:
		if key.begins_with("DistLabel_"):
			var val = int(key.split("_")[1])
			if val >= current_threshold:
				debug_objects[key].visible = false


# Optimized Gravity Lookup
func GetGravityData(at_pos: Vector3) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	
	if not space_state:
		return {"direction": Vector3.ZERO}
	
	
	# Using Point query is MUCH faster than Shape query for a simulation loop
	var query = PhysicsPointQueryParameters3D.new()
	query.position = at_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	
	var best_area: Area3D = null
	for res in results:
		var area = res.collider as Area3D
		if area and area.monitoring:
			if best_area == null or area.priority > best_area.priority:
				best_area = area
				
	if best_area:
		var dir = best_area.gravity_direction
		if best_area.gravity_point:
			dir = (best_area.global_transform.origin - at_pos).normalized()
		return {"strength": best_area.gravity, "direction": dir}
	
	return {"strength": current_gravity, "direction": current_gravity_direction}


func LaserPointer(distance: float = 100.0):
	var start = first_person_view.global_transform.origin
	var end = start + (-first_person_view.global_transform.basis.z * distance)
	
	# Straight line projection
	CreateLine("Laser_Guide", start, end, 0.001, 0.001, Color.RED, 0.8)
	CreatePoint("Laser_Dot", end, 0.01, Color.RED)


var rope_anchors: Array[Vector3] = [] # Anchor 0 is the wall, Last is the swing point
var is_grappling = false
var rope_length: float = 0.0 # We set this when the hook hits
var last_rope_segment_count = 0

func GrappleLogic(delta: float):
	# --- 0. CLEANUP & EXIT ---
	if not is_grappling or rope_anchors.size() == 0:
		if last_rope_segment_count > 0:
			for i in range(last_rope_segment_count + 1):
				var l_name = "Rope_Seg_" + str(i)
				if l_name in debug_objects:
					debug_objects[l_name].queue_free()
					debug_objects.erase(l_name)
			last_rope_segment_count = 0
		return
	
	var player_pos = player_rigidbody.global_transform.origin
	var space_state = get_world_3d().direct_space_state
	
	if not space_state:
		return
	
	# --- 1. INPUT: LENGTH ADJUSTMENT (Reel In/Out) ---
	var reel_speed = 20.0 * delta
	if Input.is_action_pressed("ScrollUp"):
		rope_length = max(1.0, rope_length - reel_speed)
	if Input.is_action_pressed("ScrollDown"):
		rope_length += reel_speed
	
	# --- 2. WRAPPING (With Distance Threshold) ---
	var current_anchor = rope_anchors.back()
	var wrap_query = PhysicsRayQueryParameters3D.create(current_anchor, player_pos)
	wrap_query.exclude = [player_rigidbody.get_rid()]
	var wrap_res = space_state.intersect_ray(wrap_query)
	
	if wrap_res:
		var new_sturdy_point = wrap_res.position + (wrap_res.normal * 0.05)
		# Only add if the new point isn't practically on top of the old one
		if new_sturdy_point.distance_to(current_anchor) > 0.01:
			rope_length -= current_anchor.distance_to(new_sturdy_point)
			rope_anchors.append(new_sturdy_point)
	
	# --- 3. UNWRAPPING (The Taut Logic) ---
	if rope_anchors.size() > 1:
		var prev_anchor = rope_anchors[rope_anchors.size() - 2]
		
		# Check if there is a clear line of sight to the PREVIOUS anchor
		var unwrap_query = PhysicsRayQueryParameters3D.create(player_pos, prev_anchor)
		unwrap_query.exclude = [player_rigidbody.get_rid()]
		var unwrap_hit = space_state.intersect_ray(unwrap_query)
		
		if unwrap_hit.is_empty():
			# Logic check: If the angle between (Prev -> Current) and (Current -> Player) 
			# becomes too wide, it means we've "doubled back" enough to straighten the rope.
			var dir_to_current = (current_anchor - prev_anchor).normalized()
			var dir_to_player = (player_pos - current_anchor).normalized()
			
			# Dot product > 0 means the player has moved "past" the corner back toward the start
			if dir_to_current.dot(dir_to_player) > -0.2:
				rope_length += current_anchor.distance_to(prev_anchor)
				# Clean up the visual line for the segment we're about to remove
				var l_name = "Rope_Seg_" + str(rope_anchors.size() - 1)
				if l_name in debug_objects:
					debug_objects[l_name].queue_free()
					debug_objects.erase(l_name)
					
				rope_anchors.pop_back()
	
	# --- 4. PHYSICS (The Pendulum) ---
	#var active_anchor = rope_anchors.back()
	#var to_anchor = active_anchor - player_pos
	#var current_dist = to_anchor.length()
	
	# --- 5. VISUALS ---
	for i in range(rope_anchors.size()):
		var p1 = rope_anchors[i]
		var p2 = player_pos if i == rope_anchors.size() - 1 else rope_anchors[i+1]
		CreateLine("Rope_Seg_" + str(i), p1, p2, 0.02, 0.02, Color.SADDLE_BROWN, 1.0)
	
	last_rope_segment_count = rope_anchors.size()


@export var hud_distance: float = 0.4

# This MUST match the 'hud_scale' uniform in your shader to line up perfectly
@export var shader_hud_scale: float = 2.0 

# Maps a 2D coordinate to your 3D Helmet world space.
# x: -1.0 (left) to 1.0 (right) edge of the HUD square
# y: -1.0 (bottom) to 1.0 (top) edge of the HUD square
func GetHUDWorldPosition(hud_x: float, hud_y: float) -> Vector3:
	# Reverse the shader's scaling
	var tan_x = hud_x / shader_hud_scale
	var tan_y = hud_y / shader_hud_scale
	
	# Since tan(angle) = opposite/adjacent, and adjacent is our forward vector,
	# we use atan() to get the actual rotation angle in radians, then convert to degrees.
	var h_angle_deg = rad_to_deg(atan(tan_x))
	var v_angle_deg = rad_to_deg(atan(tan_y))
	
	return GetHelmetSlot(h_angle_deg, v_angle_deg, hud_distance)


# The maximum angle (in degrees) from the center to the edge of the HUD.
# E.g., 45.0 means the HUD spans 90 degrees total horizontally.
@export var max_hud_fov_h: float = 120.0 
@export var max_hud_fov_v: float = 90.0

# Maps a 2D coordinate (-1.0 to 1.0) to 3D space with adjustable depth.
func GetCurvedHUDWorldPosition(hud_x: float, hud_y: float, custom_distance: float) -> Vector3:
	var h_angle_deg = hud_x * (max_hud_fov_h * 0.5)
	var v_angle_deg = hud_y * (max_hud_fov_v * 0.5)
	
	# If no custom distance is provided, use the default export variable
	var final_dist = hud_distance if custom_distance < 0 else custom_distance
	
	var helmet_xform = helmet_hud_mesh.global_transform
	var b = helmet_xform.basis
	var dir = -b.z 
	
	# Rotation math stays the same to follow the curve
	dir = dir.rotated(b.y, deg_to_rad(-h_angle_deg)) 
	dir = dir.rotated(b.x, deg_to_rad(v_angle_deg))
	
	# Multiplying the direction by final_dist moves it closer or further
	return helmet_xform.origin + (dir * final_dist)


var player_speed

func HelmetHudInfo():
	# Format: Name, Value, Color(R, G, B, A), Position
	#if CollisionLogic() or player_collisions != []:
	#	hud_2d.update_stat("Colliding with?", player_collisions[0].name, Color(1, 0, 0, 1), Vector2(5, 90))
	#else:
	#	hud_2d.update_stat("Colliding with?", "nothing", Color(0, 0, 1, 1), Vector2(5, 90))
	
	#if grounded:
	#	hud_2d.update_stat("Standing on?", "ground", Color(1, 0, 0, 1), Vector2(5, 110))
	#else:
	#	hud_2d.update_stat("Standing on?", "nothing", Color(0, 0, 1, 1), Vector2(5, 110))
	
	# 2. Speed Logic
	player_speed = snapped(player_rigidbody.linear_velocity.length(), 0.1)
	var full_text = str(player_speed)
	var speed_display_text = ""
	var speed_color = Color.GREEN
	
	if player_speed > 30:
		speed_color = Color(1, 0, 0, 1) # Solid Red
		speed_display_text = "[color=red][font_size=26][pulse][shake rate=100 level=10]" + full_text + "[/shake][/pulse][/font_size][/color]"
	elif player_speed > 15:
		speed_color = Color(1, 1, 0, 1) # Yellow
		speed_display_text = "[color=yellow][font_size=22][pulse][shake rate=60 level=10]" + full_text + "[/shake][/pulse][/font_size][/color]"
	else:
		speed_color = Color(0, 1, 0, 1) # Green
		speed_display_text = "[color=green][font_size=18][pulse]" + full_text + "[/pulse][/font_size][/color]"
	
	hud_2d.update_stat("Speed", speed_display_text, speed_color, Vector2(230, 5))
	
	# 3. Leg Length
	#hud_2d.update_stat("", snapped(current_leg_length, 0.1), Color(0, 1, 0.5, 0.8), Vector2(65, 330))
	
	# Leg Progress (Spring Green at 80% opacity)
	#hud_2d.update_progress("Leg_Length", current_leg_length * 85, Color(0, 1, 0.5, 0.8), Vector2(5, 330))
	
	# Jump charge bar (Magenta)
	#hud_2d.update_progress("Jump Force", current_jump_charge * 100, Color(1, 0, 1, 0.8), Vector2(5, 360))


# Standardized way to get a position on the inner "helmet" curve
# h_angle: degrees left(-) or right(+)
# v_angle: degrees up(+) or down(-)
# distance: how far from the "eye"
func GetHelmetSlot(h_angle: float, v_angle: float, distance: float = 0.2) -> Vector3:
	var cam_xform = first_person_view.global_transform
	var b = cam_xform.basis
	var dir = -b.z 
	# Corrected variable names to use the local basis
	dir = dir.rotated(b.y, deg_to_rad(-h_angle)) 
	dir = dir.rotated(b.x, deg_to_rad(v_angle))
	return cam_xform.origin + (dir * distance)
