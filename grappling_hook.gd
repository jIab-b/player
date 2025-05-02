extends Node3D

class_name GrapplingHook

# Exported variables for customization
@export var max_grapple_distance: float = 50.0
@export var grapple_speed: float = 50.0
@export var spring_stiffness: float = 10.0
@export var spring_damping: float = 1.0
@export var pull_strength: float = 5.0
@export var retract_speed: float = 10.0
@export var grapple_layer_mask: int = 1  # Physics layer to interact with

# Raycast for grapple detection and visualization
var raycast: RayCast3D
# Line renderer for the chain visualization
var chain_line: MeshInstance3D
# References
var player: Node3D  # Parent player node

# Grapple state
var is_grappling: bool = false
var grapple_point: Vector3 = Vector3.ZERO
var current_length: float = 0.0
var target_length: float = 0.0
var grapple_velocity: float = 0.0

func _ready():
    # Setup raycast
    raycast = RayCast3D.new()
    raycast.enabled = false
    raycast.collision_mask = grapple_layer_mask
    add_child(raycast)
    
    # Setup chain line
    chain_line = MeshInstance3D.new()
    var immediate_mesh = ImmediateMesh.new()
    chain_line.mesh = immediate_mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.7, 0.7, 0.7)
    material.metallic = 0.8
    material.roughness = 0.2
    chain_line.material_override = material
    add_child(chain_line)
    
    # Get player reference
    player = get_parent()
    
    # Hide chain initially
    chain_line.visible = false

func _process(delta):
    # Update chain visualization
    if is_grappling:
        draw_chain()

func _physics_process(delta):
    # Handle input
    if Input.is_action_just_pressed("grapple"):
        shoot_grapple()
    elif Input.is_action_just_released("grapple"):
        release_grapple()
    
    # Apply grapple physics if grappling
    if is_grappling:
        apply_spring_physics(delta)

func shoot_grapple():
    if is_grappling:
        return
    
    # Setup raycast direction from player's forward vector
    raycast.global_transform.origin = global_transform.origin
    raycast.target_position = Vector3(0, 0, -max_grapple_distance)  # Shooting forward
    raycast.enabled = true
    raycast.force_raycast_update()
    
    # Check if raycast hit something
    if raycast.is_colliding():
        is_grappling = true
        grapple_point = raycast.get_collision_point()
        current_length = global_transform.origin.distance_to(grapple_point)
        target_length = current_length
        chain_line.visible = true
        
        # Play sound or animation here
        # $GrappleSound.play()

func release_grapple():
    is_grappling = false
    raycast.enabled = false
    chain_line.visible = false
    
    # Play retract sound or animation here
    # $RetractSound.play()

func apply_spring_physics(delta):
    # Calculate current distance to grapple point
    var current_player_pos = global_transform.origin
    var current_distance = current_player_pos.distance_to(grapple_point)
    
    # Calculate spring force using Hooke's law with damping
    var displacement = current_distance - target_length
    var spring_force = spring_stiffness * displacement
    
    # Apply damping to the velocity
    grapple_velocity += spring_force * delta
    grapple_velocity -= grapple_velocity * spring_damping * delta
    
    # Calculate pull direction
    var pull_direction = (grapple_point - current_player_pos).normalized()
    
    # Apply force to the player (assuming player has a method or property to apply forces)
    if player is CharacterBody3D:
        player.velocity += pull_direction * grapple_velocity * pull_strength * delta
    
    # Optional: Allow manual control of grapple length
    #if Input.is_action_pressed("grapple_retract"):
        #target_length = max(target_length - retract_speed * delta, 1.0)  # Minimum length of 1 unit
    #elif Input.is_action_pressed("grapple_extend"):
        #target_length = min(target_length + retract_speed * delta, max_grapple_distance)

func draw_chain():
    # Draw the chain as a line from player to grapple point
    var immediate_mesh = chain_line.mesh as ImmediateMesh
    immediate_mesh.clear_surfaces()
    
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    immediate_mesh.surface_add_vertex(Vector3.ZERO)  # Local point (converted to global in shader)
    immediate_mesh.surface_add_vertex(to_local(grapple_point))  # Grapple point in local coordinates
    immediate_mesh.surface_end()
