class_name HorrorWorld
extends Node3D
## An original, procedural interpretation of the old town and waterfront.
## The playable route stays on y = 0 and follows the negative Z axis.

var landmark_positions := {
	"square": Vector3(0, 0, 0),
	"fuse": Vector3(-3, 1, -30),
	"gate": Vector3(0, 0, -61),
	"waterfront": Vector3(0, 0, -73),
	"casino": Vector3(0, 0, -91),
}
var _rng := RandomNumberGenerator.new()
var _stone: StandardMaterial3D
var _plaster: StandardMaterial3D
var _dark: StandardMaterial3D
var _iron: StandardMaterial3D
var _glass: StandardMaterial3D
var _warm: StandardMaterial3D
var _blood: StandardMaterial3D
var _plaster_texture: NoiseTexture2D


func get_spawn_position() -> Vector3:
	return Vector3(0, 1, 8)


func build() -> void:
	_rng.seed = 3170317
	_materials()
	_atmosphere()
	_ground()
	_square()
	_alley()
	_waterfront()
	_casino()
	_small_details()


func _materials() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1910
	noise.frequency = 0.024
	noise.fractal_octaves = 5
	var tint := Gradient.new()
	tint.set_color(0, Color(0.72, 0.71, 0.68))
	tint.set_color(1, Color(1.0, 0.99, 0.95))
	_plaster_texture = NoiseTexture2D.new()
	_plaster_texture.width = 256
	_plaster_texture.height = 256
	_plaster_texture.noise = noise
	_plaster_texture.color_ramp = tint
	_plaster_texture.seamless = true
	_stone = _mat(Color("747368"), 0.78)
	_plaster = _mat(Color("655f50"), 0.94)
	_weathered_plaster(_plaster)
	_dark = _mat(Color("171c20"), 0.95)
	_iron = _mat(Color("262a28"), 0.4, 0.65)
	_glass = _mat(Color("101b23"), 0.22, 0.25)
	_warm = _mat(Color("e0a24d"), 0.5)
	_warm.emission_enabled = true
	_warm.emission = Color("e8ac56")
	_warm.emission_energy_multiplier = 0.9
	_blood = _mat(Color("3b1010"), 0.35)


func _mat(color: Color, roughness: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	return material


func _weathered_plaster(material: StandardMaterial3D) -> void:
	material.albedo_texture = _plaster_texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.65


func _atmosphere() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("060d17")
	sky_material.sky_horizon_color = Color("29343a")
	sky_material.ground_bottom_color = Color("080d12")
	sky_material.ground_horizon_color = Color("29343a")
	sky_material.sky_curve = 0.25
	sky_material.sun_angle_max = 1.2
	sky_material.sun_curve = 0.15
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6f899c")
	env.ambient_light_energy = 0.43
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("24333e")
	env.fog_light_energy = 0.6
	env.fog_density = 0.009
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, -28, 0)
	moon.light_color = Color("93b0c9")
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90
	add_child(moon)
	# A visible moon hangs above the sea, rather than acting as a navigation marker.
	var moon_mat := _mat(Color("a2b2b8"))
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 6.0
	var moon_disc := MeshInstance3D.new()
	moon_disc.mesh = sphere
	moon_disc.material_override = moon_mat
	moon_disc.position = Vector3(92, 75, -175)
	add_child(moon_disc)


func _ground() -> void:
	var cobbles := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    vec2 p = UV * vec2(148.0, 472.0);
    p.x += mod(floor(p.y), 2.0) * 0.5;
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float mortar = smoothstep(0.025, 0.075, min(min(f.x, 1.0-f.x), min(f.y, 1.0-f.y)));
    float stone = 0.17 + hash(cell) * 0.12;
    float wet = smoothstep(0.6, 0.94, sin(UV.x * 83.0 + sin(UV.y * 71.0)) * 0.5 + 0.5);
    ALBEDO = mix(vec3(0.052, 0.061, 0.067), vec3(stone * 0.9, stone * 0.94, stone), mortar);
    ROUGHNESS = mix(0.74, 0.18, wet);
    METALLIC = 0.15;
}
"""
	cobbles.shader = shader
	_box(Vector3(0, -0.22, -43), Vector3(37, 0.44, 118), cobbles, true)
	# Alley curbs leave the route level and wide enough for first-person movement.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 3.8, 0.07, -40), Vector3(0.28, 0.14, 44), _stone)
		_box(Vector3(side * 17.8, 0.18, -1), Vector3(0.5, 0.36, 33), _stone, true)
	# Rear and side boundaries are dressed as buildings or seawalls.
	_box(Vector3(0, 2.5, 16.8), Vector3(38, 5, 1), _plaster, true)
	_box(Vector3(-19, 1.7, -72), Vector3(1, 3.4, 145), _dark, true)
	_box(Vector3(19, 1.7, -30), Vector3(1, 3.4, 72), _dark, true)


func _square() -> void:
	_building(Vector3(-19, 0, -1), Vector3(8, 14, 31), 1)
	_building(Vector3(19, 0, 0), Vector3(8, 17, 32), -1)
	_building(Vector3(-11, 0, -20), Vector3(14, 16, 8), 0)
	_building(Vector3(11, 0, -20), Vector3(14, 13, 8), 0)
	# Ovid: pedestal, draped robe, bowed head and manuscript; intentionally stylized.
	var bronze := _mat(Color("333e36"), 0.65, 0.7)
	_box(Vector3(-7, 0.18, -5), Vector3(4.5, 0.36, 4.5), _stone, true)
	_box(Vector3(-7, 0.48, -5), Vector3(3.5, 0.28, 3.5), _stone, true)
	_box(Vector3(-7, 1.65, -5), Vector3(2.1, 2.3, 2.1), _stone, true)
	_box(Vector3(-7, 2.92, -5), Vector3(2.8, 0.25, 2.8), _stone)
	_cylinder(Vector3(-7, 4.05, -5), 0.54, 0.34, 2.1, bronze)
	_sphere(Vector3(-7, 5.38, -5), Vector3(0.36, 0.45, 0.34), bronze)
	_beam(Vector3(-7.4, 4.8, -5), Vector3(-7.68, 4.1, -4.78), 0.15, bronze)
	_beam(Vector3(-6.6, 4.75, -5), Vector3(-6.3, 4.3, -4.65), 0.15, bronze)
	_box(Vector3(-6.4, 4.28, -4.55), Vector3(0.5, 0.08, 0.35), bronze)
	_label("O V I D I U S", Vector3(-7, 1.8, -3.93), 0.17, Color("b0aa91"))
	_label("PIAȚA OVIDIU", Vector3(0, 3.7, -15.9), 0.19, Color("c4baa0"))
	for p in [Vector3(-12, 0, 6), Vector3(11, 0, 1), Vector3(-12, 0, -11), Vector3(8, 0, -12)]:
		_lamp(p)
	_bench(Vector3(-11, 0, 3), 0)
	_bench(Vector3(11, 0, -7), PI)
	# Closed café awning and furniture, away from the walking route.
	_box(Vector3(13.2, 3.3, 7), Vector3(5.5, 0.18, 5), _mat(Color("394137")))
	for x in [11.0, 15.5]:
		_cylinder(Vector3(x, 1.6, 9), 0.045, 0.045, 3.2, _iron)
	for z in [5.5, 9.0]:
		_cylinder(Vector3(13.1, 0.85, z), 0.7, 0.7, 0.08, _dark)
		_cylinder(Vector3(13.1, 0.43, z), 0.07, 0.07, 0.8, _iron)
	# Small Romanian tricolor on a façade.
	_beam(Vector3(-15, 8, -7), Vector3(-13, 9.1, -7), 0.035, _iron)
	for i in 3:
		_box(Vector3(-13.7 + i * 0.34, 8.2, -7), Vector3(0.34, 1.25, 0.04), _mat([Color("233853"), Color("b7a046"), Color("743736")][i]))


func _building(origin: Vector3, size: Vector3, face: int) -> void:
	var plaster := _mat(Color.from_hsv(_rng.randf_range(0.09, 0.14), _rng.randf_range(0.1, 0.22), _rng.randf_range(0.25, 0.43)), 0.96)
	_weathered_plaster(plaster)
	_box(origin + Vector3(0, size.y * 0.5, 0), size, plaster, true)
	_box(origin + Vector3(0, size.y + 0.1, 0), Vector3(size.x + 0.4, 0.38, size.z + 0.4), _stone)
	_box(origin + Vector3(0, 0.5, 0), Vector3(size.x + 0.13, 1.0, size.z + 0.13), _stone)
	# face 0 faces the square (+Z); side façades face the road.
	var normal := Vector3(0, 0, 1) if face == 0 else Vector3(face, 0, 0)
	var axis := Vector3(1, 0, 0) if face == 0 else Vector3(0, 0, 1)
	var width: float = size.x if face == 0 else size.z
	var depth: float = size.z if face == 0 else size.x
	var front := origin + normal * (depth * 0.5 + 0.06)
	for floor_index in range(1, int(size.y / 3.1)):
		var y: float = floor_index * 3.0 + 1.3
		var count := int(width / 3.4)
		for i in count:
			var p := front + axis * ((i - (count - 1) * 0.5) * 3.1) + Vector3(0, y, 0)
			var window_size := Vector3(1.25, 1.8, 0.09) if face == 0 else Vector3(0.09, 1.8, 1.25)
			_box(p, window_size + Vector3(0.18, 0.22, 0.18), _stone)
			_box(p + normal * 0.11, window_size, _glass if _rng.randf() > 0.07 else _warm)
			_box(p + normal * 0.18, Vector3(0.05, 1.8, 0.05) if face == 0 else Vector3(0.05, 1.8, 0.05), _iron)
			var sill_size := Vector3(1.6, 0.16, 0.42) if face == 0 else Vector3(0.42, 0.16, 1.6)
			_box(p + Vector3(0, -0.98, 0), sill_size, _stone)
		var band_size := Vector3(size.x + 0.16, 0.17, size.z + 0.16)
		_box(origin + Vector3(0, y - 1.43, 0), band_size, _stone)
	# A battered ground-floor door, slightly recessed visually.
	var door := front + Vector3(0, 1.3, 0)
	_box(door, Vector3(1.7, 2.6, 0.15) if face == 0 else Vector3(0.15, 2.6, 1.7), _dark)
	for j in 3:
		var drain_pos := front + axis * (width * 0.38) + Vector3(0, size.y * 0.5, 0)
		_cylinder(drain_pos, 0.06, 0.06, size.y, _iron)
		break


func _alley() -> void:
	for side in [-1, 1]:
		for i in 4:
			var z: float = -25.0 - i * 9.0
			_building(Vector3(side * 9.5, 0, z), Vector3(11, 10 + _rng.randf() * 5, 9), -side)
			# Balconies and iron bars cast irregular shadows into the alley.
			_box(Vector3(side * 3.8, 5.4, z), Vector3(1.2, 0.2, 2.4), _stone)
			for dz in [-1.1, -0.55, 0.0, 0.55, 1.1]:
				_cylinder(Vector3(side * 3.2, 6.0, z + dz), 0.025, 0.025, 1.2, _iron)
			_box(Vector3(side * 3.2, 6.6, z), Vector3(0.08, 0.08, 2.5), _iron)
	for z in [-21.0, -39.0, -54.0]:
		_lamp(Vector3(3.2 if z != -39.0 else -3.2, 0, z), 4.6)
		# Sagging utility wire.
		var last := Vector3(-4, 9, z)
		for i in range(1, 9):
			var x := -4.0 + i
			var p := Vector3(x, 8.4 + 0.6 * pow(absf(x) / 4.0, 2.0), z + 0.15 * sin(i))
			_beam(last, p, 0.014, _iron)
			last = p
	# The waterfront boundary funnels every route through the parent's puzzle gate.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 11.25, 1.8, -61), Vector3(14.5, 3.6, 0.9), _stone, true)
		_box(Vector3(side * 4.35, 2.2, -61), Vector3(0.7, 4.4, 1.1), _stone, true)
		_box(Vector3(side * 4.35, 4.5, -61), Vector3(1, 0.2, 1.4), _stone)
	# Utility station: parent script places the actual collectible at this location.
	_box(Vector3(-3.55, 1.15, -30), Vector3(0.65, 1.65, 1.2), _mat(Color("3e514b")), true)
	_box(Vector3(-3.19, 1.15, -30), Vector3(0.06, 1.35, 0.98), _iron)
	_label("REȚEA • 03", Vector3(-3.12, 1.75, -30), 0.095, Color("d0b47c"), PI / 2)
	_label("PERICOL", Vector3(-3.12, 0.75, -30), 0.085, Color("9f5143"), PI / 2)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-2.9, 2.2, -30)
	glow.light_color = Color("dca964")
	glow.light_energy = 0.7
	glow.omni_range = 4
	add_child(glow)
	# A parked Dacia-like silhouette occupies a niche, never the route.
	var car := _mat(Color("4e2927"), 0.5, 0.45)
	_box(Vector3(2.6, 0.6, -45), Vector3(1.65, 0.7, 3.6), car, true)
	_box(Vector3(2.6, 1.15, -45.3), Vector3(1.5, 0.65, 1.9), car)
	_box(Vector3(2.6, 1.23, -44.32), Vector3(1.3, 0.43, 0.04), _glass)
	for x in [1.85, 3.35]:
		for z in [-46.1, -43.9]:
			_sphere(Vector3(x, 0.33, z), Vector3(0.18, 0.35, 0.35), _dark)
	_label("MAREA\nNU UITĂ", Vector3(-3.91, 2.1, -47), 0.3, Color("5c2421"), PI / 2)
	_label("SPRE FALEZĂ →", Vector3(0, 5.4, -57.4), 0.14, Color("b6ab8f"))


func _waterfront() -> void:
	# Solid seawall prevents walking into the water; sea remains clearly visible.
	_box(Vector3(15.7, 0.45, -83), Vector3(0.5, 0.9, 44), _stone, true)
	for z in range(-103, -60, 3):
		_box(Vector3(15.7, 0.83, z), Vector3(0.48, 1.65, 0.48), _stone)
	_box(Vector3(15.7, 1.45, -82), Vector3(0.14, 0.12, 42), _iron)
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
void vertex() {
    VERTEX.y += sin(VERTEX.x * 0.38 + TIME * 0.8) * 0.075;
    VERTEX.y += cos(VERTEX.z * 0.7 - TIME * 0.65) * 0.04;
}
void fragment() {
    float ripple = sin(UV.x * 790.0 + TIME * 1.2 + sin(UV.y * 710.0)) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.012, 0.027, 0.034), vec3(0.05, 0.09, 0.11), pow(ripple, 12.0));
    ROUGHNESS = 0.2;
    METALLIC = 0.55;
}
"""
	water.shader = shader
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(220, 280)
	sea_mesh.subdivide_width = 100
	sea_mesh.subdivide_depth = 100
	var sea := MeshInstance3D.new()
	sea.mesh = sea_mesh
	sea.material_override = water
	sea.position = Vector3(127, -1.1, -95)
	add_child(sea)
	for p in [Vector3(-7, 0, -68), Vector3(11, 0, -73), Vector3(11, 0, -88), Vector3(-12, 0, -88)]:
		_lamp(p)
	_bench(Vector3(12.8, 0, -79), -PI / 2)
	_bench(Vector3(12.8, 0, -91), -PI / 2)
	_label("FALEZA CAZINO", Vector3(-9, 2.1, -65), 0.15, Color("c1bba6"))
	_box(Vector3(-9, 2.1, -65.08), Vector3(3.5, 0.65, 0.12), _dark)
	for i in 6:
		_crane(Vector3(58 + i * 12, 0, -134 - i * 6), 16 + i % 3 * 3)
	# West side retaining wall and closed access gate keep the slice contained.
	_box(Vector3(-18, 1, -80), Vector3(0.8, 2, 31), _stone, true)
	for z in range(-94, -65, 2):
		_cylinder(Vector3(-18, 2.6, z), 0.035, 0.035, 2, _iron)


func _casino() -> void:
	var pale := _mat(Color("8e8a7c"), 0.87)
	_weathered_plaster(pale)
	var trim := _mat(Color("a6a08c"), 0.8)
	# Set behind the playable esplanade; columns and ornament evoke the landmark.
	_box(Vector3(0, 7.5, -105), Vector3(38, 15, 14), pale, true)
	_box(Vector3(0, 15.1, -105), Vector3(39, 0.5, 15), trim)
	_box(Vector3(0, 8.5, -97.85), Vector3(39, 0.35, 0.8), trim)
	_box(Vector3(0, 1, -97.55), Vector3(38.5, 1.7, 1), _stone, true)
	# Front doors stand at ground level so no stair controller is needed.
	_box(Vector3(0, 2.0, -97.0), Vector3(3.2, 4, 0.24), _dark)
	for x in [-0.8, 0.8]:
		_box(Vector3(x, 2.45, -96.83), Vector3(1.35, 2.6, 0.04), _glass)
		_box(Vector3(x, 1.3, -96.75), Vector3(0.08, 0.36, 0.08), _warm)
	_arch(Vector3(0, 0.2, -96.72), 2, 3.4, trim)
	_label("C A Z I N O U L", Vector3(0, 7.3, -97.32), 0.48, Color("d1c9ac"))
	_label("CONSTANȚA • 1910", Vector3(0, 6.25, -97.25), 0.13, Color("aca58f"))
	for x in [-15.5, -10.3, -5.1, 5.1, 10.3, 15.5]:
		_box(Vector3(x, 3.45, -97.1), Vector3(3.3, 4.8, 0.2), _glass)
		_arch(Vector3(x, 0.8, -96.82), 1.85, 4.0, trim)
		_box(Vector3(x, 3.4, -96.68), Vector3(0.13, 4.6, 0.09), _iron)
		_box(Vector3(x, 3.6, -96.65), Vector3(3.2, 0.1, 0.08), _iron)
		_box(Vector3(x, 10.7, -97.2), Vector3(2.7, 3.0, 0.18), _glass)
		_arch(Vector3(x, 9.1, -96.97), 1.5, 2.3, trim)
		_box(Vector3(x, 8.5, -96.5), Vector3(3.7, 0.25, 1.5), trim)
	for x in [-18.3, -13, -7.7, -2.6, 2.6, 7.7, 13, 18.3]:
		_cylinder(Vector3(x, 4.1, -96.8), 0.33, 0.26, 7, trim)
		_box(Vector3(x, 0.65, -96.8), Vector3(0.9, 0.5, 0.9), trim)
		_box(Vector3(x, 7.65, -96.8), Vector3(0.85, 0.4, 0.85), trim)
	# Central Art Nouveau crown and round window.
	_box(Vector3(0, 16.3, -103), Vector3(10, 2.8, 9), pale)
	_sphere(Vector3(0, 17.3, -102.5), Vector3(5.2, 2.8, 4.5), _stone)
	_cylinder(Vector3(0, 13, -97.45), 1.5, 1.5, 0.16, _glass, Vector3(PI / 2, 0, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.47
	ring.outer_radius = 1.68
	var ring_instance := MeshInstance3D.new()
	ring_instance.mesh = ring
	ring_instance.material_override = trim
	ring_instance.rotation.x = PI / 2
	ring_instance.position = Vector3(0, 13, -97.25)
	add_child(ring_instance)
	for x in [-17, 17]:
		_box(Vector3(x, 16.4, -104), Vector3(5, 3.2, 9), pale)
		_sphere(Vector3(x, 18.0, -104), Vector3(2.8, 2.2, 4.6), _stone)
	# Broad side steps are scenery; the central approach remains flat.
	for side in [-1.0, 1.0]:
		for i in 4:
			_box(Vector3(side * 10.5, 0.06 + i * 0.1, -95.7 - i * 0.5), Vector3(14, 0.12 + i * 0.2, 0.55), _stone)
	for x in [-5.5, 5.5]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 3, -94.7)
		light.light_color = Color("b6c0ba")
		light.light_energy = 1.4
		light.omni_range = 13
		add_child(light)


func _small_details() -> void:
	# Stones, leaf litter and dark puddles make the road feel inhabited without clutter.
	var dirt := _mat(Color("292a22"), 0.95)
	var paper := _mat(Color("858174"), 0.9)
	for i in 90:
		var z := _rng.randf_range(-89, 13)
		var alley := z < -18 and z > -59
		var x := _rng.randf_range(-3.5, 3.5) if alley else _rng.randf_range(-15, 14)
		var debris := _box(Vector3(x, 0.015, z), Vector3(_rng.randf_range(0.05, 0.3), 0.02, _rng.randf_range(0.08, 0.3)), paper if i % 7 == 0 else dirt)
		debris.rotation.y = _rng.randf() * TAU
	for z in [-34.0, -36.2, -37.0, -38.1]:
		var pool := _cylinder(Vector3(_rng.randf_range(-0.8, 0.8), 0.016, z), _rng.randf_range(0.25, 0.65), 0.5, 0.022, _blood)
		pool.scale.z = 1.7
	for p in [Vector3(3.4, 0, -24), Vector3(-3.3, 0, -51), Vector3(-13, 0, 9)]:
		_cylinder(p + Vector3(0, 0.5, 0), 0.32, 0.3, 1, _iron)
		_cylinder(p + Vector3(0, 1.03, 0), 0.36, 0.36, 0.08, _iron)


func _lamp(p: Vector3, height: float = 5.2) -> void:
	_cylinder(p + Vector3(0, height * 0.5, 0), 0.09, 0.06, height, _iron)
	_cylinder(p + Vector3(0, 0.3, 0), 0.2, 0.16, 0.6, _iron)
	_box(p + Vector3(0, height + 0.3, 0), Vector3(0.34, 0.5, 0.34), _warm)
	_box(p + Vector3(0, height + 0.59, 0), Vector3(0.57, 0.1, 0.57), _iron)
	_cylinder(p + Vector3(0, height + 0.73, 0), 0.23, 0.0, 0.28, _iron)
	var light := OmniLight3D.new()
	light.position = p + Vector3(0, height, 0)
	light.light_color = Color("ffc27a")
	light.light_energy = 2.1
	light.omni_range = 11
	light.omni_attenuation = 1.35
	light.shadow_enabled = true
	add_child(light)


func _bench(p: Vector3, yaw: float) -> void:
	var parent := Node3D.new()
	parent.position = p
	parent.rotation.y = yaw
	add_child(parent)
	var wood := _mat(Color("413a29"), 0.85)
	for z in [-0.22, 0.0, 0.22]:
		_box(Vector3(0, 0.57, z), Vector3(2.2, 0.09, 0.16), wood, false, parent)
	for y in [0.9, 1.13]:
		_box(Vector3(0, y, -0.35), Vector3(2.2, 0.18, 0.08), wood, false, parent)
	for x in [-0.8, 0.8]:
		_box(Vector3(x, 0.3, 0), Vector3(0.07, 0.6, 0.6), _iron, false, parent)


func _crane(p: Vector3, height: float) -> void:
	var material := _mat(Color("1c2429"), 0.9)
	_beam(p, p + Vector3(0, height, 0), 0.28, material)
	_beam(p + Vector3(0, height, 0), p + Vector3(-10, height + 5, 0), 0.25, material)
	_beam(p + Vector3(0, height, 0), p + Vector3(5, height - 1, 0), 0.18, material)
	_beam(p + Vector3(-10, height + 5, 0), p + Vector3(-10, height - 6, 0), 0.035, _iron)
	for y in range(0, int(height), 3):
		_beam(p + Vector3(-1.2, y, 0), p + Vector3(1.2, y + 3, 0), 0.07, material)
		_beam(p + Vector3(1.2, y, 0), p + Vector3(-1.2, y + 3, 0), 0.07, material)
	var red := _mat(Color("8d2c24"))
	red.emission_enabled = true
	red.emission = Color("b2251d")
	red.emission_energy_multiplier = 4
	_sphere(p + Vector3(0, height + 0.6, 0), Vector3.ONE * 0.19, red)


func _arch(p: Vector3, radius: float, shoulder: float, material: Material) -> void:
	for side in [-1.0, 1.0]:
		_box(p + Vector3(side * radius, shoulder * 0.5, 0), Vector3(0.24, shoulder, 0.34), material)
	for i in 12:
		var a: float = i * PI / 12.0
		var b: float = (i + 1) * PI / 12.0
		_beam(p + Vector3(cos(a) * radius, shoulder + sin(a) * radius, 0), p + Vector3(cos(b) * radius, shoulder + sin(b) * radius, 0), 0.15, material)


func _label(value: String, p: Vector3, font_size_m: float, color: Color, yaw: float = 0) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = 64
	label.pixel_size = font_size_m / 64.0
	label.modulate = color
	label.outline_modulate = Color(0.025, 0.03, 0.03)
	label.outline_size = 4
	label.no_depth_test = false
	label.position = p
	label.rotation.y = yaw
	add_child(label)
	return label


func _box(p: Vector3, size: Vector3, material: Material, solid: bool = false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _cylinder(p: Vector3, bottom: float, top: float, height: float, material: Material, rotation_vector: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	instance.rotation = rotation_vector
	add_child(instance)
	return instance


func _sphere(p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	instance.scale = size
	add_child(instance)
	return instance


func _beam(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var instance := _cylinder((a + b) * 0.5, radius, radius, a.distance_to(b), material)
	var direction := (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		instance.quaternion = Quaternion(Vector3.UP, direction)
