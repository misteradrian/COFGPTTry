extends SceneTree
## Integration tests against the actual playable scene, physics and state machine.

var failures := 0
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	if scene == null:
		push_error("Could not load main scene")
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	await frames(4)
	check(game.state == "title", "scene boots to title screen")
	check(game.hud.menu_layer.visible, "title interface visible")
	game.hud.start_requested.emit()
	await frames(10)
	check(game.state == "playing" and game.player.controls_enabled, "start button begins gameplay")
	check(game.player.is_on_floor(), "spawn rests on world collision")
	check(game.player.camera.current, "first-person camera active")
	# The phone must be reachable through real movement and targeting.
	Input.action_press("move_forward")
	await frames(42)
	Input.action_release("move_forward")
	await frames(5)
	check(game.player.position.z < 6.0, "WASD moves the physical player through the square")
	game.player.camera.look_at(game.markers.phone)
	game._update_target()
	check(game.target == "phone", "phone can be targeted from the approach")
	game.interact_with("phone")
	check(game.stage == 1, "answering phone advances objective")
	game.interact_with("gate")
	check(not game.gate_open, "gate cannot open without fuse")
	game.interact_with("door")
	check(game.state == "playing", "Casino cannot finish before gate puzzle")
	game.player.position = Vector3(-0.5, 1.0, -28.5)
	game.player.camera.look_at(game.markers.fuse)
	await frames(2)
	game._update_target()
	check(game.target == "fuse", "fuse can be targeted beside maintenance box")
	game.interact_with("fuse")
	check(game.has_fuse and game.enemy.active and not game.fuse.visible, "fuse pickup wakes enemy and updates inventory")
	game.player.position = Vector3(-1.0, 1.0, -57.8)
	game.player.camera.look_at(game.markers.gate)
	await frames(2)
	game._update_target()
	check(game.target == "gate", "gate power panel can be targeted without crossing barrier")
	game.interact_with("gate")
	check(game.gate_open and game.gate.collision_layer == 0, "fuse unlocks physical promenade gate")
	game.pause_game()
	var gate_height: float = game.gate.position.y
	await frames(8)
	check(game.gate.position.y == gate_height, "pause freezes gate animation")
	game.resume_game()
	# Gate must physically block before opening, and permit travel after.
	game.start_game()
	game.player.reset_at(Vector3(0, 1.0, -58.0))
	game.player.set_controls_enabled(true)
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	check(game.player.position.z > -61.0, "closed gate blocks player physics")
	game.interact_with("phone")
	game.interact_with("fuse")
	game.enemy.active = false
	game.interact_with("gate")
	Input.action_press("move_forward")
	await frames(75)
	Input.action_release("move_forward")
	check(game.player.position.z < -62.0, "unlocked gate allows player through")
	# Melee uses the real attack cone, ray query, and cooldown.
	game.player.reset_at(Vector3(0, 1.0, -40))
	game.player.set_controls_enabled(true)
	game.enemy.reset_at(Vector3(0, 1.0, -42))
	await frames(3)
	game.player.attack()
	check(game.enemy.health == 65.0, "pipe strike damages enemy within range")
	game.player.attack()
	check(game.enemy.health == 65.0, "melee cooldown prevents repeated immediate hits")
	game.enemy.take_damage(100.0)
	await frames(2)
	check(game.enemy.dead, "enemy can die and leave corpse")
	game.enemy.reset_at(Vector3(0, 1.0, -41.0))
	game.enemy.active = true
	await frames(8)
	check(game.player.health < 100.0, "nearby active enemy attacks player through real physics")
	game.enemy.active = false
	# Restart, pause, flashlight, death and ending are all reversible.
	game.pause_game()
	var paused_position: Vector3 = game.player.position
	Input.action_press("move_forward")
	await frames(5)
	Input.action_release("move_forward")
	check(game.state == "paused" and game.player.position == paused_position, "pause freezes gameplay physics")
	game.resume_game()
	check(game.state == "playing" and game.player.controls_enabled, "resume restores controls")
	var key := InputEventAction.new()
	key.action = "flashlight"
	key.pressed = true
	game.player._unhandled_input(key)
	check(not game.player.flashlight_on and not game.player.flashlight.visible, "flashlight toggles off")
	game.player.take_damage(1000)
	check(game.state == "dead" and not game.player.controls_enabled, "lethal damage opens death menu")
	game.hud.restart_requested.emit()
	check(game.state == "playing" and game.player.health == 100 and game.player.flashlight_on, "restart restores health and flashlight")
	check(not game.gate_open and not game.has_fuse and not game.enemy.dead and game.fuse.visible, "restart restores puzzle and enemy")
	game.interact_with("phone")
	game.interact_with("fuse")
	game.interact_with("gate")
	game.player.position = Vector3(0, 1, -70)
	await frames(2)
	check(game.shifted and game.displaced_statue.visible and not game.original_statue[0].visible, "promenade crossing physically relocates Ovid statue")
	game.player.position = Vector3(0, 1, -94.3)
	game.player.camera.look_at(game.markers.door)
	await frames(2)
	game._update_target()
	check(game.target == "door", "Casino endpoint is physically reachable and targetable")
	game.interact_with("door")
	check(game.state == "ending" and game.stage == 4 and not game.player.controls_enabled, "Casino interaction completes playable slice")
	print("SMOKE: %d checks, %d failures" % [checks, failures])
	game.ambience.stop_all()
	await frames(10)
	game.queue_free()
	await frames(5)
	quit(0 if failures == 0 else 1)
