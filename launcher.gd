extends Node
class_name RocketLauncher

# Preload the rocket scene
var rocket_scene : PackedScene

var rocket_speed: float = 2.0
var explosion_force: float = 10.0
var explosion_radius: float = 5.0
var explosion_damage: float = 50.0

var camera_dir: Vector3

func _ready():
    # Make sure the rocket scene is assigned
    rocket_scene = load("res://rocket.tscn")
    if rocket_scene == null:
        push_error("Rocket scene not assigned to RocketLauncher!")

func shoot_rocket():
    # Return early if the rocket scene isn't assigned
    if rocket_scene == null:
        return
        
    # Instance the rocket from the packed scene
    var rocket_instance = rocket_scene.instantiate()
    
    # Add the rocket to the root
    get_tree().root.add_child(rocket_instance)
    
    # Initialize the rocket with parameters
    # Assuming the Rocket scene has an initialize method
    rocket_instance.initialize(
        rocket_speed,
        explosion_force,
        explosion_radius,
        explosion_damage,
        camera_dir.normalized()
    )
    
    # Set the rocket's position
    rocket_instance.global_position = get_parent().global_position
    
func _physics_process(_delta):
    # Update camera direction
    camera_dir = get_parent().get_parent().camera_dir_global

    # Check for shoot input
    if Input.is_action_just_pressed("shoot"):
        shoot_rocket()
