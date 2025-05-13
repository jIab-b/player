extends CharacterBody3D

# Movement parameters
@export var speed: float = 5.0
@export var acceleration: float = 10.0
@export var dist_limit: float = 2.0  # How close the enemy gets to player
@export var rotation_speed: float = 5.0  # How fast the enemy rotates to face player

# Gravity parameters
@export var gravity_enabled: bool = true
@export var gravity_value: float = 9.8

# Optional parameters for fine-tuning
@export var path_recalculation_interval: float = 0.2  # How often to update path
@export var is_active: bool = true  # Can be used to pause/resume enemy

# Health and damage parameters
@export var max_health: float = 500.0
var current_health: float = max_health

# Navigation
var _path_finding_timer: float = 0.0
var _target_position: Vector3

func _ready() -> void:
    # Set initial target
    #_update_target_position()
    pass
    
func apply_movement():
    pass
func _physics_process(delta: float) -> void:
    if not is_active:
        return
    
    # Apply gravity if enabled
    if gravity_enabled and not is_on_floor():
        velocity.y -= gravity_value * delta
    
    # Update target periodically
    _path_finding_timer -= delta
    if _path_finding_timer <= 0:
        _update_target_position()
        _path_finding_timer = path_recalculation_interval
    
    # Calculate direction to player
    var player_pos = Global.player_pos
    var direction = global_position.direction_to(player_pos)
    var distance_to_player = global_position.distance_to(player_pos)
    
    # Handle movement
    if distance_to_player > dist_limit and is_on_floor():
        # Create horizontal direction (ignore y component for movement)
        var horizontal_direction = Vector3(direction.x, 0, direction.z).normalized()
        
        # Smoothly accelerate toward target direction
        var target_velocity = horizontal_direction * speed
        velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
        velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
        
        # Rotate to face direction of movement
        if horizontal_direction != Vector3.ZERO:
            var look_direction = horizontal_direction
            var current_rotation = global_transform.basis.get_euler().y
            var target_rotation = atan2(look_direction.x, look_direction.z)
            var rotation_change = rotation_speed * delta
            
            # Smoothly rotate toward target direction
            var angle_diff = fposmod(target_rotation - current_rotation + PI, TAU) - PI
            if abs(angle_diff) < rotation_change:
                global_rotation.y = target_rotation
            else:
                global_rotation.y += sign(angle_diff) * rotation_change
    else:
        # Stop if within distance limit
        velocity.x = move_toward(velocity.x, 0, acceleration * delta)
        velocity.z = move_toward(velocity.z, 0, acceleration * delta)
    
    if global_position.distance_to(Global.player_pos) > 100:
        queue_free()
    # Apply movement
    move_and_slide()

func _update_target_position() -> void:
    _target_position = Global.player_pos
    
# Handle damage and health
func take_damage(amount: float) -> void:
    current_health -= amount
    print("Enemy took ", amount, " damage. Health: ", current_health)
    
    if current_health <= 0:
        die()

func die() -> void:
    # Handle enemy death
    print("Enemy died")
    queue_free()

func set_active(active: bool) -> void:
    is_active = active
