
class_name AdaptiveRopeGrapple
extends Node3D

# Configuration
@export var max_segments := 50
@export var base_segment_length := 0.5
@export var tension_threshold := 1.2
@export var segment_mesh: Mesh
@export var grapple_pull_strength := 15.0  # Force applied when pulling player
@export var swing_dampening := 0.98        # Reduces swing momentum
@export var max_grapple_speed := 30.0      # Maximum speed when grappling

# Runtime variables
var is_grappled := false
var segments := []
var grapple_target: Vector3
var previous_positions := {}
var player_body: CharacterBody3D = null  # Reference to player body


func _ready():
    assign_segment_mesh()
    # Get parent if it's a CharacterBody3D
    if get_parent() is CharacterBody3D:
        player_body = get_parent()
    
func assign_segment_mesh():
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 0.05
    cylinder.bottom_radius = 0.05
    cylinder.height = 0.5
    cylinder.radial_segments = 12
    cylinder.rings = 1

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.5, 0.0) # Orange

    cylinder.material = material
    segment_mesh = cylinder


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("grapple"):
        shoot_grapple()
    elif event.is_action_released("grapple"):
        release_grapple()
       
func shoot_grapple():
    var space_state = get_world_3d().direct_space_state
    var camera = get_viewport().get_camera_3d()
    var start = camera.global_position
    var end = start + camera.global_transform.basis.z * -100
    
    var query = PhysicsRayQueryParameters3D.create(start, end)
    var result = space_state.intersect_ray(query)
    
    if result:
        initialize_rope(result.position)
        is_grappled = true

func initialize_rope(target_position: Vector3):
    grapple_target = target_position
    clear_segments()
    
    # Initial segment setup
    var start_point = global_position
    var direction = (grapple_target - start_point).normalized()
    var segment_count = clamp(ceil((start_point.distance_to(grapple_target) / base_segment_length)), 1, max_segments)
    print(segment_count)    
    for i in segment_count:
        var segment_pos = start_point + direction * base_segment_length * i
        add_segment(segment_pos)

func add_segment(seg_pos: Vector3):
    var new_segment = MeshInstance3D.new()
    new_segment.mesh = segment_mesh
    new_segment.position = seg_pos
    add_child(new_segment)
    segments.append(new_segment)
    previous_positions[new_segment] = seg_pos

func clear_segments():
    for segment in segments:
        segment.queue_free()
    segments.clear()
    previous_positions.clear()

func _physics_process(delta):
    if !is_grappled || segments.is_empty():
        return
    
    # Store initial position before update
    var initial_pos = global_position
    
    # Verlet integration for rope physics
    update_segment_positions(delta)
    
    # Update player position and velocity based on rope physics
    update_player_movement(delta, initial_pos)
    
    # Adaptive subdivision logic
    var total_length = calculate_rope_length()
    var desired_length = segments[0].global_position.distance_to(grapple_target)
    
    if desired_length / total_length > tension_threshold && segments.size() < max_segments:
        subdivide_segment()
    elif desired_length / total_length < 1.0 / tension_threshold && segments.size() > 1:
        merge_segments()

func update_segment_positions(delta):
    var gravity = Vector3.DOWN * 9.8 * delta
    
    # Update first segment (player connection)
    var first_segment = segments[0]
    var current_pos = first_segment.global_position
    previous_positions[first_segment] = current_pos
    
    # Make first segment follow the player
    first_segment.global_position = global_position
    
    # Update intermediate segments
    for i in range(1, segments.size()):
        var segment = segments[i]
        current_pos = segment.global_position
        var previous_pos = previous_positions[segment]
        var new_pos = current_pos + (current_pos - previous_pos) * 0.99 + gravity
        
        # Apply distance constraint
        var parent_segment = segments[i-1]
        var to_parent = (parent_segment.global_position - new_pos).normalized()
        new_pos = parent_segment.global_position - to_parent * base_segment_length
        
        segment.global_position = new_pos
        previous_positions[segment] = current_pos
    
    # Update last segment (grapple point)
    var last_segment = segments[-1]
    last_segment.global_position = grapple_target

func update_player_movement(delta: float, initial_pos: Vector3):
    if player_body == null:
        return
        
    # Calculate rope direction and length
    var rope_vector = grapple_target - global_position
    var rope_direction = rope_vector.normalized()
    var rope_length = rope_vector.length()
    
    # Calculate tension force based on distance to target
    var rest_length = base_segment_length * (segments.size() - 1)
    var tension = 0.0
    
    # Only apply tension when rope is extended
    if rope_length > rest_length:
        tension = (rope_length - rest_length) * grapple_pull_strength
    
    # Calculate pull force
    var pull_force = rope_direction * tension * delta
    
    # Add player input for swinging
    var input_direction = Vector3.ZERO
    if Input.is_action_pressed("move_forward"):
        input_direction.z -= 1
    if Input.is_action_pressed("move_back"):
        input_direction.z += 1
    if Input.is_action_pressed("move_left"):
        input_direction.x -= 1
    if Input.is_action_pressed("move_right"):
        input_direction.x += 1
    
    # Convert input to world space
    var camera = get_viewport().get_camera_3d()
    var camera_basis = camera.global_transform.basis
    input_direction = (camera_basis * Vector3(input_direction.x, 0, input_direction.z)).normalized()
    
    # Create swing force perpendicular to rope
    var swing_force = Vector3.ZERO
    if input_direction != Vector3.ZERO:
        # Project input onto plane perpendicular to rope
        swing_force = (input_direction - rope_direction * input_direction.dot(rope_direction))
        swing_force = swing_force.normalized() * 5.0 * delta
    
    # Combine forces
    var total_force = pull_force + swing_force
    
    # Update velocity
    player_body.velocity += total_force
    
    # Apply dampening to smooth swinging
    player_body.velocity *= swing_dampening
    
    # Clamp velocity to max speed
    if player_body.velocity.length() > max_grapple_speed:
        player_body.velocity = player_body.velocity.normalized() * max_grapple_speed
    
    # Move the player
    player_body.move_and_slide()

func subdivide_segment():
    var new_segment_index = find_most_stretched_segment()
    if new_segment_index == -1:
        return
    
    var prev_segment = segments[new_segment_index]
    var next_segment = segments[new_segment_index + 1]
    var new_position = (prev_segment.global_position + next_segment.global_position) * 0.5
    add_segment_at(new_segment_index + 1, new_position)

func merge_segments():
    var least_tension_index = find_least_tension_segment()
    if least_tension_index == -1:
        return
    
    remove_segment(least_tension_index)

func calculate_rope_length() -> float:
    var length = 0.0
    for i in range(segments.size() - 1):
        length += segments[i].global_position.distance_to(segments[i+1].global_position)
    return length

# Helper functions for adaptive subdivision
func find_most_stretched_segment() -> int:
    var max_stretch = 0.0
    var max_index = -1
    
    for i in range(segments.size() - 1):
        var stretch = segments[i].global_position.distance_to(segments[i+1].global_position)
        if stretch > base_segment_length * tension_threshold && stretch > max_stretch:
            max_stretch = stretch
            max_index = i
    
    return max_index

func find_least_tension_segment() -> int:
    var min_tension = INF
    var min_index = -1
    
    for i in range(segments.size() - 1):
        var tension = segments[i].global_position.distance_to(segments[i+1].global_position)
        if tension < base_segment_length / tension_threshold && tension < min_tension:
            min_tension = tension
            min_index = i
    
    return min_index

func release_grapple():
    is_grappled = false
    clear_segments()
    
func add_segment_at(index: int, seg_pos: Vector3):
    var new_segment = MeshInstance3D.new()
    new_segment.mesh = segment_mesh
    new_segment.position = seg_pos
    add_child(new_segment)
    segments.insert(index, new_segment)
    previous_positions[new_segment] = seg_pos

func remove_segment(index: int):
    if index < 0 or index >= segments.size():
        return
    var segment = segments[index]
    segment.queue_free()
    previous_positions.erase(segment)
    segments.remove_at(index)
