extends Node3D

class_name Grapple

# Grappling hook parameters
@export var max_distance: float = 50.0
@export var spring_strength: float = 20.0
@export var damping: float = 5.0
@export var retracting_speed: float = 10.0
@export var pull_force: float = 10.0

# Visual settings
@export var rope_thickness: float = 0.05
@export var rope_color: Color = Color(1.0, 0.5, 0.0, 1.0)  # Bright orange

# Grapple state variables
var is_grappling: bool = false
var grapple_point: Vector3 = Vector3.ZERO
var rope_mesh: MeshInstance3D
var rope_material: StandardMaterial3D
var camera_node: Camera3D
var camera_offset: Vector3 = Vector3(0, -0.7, -0.5)  # Offset for better visibility
var enemy_attached


# Physics variables
var current_rope_length: float = 0.0
var target_rope_length: float = 0.0
var rope_velocity: float = 0.0

func _ready():
    # Create rope mesh
    rope_mesh = MeshInstance3D.new()
    add_child(rope_mesh)
    
    # Set up rope material
    rope_material = StandardMaterial3D.new()
    rope_material.albedo_color = rope_color
    rope_material.roughness = 0.4
    
    # Reference to camera
    camera_node = get_parent().get_node("CameraPivot/CameraFirst")

func _process(_delta):
    # Update grapple visuals if active
    if is_grappling:
        _update_rope_mesh()

func _physics_process(delta):
    # Check for grapple input
    if enemy_attached != null:
        grapple_point = enemy_attached.position

    if Input.is_action_just_pressed("grapple"):
        if !is_grappling:
            _shoot_grapple()
        else:
            _release_grapple()
    
    # Apply spring physics if grappling
    if is_grappling:
        _apply_spring_physics(delta)

func _shoot_grapple():
    # Get grapple start position (camera with offset)
    var start_pos = camera_node.global_transform.origin + camera_node.global_transform.basis * camera_offset
    
    # Cast ray from camera
    var space_state = get_world_3d().direct_space_state
    var ray_end = start_pos + camera_node.global_transform.basis.z * -max_distance
    
    var query = PhysicsRayQueryParameters3D.create(start_pos, ray_end)
    query.exclude = [get_parent()]
    var result = space_state.intersect_ray(query)
    
    # If we hit something, attach the grapple
    if result:
        
        # Check if the object is an enemy
        if result.collider.is_in_group("enemy"):
            print('enemy grappled')
            enemy_attached = result.collider
        
        is_grappling = true
        grapple_point = result.position

        current_rope_length = start_pos.distance_to(grapple_point)
        target_rope_length = current_rope_length
        rope_velocity = 0.0
        
        # Make rope visible
        rope_mesh.visible = true

func apply_release_force():
    var vertical_boost = 5.0
    var pull_boost = 8.0
   
    #var direction = grapple_point.direction_to(get_parent().position)
    var pull_dir = get_parent().global_position.direction_to(grapple_point)
    
    get_parent().velocity += pull_dir * pull_boost
    get_parent().velocity.y += vertical_boost 

func get_boost_dir() -> Vector3:
    # Create the orthogonal plane
    var normal = (grapple_point - Global.player_pos).normalized()
    var d = -normal.dot(enemy_attached.global_position)
    var orthogonal_boost_plane = Plane(normal, d)
    
    # Find where the camera ray intersects this plane
    var intersection_point = get_camera_plane_intersection(orthogonal_boost_plane)
    
    # Calculate direction from enemy to intersection point
    var boost_dir = (intersection_point - enemy_attached.global_position).normalized()
    
    return boost_dir

func _release_grapple():

    is_grappling = false
    if enemy_attached:
        
        enemy_attached.velocity += get_boost_dir() * 20.0 
        enemy_attached = null

    
    apply_release_force()
    rope_mesh.visible = false

func _apply_spring_physics(_delta):
    var player = get_parent()
    var player_body: CharacterBody3D = player as CharacterBody3D
    
    if player_body:
        # Get current rope start position
        var start_pos = camera_node.global_transform.origin + camera_node.global_transform.basis * camera_offset
        # Calculate current distance to grapple point
        var current_distance = start_pos.distance_to(grapple_point)

        # Spring physics - calculate force based on Hooke's law with damping
        var direction_to_point = (grapple_point - start_pos).normalized()
        var _spring_force = direction_to_point * spring_strength * (current_distance - target_rope_length)
        
        # Apply damping
        _spring_force -= player_body.velocity * damping
        
        # Apply the force to the player
        #player_body.velocity += spring_force * delta
        
        # If player is trying to retract rope
        #if Input.is_action_pressed("retract_grapple") and target_rope_length > 3.0:
            #target_rope_length -= retracting_speed * delta
        #
        ## If player is trying to extend rope
        #if Input.is_action_pressed("extend_grapple"):
            #target_rope_length += retracting_speed * delta
            #target_rope_length = min(target_rope_length, max_distance)


# Function to find where camera ray intersects with an orthogonal plane
func get_camera_plane_intersection(orthogonal_plane: Plane) -> Vector3:
    # Get camera position and direction
    var camera_pos = camera_node.global_transform.origin
    var camera_dir = -camera_node.global_transform.basis.z.normalized()
    
    # Calculate the intersection parameter t
    # For a ray: p(t) = camera_pos + t * camera_dir
    # For a plane: normal·p + d = 0
    # Solving for t: t = -(normal·camera_pos + d) / (normal·camera_dir)
    
    var denominator = orthogonal_plane.normal.dot(camera_dir)
    
    # Check if ray is parallel to plane (or nearly so)
    if abs(denominator) < 0.0001:
        # Ray is parallel to plane, no intersection or infinite intersections
        return Vector3.ZERO  # Or handle this case differently
    
    # Calculate t
    var t = -(orthogonal_plane.normal.dot(camera_pos) + orthogonal_plane.d) / denominator
    
    # If t is negative, the intersection is behind the camera
    if t < 0:
        # You might want to handle this case differently
        return camera_pos  # Return camera position or some other fallback
    
    # Calculate the intersection point
    var intersection_point = camera_pos + camera_dir * t
    
    return intersection_point



func _update_rope_mesh():
    # Get rope start position (camera with offset)
    var start_pos = camera_node.global_transform.origin + camera_node.global_transform.basis * camera_offset
    
    # Calculate rope properties
    var rope_vector = grapple_point - start_pos
    var _rope_length = rope_vector.length()
    var rope_direction = rope_vector.normalized()
    
    # Create rope mesh
    var immediate_mesh = ImmediateMesh.new()
    rope_mesh.mesh = immediate_mesh
    rope_mesh.material_override = rope_material
    
    # Draw the rope as a simple cylinder
    immediate_mesh.clear_surfaces()
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    
    # We'll create a basic cylinder from start to end
    var segments = 8  # Number of sides for our rope cylinder
    var up = (rope_direction.cross(Vector3.UP).normalized() 
              if rope_direction != Vector3.UP and rope_direction != Vector3.DOWN 
              else rope_direction.cross(Vector3.RIGHT).normalized())
    var right = rope_direction.cross(up).normalized()
    
    # Create vertices
    var prev_vertices = []
    var curr_vertices = []
    
    for i in range(segments + 1):
        var angle = 2 * PI * i / segments
        var x = cos(angle) * rope_thickness
        var y = sin(angle) * rope_thickness
        
        var offset = right * x + up * y
        
        # Store vertices for start and end of current segment
        var vertex_start = to_local(start_pos + offset)
        var vertex_end = to_local(grapple_point + offset)
        
        # For the first iteration, just store the vertices
        if i == 0:
            prev_vertices = [vertex_start, vertex_end]
            continue
            
        # Store current vertices for potential next iteration
        curr_vertices = [vertex_start, vertex_end]
        
        # Add first triangle
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(0, 0))
        immediate_mesh.surface_add_vertex(prev_vertices[0])
        
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(1, 0))
        immediate_mesh.surface_add_vertex(curr_vertices[0])
        
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(1, 1))
        immediate_mesh.surface_add_vertex(curr_vertices[1])
        
        # Add second triangle
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(0, 0))
        immediate_mesh.surface_add_vertex(prev_vertices[0])
        
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(1, 1))
        immediate_mesh.surface_add_vertex(curr_vertices[1])
        
        immediate_mesh.surface_set_normal(rope_direction)
        immediate_mesh.surface_set_uv(Vector2(0, 1))
        immediate_mesh.surface_add_vertex(prev_vertices[1])
        
        # Update previous vertices for next iteration
        prev_vertices = curr_vertices
    
    immediate_mesh.surface_end()
