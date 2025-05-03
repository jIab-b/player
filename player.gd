extends CharacterBody3D

# Movement constants
const GRAVITY: float = 20.0
const FRICTION: float = 0.4
const STOP_SPEED: float = 150.0
const GROUND_ACCELERATE: float = 30.0
const AIR_ACCELERATE: float = 100.0
const MAX_VELOCITY_GROUND: float = 6.0  # Maximum ground speed
const MAX_VELOCITY_AIR: float = 1.0     # Air control amount
const JUMP_FORCE: float = 9.0

#var ground_normal: Vector3 = Vector3.UP
var jump_buffer = 0
var buffer_val = 0.2

# Look variables
var mouse_sensitivity := 0.1
var yaw := 0.0
var pitch := 0.0
var pitch_min := -89.0
var pitch_max := 89.0

# Camera switch
var is_first_person := true

# References
@onready var weapon = $weapon
@onready var pivot: Node3D = $CameraPivot
@onready var camera_fp: Camera3D = $CameraPivot/CameraFirst
@onready var camera_tp: Camera3D = $CameraPivot/CameraThird

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    set_camera_mode(true)

func set_camera_mode(first_person: bool):
    is_first_person = first_person
    camera_fp.current = is_first_person
    camera_tp.current = not is_first_person

func _input(event):
    if event is InputEventMouseMotion:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
        rotation.y = deg_to_rad(yaw)
        pivot.rotation.x = deg_to_rad(pitch)
    elif event.is_action_pressed("camera_switch"):
        print('switching camera')
        set_camera_mode(!is_first_person)

func apply_weapon_offset():
    var forward_direction = global_position
    if is_first_person:
        forward_direction = camera_fp.transform.basis.z
    else:
        forward_direction = camera_tp.transform.basis.z
        
    forward_direction.y = 0
    forward_direction = forward_direction.normalized()
    var offset_pos = forward_direction
    offset_pos.y = weapon.position.y
    weapon.position = -offset_pos
    

func _physics_process(delta: float) -> void:
    
    var wish_dir = Vector3.ZERO
    wish_dir = process_input()

    apply_weapon_offset()

    velocity = apply_movement(delta, wish_dir)

    move_and_slide()
    if jump_buffer > 0:
        jump_buffer -= delta

func process_input():
    # Calculate movement direction based on input
    var input_dir = Vector3.ZERO
    input_dir.x = Input.get_axis("move_left", "move_right")
    input_dir.z = Input.get_axis("move_forward", "move_back")
    
    # Transform input direction to be relative to camera orientation (only yaw)
    var camera_basis
    if is_first_person:
        camera_basis = camera_fp.global_transform.basis
    if !is_first_person:
        camera_basis = camera_tp.global_transform.basis

    var camera_z = Vector3(camera_basis.z.x, 0, camera_basis.z.z).normalized()
    var camera_x = Vector3(camera_basis.x.x, 0, camera_basis.x.z).normalized()
    
    var wish_dir = (camera_x * input_dir.x + camera_z * input_dir.z).normalized()
    return wish_dir

func apply_movement(delta, wish_dir):
    # Check if we're on the ground
    var on_ground: bool = is_on_floor()
    
    # Apply gravity
    if !on_ground:
        velocity.y -= GRAVITY * delta
    
    # Handle jumping
    if (Input.is_action_pressed("jump")):
        jump_buffer = buffer_val
    if on_ground and jump_buffer > 0:
        velocity.y += JUMP_FORCE
        on_ground = false
    
    
    # Get 2D velocity (horizontal movement)
    var current_speed = Vector3(velocity.x, 0, velocity.z)
    
    # Ground movement
    if on_ground:
        # Apply friction
        current_speed = apply_friction(delta, current_speed)
        
        # Accelerate
        current_speed = accelerate(
            wish_dir, 
            MAX_VELOCITY_GROUND, 
            GROUND_ACCELERATE, 
            delta, 
            current_speed
        )
    # Air movement
    else:
        # Air control - strafing/air acceleration
        current_speed = accelerate(
            wish_dir, 
            MAX_VELOCITY_AIR, 
            AIR_ACCELERATE, 
            delta, 
            current_speed
        )
    
    # Assign back the 2D movement velocity, keeping our Y velocity
    velocity.x = current_speed.x
    velocity.z = current_speed.z
    return velocity

func apply_friction(delta: float, current_speed: Vector3):
    var speed = current_speed.length()
    
    # Don't apply friction if too slow to avoid jittering
    if speed < 0.1:
        return current_speed
    
    # Calculate friction
    var drop = 0.0
    var control = max(STOP_SPEED, speed)
    drop = control * FRICTION * delta
    
    # Scale the velocity
    var new_speed = max(0, speed - drop) / speed
    current_speed.x *= new_speed
    current_speed.z *= new_speed
    return current_speed

func accelerate(wish_dir: Vector3, max_speed: float, accel: float, delta: float, current_speed: Vector3):

    var current_speed_proj = current_speed.dot(wish_dir)
    

    var add_speed = max_speed - current_speed_proj

    if add_speed <= 0:
        return current_speed

    var accel_speed = min(accel * delta * max_speed, add_speed)
    

    current_speed.x += accel_speed * wish_dir.x
    current_speed.z += accel_speed * wish_dir.z
    return current_speed

# Optional helper function to get slope normal when sliding on surfaces
func get_ground_normal() -> Vector3:
    if get_slide_collision_count() > 0:
        var collision = get_slide_collision(0)
        if collision and collision.get_normal() != Vector3.ZERO:
            return collision.get_normal()
    return Vector3.UP
