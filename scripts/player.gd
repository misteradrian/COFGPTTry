class_name HorrorPlayer
extends CharacterBody3D

signal health_changed(value: float)
signal died
signal attacked

const WALK_SPEED := 3.4
const SPRINT_SPEED := 5.5
const LOOK_SENSITIVITY := 0.0022
const ATTACK_INTERVAL := 0.68

var health: float = 100.0
var stamina: float = 100.0
var dead: bool = false
var controls_enabled: bool = false
var flashlight_on: bool = true
var camera: Camera3D
var flashlight: SpotLight3D
var _weapon: Node3D
var _attack_cooldown: float = 0.0
var _swing_time: float = 0.0
var _walk_time: float = 0.0
var _pitch: float = 0.0
var _exhausted: bool = false


func _ready() -> void:
	name = "Player"
	add_to_group("player")
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collider.shape = capsule
	add_child(collider)
	floor_snap_length = 0.3
	max_slides = 6
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.position.y = 0.63
	camera.fov = 77.0
	camera.near = 0.04
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0.16, -0.16, -0.18)
	flashlight.light_color = Color(0.87, 0.9, 0.79)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 32.0
	flashlight.spot_angle_attenuation = 1.3
	flashlight.spot_attenuation = 0.8
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	_build_weapon()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = _pitch
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	if event.is_action_pressed("attack"):
		attack()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_swing_time = maxf(0.0, _swing_time - delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	var input_vector := Vector2.ZERO
	if controls_enabled and not dead:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := input_vector.length_squared() > 0.01
	if stamina <= 1.0:
		_exhausted = true
	elif stamina > 25.0:
		_exhausted = false
	var sprinting := controls_enabled and moving and Input.is_action_pressed("sprint") and not _exhausted and not dead
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting:
		stamina = maxf(0.0, stamina - 23.0 * delta)
	else:
		stamina = minf(100.0, stamina + 18.0 * delta)
	var direction := global_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
	move_and_slide()
	if global_position.y < -10.0 and not dead:
		take_damage(100.0)
	_update_view(delta, moving, sprinting)


func _update_view(delta: float, moving: bool, sprinting: bool) -> void:
	if not is_instance_valid(camera):
		return
	if moving and controls_enabled and is_on_floor():
		_walk_time += delta * (12.0 if sprinting else 8.0)
		camera.position.y = lerpf(camera.position.y, 0.63 + sin(_walk_time) * 0.025, delta * 12.0)
	else:
		camera.position.y = lerpf(camera.position.y, 0.63, delta * 8.0)
	camera.fov = lerpf(camera.fov, 82.0 if sprinting else 77.0, delta * 5.0)
	var swing := sin((_swing_time / 0.36) * PI) if _swing_time > 0.0 else 0.0
	_weapon.position = Vector3(0.29 - swing * 0.38, -0.34 + swing * 0.1, -0.52 - swing * 0.12)
	_weapon.rotation = Vector3(-0.12 - swing * 0.65, -0.1 - swing * 1.7, -0.23 + swing * 0.35)


func attack() -> void:
	if dead or not controls_enabled or _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL
	_swing_time = 0.36
	attacked.emit()
	var best_target: Node3D = null
	var best_distance := 2.55
	var forward := -camera.global_basis.z
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D or not node.has_method("take_damage") or bool(node.get("dead")):
			continue
		var target := node as Node3D
		var offset := target.global_position + Vector3(0.0, 0.2, 0.0) - camera.global_position
		var distance := offset.length()
		if distance > best_distance or forward.dot(offset.normalized()) < 0.43:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position + Vector3(0.0, 0.2, 0.0))
		query.exclude = [get_rid()]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.collider != target:
			continue
		best_distance = distance
		best_target = target
	if best_target != null:
		best_target.call("take_damage", 35.0)


func take_damage(amount: float) -> void:
	if dead:
		return
	health = clampf(health - amount, 0.0, 100.0)
	health_changed.emit(health)
	if health <= 0.0:
		dead = true
		controls_enabled = false
		died.emit()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled and not dead


func reset_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = 100.0
	stamina = 100.0
	dead = false
	_exhausted = false
	_attack_cooldown = 0.0
	_swing_time = 0.0
	rotation = Vector3.ZERO
	_pitch = 0.0
	if is_instance_valid(camera):
		camera.rotation = Vector3.ZERO
		camera.position.y = 0.63
	flashlight_on = true
	if is_instance_valid(flashlight):
		flashlight.visible = true
	health_changed.emit(health)


func _build_weapon() -> void:
	_weapon = Node3D.new()
	_weapon.name = "Pipe"
	camera.add_child(_weapon)
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.28, 0.17, 0.1)
	rust.metallic = 0.7
	rust.roughness = 0.74
	var pipe := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.03
	cylinder.height = 0.85
	cylinder.radial_segments = 10
	pipe.mesh = cylinder
	pipe.material_override = rust
	pipe.position = Vector3(0.0, 0.2, -0.04)
	pipe.rotation.x = -0.3
	pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon.add_child(pipe)
	var joint := MeshInstance3D.new()
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = 0.042
	joint_mesh.height = 0.084
	joint_mesh.radial_segments = 8
	joint_mesh.rings = 4
	joint.mesh = joint_mesh
	joint.material_override = rust
	joint.position = Vector3(0.0, 0.61, -0.165)
	joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon.add_child(joint)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.37, 0.3, 0.25)
	skin.roughness = 0.95
	var hand := MeshInstance3D.new()
	var hand_mesh := CapsuleMesh.new()
	hand_mesh.radius = 0.055
	hand_mesh.height = 0.21
	hand_mesh.radial_segments = 8
	hand_mesh.rings = 4
	hand.mesh = hand_mesh
	hand.material_override = skin
	hand.rotation.z = PI / 2.0
	hand.position = Vector3(0.025, -0.035, 0.0)
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon.add_child(hand)
