extends Node3D
## The complete small, restartable vertical slice. No network or external assets.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WorldScript = preload("res://scripts/world.gd")
const HUDScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/ambience.gd")

var world: WorldScript
var player: PlayerScript
var enemy: EnemyScript
var hud: HUDScript
var ambience: AudioScript
var state := "title"
var stage := 0
var has_fuse := false
var gate_open := false
var shifted := false
var current_location := ""
var gate: StaticBody3D
var fuse: Node3D
var gate_indicator: MeshInstance3D
var title_camera: Camera3D
var target := ""
var elapsed := 0.0
var ring_timer := 0.0
var step_timer := 0.0
var gate_tween: Tween
var displaced_statue: Node3D
var original_statue: Array[Node3D] = []
var markers := {
	"phone": Vector3(0.0, 1.1, 3.0),
	"fuse": Vector3(-2.8, 1.25, -29.5),
	"gate": Vector3(-2.9, 1.3, -59.2),
	"door": Vector3(0.0, 1.6, -96.75),
}

func _ready() -> void:
	_setup_input()
	world = WorldScript.new()
	add_child(world)
	world.build()
	_create_props()
	_create_impossible_statue()
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.reset_at(world.get_spawn_position())
	player.died.connect(_on_death)
	player.health_changed.connect(func(_value):
		if _value < 100.0 and is_instance_valid(hud):
			hud.flash_damage()
			ambience.play_cue("hurt")
	)
	player.attacked.connect(func(): ambience.play_cue("hit"))
	enemy = EnemyScript.new()
	enemy.name = "TheDrowned"
	enemy.player = player
	add_child(enemy)
	enemy.reset_at(Vector3(1.2, 1.0, -43.0))
	enemy.killed.connect(func():
		ambience.set_tension(0.25)
		hud.show_subtitle("It smells of salt. The street is quiet again.", 4.0)
	)
	hud = HUDScript.new()
	add_child(hud)
	hud.start_requested.connect(start_game)
	hud.restart_requested.connect(start_game)
	hud.resume_requested.connect(resume_game)
	hud.quit_requested.connect(func(): get_tree().quit())
	ambience = AudioScript.new()
	add_child(ambience)
	ambience.start_ambience()
	title_camera = Camera3D.new()
	add_child(title_camera)
	title_camera.position = Vector3(9.0, 3.0, 12.0)
	title_camera.look_at(Vector3(-2.0, 2.0, -12.0))
	title_camera.current = true
	hud.show_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Local rendering verification, deliberately opt-in and never part of gameplay.
	if "--capture-title" in OS.get_cmdline_user_args():
		_capture_after_frames("/tmp/marea-title.png")
	if "--capture-game" in OS.get_cmdline_user_args():
		start_game()
		_capture_after_frames("/tmp/marea-game.png")

func _setup_input() -> void:
	var bindings := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
		"move_right": KEY_D, "sprint": KEY_SHIFT, "interact": KEY_E,
		"flashlight": KEY_F, "pause": KEY_ESCAPE,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)

func start_game() -> void:
	state = "playing"
	stage = 0
	has_fuse = false
	gate_open = false
	shifted = false
	_set_statue_shift(false)
	current_location = ""
	elapsed = 0.0
	ring_timer = 0.0
	step_timer = 0.0
	if gate_tween and gate_tween.is_valid():
		gate_tween.kill()
	gate.position = Vector3(0.0, 0.0, -61.0)
	gate.collision_layer = 1
	fuse.visible = true
	_set_indicator(Color(0.65, 0.13, 0.05))
	player.reset_at(world.get_spawn_position())
	player.camera.current = true
	player.set_physics_process(true)
	player.set_controls_enabled(true)
	enemy.reset_at(Vector3(1.2, 1.0, -43.0))
	enemy.active = false
	enemy.set_physics_process(true)
	ambience.set_tension(0.15)
	ambience.set_sea_silent(false)
	hud.show_game()
	hud.set_objective("Answer the ringing phone in the square.")
	hud.show_subtitle("03:17. The message said to come alone.", 6.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ambience.play_cue("start")

func pause_game() -> void:
	if state != "playing":
		return
	state = "paused"
	player.set_controls_enabled(false)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	if gate_tween and gate_tween.is_valid():
		gate_tween.pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()

func resume_game() -> void:
	if state != "paused":
		return
	state = "playing"
	player.set_controls_enabled(true)
	player.set_physics_process(true)
	enemy.set_physics_process(true)
	if gate_tween and gate_tween.is_valid():
		gate_tween.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == "playing":
			pause_game()
		elif state == "paused":
			resume_game()
		get_viewport().set_input_as_handled()
	elif state == "playing" and event.is_action_pressed("interact") and target != "":
		interact_with(target)

func _process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	hud.set_stats(player.health, player.stamina, player.flashlight_on)
	_update_target()
	_update_location()
	if stage == 0:
		ring_timer -= delta
		if ring_timer <= 0.0:
			ambience.play_cue("phone")
			ring_timer = 5.0
	if player.velocity.length() > 1.0 and player.is_on_floor():
		step_timer -= delta
		if step_timer <= 0.0:
			ambience.play_cue("step")
			step_timer = 0.38 if player.velocity.length() > 4.0 else 0.56
	if gate_open and player.position.z < -67.0 and not shifted:
		shifted = true
		_set_statue_shift(true)
		ambience.play_cue("ending")
		ambience.set_sea_silent(true)
		hud.show_subtitle("The sea has gone silent.\nThat statue… it was back in the square.", 8.0)
		ambience.set_tension(0.7)
	if player.position.y < -8.0:
		player.take_damage(1000.0)

func _update_target() -> void:
	target = ""
	var prompts := {
		"phone": "E  ·  Answer the phone",
		"fuse": "E  ·  Take the ceramic fuse",
		"gate": "E  ·  Insert fuse" if has_fuse else "E  ·  Examine the locked gate",
		"door": "E  ·  Open the Casino doors",
	}
	for id in ["phone", "fuse", "gate", "door"]:
		if (id == "phone" and stage > 0) or (id == "fuse" and (stage == 0 or has_fuse)):
			continue
		if (id == "gate" and gate_open) or (id == "door" and not gate_open):
			continue
		var point: Vector3 = markers[id]
		var direction := point - player.camera.global_position
		if direction.length() > 3.1:
			continue
		if (-player.camera.global_basis.z).dot(direction.normalized()) < 0.48:
			continue
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, point)
		ray.exclude = [player.get_rid()]
		var obstacle := get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstacle.is_empty() and obstacle.position.distance_to(point) > 0.5:
			continue
		target = id
		break
	hud.set_prompt(prompts[target] if target != "" else "")

func interact_with(id: String) -> void:
	# The same state machine is used by real interactions and the integration test.
	if state != "playing":
		return
	match id:
		"phone":
			if stage != 0:
				return
			stage = 1
			hud.set_objective("Find a fuse in the Old Town maintenance box.")
			hud.show_subtitle("A familiar voice: ‘The promenade gate has no power.\nFind the fuse. Meet me where the music drowned.’", 9.0)
			ambience.play_cue("pickup")
		"fuse":
			if stage != 1 or has_fuse:
				return
			has_fuse = true
			stage = 2
			fuse.visible = false
			enemy.active = true
			hud.set_objective("Restore power at the promenade gate. Keep moving.")
			hud.show_subtitle("Something drags itself out of the dark.\nLeft click: swing the pipe. Shift: run.", 7.0)
			ambience.play_cue("pickup")
			ambience.set_tension(0.9)
		"gate":
			if gate_open:
				return
			if not has_fuse:
				hud.show_subtitle("A fuse is missing. The maintenance box is back in the Old Town.", 5.0)
				return
			gate_open = true
			stage = 3
			gate.collision_layer = 0
			gate_tween = create_tween()
			gate_tween.tween_property(gate, "position:y", 4.5, 2.8).set_trans(Tween.TRANS_SINE)
			_set_indicator(Color(0.17, 0.65, 0.4))
			ambience.play_cue("gate")
			hud.set_objective("Follow the sea wall. Reach the Casino doors.")
			hud.show_subtitle("The gate wakes. Beyond it, every window is watching.", 6.0)
		"door":
			if not gate_open:
				return
			state = "ending"
			stage = 4
			player.set_controls_enabled(false)
			enemy.active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ambience.play_cue("ending")
			hud.show_ending()

func _on_death() -> void:
	if state != "playing":
		return
	state = "dead"
	player.set_controls_enabled(false)
	enemy.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_death()

func _update_location() -> void:
	var next := "PIAȚA OVIDIU"
	if player.position.z < -66.0:
		next = "CAZINOUL" if player.position.z < -85.0 else "FALEZA"
	elif player.position.z < -18.0:
		next = "CENTRUL VECHI"
	if next != current_location:
		current_location = next
		hud.show_location(next, "Constanța · 03:17")

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	mat.metallic = metallic
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func _label(parent: Node3D, text: String, pos: Vector3, size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.009
	label.modulate = Color(0.84, 0.77, 0.58)
	label.no_depth_test = false
	parent.add_child(label)
	label.position = pos
	return label

func _create_props() -> void:
	var iron := _material(Color(0.075, 0.085, 0.08), 0.65)
	var rust := _material(Color(0.25, 0.10, 0.055), 0.45)
	var stone := _material(Color(0.29, 0.28, 0.23))
	# Ringing public telephone on a low pedestal.
	_box(self, Vector3(0, 0.5, 3), Vector3(0.5, 1.0, 0.5), stone)
	_box(self, Vector3(0, 1.08, 3), Vector3(0.44, 0.13, 0.28), iron)
	_box(self, Vector3(0, 1.19, 3), Vector3(0.48, 0.09, 0.10), rust)
	_label(self, "TELEFON", Vector3(0, 0.78, 3.26), 20)
	var phone_light := OmniLight3D.new()
	phone_light.light_color = Color(1.0, 0.6, 0.25)
	phone_light.light_energy = 0.6
	phone_light.omni_range = 4.0
	add_child(phone_light)
	phone_light.position = Vector3(0, 1.7, 3)
	# Ceramic fuse and readable physical clue.
	fuse = Node3D.new()
	add_child(fuse)
	fuse.position = markers.fuse
	_box(fuse, Vector3.ZERO, Vector3(0.32, 0.13, 0.12), _material(Color(0.85, 0.78, 0.58)))
	_box(fuse, Vector3(-0.15, 0, 0), Vector3(0.045, 0.15, 0.15), rust)
	_box(fuse, Vector3(0.15, 0, 0), Vector3(0.045, 0.15, 0.15), rust)
	_label(self, "SIGURANȚE / FALEZĂ", Vector3(-2.8, 1.85, -29.4), 20)
	# Portcullis blocks the entire eight-meter-wide alley.
	gate = StaticBody3D.new()
	add_child(gate)
	gate.position = Vector3(0, 0, -61)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9, 4.5, 0.3)
	collision.shape = shape
	collision.position.y = 2.25
	gate.add_child(collision)
	for i in range(19):
		_box(gate, Vector3(-4.5 + i * 0.5, 2.1, 0), Vector3(0.045, 4.2, 0.055), iron)
	_box(gate, Vector3(0, 1.0, 0), Vector3(9, 0.07, 0.08), rust)
	_box(gate, Vector3(0, 3.9, 0), Vector3(9, 0.1, 0.1), rust)
	_box(self, Vector3(-2.9, 1.0, -59.3), Vector3(0.65, 1.4, 0.4), iron)
	gate_indicator = _box(self, Vector3(-2.9, 1.4, -59.06), Vector3(0.24, 0.12, 0.035), iron)
	_label(self, "ACCES FALEZĂ\nLIPSĂ SIGURANȚĂ", Vector3(-2.9, 1.8, -59.04), 18)
	_label(self, "MAREA\nNU UITĂ", Vector3(3.8, 2.1, -94.8), 55)

func _set_indicator(color: Color) -> void:
	var mat := _material(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	gate_indicator.material_override = mat

func _create_impossible_statue() -> void:
	displaced_statue = Node3D.new()
	displaced_statue.name = "DisplacedOvid"
	add_child(displaced_statue)
	# Reuse the actual Ovid landmark, making its reappearance recognizable.
	for child in world.get_children():
		if child is Node3D and absf(child.position.x + 7.0) < 2.4 and absf(child.position.z + 5.0) < 2.4 and child.position.y > 0.0:
			original_statue.append(child)
			var copy := child.duplicate() as Node3D
			displaced_statue.add_child(copy)
			copy.position += Vector3(7.0, 0.0, -75.0)
	displaced_statue.visible = false
	_set_statue_shift(false)

func _set_statue_shift(enabled: bool) -> void:
	displaced_statue.visible = enabled
	for part in original_statue:
		part.visible = not enabled
		for body in part.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 0 if enabled else 1
	for body in displaced_statue.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 1 if enabled else 0

func _capture_after_frames(path: String) -> void:
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
