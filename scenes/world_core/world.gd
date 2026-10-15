extends Node3D

# --- Hierarchical Constants ---
const TIER_LOCAL_SIZE: float = 1000.0    # 1km
const TIER_REGIONAL_SIZE: float = 10000.0 # 10km
const TIER_SECTOR_SIZE: float = 100000.0 # 100km

enum UpdateTier { LOCAL, REGIONAL, SECTOR }

# --- Spatial Maps ---
# Nested Dictionaries: chunk_maps[UpdateTier][Vector3i] = Array[Node3D]
var chunk_maps: Dictionary = {
	UpdateTier.LOCAL: {},
	UpdateTier.REGIONAL: {},
	UpdateTier.SECTOR: {}
}

# --- State Tracking ---
var world_chunk_offset: Vector3i = Vector3i.ZERO
var planet_old_positions: Dictionary = {}
var total_time: float = 0.0

@onready var world_core = get_tree().current_scene
@onready var player_rigidbody: RigidBody3D = get_node("PlayerRB3D")

# --- World Shift Settings ---
var world_offset_fine: Vector3 = Vector3.ZERO

# --- Global Orbit Settings ---
@export var orbit_axis: Vector3 = Vector3.UP # Change this to tilt the "disk"

# --- Node References ---
#@onready var tiny_sun: StaticBody3D = $TinySun
#@onready var tiny_moon: StaticBody3D = $TinyMoon
@onready var starter_planet: StaticBody3D = get_node("StarterPlanetSB3D")
@onready var second_planet: StaticBody3D = get_node("SecondPlanetSB3D")

@onready var first_person_view = get_node("PlayerRB3D/FirstPersonViewC3D")

var shader_material: ShaderMaterial
var shader_material_2: ShaderMaterial

# --- Tweakable Orbit & Rotation Values ---
@export_group("Sun Setup")
@export var sun_spin_speed: float = 0.0
@export var sun_spin_axis: Vector3 = Vector3.UP

@export_group("Sun -> Planet 1")
@export var sun_p1_radius: float = 4168.0
@export var sun_p1_speed: float = 0.0
@export var p1_spin_speed: float = 0.0
@export var p1_spin_axis: Vector3 = Vector3.UP

@export_group("Planet 1 -> Tiny Moon")
@export var p1_moon_radius: float = 300.0
@export var p1_moon_speed: float = 0.01
@export var moon_spin_speed: float = 0.0
@export var moon_spin_axis: Vector3 = Vector3.UP


func _ready() -> void:
	# 1. Register for World Shifting
	var shiftable_entities = [starter_planet, second_planet]
	for entity in shiftable_entities:
		if is_instance_valid(entity):
			entity.add_to_group("shiftable")
	
	# 2. Register for Chunk/Active Cell Processing
	var celestial_entities = [starter_planet, second_planet]
	for entity in celestial_entities:
		if is_instance_valid(entity):
			entity.add_to_group("celestial_bodies")
	
	# 3. Initialize Position Cache
	for entity in celestial_entities:
		if is_instance_valid(entity):
			planet_old_positions[entity] = entity.global_position

	# 4. Player Configuration
	if player_rigidbody:
		player_rigidbody.add_to_group("player")
		if player_rigidbody.get_parent() != world_core:
			player_rigidbody.add_to_group("shiftable")

	# 5. Verify World Core
	if not world_core:
		push_error("World Core reference is invalid. Ensure this script is in a valid SceneTree.")
	
	_init_debug_materials()
	
	# Pre-generate starting sector grid
	var initial_sector_coords = get_tier_coords(player_rigidbody.global_position, TIER_SECTOR_SIZE)
	_maintain_sector_grid(initial_sector_coords)


func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	total_time += delta
	var frame_count = Engine.get_physics_frames()
	
	# 1. Coordinate Stability
	manage_floating_origin()
	
	# 2. Re-map Entities
	update_hierarchical_maps(frame_count)
	
	# 3. Tiered Processing
	process_tiered_logic(delta, frame_count)
	
	# Final step: Debug Visualization
	#update_debug_visualization()


# --- Hierarchical Mapping ---
func get_tier_coords(pos: Vector3, size: float) -> Vector3i:
	return Vector3i(floor(pos.x / size), floor(pos.y / size), floor(pos.z / size))

func update_hierarchical_maps(frame: int) -> void:
	for key in chunk_maps[UpdateTier.LOCAL]:
		chunk_maps[UpdateTier.LOCAL][key].clear()
	
	var update_regional = (frame % 10 == 0)
	var update_sector = (frame % 60 == 0)
	
	if update_regional:
		for key in chunk_maps[UpdateTier.REGIONAL]:
			chunk_maps[UpdateTier.REGIONAL][key].clear()
			
	if update_sector:
		for key in chunk_maps[UpdateTier.SECTOR]:
			chunk_maps[UpdateTier.SECTOR][key].clear()
			
		var player_sector = get_tier_coords(player_rigidbody.global_position, TIER_SECTOR_SIZE)
		_maintain_sector_grid(player_sector)

	var entities = get_tree().get_nodes_in_group("celestial_bodies")
	var p_pos = player_rigidbody.global_position

	for entity in entities:
		var dist = p_pos.distance_to(entity.global_position)
		
		if dist <= 5000.0:
			_add_to_map(UpdateTier.LOCAL, entity, TIER_LOCAL_SIZE)
		elif dist <= 50000.0 and update_regional:
			_add_to_map(UpdateTier.REGIONAL, entity, TIER_REGIONAL_SIZE)
		elif update_sector:
			_add_to_map(UpdateTier.SECTOR, entity, TIER_SECTOR_SIZE)


func _add_to_map(tier: UpdateTier, node: Node3D, size: float) -> void:
	var coords = get_tier_coords(node.global_position, size)
	if not chunk_maps[tier].has(coords):
		chunk_maps[tier][coords] = []
	chunk_maps[tier][coords].append(node)


# --- Tiered Execution ---
func process_tiered_logic(delta: float, frame: int) -> void:
	var active_for_inertia: Array[Node3D] = []
	
	# 1. ALWAYS process LOCAL (Every Frame)
	var local_coords = get_tier_coords(player_rigidbody.global_position, TIER_LOCAL_SIZE)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var target = local_coords + Vector3i(x, y, z)
				if chunk_maps[UpdateTier.LOCAL].has(target):
					for node in chunk_maps[UpdateTier.LOCAL][target]:
						_update_node_orbit(node)
						active_for_inertia.append(node)

	# 2. REGIONAL (Every 2 frames)
	if frame % 2 == 0:
		for coords in chunk_maps[UpdateTier.REGIONAL]:
			for node in chunk_maps[UpdateTier.REGIONAL][coords]:
				_update_node_orbit(node)
				active_for_inertia.append(node)

	# 3. SECTOR (Every 3 frames)
	if frame % 3 == 0:
		for coords in chunk_maps[UpdateTier.SECTOR]:
			for node in chunk_maps[UpdateTier.SECTOR][coords]:
				_update_node_orbit(node)
				active_for_inertia.append(node)

	# 4. Finalize Physics Inertia
	apply_frame_inertia(delta, active_for_inertia)


# --- Celestial Motion & Rotation ---
func _update_node_orbit(node: Node3D) -> void:
	# Store old position BEFORE moving (Crucial for inertia math)
	planet_old_positions[node] = node.global_position
	
	# Direct Node reference checks to eliminate string-matching bugs
	#if node == tiny_planet_1:
	#	node.global_position = calculate_orbit(tiny_sun.global_position, sun_p1_radius, sun_p1_speed)
	#	node.basis = calculate_rotation_basis(p1_spin_axis, p1_spin_speed)
	
	#elif node == tiny_moon:
	#	node.global_position = calculate_orbit(tiny_planet_1.global_position, p1_moon_radius, p1_moon_speed)
	#	node.basis = calculate_rotation_basis(moon_spin_axis, moon_spin_speed)

	#elif node == tiny_sun:
	#	node.basis = calculate_rotation_basis(sun_spin_axis, sun_spin_speed)


func calculate_rotation_basis(axis: Vector3, speed: float) -> Basis:
	var norm_axis = axis.normalized()
	if norm_axis.is_zero_approx():
		norm_axis = Vector3.UP
	# Deterministic rotation based on total_time guarantees no stutter during frame-skips
	return Basis(Quaternion(norm_axis, total_time * speed))


func calculate_orbit(center: Vector3, radius: float, speed: float) -> Vector3:
	var angle = total_time * speed
	var local_pos = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	
	var target_axis = orbit_axis.normalized()
	if target_axis.is_equal_approx(Vector3.UP):
		return center + local_pos
		
	var q = Quaternion(Vector3.UP, target_axis)
	return center + (q * local_pos)


# --- Surface Displacement (Inertia) ---
@onready var gravity_detector: Area3D = get_node("PlayerRB3D/GravityDetectorA3D")

func apply_frame_inertia(delta: float, _active_entities: Array[Node3D]) -> void:
	var overlapping_areas = gravity_detector.get_overlapping_areas()
	if overlapping_areas.is_empty(): return

	var player_pos = player_rigidbody.global_position
	var total_displacement = Vector3.ZERO

	for area in overlapping_areas:
		var planet = area.get_parent()
		if not planet_old_positions.has(planet): continue
		
		# 1. Linear orbital movement delta
		var movement_delta = planet.global_position - planet_old_positions[planet]
		
		# 2. Match exact spin speed and axis for the current body
		var spin_speed = 0.0
		var spin_axis = Vector3.UP

		#if planet == tiny_planet_1:
		#	spin_speed = p1_spin_speed
		#	spin_axis = p1_spin_axis.normalized()
		#elif planet == tiny_moon:
		#	spin_speed = moon_spin_speed
		#	spin_axis = moon_spin_axis.normalized()
		#elif planet == tiny_sun:
		#	spin_speed = sun_spin_speed
		#	spin_axis = sun_spin_axis.normalized()

		# 3. Tangential Velocity (v = w x r)
		var to_player = player_pos - planet.global_position
		var angular_velocity = spin_axis * spin_speed
		var rotation_displacement = angular_velocity.cross(to_player) * delta
		
		# 4. Weighting by proximity radius
		var dist = to_player.length()
		var max_radius = 1.0
		for child in area.get_children():
			if child is CollisionShape3D and child.shape is SphereShape3D:
				max_radius = child.shape.radius
		
		var weight = clamp(1.0 - (dist / max_radius), 0.0, 1.0)
		weight = pow(weight, 2.0)
		
		total_displacement += (movement_delta + rotation_displacement) * weight
		# 5. Apply continuous displacement safely to the RigidBody state
	
	var t = player_rigidbody.global_transform
	t.origin += total_displacement
	player_rigidbody.global_transform = t # Force immediate GDScript sync!
	PhysicsServer3D.body_set_state(player_rigidbody.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)


# --- Floating Origin ---
func manage_floating_origin() -> void:
	var p_pos = player_rigidbody.global_position
	if abs(p_pos.x) > TIER_LOCAL_SIZE / 2 or abs(p_pos.y) > TIER_LOCAL_SIZE / 2 or abs(p_pos.z) > TIER_LOCAL_SIZE / 2:
		var snap_offset = (p_pos / TIER_LOCAL_SIZE).round() * TIER_LOCAL_SIZE
		shift_world(-snap_offset)
		world_chunk_offset += Vector3i(snap_offset / TIER_LOCAL_SIZE)


func shift_world(offset: Vector3) -> void:
	if not is_instance_valid(world_core):
		return
	
	var shiftable_nodes = get_tree().get_nodes_in_group("shiftable")
	for node in shiftable_nodes:
		if node is Node3D:
			if node is RigidBody3D:
				var t = node.global_transform
				t.origin += offset
				node.global_transform = t # Force immediate GDScript sync!
				PhysicsServer3D.body_set_state(node.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
			else:
				node.global_translate(offset)
	
	if not player_rigidbody.is_in_group("shiftable"):
		var t = player_rigidbody.global_transform
		t.origin += offset
		player_rigidbody.global_transform = t # Force immediate GDScript sync!
		PhysicsServer3D.body_set_state(player_rigidbody.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	
	world_offset_fine += offset
	
	for planet in planet_old_positions.keys():
		planet_old_positions[planet] += offset


func get_absolute_position(pos: Vector3) -> Vector3:
	return pos - world_offset_fine


# --- Debug Visualization Settings ---
@export var show_debug_chunks: bool = true
var debug_container: Node3D

var mm_local: MultiMeshInstance3D
var mm_regional: MultiMeshInstance3D
var mm_sector: MultiMeshInstance3D

var ALPHA_LOCAL: float = 0.0025
var ALPHA_REGIONAL: float = 0.023
var ALPHA_SECTOR: float = 0.02
const ALPHA_ACTIVE_MULTIPLIER: float = 5.0

func _init_debug_materials():
	debug_container = Node3D.new()
	debug_container.name = "ChunkVisualizerContainer"
	add_child(debug_container)
	
	var shared_mat = StandardMaterial3D.new()
	shared_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	shared_mat.vertex_color_use_as_albedo = true
	shared_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	mm_local = _create_multimesh(shared_mat, TIER_LOCAL_SIZE)
	mm_regional = _create_multimesh(shared_mat, TIER_REGIONAL_SIZE)
	mm_sector = _create_multimesh(shared_mat, TIER_SECTOR_SIZE)


func _maintain_sector_grid(center_coords: Vector3i) -> void:
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var coords = center_coords + Vector3i(x, y, z)
				if not chunk_maps[UpdateTier.SECTOR].has(coords):
					chunk_maps[UpdateTier.SECTOR][coords] = []


func _create_multimesh(mat: StandardMaterial3D, size: float) -> MultiMeshInstance3D:
	var mmi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	
	var box = BoxMesh.new()
	box.size = Vector3(size, size, size)
	mm.mesh = box
	
	mmi.multimesh = mm
	mmi.material_override = mat
	debug_container.add_child(mmi)
	return mmi


func update_debug_visualization() -> void:
	if not show_debug_chunks:
		if debug_container.visible: debug_container.visible = false
		return
	
	debug_container.visible = true
	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var p_pos = player_rigidbody.global_position
	
	var local_data: Array[Dictionary] = []
	var regional_data: Array[Dictionary] = []
	var sector_data: Array[Dictionary] = []

	var local_coords = get_tier_coords(p_pos, TIER_LOCAL_SIZE)
	for x in range(-5, 6):
		for y in range(-5, 6):
			for z in range(-5, 6):
				var coords = local_coords + Vector3i(x, y, z)
				if _is_in_view(camera, coords, TIER_LOCAL_SIZE):
					var is_active = (abs(x) <= 1 and abs(y) <= 1 and abs(z) <= 1)
					var alpha = ALPHA_LOCAL * (ALPHA_ACTIVE_MULTIPLIER if is_active else 1.0)
					var pos = Vector3(coords) * TIER_LOCAL_SIZE + Vector3(TIER_LOCAL_SIZE/2, TIER_LOCAL_SIZE/2, TIER_LOCAL_SIZE/2)
					local_data.append({"pos": pos, "color": Color(0.0, 1.0, 0.0, alpha)})

	_gather_hierarchical_data(UpdateTier.REGIONAL, TIER_REGIONAL_SIZE, Color(1.0, 0.5, 0.0, ALPHA_REGIONAL), regional_data, camera)
	_gather_hierarchical_data(UpdateTier.SECTOR, TIER_SECTOR_SIZE, Color(1.0, 0.0, 0.0, ALPHA_SECTOR), sector_data, camera)

	_apply_multimesh_data(mm_local, local_data)
	_apply_multimesh_data(mm_regional, regional_data)
	_apply_multimesh_data(mm_sector, sector_data)


func _gather_hierarchical_data(tier: UpdateTier, size: float, base_color: Color, data_buffer: Array[Dictionary], cam: Camera3D):
	if not chunk_maps.has(tier): return
	
	for coords in chunk_maps[tier]:
		if _is_in_view(cam, coords, size):
			var pos = Vector3(coords) * size + Vector3(size/2, size/2, size/2)
			data_buffer.append({"pos": pos, "color": base_color})


func _apply_multimesh_data(mmi: MultiMeshInstance3D, data: Array[Dictionary]) -> void:
	var mm = mmi.multimesh
	mm.instance_count = data.size()
	
	for i in range(data.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), data[i]["pos"]))
		mm.set_instance_color(i, data[i]["color"])


func _is_in_view(cam: Camera3D, coords: Vector3i, size: float) -> bool:
	var world_pos = Vector3(coords) * size + Vector3(size/2, size/2, size/2)
	if cam.is_position_in_frustum(world_pos):
		return true
	
	var p_pos = player_rigidbody.global_position
	if abs(p_pos.x - world_pos.x) < size/2 and \
	   abs(p_pos.y - world_pos.y) < size/2 and \
	   abs(p_pos.z - world_pos.z) < size/2:
		return true
		
	return false


func teleport_to_global(target_sector: Vector3i, target_offset: Vector3):
	var sector_diff = target_sector - world_chunk_offset
	var m_offset = Vector3(sector_diff) * TIER_SECTOR_SIZE
	player_rigidbody.global_position = target_offset + m_offset
	manage_floating_origin()
