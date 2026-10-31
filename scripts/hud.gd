class_name HorrorHUD
extends CanvasLayer

signal start_requested
signal restart_requested
signal resume_requested
signal quit_requested

const PAPER := Color("dfded4")
const MUTED := Color("9d9e98")
const RUST := Color("c38a57")

var root: Control
var game_layer: Control
var menu_layer: Control
var menu_content: Control
var objective_label: Label
var prompt_label: Label
var subtitle_label: Label
var health_label: Label
var stamina_bar: ProgressBar
var light_label: Label
var location_label: Label
var location_detail: Label
var location_panel: VBoxContainer
var damage_overlay: ColorRect
var subtitle_time := 0.0
var location_time := 0.0
var damage_time := 0.0
var serif: SystemFont
var sans: SystemFont


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["DejaVu Serif", "Liberation Serif", "serif"])
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["DejaVu Sans", "Liberation Sans", "sans-serif"])
	root = Control.new()
	root.name = "HorrorInterface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_game()
	_build_atmosphere()
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_shader := Shader.new()
	shade_shader.code = "shader_type canvas_item; void fragment() { float a = mix(0.96, 0.33, smoothstep(0.0, 1.0, UV.x)); COLOR = vec4(0.018, 0.024, 0.027, a); }"
	var shade_material := ShaderMaterial.new()
	shade_material.shader = shade_shader
	shade.material = shade_material
	menu_layer.add_child(shade)
	menu_content = Control.new()
	menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(menu_content)
	show_title()


func _build_game() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_layer)
	var top := VBoxContainer.new()
	top.position = Vector2(38, 32)
	top.custom_minimum_size = Vector2(410, 0)
	top.add_theme_constant_override("separation", 8)
	game_layer.add_child(top)
	top.add_child(_label("03:17   /   CONSTANȚA", 11, MUTED))
	var rule := ColorRect.new()
	rule.color = RUST
	rule.custom_minimum_size = Vector2(42, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(rule)
	objective_label = _label("Follow the voice.", 16, PAPER)
	objective_label.custom_minimum_size.x = 410
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(objective_label)
	var crosshair := Label.new()
	crosshair.text = "·"
	crosshair.add_theme_color_override("font_color", Color(0.9, 0.9, 0.82, 0.7))
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -8
	crosshair.offset_top = -16
	crosshair.offset_right = 8
	crosshair.offset_bottom = 16
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.add_child(crosshair)
	prompt_label = _label("", 15, PAPER)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -340
	prompt_label.offset_right = 340
	prompt_label.offset_top = 44
	prompt_label.offset_bottom = 86
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_layer.add_child(prompt_label)
	var vitals := HBoxContainer.new()
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 38
	vitals.offset_top = -64
	vitals.offset_right = 380
	vitals.offset_bottom = -26
	vitals.add_theme_constant_override("separation", 20)
	game_layer.add_child(vitals)
	var health_box := VBoxContainer.new()
	health_box.add_theme_constant_override("separation", 2)
	health_box.add_child(_label("VITALS", 10, MUTED))
	health_label = _label("100", 23, PAPER)
	health_box.add_child(health_label)
	vitals.add_child(health_box)
	var stamina_box := VBoxContainer.new()
	stamina_box.custom_minimum_size.x = 120
	stamina_box.add_theme_constant_override("separation", 10)
	stamina_box.add_child(_label("BREATH", 10, MUTED))
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(120, 3)
	stamina_bar.show_percentage = false
	stamina_bar.value = 100
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.55, 0.55, 0.51, 0.17)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Color("b0aba0")
	stamina_bar.add_theme_stylebox_override("background", bar_bg)
	stamina_bar.add_theme_stylebox_override("fill", bar_fg)
	stamina_box.add_child(stamina_bar)
	vitals.add_child(stamina_box)
	light_label = _label("F  /  LIGHT ON", 11, MUTED)
	light_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	light_label.offset_left = -240
	light_label.offset_right = -38
	light_label.offset_top = -48
	light_label.offset_bottom = -28
	light_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game_layer.add_child(light_label)
	subtitle_label = _label("", 19, PAPER)
	subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_label.offset_left = -410
	subtitle_label.offset_right = 410
	subtitle_label.offset_top = -142
	subtitle_label.offset_bottom = -74
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	subtitle_label.add_theme_constant_override("shadow_offset_x", 1)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
	game_layer.add_child(subtitle_label)
	location_panel = VBoxContainer.new()
	location_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	location_panel.offset_left = -280
	location_panel.offset_right = 280
	location_panel.offset_top = 80
	location_panel.offset_bottom = 150
	location_panel.add_theme_constant_override("separation", 6)
	game_layer.add_child(location_panel)
	location_label = _label("", 28, PAPER, true)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_panel.add_child(location_label)
	location_detail = _label("", 11, MUTED)
	location_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_panel.add_child(location_detail)
	location_panel.modulate.a = 0.0


func _build_atmosphere() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec2 p = UV * 2.0 - 1.0; float v = smoothstep(0.33, 1.5, length(p)); float n = fract(sin(dot(UV * vec2(1280.0,720.0) + floor(TIME * 12.0), vec2(12.9898,78.233))) * 43758.5453); COLOR = vec4(vec3(n * 0.035), v * 0.33 + n * 0.025); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	root.add_child(vignette)
	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.48, 0.025, 0.015, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)


func _label(value: String, font_size: int, color: Color = PAPER, use_serif: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", serif if use_serif else sans)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(270, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", sans)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_focus_color", Color("ffffff"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.16, 0.11, 0.35) if primary else Color(0, 0, 0, 0)
	normal.border_color = Color(0.7, 0.48, 0.3, 0.7) if primary else Color(0.7, 0.65, 0.58, 0.15)
	normal.set_border_width_all(1)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	button.add_theme_stylebox_override("normal", normal)
	var hovered := normal.duplicate() as StyleBoxFlat
	hovered.bg_color = Color(0.36, 0.24, 0.14, 0.78)
	hovered.border_color = RUST
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("focus", hovered)
	button.add_theme_stylebox_override("pressed", hovered)
	button.pressed.connect(callback)
	return button


func _clear_menu() -> void:
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	menu_layer.show()
	game_layer.hide()


func _menu_footer() -> void:
	var footer := _label("WASD  MOVE     SHIFT  SPRINT     F  FLASHLIGHT     E  INTERACT     LMB  STRIKE     ESC  PAUSE", 10, MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 74
	footer.offset_right = -40
	footer.offset_top = -42
	footer.offset_bottom = -22
	menu_content.add_child(footer)
	var edition := _label("A CONSTANȚA HORROR STORY   /   PLAYABLE PROTOTYPE", 10, MUTED)
	edition.position = Vector2(74, 38)
	menu_content.add_child(edition)


func show_title() -> void:
	_clear_menu()
	_menu_footer()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 74
	column.offset_right = 680
	column.offset_top = -264
	column.offset_bottom = 240
	column.add_theme_constant_override("separation", 8)
	menu_content.add_child(column)
	column.add_child(_label("CONSTANȚA   /   03:17", 12, RUST))
	var title := _label("MAREA", 86, PAPER, true)
	title.add_theme_constant_override("outline_size", 0)
	column.add_child(title)
	var title_second := _label("NU UITĂ", 62, PAPER, true)
	column.add_child(title_second)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	column.add_child(spacer)
	column.add_child(_label("THE SEA DOESN’T FORGET", 11, RUST))
	var premise := _label("A voice from the water. A city that remembers.\nFollow a dead caller through Constanța’s empty streets.", 16, MUTED)
	premise.add_theme_constant_override("line_spacing", 5)
	column.add_child(premise)
	var button_gap := Control.new()
	button_gap.custom_minimum_size.y = 16
	column.add_child(button_gap)
	var start := _button("INTRĂ ÎN ORAȘ   →", func() -> void: start_requested.emit(), true)
	column.add_child(start)
	column.add_child(_button("QUIT", func() -> void: quit_requested.emit()))
	var chapter := VBoxContainer.new()
	chapter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	chapter.offset_left = -286
	chapter.offset_right = -62
	chapter.offset_top = -162
	chapter.offset_bottom = -76
	chapter.add_theme_constant_override("separation", 8)
	menu_content.add_child(chapter)
	chapter.add_child(_label("01    /    THE CALL", 11, RUST))
	chapter.add_child(_label("Piața Ovidiu\nCentrul Vechi\nCazinoul", 17, PAPER, true))
	start.grab_focus()


func show_game() -> void:
	menu_layer.hide()
	game_layer.show()


func _simple_menu(kicker: String, title: String, body: String) -> VBoxContainer:
	_clear_menu()
	_menu_footer()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 90
	column.offset_right = 760
	column.offset_top = -150
	column.offset_bottom = 220
	column.add_theme_constant_override("separation", 18)
	menu_content.add_child(column)
	column.add_child(_label(kicker, 11, RUST))
	column.add_child(_label(title, 52, PAPER, true))
	var copy := _label(body, 17, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(copy)
	return column


func show_pause() -> void:
	var column := _simple_menu("03:17   /   THE WATER WAITS", "A moment of silence.", "Return when you are ready.")
	var resume := _button("RESUME   →", func() -> void: resume_requested.emit(), true)
	column.add_child(resume)
	column.add_child(_button("START AGAIN", func() -> void: restart_requested.emit()))
	column.add_child(_button("QUIT", func() -> void: quit_requested.emit()))
	resume.grab_focus()


func show_death() -> void:
	var column := _simple_menu("THE SEA TAKES ANOTHER", "You slipped beneath.", "The call is still waiting. Wake up in the square and try again.")
	var retry := _button("WAKE UP   →", func() -> void: restart_requested.emit(), true)
	column.add_child(retry)
	column.add_child(_button("QUIT", func() -> void: quit_requested.emit()))
	retry.grab_focus()


func show_ending() -> void:
	var column := _simple_menu("END OF CHAPTER 01", "It remembers you.", "The Casino door opens from the inside.\nSomewhere below the floor, your phone begins to ring.\n\nThank you for playing this first prototype.")
	var replay := _button("FOLLOW THE CALL AGAIN   →", func() -> void: restart_requested.emit(), true)
	column.add_child(replay)
	column.add_child(_button("QUIT", func() -> void: quit_requested.emit()))
	replay.grab_focus()


func set_stats(health: float, stamina: float, flashlight_on: bool) -> void:
	health_label.text = "%03d" % int(maxf(health, 0.0))
	health_label.add_theme_color_override("font_color", Color("bc5b43") if health < 35.0 else PAPER)
	stamina_bar.value = clampf(stamina, 0.0, 100.0)
	light_label.text = "F  /  LIGHT ON" if flashlight_on else "F  /  LIGHT OFF"


func set_objective(value: String) -> void:
	objective_label.text = value


func set_prompt(value: String) -> void:
	prompt_label.text = value
	prompt_label.visible = not value.is_empty()


func show_subtitle(value: String, duration: float = 5.0) -> void:
	subtitle_label.text = value
	subtitle_time = duration
	subtitle_label.modulate.a = 1.0


func show_location(title: String, detail: String = "Constanța") -> void:
	location_label.text = title
	location_detail.text = detail.to_upper()
	location_time = 5.0
	location_panel.modulate.a = 0.0


func flash_damage() -> void:
	damage_time = 0.5


func _process(delta: float) -> void:
	if subtitle_time > 0.0:
		subtitle_time = maxf(0.0, subtitle_time - delta)
		subtitle_label.modulate.a = minf(1.0, subtitle_time)
	if location_time > 0.0:
		location_time = maxf(0.0, location_time - delta)
		location_panel.modulate.a = minf(minf(1.0, (5.0 - location_time) * 1.5), location_time)
	if damage_time > 0.0:
		damage_time = maxf(0.0, damage_time - delta)
	damage_overlay.color.a = damage_time * 0.55
