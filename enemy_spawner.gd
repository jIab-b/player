extends Node3D

# Enemy scene to spawn
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 5.0  # Time between spawns in seconds
@export var spawn_distance: float = 34.0  # Distance from origin to spawn enemies
@export var vertical_offset: float = 1.0  # Vertical offset from origin

# Timer for spawning
var spawn_timer: float = 0.0

func _ready() -> void:

    # Initialize with the enemy scene if not set in the editor
    if enemy_scene == null:
        enemy_scene = load("res://enemy.tscn")

func _process(delta: float) -> void:
    # Update timer
    spawn_timer += delta
    
    # Check if it's time to spawn a new enemy
    if spawn_timer >= spawn_interval:
        spawn_timer = 0.0  # Reset timer
        spawn_enemy()

func spawn_enemy() -> void:

    # Create instance of enemy scene
    var enemy_instance = enemy_scene.instantiate()
    
    # Generate a random distance between 0 and spawn_distance
    var random_distance = randf() * spawn_distance
    
    # Randomly choose whether to spawn up or down (along Z axis)
    var direction = 1 if randf() > 0.5 else -1
    
    # Add enemy to the current scene first
    add_child(enemy_instance)
    
    # Set spawn position
    # X = 0 (origin), Y = vertical_offset, Z = random_distance * direction
    enemy_instance.global_position = Vector3(0, vertical_offset, random_distance * direction)
    
    print("Spawned enemy at position: ", enemy_instance.global_position)
