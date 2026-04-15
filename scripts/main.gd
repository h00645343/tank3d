extends Node3D

const ARENA_LIMIT := 16.0
const PLAYER_COLOR := Color(0.12, 0.58, 0.24)
const ENEMY_COLOR := Color(0.72, 0.16, 0.13)
const METAL_COLOR := Color(0.16, 0.18, 0.20)
const GROUND_COLOR := Color(0.27, 0.42, 0.31)
const WALL_COLOR := Color(0.52, 0.55, 0.58)
const SHELL_COLOR := Color(1.0, 0.72, 0.12)
const ENEMY_HUNT_RANGE := 80.0
const ENEMY_ATTACK_RANGE := 17.0
const ENEMY_MIN_RANGE := 6.0
const ENEMY_PREFERRED_RANGE := 11.0
const ENEMY_MOVE_SPEED := 5.8
const ENEMY_TURN_SPEED := 130.0
const ENEMY_MEMORY_TIME := 8.0
const ENEMY_REACTION_TIME := 0.28
const ENEMY_LOW_HEALTH_RATIO := 0.32
const ENEMY_COVER_SCAN_RADIUS := 6.0
const ENEMY_SUPPRESSIVE_MEMORY := 2.2
const ENEMY_AIM_READY_DOT := 0.86
const ELITE_OPENING_PRESSURE_DURATION := 3.0
const ELITE_OPENING_SHOTS := 3
const MUSIC_MIX_RATE := 22050
const MUSIC_TEMPO := 108.0
const SAVE_PATH := "user://tank3d_save.json"
const FORCE_ELITE_MODE := false
const AI_HUNT := "hunt"
const AI_FLANK := "flank"
const AI_PRESSURE := "pressure"
const AI_RETREAT := "retreat"
const AI_EVADE := "evade"

@export var use_orthographic := false
@export var orthographic_size := 15.0
@export var music_volume_db := -18.0

class TankHealth:
	extends Node

	signal health_changed(current: float, maximum: float)
	signal died

	var max_health := 100.0
	var current_health := 100.0
	var damage_multiplier := 1.0
	var dead := false

	func setup(maximum: float) -> void:
		max_health = maximum
		current_health = maximum
		dead = false
		health_changed.emit(current_health, max_health)

	func take_damage(amount: float) -> void:
		if dead or amount <= 0.0:
			return
		current_health = max(0.0, current_health - amount * max(0.0, damage_multiplier))
		health_changed.emit(current_health, max_health)
		if current_health <= 0.0:
			dead = true
			died.emit()

	func percent() -> float:
		if max_health <= 0.0:
			return 0.0
		return clamp(current_health / max_health, 0.0, 1.0)

class Projectile:
	extends Area3D

	var owner_tank: Node3D
	var damage := 25.0
	var speed := 24.0
	var life_time := 4.0
	var age := 0.0
	var visual_radius := 0.16
	var visual_color := SHELL_COLOR
	var visual_energy := 0.0

	func _ready() -> void:
		add_to_group("projectiles")

		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = visual_radius
		sphere.height = visual_radius * 2.0
		mesh.mesh = sphere
		mesh.material_override = _make_material(visual_color, visual_energy)
		add_child(mesh)

		var shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = visual_radius
		shape.shape = sphere_shape
		add_child(shape)

		if visual_energy > 0.0:
			var light := OmniLight3D.new()
			light.light_color = visual_color
			light.light_energy = 0.7 + visual_energy * 0.35
			light.omni_range = 2.2
			add_child(light)

		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		age += delta
		if age >= life_time:
			queue_free()
			return
		global_position += -global_transform.basis.z * speed * delta

	func init(projectile_owner: Node3D, final_damage: float, final_speed: float, from_enemy: bool = false) -> void:
		owner_tank = projectile_owner
		damage = final_damage
		speed = final_speed
		if from_enemy:
			visual_radius = 0.22
			visual_color = Color(1.0, 0.35, 0.18)
			visual_energy = 1.8
		else:
			visual_radius = 0.16
			visual_color = SHELL_COLOR
			visual_energy = 0.6

	func travel_direction() -> Vector3:
		return -global_transform.basis.z.normalized()

	func _on_body_entered(body: Node) -> void:
		if body == owner_tank:
			return
		var health := body.get_node_or_null("Health") as TankHealth
		if health != null:
			health.take_damage(damage)
		queue_free()

	static func _make_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		if emission > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission
		return material

var player: CharacterBody3D
var player_health: TankHealth
var enemies: Array[CharacterBody3D] = []
var patrol_points: Dictionary = {}
var patrol_indices: Dictionary = {}
var enemy_next_fire: Dictionary = {}
var enemy_strafe_direction: Dictionary = {}
var enemy_rethink_until: Dictionary = {}
var enemy_attack_anchor: Dictionary = {}
var enemy_last_known_player_position: Dictionary = {}
var enemy_burst_remaining: Dictionary = {}
var enemy_opening_shots_remaining: Dictionary = {}
var enemy_state: Dictionary = {}
var enemy_state_until: Dictionary = {}
var enemy_visible_player: Dictionary = {}
var enemy_reaction_ready_at: Dictionary = {}
var enemy_memory_until: Dictionary = {}
var enemy_last_seen_at: Dictionary = {}
var enemy_aim_noise: Dictionary = {}
var enemy_aim_noise_until: Dictionary = {}
var enemy_cover_anchor: Dictionary = {}
var enemy_was_hit_until: Dictionary = {}
var enemy_role: Dictionary = {}
var opening_pressure_until := 0.0
var game_over := false

var camera: Camera3D
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var music_sample_index := 0
var player_previous_position := Vector3.ZERO
var player_velocity_estimate := Vector3.ZERO
var ui_layer: CanvasLayer
var hud_panel: Control
var begin_panel: Control
var settings_panel: Control
var rank_panel: Control
var victory_panel: Control
var defeat_panel: Control
var status_label: Label
var objective_label: Label
var health_bar: ProgressBar
var score_label: Label
var time_label: Label
var speed_label: Label
var shield_label: Label
var power_label: Label

var game_started := false
var player_next_fire := 0.0
var speed_multiplier := 1.0
var damage_multiplier := 1.0
var shield_multiplier := 1.0
var speed_active_until := 0.0
var shield_active_until := 0.0
var power_active_until := 0.0
var speed_cooldown_until := 0.0
var shield_cooldown_until := 0.0
var power_cooldown_until := 0.0
var score := 0
var elapsed_time := 0.0
var music_enabled := true
var sound_enabled := true
var stored_music_volume := 0.75
var stored_sound_volume := 0.75
var enemy_attack_level := 0
var enemy_damage_multiplier := 1.0
var enemy_fire_rate_multiplier := 1.0
var enemy_aggression_multiplier := 1.0
var ranks: Array = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.11, 0.13))
	_create_lighting()
	_create_map()
	player = _create_tank("Player Tank", Vector3(0.0, 0.6, -8.0), true)
	player_previous_position = player.global_position
	player_health = player.get_node("Health") as TankHealth
	player_health.died.connect(_on_player_died)
	_create_enemies()
	_create_camera()
	_load_game_data()
	_enforce_elite_mode()
	_create_ui()
	_create_background_music()
	_apply_audio_settings()
	_update_objective()
	_update_status("Destroy all enemy tanks")
	_show_panel(begin_panel)

func _process(delta: float) -> void:
	_fill_music_buffer()
	if not game_started:
		return

	if game_over:
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE):
			get_tree().reload_current_scene()
		return

	_update_skill_timers()
	_update_player_velocity(delta)
	elapsed_time += delta
	_aim_player_turret()
	_update_camera(delta)
	_update_ui()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire(player, 25.0 * damage_multiplier, 26.0, 0.45, true)
	if Input.is_key_pressed(KEY_Q):
		_activate_speed()
	if Input.is_key_pressed(KEY_E):
		_activate_shield()
	if Input.is_key_pressed(KEY_R):
		_activate_power()

func _physics_process(delta: float) -> void:
	if game_over or not game_started:
		_fill_music_buffer()
		return
	_move_player(delta)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy):
			_update_enemy(enemy, delta)

func _create_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(sun)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.52)
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)

func _create_map() -> void:
	_create_static_box("Arena Floor", Vector3(0.0, -0.15, 0.0), Vector3(34.0, 0.3, 34.0), GROUND_COLOR)
	_create_static_box("North Wall", Vector3(0.0, 1.25, 17.0), Vector3(36.0, 2.5, 1.0), WALL_COLOR)
	_create_static_box("South Wall", Vector3(0.0, 1.25, -17.0), Vector3(36.0, 2.5, 1.0), WALL_COLOR)
	_create_static_box("East Wall", Vector3(17.0, 1.25, 0.0), Vector3(1.0, 2.5, 36.0), WALL_COLOR)
	_create_static_box("West Wall", Vector3(-17.0, 1.25, 0.0), Vector3(1.0, 2.5, 36.0), WALL_COLOR)
	_create_static_box("Center Block A", Vector3(-5.0, 0.8, 1.0), Vector3(3.0, 1.6, 5.0), WALL_COLOR)
	_create_static_box("Center Block B", Vector3(6.0, 0.8, -2.0), Vector3(4.0, 1.6, 3.0), WALL_COLOR)
	_create_static_box("Cover North", Vector3(0.0, 0.8, 9.0), Vector3(7.0, 1.6, 1.2), WALL_COLOR)
	_create_static_box("Cover South", Vector3(0.0, 0.8, -12.0), Vector3(7.0, 1.6, 1.2), WALL_COLOR)
	_create_static_box("Side Cover Left", Vector3(-11.0, 0.8, -4.0), Vector3(1.2, 1.6, 6.0), WALL_COLOR)
	_create_static_box("Side Cover Right", Vector3(12.0, 0.8, 5.0), Vector3(1.2, 1.6, 6.0), WALL_COLOR)

func _create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	_add_box_visual(body, size, color, Vector3.ZERO)
	_add_box_collision(body, size, Vector3.ZERO)

func _create_tank(tank_name: String, position: Vector3, is_player: bool) -> CharacterBody3D:
	var tank := CharacterBody3D.new()
	tank.name = tank_name
	tank.position = position
	if not is_player:
		tank.rotation_degrees.y = 180.0
	add_child(tank)

	_add_box_collision(tank, Vector3(1.9, 0.9, 2.55), Vector3(0.0, 0.0, 0.0))
	_add_box_visual(tank, Vector3(1.8, 0.7, 2.3), PLAYER_COLOR if is_player else ENEMY_COLOR, Vector3.ZERO)
	_add_box_visual(tank, Vector3(0.35, 0.5, 2.55), METAL_COLOR, Vector3(-1.05, -0.05, 0.0))
	_add_box_visual(tank, Vector3(0.35, 0.5, 2.55), METAL_COLOR, Vector3(1.05, -0.05, 0.0))

	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 0.55, 0.0)
	tank.add_child(turret)
	_add_box_visual(turret, Vector3(1.1, 0.45, 1.05), PLAYER_COLOR if is_player else ENEMY_COLOR, Vector3.ZERO)
	_add_box_visual(turret, Vector3(0.25, 0.25, 1.55), METAL_COLOR, Vector3(0.0, 0.0, -0.95))

	var fire_point := Marker3D.new()
	fire_point.name = "FirePoint"
	fire_point.position = Vector3(0.0, 0.0, -1.85)
	turret.add_child(fire_point)

	var health := TankHealth.new()
	health.name = "Health"
	tank.add_child(health)
	health.setup(130.0 if is_player else 85.0)

	_create_world_health_bar(tank, health, is_player)
	return tank

func _create_world_health_bar(tank: Node3D, health: TankHealth, is_player: bool) -> void:
	var mount := Node3D.new()
	mount.name = "WorldHealthBar"
	mount.position = Vector3(0.0, 1.65, 0.0)
	tank.add_child(mount)

	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(1.45, 0.08, 0.05)
	back.mesh = back_mesh
	back.material_override = _make_material(Color(0.06, 0.06, 0.06))
	mount.add_child(back)

	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(1.35, 0.09, 0.06)
	fill.mesh = fill_mesh
	fill.position.x = 0.0
	fill.material_override = _make_material(Color(0.2, 0.9, 0.25) if is_player else Color(0.95, 0.34, 0.2))
	mount.add_child(fill)
	health.health_changed.connect(func(_current: float, _maximum: float) -> void:
		var percent := health.percent()
		fill.scale.x = percent
		fill.position.x = -0.675 * (1.0 - percent)
	)

func _create_enemies() -> void:
	var spawn_points := [
		Vector3(-11.0, 0.6, 10.0),
		Vector3(11.0, 0.6, 10.0),
		Vector3(-12.0, 0.6, -8.0),
		Vector3(12.0, 0.6, -10.0),
	]
	for i in range(spawn_points.size()):
		var enemy := _create_tank("Enemy Tank %d" % (i + 1), spawn_points[i], false)
		enemies.append(enemy)
		patrol_points[enemy] = _make_patrol_points(spawn_points[i], i)
		patrol_indices[enemy] = 0
		enemy_next_fire[enemy] = 0.0
		enemy_strafe_direction[enemy] = -1.0 if i % 2 == 0 else 1.0
		enemy_rethink_until[enemy] = 0.0
		enemy_attack_anchor[enemy] = spawn_points[i]
		enemy_last_known_player_position[enemy] = player.global_position
		enemy_burst_remaining[enemy] = 0
		enemy_opening_shots_remaining[enemy] = ELITE_OPENING_SHOTS
		enemy_state[enemy] = AI_HUNT
		enemy_state_until[enemy] = 0.0
		enemy_visible_player[enemy] = false
		enemy_reaction_ready_at[enemy] = 0.0
		enemy_memory_until[enemy] = 0.0
		enemy_last_seen_at[enemy] = -999.0
		enemy_aim_noise[enemy] = Vector3.ZERO
		enemy_aim_noise_until[enemy] = 0.0
		enemy_cover_anchor[enemy] = spawn_points[i]
		enemy_was_hit_until[enemy] = 0.0
		enemy_role[enemy] = i % 3
		var health := enemy.get_node("Health") as TankHealth
		health.died.connect(_on_enemy_died.bind(enemy))
		health.health_changed.connect(func(_current: float, _maximum: float) -> void:
			_on_enemy_health_changed(enemy)
		)

func _make_patrol_points(center: Vector3, index: int) -> Array[Vector3]:
	var offset := 3.5 + index
	return [
		center + Vector3(-offset, 0.0, 0.0),
		center + Vector3(0.0, 0.0, offset),
		center + Vector3(offset, 0.0, 0.0),
		center + Vector3(0.0, 0.0, -offset),
	]

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Main Camera"
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 150.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if use_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	camera.size = orthographic_size
	add_child(camera)
	_update_camera(1.0)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	hud_panel = Control.new()
	hud_panel.name = "Game HUD"
	hud_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_panel.visible = false
	ui_layer.add_child(hud_panel)

	status_label = _make_label("Destroy all enemy tanks", HORIZONTAL_ALIGNMENT_CENTER, 22)
	status_label.anchor_left = 0.0
	status_label.anchor_right = 1.0
	status_label.offset_top = 18.0
	status_label.offset_bottom = 58.0
	hud_panel.add_child(status_label)

	objective_label = _make_label("Enemies: 0", HORIZONTAL_ALIGNMENT_RIGHT, 20)
	objective_label.anchor_left = 1.0
	objective_label.anchor_right = 1.0
	objective_label.offset_left = -260.0
	objective_label.offset_top = 18.0
	objective_label.offset_right = -24.0
	objective_label.offset_bottom = 58.0
	hud_panel.add_child(objective_label)

	score_label = _make_label("Score: 0", HORIZONTAL_ALIGNMENT_LEFT, 18)
	score_label.offset_left = 24.0
	score_label.offset_top = 58.0
	score_label.offset_right = 260.0
	score_label.offset_bottom = 88.0
	hud_panel.add_child(score_label)

	time_label = _make_label("Time: 00:00", HORIZONTAL_ALIGNMENT_LEFT, 18)
	time_label.offset_left = 24.0
	time_label.offset_top = 88.0
	time_label.offset_right = 260.0
	time_label.offset_bottom = 118.0
	hud_panel.add_child(time_label)

	var hint := _make_label("WASD move | Mouse aim/fire | Q speed | E shield | R power", HORIZONTAL_ALIGNMENT_CENTER, 16)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -42.0
	hint.offset_bottom = -12.0
	hud_panel.add_child(hint)

	health_bar = ProgressBar.new()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.offset_left = 24.0
	health_bar.offset_top = 24.0
	health_bar.offset_right = 340.0
	health_bar.offset_bottom = 50.0
	hud_panel.add_child(health_bar)

	speed_label = _make_skill_label("Q Speed\nReady", 24.0)
	shield_label = _make_skill_label("E Shield\nReady", 142.0)
	power_label = _make_skill_label("R Power\nReady", 260.0)
	hud_panel.add_child(speed_label)
	hud_panel.add_child(shield_label)
	hud_panel.add_child(power_label)

	begin_panel = _create_begin_panel()
	settings_panel = _create_settings_panel()
	rank_panel = _create_rank_panel()
	victory_panel = _create_result_panel(true)
	defeat_panel = _create_result_panel(false)
	ui_layer.add_child(begin_panel)
	ui_layer.add_child(settings_panel)
	ui_layer.add_child(rank_panel)
	ui_layer.add_child(victory_panel)
	ui_layer.add_child(defeat_panel)

func _make_label(text: String, alignment: HorizontalAlignment, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _make_skill_label(text: String, left: float) -> Label:
	var label := _make_label(text, HORIZONTAL_ALIGNMENT_CENTER, 15)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = left
	label.offset_top = -96.0
	label.offset_right = left + 100.0
	label.offset_bottom = -42.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	return label

func _create_panel(title: String) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(430, 360)
	panel.offset_left = -215
	panel.offset_top = -180
	panel.offset_right = 215
	panel.offset_bottom = 180

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title_label := _make_label(title, HORIZONTAL_ALIGNMENT_CENTER, 28)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(title_label)
	return panel

func _panel_box(panel: Control) -> VBoxContainer:
	return panel.get_node("MarginContainer/Content") as VBoxContainer

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	return button

func _make_slider(minimum: float, maximum: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = clamp(value, minimum, maximum)
	return slider

func _resize_panel(panel: Control, size: Vector2) -> void:
	panel.custom_minimum_size = size
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5

func _apply_enemy_attack_preset(level: int) -> void:
	match clamp(level, 0, 2):
		0:
			enemy_damage_multiplier = 1.0
			enemy_fire_rate_multiplier = 0.78
			enemy_aggression_multiplier = 1.0
		1:
			enemy_damage_multiplier = 1.2
			enemy_fire_rate_multiplier = 1.25
			enemy_aggression_multiplier = 1.25
		2:
			enemy_damage_multiplier = 1.55
			enemy_fire_rate_multiplier = 2.1
			enemy_aggression_multiplier = 1.65

func _enforce_elite_mode() -> void:
	if not FORCE_ELITE_MODE:
		return
	enemy_attack_level = 2
	_apply_enemy_attack_preset(2)
	_save_game_data()

func _create_begin_panel() -> Control:
	var panel := _create_panel("Tank3D")
	var box := _panel_box(panel)
	var start := _make_button("Start Game")
	var settings := _make_button("Settings")
	var rank := _make_button("Ranking")
	var quit := _make_button("Quit")
	box.add_child(start)
	box.add_child(settings)
	box.add_child(rank)
	box.add_child(quit)
	start.pressed.connect(_start_game)
	settings.pressed.connect(func() -> void: _show_panel(settings_panel))
	rank.pressed.connect(func() -> void:
		_refresh_rank_panel()
		_show_panel(rank_panel)
	)
	quit.pressed.connect(get_tree().quit)
	return panel

func _create_settings_panel() -> Control:
	var panel := _create_panel("Settings")
	_resize_panel(panel, Vector2(520, 520))
	var box := _panel_box(panel)

	var audio_title := _make_label("Audio", HORIZONTAL_ALIGNMENT_LEFT, 18)
	audio_title.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(audio_title)

	var music_toggle := CheckBox.new()
	music_toggle.text = "Background Music"
	music_toggle.button_pressed = music_enabled
	box.add_child(music_toggle)

	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = stored_music_volume
	box.add_child(music_slider)

	var sound_toggle := CheckBox.new()
	sound_toggle.text = "Sound Effects"
	sound_toggle.button_pressed = sound_enabled
	box.add_child(sound_toggle)

	var sound_slider := HSlider.new()
	sound_slider.min_value = 0.0
	sound_slider.max_value = 1.0
	sound_slider.step = 0.01
	sound_slider.value = stored_sound_volume
	box.add_child(sound_slider)

	var combat_title := _make_label("Enemy Attack", HORIZONTAL_ALIGNMENT_LEFT, 18)
	combat_title.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(combat_title)

	var attack_preset := OptionButton.new()
	attack_preset.add_item("Normal", 0)
	attack_preset.add_item("Aggressive", 1)
	attack_preset.add_item("Elite", 2)
	attack_preset.select(clamp(enemy_attack_level, 0, 2))
	box.add_child(attack_preset)

	var fire_rate_label := _make_label("Fire Frequency Coefficient x%.2f (Elite highest)" % enemy_fire_rate_multiplier, HORIZONTAL_ALIGNMENT_LEFT, 15)
	fire_rate_label.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(fire_rate_label)

	var difficulty_label := _make_label("", HORIZONTAL_ALIGNMENT_LEFT, 15)
	difficulty_label.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(difficulty_label)
	_update_attack_difficulty_text(difficulty_label)

	var back := _make_button("Back")
	box.add_child(back)

	music_toggle.toggled.connect(func(value: bool) -> void:
		music_enabled = value
		_save_game_data()
		_apply_audio_settings()
	)
	music_slider.value_changed.connect(func(value: float) -> void:
		stored_music_volume = value
		_save_game_data()
		_apply_audio_settings()
	)
	sound_toggle.toggled.connect(func(value: bool) -> void:
		sound_enabled = value
		_save_game_data()
	)
	sound_slider.value_changed.connect(func(value: float) -> void:
		stored_sound_volume = value
		_save_game_data()
	)
	attack_preset.item_selected.connect(func(index: int) -> void:
		enemy_attack_level = index
		_apply_enemy_attack_preset(index)
		fire_rate_label.text = "Fire Frequency Coefficient x%.2f (Elite highest)" % enemy_fire_rate_multiplier
		_update_attack_difficulty_text(difficulty_label)
		_save_game_data()
	)
	back.pressed.connect(func() -> void: _show_panel(begin_panel))
	return panel

func _update_attack_difficulty_text(label: Label) -> void:
	if label == null:
		return
	match clamp(enemy_attack_level, 0, 2):
		0:
			label.text = "Difficulty: Normal"
		1:
			label.text = "Difficulty: Aggressive"
		2:
			label.text = "Difficulty: Elite"

func _create_rank_panel() -> Control:
	var panel := _create_panel("Ranking")
	var box := _panel_box(panel)
	var list := RichTextLabel.new()
	list.name = "RankList"
	list.custom_minimum_size = Vector2(0, 210)
	list.fit_content = false
	box.add_child(list)
	var back := _make_button("Back")
	box.add_child(back)
	back.pressed.connect(func() -> void:
		if game_over:
			_show_panel(victory_panel)
		else:
			_show_panel(begin_panel)
	)
	return panel

func _create_result_panel(victory: bool) -> Control:
	var panel := _create_panel("Victory" if victory else "Defeat")
	var box := _panel_box(panel)
	var message := _make_label("Congratulations, commander" if victory else "Your tank has been destroyed", HORIZONTAL_ALIGNMENT_CENTER, 18)
	message.name = "Message"
	message.add_theme_color_override("font_color", Color(0.1, 0.14, 0.12))
	box.add_child(message)
	if victory:
		var name_input := LineEdit.new()
		name_input.name = "PlayerName"
		name_input.placeholder_text = "Player name"
		name_input.text = "Player"
		box.add_child(name_input)
		var submit := _make_button("Save Score")
		box.add_child(submit)
		submit.pressed.connect(func() -> void:
			_add_rank(name_input.text)
			_refresh_rank_panel()
			_show_panel(rank_panel)
		)
	var retry := _make_button("Restart")
	var menu := _make_button("Main Menu")
	box.add_child(retry)
	box.add_child(menu)
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	menu.pressed.connect(func() -> void: get_tree().reload_current_scene())
	return panel

func _hide_all_panels() -> void:
	for panel in [begin_panel, settings_panel, rank_panel, victory_panel, defeat_panel]:
		if panel != null:
			panel.visible = false

func _show_panel(panel: Control) -> void:
	_hide_all_panels()
	if panel != null:
		panel.visible = true

func _start_game() -> void:
	game_started = true
	game_over = false
	elapsed_time = 0.0
	score = 0
	var now := Time.get_ticks_msec() / 1000.0
	opening_pressure_until = now + ELITE_OPENING_PRESSURE_DURATION if enemy_attack_level >= 2 else 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		enemy_opening_shots_remaining[enemy] = ELITE_OPENING_SHOTS
		enemy_reaction_ready_at[enemy] = now + randf_range(0.05, 0.28)
		enemy_next_fire[enemy] = now + randf_range(0.12, 0.45)
	hud_panel.visible = true
	_hide_all_panels()
	_update_ui()

func _create_background_music() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MUSIC_MIX_RATE
	stream.buffer_length = 2.0

	music_player = AudioStreamPlayer.new()
	music_player.name = "Background Music"
	music_player.stream = stream
	music_player.volume_db = music_volume_db
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_fill_music_buffer()

func _apply_audio_settings() -> void:
	if music_player == null:
		return
	if music_enabled:
		music_player.volume_db = linear_to_db(max(stored_music_volume, 0.001))
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()

func _load_game_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	var music_data: Dictionary = data.get("music", {})
	music_enabled = bool(music_data.get("music_enabled", true))
	sound_enabled = bool(music_data.get("sound_enabled", true))
	stored_music_volume = clamp(float(music_data.get("music_volume", 0.75)), 0.0, 1.0)
	stored_sound_volume = clamp(float(music_data.get("sound_volume", 0.75)), 0.0, 1.0)
	var enemy_data: Dictionary = data.get("enemy_attack", {})
	var raw_level := int(enemy_data.get("level", 0))
	enemy_attack_level = raw_level if raw_level >= 0 and raw_level <= 2 else 0
	_apply_enemy_attack_preset(enemy_attack_level)
	ranks = data.get("ranks", [])

func _save_game_data() -> void:
	var data := {
		"music": {
			"music_enabled": music_enabled,
			"sound_enabled": sound_enabled,
			"music_volume": stored_music_volume,
			"sound_volume": stored_sound_volume,
		},
		"enemy_attack": {
			"level": enemy_attack_level,
			"damage_multiplier": enemy_damage_multiplier,
			"fire_rate_multiplier": enemy_fire_rate_multiplier,
			"aggression_multiplier": enemy_aggression_multiplier,
		},
		"ranks": ranks,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func _add_rank(player_name: String) -> void:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player"
	ranks.append({
		"name": clean_name,
		"score": score,
		"time": elapsed_time,
	})
	ranks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return float(a.get("time", 99999.0)) < float(b.get("time", 99999.0))
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	if ranks.size() > 10:
		ranks = ranks.slice(0, 10)
	_save_game_data()

func _refresh_rank_panel() -> void:
	if rank_panel == null:
		return
	var list := rank_panel.get_node("MarginContainer/Content/RankList") as RichTextLabel
	var text := "[b]Rank   Player      Score   Time[/b]\n"
	for i in range(10):
		if i < ranks.size():
			var entry: Dictionary = ranks[i]
			text += "%2d     %-10s  %5d   %s\n" % [i + 1, str(entry.get("name", "Player")).left(10), int(entry.get("score", 0)), _format_time(float(entry.get("time", 0.0)))]
		else:
			text += "%2d     Waiting     -----   --:--\n" % [i + 1]
	list.text = text

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

func _fill_music_buffer() -> void:
	if music_playback == null:
		return
	var frames_available := music_playback.get_frames_available()
	for i in range(frames_available):
		var sample := _music_sample(music_sample_index)
		music_playback.push_frame(Vector2(sample, sample))
		music_sample_index += 1

func _music_sample(sample_index: int) -> float:
	var time := float(sample_index) / MUSIC_MIX_RATE
	var beat := time * MUSIC_TEMPO / 60.0
	var step := int(floor(beat * 2.0)) % 16
	var chord_root: float = [55.0, 65.41, 49.0, 73.42][int(floor(beat / 4.0)) % 4]
	var bass_gate := 1.0 if step in [0, 3, 6, 8, 11, 14] else 0.25
	var bass := sin(TAU * chord_root * time) * bass_gate * 0.16
	var pulse := sin(TAU * chord_root * 2.0 * time) * (0.08 if step % 2 == 0 else 0.02)
	var melody_note: float = [220.0, 246.94, 261.63, 329.63, 293.66, 246.94, 196.0, 164.81][int(step / 2)]
	var melody_gate := 1.0 - fmod(beat * 2.0, 1.0)
	var melody := sin(TAU * melody_note * time) * melody_gate * 0.055
	var kick_phase := fmod(beat, 1.0)
	var kick: float = sin(TAU * (78.0 - kick_phase * 42.0) * time) * max(0.0, 1.0 - kick_phase * 10.0) * 0.22
	return clamp((bass + pulse + melody + kick) * 0.55, -0.45, 0.45)

func _update_player_velocity(delta: float) -> void:
	if delta <= 0.0 or player == null:
		return
	player_velocity_estimate = (player.global_position - player_previous_position) / delta
	player_previous_position = player.global_position

func _move_player(delta: float) -> void:
	var move_input := (1 if Input.is_key_pressed(KEY_W) else 0) - (1 if Input.is_key_pressed(KEY_S) else 0)
	var turn_input := (1 if Input.is_key_pressed(KEY_A) else 0) - (1 if Input.is_key_pressed(KEY_D) else 0)
	player.rotate_y(turn_input * deg_to_rad(115.0) * delta)
	player.velocity = -player.global_transform.basis.z * move_input * 8.0 * speed_multiplier
	player.move_and_slide()

func _update_enemy(enemy: CharacterBody3D, delta: float) -> void:
	var health := enemy.get_node("Health") as TankHealth
	if health.dead:
		return

	var can_see_player := _enemy_has_fire_solution(enemy)
	_update_enemy_awareness(enemy, can_see_player)
	_refresh_enemy_tactics(enemy, can_see_player)
	var distance := enemy.global_position.distance_to(player.global_position)
	var now := Time.get_ticks_msec() / 1000.0
	var remembers_target := now < float(enemy_memory_until.get(enemy, 0.0))

	var move_direction := _get_enemy_move_direction(enemy)
	if move_direction.length_squared() > 0.01:
		var state_name := str(enemy_state.get(enemy, AI_HUNT))
		var speed_factor := 1.0
		if state_name == AI_PRESSURE:
			speed_factor = 1.14
		elif state_name == AI_RETREAT or state_name == AI_EVADE:
			speed_factor = 1.22
		_rotate_toward(enemy, move_direction.normalized(), deg_to_rad(ENEMY_TURN_SPEED) * delta)
		enemy.velocity = -enemy.global_transform.basis.z * ENEMY_MOVE_SPEED * enemy_aggression_multiplier * speed_factor
		enemy.move_and_slide()
	else:
		enemy.velocity = Vector3.ZERO

	var turret := enemy.get_node("Turret") as Node3D
	var aim_point := _get_enemy_aim_point(enemy, can_see_player)
	var to_aim := aim_point - turret.global_position
	to_aim.y = 0.0
	if to_aim.length_squared() > 0.001:
		_look_at_flat(turret, to_aim.normalized())

	_update_enemy_fire_control(enemy, can_see_player, remembers_target, distance)

func _update_enemy_awareness(enemy: CharacterBody3D, can_see_player: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if enemy.global_position.distance_to(player.global_position) > ENEMY_HUNT_RANGE:
		can_see_player = false

	var was_visible := bool(enemy_visible_player.get(enemy, false))
	if can_see_player:
		enemy_last_known_player_position[enemy] = player.global_position
		enemy_memory_until[enemy] = now + ENEMY_MEMORY_TIME
		enemy_last_seen_at[enemy] = now
		if not was_visible:
			var reaction: float = ENEMY_REACTION_TIME / max(enemy_aggression_multiplier, 0.5)
			reaction *= randf_range(0.65, 1.35)
			enemy_reaction_ready_at[enemy] = now + reaction
		enemy_visible_player[enemy] = true
	else:
		enemy_visible_player[enemy] = false

func _refresh_enemy_tactics(enemy: CharacterBody3D, can_see_player: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(enemy_rethink_until.get(enemy, 0.0)) and now < float(enemy_state_until.get(enemy, 0.0)):
		return
	enemy_rethink_until[enemy] = now + randf_range(0.65, 1.35)
	if randf() < 0.62:
		enemy_strafe_direction[enemy] = -float(enemy_strafe_direction.get(enemy, 1.0))
	enemy_attack_anchor[enemy] = _pick_enemy_attack_anchor(enemy)
	enemy_cover_anchor[enemy] = _pick_enemy_cover_anchor(enemy)

	var health := enemy.get_node("Health") as TankHealth
	var health_ratio := health.percent()
	var distance := enemy.global_position.distance_to(player.global_position)
	var remembers_player := now < float(enemy_memory_until.get(enemy, 0.0))
	var was_recently_hit := now < float(enemy_was_hit_until.get(enemy, 0.0))
	var role := int(enemy_role.get(enemy, 0))
	var next_state := AI_HUNT

	if _get_projectile_avoidance(enemy).length_squared() > 0.04:
		next_state = AI_EVADE
	elif health_ratio <= ENEMY_LOW_HEALTH_RATIO and can_see_player:
		next_state = AI_RETREAT
	elif was_recently_hit and can_see_player:
		next_state = AI_PRESSURE
	elif can_see_player and distance <= ENEMY_PREFERRED_RANGE + 3.0 and role != 1:
		next_state = AI_PRESSURE
	elif remembers_player and (role == 1 or not can_see_player):
		next_state = AI_FLANK
	elif can_see_player:
		next_state = AI_PRESSURE if randf() < 0.5 * enemy_aggression_multiplier else AI_FLANK

	enemy_state[enemy] = next_state
	enemy_state_until[enemy] = now + randf_range(0.75, 1.6)

func _get_enemy_move_direction(enemy: CharacterBody3D) -> Vector3:
	var to_player := player.global_position - enemy.global_position
	to_player.y = 0.0
	var player_distance := to_player.length()
	var desired := Vector3.ZERO
	var now := Time.get_ticks_msec() / 1000.0
	var state_name := str(enemy_state.get(enemy, AI_HUNT))

	var dodge := _get_projectile_avoidance(enemy)
	if dodge.length_squared() > 0.01:
		desired += dodge * (4.2 if state_name == AI_EVADE else 3.2)

	var effective_min_range: float = ENEMY_MIN_RANGE / max(enemy_aggression_multiplier, 0.5)
	var effective_preferred_range: float = ENEMY_PREFERRED_RANGE / max(enemy_aggression_multiplier * 0.75, 0.5)

	if player_distance <= ENEMY_HUNT_RANGE and player_distance > 0.01:
		var toward_player := to_player / player_distance
		var strafe := Vector3(-toward_player.z, 0.0, toward_player.x) * float(enemy_strafe_direction.get(enemy, 1.0))
		var anchor: Vector3 = enemy_attack_anchor.get(enemy, enemy.global_position)
		var to_anchor := anchor - enemy.global_position
		to_anchor.y = 0.0
		var last_known: Vector3 = enemy_last_known_player_position.get(enemy, player.global_position)
		var to_last_known := last_known - enemy.global_position
		to_last_known.y = 0.0
		var cover_anchor: Vector3 = enemy_cover_anchor.get(enemy, enemy.global_position)
		var to_cover := cover_anchor - enemy.global_position
		to_cover.y = 0.0
		var remembers_player := now < float(enemy_memory_until.get(enemy, 0.0))

		match state_name:
			AI_EVADE:
				desired += dodge * 4.5 + strafe * 1.0
			AI_RETREAT:
				desired -= toward_player * 1.65
				if to_cover.length_squared() > 1.0:
					desired += to_cover.normalized() * 2.1
				desired += strafe * 0.45
			AI_PRESSURE:
				if player_distance > effective_min_range:
					desired += toward_player * 2.1
				else:
					desired += strafe * 1.15
				desired += strafe * 0.55
			AI_FLANK:
				if to_anchor.length_squared() > 1.0:
					desired += to_anchor.normalized() * 2.0
				desired += strafe * 1.25
				if player_distance > effective_preferred_range + 2.5:
					desired += toward_player * 0.7
			_:
				if player_distance > effective_preferred_range:
					desired += toward_player * 1.85
				elif player_distance < effective_min_range:
					desired -= toward_player * 1.25
				if remembers_player and to_last_known.length_squared() > 1.0:
					desired += to_last_known.normalized() * 1.1
				desired += strafe * 0.35
	else:
		var patrol_target := _get_enemy_patrol_target(enemy)
		var patrol_direction := patrol_target - enemy.global_position
		patrol_direction.y = 0.0
		if patrol_direction.length_squared() > 0.25:
			desired += patrol_direction.normalized()

	desired += _get_obstacle_avoidance(enemy, desired.normalized() if desired.length_squared() > 0.01 else -enemy.global_transform.basis.z) * 2.4
	desired += _get_enemy_separation(enemy) * 1.6
	desired += _get_arena_boundary_avoidance(enemy) * 2.0

	if desired.length_squared() <= 0.01:
		return Vector3.ZERO
	return desired.normalized()

func _pick_enemy_attack_anchor(enemy: CharacterBody3D) -> Vector3:
	var to_enemy := enemy.global_position - player.global_position
	to_enemy.y = 0.0
	if to_enemy.length_squared() <= 0.01:
		to_enemy = Vector3.FORWARD
	var from_player := to_enemy.normalized()
	var side := Vector3(-from_player.z, 0.0, from_player.x) * float(enemy_strafe_direction.get(enemy, 1.0))
	var desired_distance := randf_range(6.5, 10.5)
	var anchor := player.global_position + from_player * desired_distance + side * randf_range(4.0, 7.5)
	anchor.x = clamp(anchor.x, -ARENA_LIMIT + 2.0, ARENA_LIMIT - 2.0)
	anchor.z = clamp(anchor.z, -ARENA_LIMIT + 2.0, ARENA_LIMIT - 2.0)
	anchor.y = enemy.global_position.y
	return anchor

func _pick_enemy_cover_anchor(enemy: CharacterBody3D) -> Vector3:
	var away := enemy.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() <= 0.01:
		away = Vector3.BACK
	away = away.normalized()
	var best := enemy.global_position + away * ENEMY_COVER_SCAN_RADIUS
	var best_score := -9999.0
	var candidates := [
		away,
		(away + Vector3(-away.z, 0.0, away.x) * 0.8).normalized(),
		(away + Vector3(away.z, 0.0, -away.x) * 0.8).normalized(),
		Vector3(-away.z, 0.0, away.x),
		Vector3(away.z, 0.0, -away.x),
	]

	for direction in candidates:
		var candidate: Vector3 = enemy.global_position + direction * ENEMY_COVER_SCAN_RADIUS
		candidate.x = clamp(candidate.x, -ARENA_LIMIT + 2.0, ARENA_LIMIT - 2.0)
		candidate.z = clamp(candidate.z, -ARENA_LIMIT + 2.0, ARENA_LIMIT - 2.0)
		candidate.y = enemy.global_position.y
		var distance_from_player: float = candidate.distance_to(player.global_position)
		var has_cover: float = 1.0 if _line_blocked(candidate + Vector3.UP * 0.5, player.global_position + Vector3.UP * 0.5, enemy) else 0.0
		var score: float = distance_from_player + has_cover * 8.0 - candidate.distance_to(enemy.global_position) * 0.35
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _line_blocked(from: Vector3, to: Vector3, ignore: CharacterBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [ignore.get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider != player

func _get_enemy_patrol_target(enemy: CharacterBody3D) -> Vector3:
	var points: Array = patrol_points[enemy]
	var index: int = patrol_indices[enemy]
	var target: Vector3 = points[index]
	if enemy.global_position.distance_to(target) <= 1.2:
		index = (index + 1) % points.size()
		patrol_indices[enemy] = index
		target = points[index]
	return target

func _get_projectile_avoidance(enemy: CharacterBody3D) -> Vector3:
	var avoidance := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("projectiles"):
		var projectile := node as Projectile
		if projectile == null or projectile.owner_tank == enemy:
			continue
		var projectile_direction := projectile.travel_direction()
		var to_enemy := enemy.global_position - projectile.global_position
		to_enemy.y = 0.0
		var closing_distance := projectile_direction.dot(to_enemy)
		if closing_distance <= 0.0 or closing_distance > 8.0:
			continue
		var lateral_offset := to_enemy - projectile_direction * closing_distance
		if lateral_offset.length() > 2.0:
			continue
		var side_step := Vector3(-projectile_direction.z, 0.0, projectile_direction.x)
		if side_step.dot(to_enemy) < 0.0:
			side_step = -side_step
		avoidance += side_step.normalized() * (1.0 - lateral_offset.length() / 2.0)
	return avoidance

func _get_obstacle_avoidance(enemy: CharacterBody3D, move_direction: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := enemy.global_position + Vector3.UP * 0.45
	var forward := move_direction.normalized()
	if forward.length_squared() <= 0.01:
		return Vector3.ZERO

	var avoidance := Vector3.ZERO
	var ray_length := 3.2
	var checks := [
		forward,
		(forward + Vector3(-forward.z, 0.0, forward.x) * 0.65).normalized(),
		(forward + Vector3(forward.z, 0.0, -forward.x) * 0.65).normalized(),
	]

	for check_direction in checks:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + check_direction * ray_length)
		query.exclude = [enemy.get_rid()]
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		normal.y = 0.0
		if normal.length_squared() > 0.01:
			avoidance += normal.normalized()

	return avoidance

func _get_enemy_separation(enemy: CharacterBody3D) -> Vector3:
	var separation := Vector3.ZERO
	for other in enemies:
		if other == enemy or not is_instance_valid(other):
			continue
		var offset := enemy.global_position - other.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.01 and distance < 3.0:
			separation += offset.normalized() * (1.0 - distance / 3.0)
	return separation

func _get_arena_boundary_avoidance(enemy: CharacterBody3D) -> Vector3:
	var margin := 3.0
	var pos := enemy.global_position
	var avoidance := Vector3.ZERO
	if pos.x > ARENA_LIMIT - margin:
		avoidance.x -= 1.0
	elif pos.x < -ARENA_LIMIT + margin:
		avoidance.x += 1.0
	if pos.z > ARENA_LIMIT - margin:
		avoidance.z -= 1.0
	elif pos.z < -ARENA_LIMIT + margin:
		avoidance.z += 1.0
	return avoidance

func _enemy_can_see_player(enemy: CharacterBody3D) -> bool:
	var fire_point := enemy.get_node("Turret/FirePoint") as Marker3D
	var origin := fire_point.global_position
	var target := player.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [enemy.get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		return false
	return _node_belongs_to_player(hit.collider)

func _enemy_has_fire_solution(enemy: CharacterBody3D) -> bool:
	if _enemy_can_see_player(enemy):
		return true
	var fire_point := enemy.get_node("Turret/FirePoint") as Marker3D
	var origin := fire_point.global_position
	var to_player := player.global_position - origin
	to_player.y = 0.0
	if to_player.length_squared() <= 0.001:
		return false
	var side := Vector3(-to_player.z, 0.0, to_player.x).normalized()
	for lateral in [0.55, -0.55, 1.05, -1.05]:
		var target: Vector3 = player.global_position + Vector3.UP * 0.5 + side * lateral
		var query := PhysicsRayQueryParameters3D.create(origin, target)
		query.exclude = [enemy.get_rid()]
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.has("collider"):
			continue
		if _node_belongs_to_player(hit.collider):
			return true
	return false

func _node_belongs_to_player(node: Node) -> bool:
	if node == null or player == null:
		return false
	var current: Node = node
	while current != null:
		if current == player:
			return true
		current = current.get_parent()
	return false

func _get_enemy_raw_aim_point(enemy: CharacterBody3D, can_see_player: bool) -> Vector3:
	var fire_point := enemy.get_node("Turret/FirePoint") as Marker3D
	var base_target: Vector3 = player.global_position if can_see_player else enemy_last_known_player_position.get(enemy, player.global_position)
	var distance: float = fire_point.global_position.distance_to(base_target)
	var travel_time: float = clamp(distance / 24.0, 0.0, 0.8)
	var lead: Vector3 = player_velocity_estimate * travel_time * (0.85 if can_see_player else 0.25)
	lead.y = 0.0
	return base_target + lead

func _get_enemy_aim_point(enemy: CharacterBody3D, can_see_player: bool) -> Vector3:
	var raw_target := _get_enemy_raw_aim_point(enemy, can_see_player)
	if enemy_attack_level >= 2:
		return raw_target + _get_enemy_aim_noise(enemy) * 0.45
	return raw_target + _get_enemy_aim_noise(enemy)

func _get_enemy_aim_noise(enemy: CharacterBody3D) -> Vector3:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= float(enemy_aim_noise_until.get(enemy, 0.0)):
		var health := enemy.get_node("Health") as TankHealth
		var composure: float = clamp(health.percent() + enemy_aggression_multiplier * 0.25, 0.25, 1.35)
		var radius: float = lerp(1.15, 0.22, clamp(enemy_fire_rate_multiplier / composure, 0.0, 1.0))
		enemy_aim_noise[enemy] = Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))
		enemy_aim_noise_until[enemy] = now + randf_range(0.18, 0.42)
	return enemy_aim_noise.get(enemy, Vector3.ZERO)

func _enemy_is_combat_ready(enemy: CharacterBody3D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(enemy_reaction_ready_at.get(enemy, 0.0)):
		return false
	var turret := enemy.get_node("Turret") as Node3D
	var to_target := _get_enemy_raw_aim_point(enemy, true) - turret.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return false
	var forward := -turret.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return true
	var aim_dot := forward.normalized().dot(to_target.normalized())
	var threshold := 0.84
	if enemy_attack_level == 1:
		threshold = 0.80
	elif enemy_attack_level >= 2:
		threshold = 0.74
	return aim_dot > threshold

func _update_enemy_fire_control(enemy: CharacterBody3D, can_see_player: bool, remembers_target: bool, distance: float) -> void:
	var aggressive_attack_range: float = ENEMY_ATTACK_RANGE * max(0.85, enemy_aggression_multiplier)
	var now := Time.get_ticks_msec() / 1000.0
	var last_seen_at := float(enemy_last_seen_at.get(enemy, -999.0))
	var recently_saw_player := (now - last_seen_at) <= ENEMY_SUPPRESSIVE_MEMORY
	var opening_active := enemy_attack_level >= 2 and now <= opening_pressure_until
	var opening_shots_left := int(enemy_opening_shots_remaining.get(enemy, 0))
	if opening_active and opening_shots_left > 0:
		var cooldown_ready_opening := now >= float(enemy_next_fire.get(enemy, 0.0))
		if cooldown_ready_opening:
			if _try_enemy_fire(enemy, min(distance, ENEMY_PREFERRED_RANGE + 1.5)):
				enemy_opening_shots_remaining[enemy] = opening_shots_left - 1
		# Opening pressure should still allow normal fire flow this frame when in range.

	if distance > aggressive_attack_range:
		return

	var has_fire_solution := can_see_player and _enemy_is_combat_ready(enemy)
	var elite_override := enemy_attack_level >= 2 and can_see_player
	if has_fire_solution:
		_try_enemy_fire(enemy, distance)
		return
	# Non-elite fallback: keep this low-frequency so normal/aggressive do not feel like elite.
	if enemy_attack_level < 2 and can_see_player and now >= float(enemy_next_fire.get(enemy, 0.0)):
		var fallback_chance := 0.015 if enemy_attack_level == 0 else 0.03
		if randf() < fallback_chance:
			var fallback_distance := distance + (1.6 if enemy_attack_level == 0 else 1.0)
			_try_enemy_fire(enemy, fallback_distance)
			return
	if elite_override:
		_try_enemy_fire(enemy, distance)
		return

	# Suppressive fire: enemy keeps pressure for a short memory window even after losing sight.
	if remembers_target and recently_saw_player and distance <= aggressive_attack_range * 0.72:
		var cooldown_ready := now >= float(enemy_next_fire.get(enemy, 0.0))
		if cooldown_ready and randf() < 0.30 * enemy_fire_rate_multiplier:
			_try_enemy_fire(enemy, distance + 1.2)

func _try_enemy_fire(enemy: CharacterBody3D, distance: float) -> bool:
	var burst_left := int(enemy_burst_remaining.get(enemy, 0))
	var state_name := str(enemy_state.get(enemy, AI_HUNT))
	var cooldown := 0.78
	var damage := 18.0
	var speed := 25.5
	var burst_chance := 0.28 * enemy_fire_rate_multiplier

	if state_name == AI_PRESSURE:
		cooldown = 0.62
		burst_chance += 0.22 * enemy_aggression_multiplier
	elif state_name == AI_FLANK:
		cooldown = 0.68
		speed = 27.0
		damage = 20.0
	elif state_name == AI_RETREAT:
		cooldown = 0.95
		burst_chance *= 0.45

	if burst_left > 0:
		cooldown = 0.28
		damage = 14.0
	elif distance <= ENEMY_PREFERRED_RANGE + 3.0 and randf() < burst_chance:
		cooldown = 0.36
		damage = 14.0
	elif distance > ENEMY_PREFERRED_RANGE:
		cooldown = max(cooldown, 0.82)
		speed = 27.0

	cooldown /= max(enemy_fire_rate_multiplier, 0.1)
	damage *= enemy_damage_multiplier
	speed *= lerp(0.92, 1.12, clamp(enemy_fire_rate_multiplier - 0.5, 0.0, 1.0))
	var cooldown_floor := 0.34
	if enemy_attack_level == 0:
		cooldown_floor = 1.15
	elif enemy_attack_level == 1:
		cooldown_floor = 0.82
	cooldown = max(cooldown, cooldown_floor)

	if _try_fire(enemy, damage, speed, cooldown, false):
		if burst_left > 0:
			enemy_burst_remaining[enemy] = burst_left - 1
		elif cooldown <= 0.36:
			enemy_burst_remaining[enemy] = 1 + int(randf() < 0.45 * enemy_fire_rate_multiplier)
		return true
	return false

func _on_enemy_health_changed(enemy: CharacterBody3D) -> void:
	if not is_instance_valid(enemy):
		return
	var now := Time.get_ticks_msec() / 1000.0
	enemy_was_hit_until[enemy] = now + 2.4
	enemy_memory_until[enemy] = now + ENEMY_MEMORY_TIME
	enemy_last_known_player_position[enemy] = player.global_position
	var health := enemy.get_node("Health") as TankHealth
	if health.percent() <= ENEMY_LOW_HEALTH_RATIO:
		enemy_state[enemy] = AI_RETREAT
		enemy_state_until[enemy] = now + randf_range(1.2, 2.2)
	else:
		enemy_state[enemy] = AI_PRESSURE
		enemy_state_until[enemy] = now + randf_range(0.8, 1.5)
	enemy_reaction_ready_at[enemy] = min(float(enemy_reaction_ready_at.get(enemy, now)), now + 0.08)

func _aim_player_turret() -> void:
	var turret := player.get_node("Turret") as Node3D
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if abs(normal.y) < 0.001:
		return
	var distance := -origin.y / normal.y
	if distance <= 0.0:
		return
	var point := origin + normal * distance
	var direction := point - turret.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_look_at_flat(turret, direction.normalized())

func _try_fire(tank: CharacterBody3D, final_damage: float, final_speed: float, cooldown: float, is_player_fire: bool) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if is_player_fire:
		if now < player_next_fire:
			return false
		player_next_fire = now + cooldown
	else:
		if now < float(enemy_next_fire.get(tank, 0.0)):
			return false
		enemy_next_fire[tank] = now + cooldown

	var fire_point := tank.get_node("Turret/FirePoint") as Marker3D
	var projectile := Projectile.new()
	add_child(projectile)
	projectile.global_transform = fire_point.global_transform
	projectile.init(tank, final_damage, final_speed, not is_player_fire)
	return true

func _activate_speed() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < speed_cooldown_until:
		return
	speed_multiplier = 1.65
	speed_active_until = now + 6.0
	speed_cooldown_until = now + 12.0

func _activate_shield() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < shield_cooldown_until:
		return
	shield_multiplier = 0.25
	player_health.damage_multiplier = shield_multiplier
	shield_active_until = now + 5.0
	shield_cooldown_until = now + 14.0

func _activate_power() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < power_cooldown_until:
		return
	damage_multiplier = 2.5
	power_active_until = now + 7.0
	power_cooldown_until = now + 16.0

func _update_skill_timers() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if speed_multiplier != 1.0 and now >= speed_active_until:
		speed_multiplier = 1.0
	if shield_multiplier != 1.0 and now >= shield_active_until:
		shield_multiplier = 1.0
		player_health.damage_multiplier = 1.0
	if damage_multiplier != 1.0 and now >= power_active_until:
		damage_multiplier = 1.0

func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if use_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	camera.size = orthographic_size
	var offset := Vector3(0.0, 22.0, 1.0) if use_orthographic else Vector3(0.0, 13.0, 11.0)
	var desired := player.global_position + offset
	camera.global_position = camera.global_position.lerp(desired, clamp(delta * 8.0, 0.0, 1.0))
	camera.look_at(player.global_position + Vector3.UP * 1.5, Vector3.UP)

func _update_ui() -> void:
	health_bar.value = player_health.percent() * 100.0
	score_label.text = "Score: %d" % score
	time_label.text = "Time: %s" % _format_time(elapsed_time)
	speed_label.text = _skill_text("Q Speed", speed_cooldown_until, speed_active_until)
	shield_label.text = _skill_text("E Shield", shield_cooldown_until, shield_active_until)
	power_label.text = _skill_text("R Power", power_cooldown_until, power_active_until)

func _skill_text(label: String, cooldown_until: float, active_until: float) -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if now < active_until:
		return "%s\nActive" % label
	if now < cooldown_until:
		return "%s\n%.1fs" % [label, cooldown_until - now]
	return "%s\nReady" % label

func _on_player_died() -> void:
	game_over = true
	_update_status("Defeat")
	_show_panel(defeat_panel)

func _on_enemy_died(enemy: CharacterBody3D) -> void:
	enemies.erase(enemy)
	patrol_points.erase(enemy)
	patrol_indices.erase(enemy)
	enemy_next_fire.erase(enemy)
	enemy_strafe_direction.erase(enemy)
	enemy_rethink_until.erase(enemy)
	enemy_attack_anchor.erase(enemy)
	enemy_last_known_player_position.erase(enemy)
	enemy_burst_remaining.erase(enemy)
	enemy_opening_shots_remaining.erase(enemy)
	enemy_state.erase(enemy)
	enemy_state_until.erase(enemy)
	enemy_visible_player.erase(enemy)
	enemy_reaction_ready_at.erase(enemy)
	enemy_memory_until.erase(enemy)
	enemy_last_seen_at.erase(enemy)
	enemy_aim_noise.erase(enemy)
	enemy_aim_noise_until.erase(enemy)
	enemy_cover_anchor.erase(enemy)
	enemy_was_hit_until.erase(enemy)
	enemy_role.erase(enemy)
	enemy.queue_free()
	score += 100 + max(0, int(45.0 - elapsed_time) * 2)
	_update_objective()
	if enemies.is_empty() and not game_over:
		game_over = true
		score += 500 + max(0, int(180.0 - elapsed_time) * 5)
		_update_ui()
		_update_status("Victory")
		var message := victory_panel.get_node("MarginContainer/Content/Message") as Label
		message.text = "Score: %d   Time: %s" % [score, _format_time(elapsed_time)]
		_show_panel(victory_panel)

func _update_objective() -> void:
	if objective_label != null:
		objective_label.text = "Enemies: %d" % enemies.size()

func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _add_box_visual(parent: Node3D, size: Vector3, color: Color, local_position: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = local_position
	mesh.material_override = _make_material(color)
	parent.add_child(mesh)

func _add_box_collision(parent: CollisionObject3D, size: Vector3, local_position: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = local_position
	parent.add_child(shape)

func _rotate_toward(node: Node3D, direction: Vector3, max_angle: float) -> void:
	var current := -node.global_transform.basis.z
	current.y = 0.0
	current = current.normalized()
	var angle := current.signed_angle_to(direction, Vector3.UP)
	node.rotate_y(clamp(angle, -max_angle, max_angle))

func _look_at_flat(node: Node3D, direction: Vector3) -> void:
	node.look_at(node.global_position + direction, Vector3.UP)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
