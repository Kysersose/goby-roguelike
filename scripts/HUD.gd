extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthLabel
@onready var mana_bar: ProgressBar = $Control/ManaBar
@onready var mana_label: Label = $Control/ManaLabel
@onready var stamina_bar: ProgressBar = $Control/StaminaBar
@onready var stamina_label: Label = $Control/StaminaLabel
@onready var xp_bar: ProgressBar = $Control/XPBar
@onready var xp_label: Label = $Control/XPLabel
@onready var level_label: Label = $Control/LevelLabel
@onready var clock_label: Label = $Control/ClockLabel
@onready var level_name_label: Label = $Control/LevelNameLabel
@onready var game_over_menu: Control = $Control/GameOverMenu
@onready var pause_menu: Control = $Control/PauseMenu
@onready var ability_bar: HBoxContainer = $Control/AbilityBar

var _game_over: bool = false
var _player: Node = null
var _elapsed_time: float = 0.0
# Each entry: {clock: CooldownClock}
var _ability_slots: Array = []

const _CooldownClock := preload("res://scripts/CooldownClock.gd")

const _ABILITY_DISPLAY_NAMES := {
	"tail_whip":   "Tail\nWhip",
	"bubble_beam": "Bubble\nBeam",
	"chomp":       "Chomp",
	"":            "—",
}

const _ABILITY_DEFS: Array = [
	{"key": "1", "name": "Tail\nWhip"},
	{"key": "2", "name": "Bubble\nBeam"},
	{"key": "3", "name": "—"},
	{"key": "4", "name": "—"},
	{"key": "5", "name": "—"},
	{"key": "SPC", "name": "Dash"},
]

func _ready() -> void:
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", hp_fill)

	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.2, 0.5, 1.0)
	mana_bar.add_theme_stylebox_override("fill", mp_fill)

	var sp_fill = StyleBoxFlat.new()
	sp_fill.bg_color = Color(1.0, 0.65, 0.1)
	stamina_bar.add_theme_stylebox_override("fill", sp_fill)

	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(1.0, 1.0, 1.0)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)

	clock_label.add_theme_font_size_override("font_size", 48)
	clock_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.83))
	level_name_label.add_theme_font_size_override("font_size", 48)
	level_name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.83))

	$Control/PauseMenu/ResumeButton.pressed.connect(_on_resume_pressed)
	$Control/PauseMenu/SaveRunButton.pressed.connect(_on_save_run_pressed)
	$Control/PauseMenu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Control/PauseMenu/ExitButton.pressed.connect(_on_exit_pressed)

	$Control/GameOverMenu/NewGameButton.pressed.connect(_on_new_game_pressed)
	$Control/GameOverMenu/MainMenuButton.pressed.connect(_on_main_menu_pressed)

	_build_ability_bar()

func _build_ability_bar() -> void:
	for def in _ABILITY_DEFS:
		# Outer panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(96, 96)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
		bg_style.border_width_bottom = 3
		bg_style.border_width_top = 3
		bg_style.border_width_left = 3
		bg_style.border_width_right = 3
		bg_style.border_color = Color(0.45, 0.45, 0.55, 1.0)
		bg_style.corner_radius_top_left = 6
		bg_style.corner_radius_top_right = 6
		bg_style.corner_radius_bottom_left = 6
		bg_style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", bg_style)

		# Stack container for layering — clip_contents keeps the clock inside the slot border
		var stack := Control.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.clip_contents = true
		panel.add_child(stack)

		# Ability name (center)
		var name_lbl := Label.new()
		name_lbl.text = def["name"]
		name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.83))
		stack.add_child(name_lbl)

		# Key label (bottom-right corner)
		var key_lbl := Label.new()
		key_lbl.text = def["key"]
		key_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		key_lbl.offset_left = -51
		key_lbl.offset_top = -27
		key_lbl.offset_right = 0
		key_lbl.offset_bottom = 0
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.83))
		stack.add_child(key_lbl)

		# Cooldown clock sweep
		var clock := _CooldownClock.new()
		clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(clock)

		ability_bar.add_child(panel)
		_ability_slots.append({"clock": clock, "name_lbl": name_lbl})

func set_player(p: Node) -> void:
	_player = p

func _process(delta: float) -> void:
	if not get_tree().paused:
		_elapsed_time += delta
		var minutes := int(_elapsed_time / 60.0)
		var seconds := int(_elapsed_time) % 60
		clock_label.text = "%d:%02d" % [minutes, seconds]

	if _player == null or _ability_slots.size() < 6:
		return
	# Update cooldown clocks for slots 0-4 (keys 1-5) based on assigned ability
	for i in 5:
		var slot_data = _ability_slots[i]
		var ability: String = _player.ability_slots[i] if i < _player.ability_slots.size() else ""
		match ability:
			"tail_whip":
				slot_data.clock.progress = clampf(_player._whip_timer / _player.TAIL_WHIP_COOLDOWN, 0.0, 1.0)
			"bubble_beam":
				slot_data.clock.progress = clampf(_player._bubble_beam_timer / _player.BUBBLE_BEAM_COOLDOWN, 0.0, 1.0)
			"chomp":
				slot_data.clock.progress = clampf(_player._chomp_cooldown_timer / _player.CHOMP_COOLDOWN, 0.0, 1.0)
			_:
				slot_data.clock.progress = 0.0

func update_ability_slot(slot_index: int, ability_name: String) -> void:
	if slot_index < 0 or slot_index >= _ability_slots.size():
		return
	_ability_slots[slot_index].name_lbl.text = _ABILITY_DISPLAY_NAMES.get(ability_name, ability_name.capitalize())

func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func update_mana(current: int, maximum: int) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d MP" % [current, maximum]

func update_stamina(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "%d / %d SP" % [roundi(current), roundi(maximum)]

func update_experience(current: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	xp_label.text = "XP: %d / %d" % [current, needed]

func update_level(lvl: int) -> void:
	level_label.text = "Level: %d" % lvl

func show_game_over() -> void:
	_game_over = true
	game_over_menu.visible = true
	get_tree().paused = true

func toggle_pause_menu() -> void:
	if _game_over:
		return
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	pause_menu.visible = pausing

func _on_resume_pressed() -> void:
	toggle_pause_menu()

func _on_save_run_pressed() -> void:
	pass # TODO: implement save system

func _on_settings_pressed() -> void:
	pass # TODO: implement settings screen

func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
