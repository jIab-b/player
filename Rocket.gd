extends Node3D
#class_name Rocket

# Rocket properties
var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var explosion_force: float = 10.0
var explosion_radius: float = 5.0
var explosion_damage: float = 50.0
var rocket_mesh: Mesh
@onready var rocket_area = $Area3D

func initialize(spd: float, expl_force: float, expl_radius: float, expl_dmg: float, dir: Vector3):
    speed = spd
    explosion_force = expl_force
    explosion_radius = expl_radius
    explosion_damage = expl_dmg
    direction = dir

# Called when the node enters the scene tree
func _ready():

    rocket_area.connect("body_entered", _on_body_entered)

# Physics process for rocket movement
func _physics_process(delta):
    # Move the rocket in the set direction
    global_position += direction * speed * delta
    
    # Optional: Orient the rocket in its movement direction
    look_at(global_position + direction, Vector3.UP)

    if global_position.distance_to(Global.player_pos) > 10:
        queue_free()
# Called when the rocket collides with something
func _on_body_entered(body):

    # Ignore collision with the shooter if needed
    # if body == shooter: return
    
    # Explode on impact
    explode()

# Handle the explosion
func explode():
    # Create explosion effect (optional)
    # var explosion_effect = preload("res://explosion_effect.tscn").instantiate()
    # explosion_effect.global_position = global_position
    # get_tree().current_scene.add_child(explosion_effect)
    print('exploding')
    # Find all bodies in explosion radius
    var bodies = get_bodies_in_radius(explosion_radius)
    
    for body in bodies:
        if body is RigidBody3D or CharacterBody3D:
            print(body)
            # Calculate distance from explosion
            var distance = global_position.distance_to(body.global_position)
            
            if distance <= explosion_radius:
                # Calculate force based on distance (closer = stronger force)
                var force_multiplier = 1.0 - (distance / explosion_radius)
                var force_direction = (body.global_position - global_position).normalized()
                var force = force_direction * explosion_force * force_multiplier
                
                # Apply explosion force
                #body.apply_central_impulse(force)
                if body.has_method('apply_movement'):
                    body.velocity += force
                
                # Apply damage if the body has a health system
                if body.has_method("take_damage"):
                    var damage = explosion_damage * force_multiplier
                    body.take_damage(damage)
    
    # Destroy the rocket
    queue_free()

# Helper function to find bodies in radius
func get_bodies_in_radius(radius: float) -> Array:
    var bodies = []
    var space_state = get_world_3d().direct_space_state
    
    # Setup query parameters
    var query = PhysicsShapeQueryParameters3D.new()
    var shape = SphereShape3D.new()
    shape.radius = radius
    
    query.set_shape(shape)
    query.transform = Transform3D(Basis(), global_position)
    query.collision_mask = 0xFFFFFFFF  # All collision layers
    
    # Perform the query
    var results = space_state.intersect_shape(query)
    
    # Extract the bodies from results
    for result in results:
        if result.collider != self and result.collider not in bodies:
            bodies.append(result.collider)
    
    return bodies
