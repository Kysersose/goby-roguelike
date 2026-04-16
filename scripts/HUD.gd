extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthLabel
@onready var mana_bar: ProgressBar = $Control/ManaBar
@onready var mana_label: Label = $Control/ManaLabel
@onready var xp_label: Label = $Control/XPLabel
@onready var level_label: Label = $Control/LevelLabel
@onready var game_over_menu: Control = $Control/GameOverMenu
@onready var pause_menu: Control = $Control/PauseMenu
@onready var ability_bar: HBoxContainer = $Control/AbilityBar

var _game_over: bool = false
var _player: Node = null
# Each entry: {overlay: ColorRect}
var _ability_slots: Array = []

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
		panel.custom_minimum_size = Vector2(64, 64)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
		bg_style.border_width_bottom = 2
		bg_style.border_width_top = 2
		bg_style.border_width_left = 2
		bg_style.border_width_right = 2
		bg_style.border_color = Color(0.45, 0.45, 0.55, 1.0)
		bg_style.corner_radius_top_left = 4
		bg_style.corner_radius_top_right = 4
		bg_style.corner_radius_bottom_left = 4
		bg_style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", bg_style)

		# Stack container for layering
		var stack := Control.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(stack)

		# Ability name (center)
		var name_lbl := Label.new()
		name_lbl.text = def["name"]
		name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
		stack.add_child(name_lbl)

		# Key label (bottom-right corner)
		var key_lbl := Label.new()
		key_lbl.text = def["key"]
		key_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		key_lbl.offset_left = -34
		key_lbl.offset_top = -18
		key_lbl.offset_right = 0
		key_lbl.offset_bottom = 0
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
		stack.add_child(key_lbl)

		# Cooldown overlay (dark rect, shown during cooldown)
		var overlay := ColorRect.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.color = Color(0, 0, 0, 0)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(overlay)

		ability_bar.add_child(panel)
		_ability_slots.append({"overlay": overlay})

func set_player(p: Node) -> void:
	_player = p

func _process(_delta: float) -> void:
	if _player == null or _ability_slots.size() < 6:
		return
	# Slot 0: Tail Whip cooldown
	var whip_pct: float = clampf(_player._whip_timer / _player.TAIL_WHIP_COOLDOWN, 0.0, 1.0)
	_ability_slots[0].overlay.color = Color(0, 0, 0, whip_pct * 0.72)
	# Slot 1: Bubble Beam cooldown
	var bubble_pct: float = clampf(_player._bubble_beam_timer / _player.BUBBLE_BEAM_COOLDOWN, 0.0, 1.0)
	_ability_slots[1].overlay.color = Color(0, 0, 0, bubble_pct * 0.72)
	# Slot 5: Dash cooldown
	var dash_pct: float = clampf(_player._dash_cooldown_timer / _player.DASH_COOLDOWN, 0.0, 1.0)
	_ability_slots[5].overlay.color = Color(0, 0, 0, dash_pct * 0.72)

func update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func update_mana(current: int, maximum: int) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d MP" % [current, maximum]

func update_experience(current: int, needed: int) -> void:
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
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
