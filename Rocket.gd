extends RigidBody3D
#class_name Rocket
# Rocket properties
var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var explosion_force: float = 10.0
var explosion_radius: float = 5.0
var explosion_damage: float = 50.0
var rocket_mesh: Mesh
var contacts_reported


func initialize(spd: float, expl_force: float, expl_radius: float, expl_dmg: float, dir: Vector3):

    speed = spd
    explosion_force = expl_force
    explosion_radius = expl_radius
    explosion_damage = expl_dmg
    direction = dir

# Called when the node enters the scene tree
func _ready():
    # Set up collision detection
    contact_monitor = true
    contacts_reported = 1
    

    # Connect the body_entered signal to detect collisions
    connect("body_entered", _on_body_entered)

# Physics process for rocket movement
func _physics_process(delta):
    # Move the rocket in the set direction

    global_position += direction * speed * delta

# Called when the rocket collides with something
func _on_body_entered(_body):
    # Explode on impact
    explode()

# Handle the explosion
func explode():
    # Find all physics bodies in explosion radius
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsShapeQueryParameters3D.new()
    query.transform = global_transform
    query.collision_mask = 0xFFFFFFFF  # All layers
    
    var sphere_shape = SphereShape3D.new()
    sphere_shape.radius = explosion_radius
    query.set_shape(sphere_shape)
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var body = result.collider
        if body is RigidBody3D and body != self:
            # Calculate distance from explosion
            var distance = global_transform.origin.distance_to(body.global_transform.origin)
            
            if distance <= explosion_radius:
                # Calculate force based on distance (closer = stronger force)
                var force_multiplier = 1.0 - (distance / explosion_radius)
                var force_direction = (body.global_transform.origin - global_transform.origin).normalized()
                var force = force_direction * explosion_force * force_multiplier
                
                # Apply explosion force
                body.apply_central_impulse(force)
                
                # Apply damage if the body has a health system
                if body.has_method("take_damage"):
                    var damage = explosion_damage * force_multiplier
                    body.take_damage(damage)
    
    queue_free()
