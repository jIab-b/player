extends Node3D

# Load the enemy spawner script
var enemy_spawner_script = load("res://enemy_spawner.gd")

func _ready():
    # Create enemy spawner

    print('loaded main')
    var spawner = Node3D.new()
    spawner.set_name("EnemySpawner")
    spawner.set_script(enemy_spawner_script)
    
    # Add spawner to the scene
    add_child(spawner)
