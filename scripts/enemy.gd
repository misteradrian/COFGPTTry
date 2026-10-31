class_name HorrorEnemy
extends CharacterBody3D

signal killed

var player: CharacterBody3D
var active: bool = false
var health: float = 100.0
var dead: bool = false
var _visual: Node3D
var _head: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _shape: CollisionShape3D
var _skin: StandardMaterial3D
var _attack_cooldown: float = 0.0
var _hurt_time: float = 0.0
var _time: float = 0.0
var _blood_pool: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.9
	_shape.shape = capsule
	add_child(_shape)
	floor_snap_length = 0.3
	_build_body()


func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	if dead:
		_visual.rotation.z = lerpf(_visual.rotation.z, 1.46, delta * 5.0)
		_visual.position.y = lerpf(_visual.position.y, -0.55, delta * 4.0)
		_blood_pool.visible = true
		return
	_skin.albedo_color = Color(0.65, 0.15, 0.12) if _hurt_time > 0.0 else Color(0.48, 0.46, 0.39)
	var walking := false
	var target_velocity := Vector3.ZERO
	if active and is_instance_valid(player) and not bool(player.get("dead")):
		var offset := player.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 22.0 and distance > 0.01:
			var direction := offset.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
			if distance > 1.32:
				target_velocity = direction * (1.85 if _hurt_time <= 0.0 else -0.65)
				walking = true
			elif _attack_cooldown <= 0.0:
				_try_attack()
	velocity.x = move_toward(velocity.x, target_velocity.x, delta * 8.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_animate_body(delta, walking)


func _try_attack() -> void:
	var from := global_position + Vector3(0.0, 0.25, 0.0)
	var to := player.global_position + Vector3(0.0, 0.2, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty() and result.collider != player:
		return
	_attack_cooldown = 1.2
	if player.has_method("take_damage"):
		player.call("take_damage", 18.0)


func take_damage(amount: float) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	_hurt_time = 0.24
	active = true
	if health <= 0.0:
		dead = true
		velocity = Vector3.ZERO
		_shape.set_deferred("disabled", true)
		killed.emit()


func reset_at(pos: Vector3) -> void:
	global_position = pos
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	health = 100.0
	dead = false
	active = false
	_attack_cooldown = 0.0
	_hurt_time = 0.0
	if is_instance_valid(_shape):
		_shape.set_deferred("disabled", false)
	if is_instance_valid(_visual):
		_visual.rotation = Vector3.ZERO
		_visual.position = Vector3.ZERO
		_blood_pool.visible = false


func _animate_body(delta: float, walking: bool) -> void:
	var stride := sin(_time * 7.0) * 0.52 if walking else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride, delta * 10.0)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride, delta * 10.0)
	_left_arm.rotation.x = -stride * 0.55 - (0.8 if _attack_cooldown > 0.85 else 0.0)
	_right_arm.rotation.x = stride * 0.55 - (1.0 if _attack_cooldown > 0.85 else 0.0)
	_head.rotation.z = 0.21 + sin(_time * 1.7) * 0.06
	_visual.position.y = sin(_time * (14.0 if walking else 2.0)) * (0.025 if walking else 0.008)


func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "Saltbound"
	add_child(_visual)
	_skin = _material(Color(0.48, 0.46, 0.39))
	var wound := _material(Color(0.22, 0.025, 0.022))
	var dark := _material(Color(0.025, 0.035, 0.028))
	var rust := _material(Color(0.27, 0.12, 0.045))
	var clothes := _material(Color(0.11, 0.16, 0.15))
	_bone(_visual, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.61, 0.05), 0.23, _skin)
	_bone(_visual, Vector3(0.0, -0.1, 0.02), Vector3(0.0, 0.22, 0.03), 0.22, clothes)
	# Exposed red seams across the chest are deliberately readable in torch light.
	for i in range(5):
		_bone(_visual, Vector3(-0.16, 0.23 + i * 0.06, -0.15), Vector3(0.12, 0.28 + i * 0.06, -0.15), 0.012, wound)
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.7, -0.07)
	_visual.add_child(_head)
	_sphere(_head, Vector3.ZERO, Vector3(0.19, 0.25, 0.17), _skin)
	_sphere(_head, Vector3(-0.065, 0.035, -0.145), Vector3(0.044, 0.032, 0.026), dark)
	_sphere(_head, Vector3(0.065, 0.025, -0.145), Vector3(0.044, 0.032, 0.026), dark)
	_sphere(_head, Vector3(0.0, -0.09, -0.155), Vector3(0.055, 0.075, 0.027), wound)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.27, 0.5, 0.0)
		_visual.add_child(arm)
		_bone(arm, Vector3.ZERO, Vector3(side * 0.08, -0.4, -0.04), 0.065, _skin)
		_bone(arm, Vector3(side * 0.08, -0.4, -0.04), Vector3(side * 0.12, -0.88, -0.12), 0.045, _skin)
		_sphere(arm, Vector3(side * 0.12, -0.9, -0.12), Vector3(0.07, 0.12, 0.045), wound)
		for finger in range(3):
			_bone(arm, Vector3(side * 0.12 + (finger - 1) * 0.025, -0.95, -0.12), Vector3(side * 0.12 + (finger - 1) * 0.03, -1.06, -0.16), 0.009, rust)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, -0.11, 0.02)
		_visual.add_child(leg)
		_bone(leg, Vector3.ZERO, Vector3(side * 0.02, -0.38, 0.06), 0.08, clothes)
		_bone(leg, Vector3(side * 0.02, -0.38, 0.06), Vector3(side * 0.04, -0.79, -0.01), 0.05, _skin)
		_sphere(leg, Vector3(side * 0.04, -0.81, -0.1), Vector3(0.075, 0.05, 0.14), dark)
		if side < 0:
			_left_arm = arm
			_left_leg = leg
		else:
			_right_arm = arm
			_right_leg = leg
	# Thin fishing wire encircles the body and hangs from the shoulders.
	for i in range(4):
		_bone(_visual, Vector3(-0.23, 0.18 + i * 0.1, -0.19), Vector3(0.23, 0.35 + i * 0.08, -0.19), 0.005, rust)
	_bone(_visual, Vector3(-0.26, 0.5, -0.05), Vector3(-0.4, -0.35, -0.19), 0.006, rust)
	_blood_pool = MeshInstance3D.new()
	var pool := CylinderMesh.new()
	pool.top_radius = 0.55
	pool.bottom_radius = 0.55
	pool.height = 0.006
	pool.radial_segments = 18
	_blood_pool.mesh = pool
	_blood_pool.material_override = wound
	_blood_pool.position = Vector3(0.3, -0.94, 0.0)
	_blood_pool.scale.z = 0.65
	_blood_pool.visible = false
	add_child(_blood_pool)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	return mat


func _bone(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 7
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	mesh_instance.position = (from + to) * 0.5
	var direction := (to - from).normalized()
	mesh_instance.quaternion = Quaternion(Vector3.UP, direction)


func _sphere(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.scale = size
	parent.add_child(mesh_instance)
