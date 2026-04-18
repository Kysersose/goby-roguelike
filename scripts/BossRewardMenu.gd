extends CanvasLayer

signal reward_chosen(type: String, slot: int)

const INPUT_GRACE_PERIOD: float = 0.35

var _player: Node = null
var _accepting_input: bool = false

func setup(player: Node) -> void:
	_player = player

func _ready() -> void:
	_build_main_panel()
	get_tree().create_timer(INPUT_GRACE_PERIOD).timeout.connect(func() -> void:
		_accepting_input = true
	)

func _build_main_panel() -> void:
	var card_container: HBoxContainer = $Control/CardContainer
	card_container.add_theme_constant_override("separation", 24)

	var cards := [
		{
			"title": "Rapid Dash",
			"color": Color(1.0, 0.85, 0.1),
			"desc": "Dash twice in\nsuccession.\nDouble-tap SPACE.\nNo extra stamina.",
			"type": "rapid_dash",
		},
		{
			"title": "Chomp",
			"color": Color(1.0, 0.3, 0.2),
			"desc": "New special attack.\nDamages nearby\nenemies.\n3 MP  •  4s cooldown",
			"type": "chomp",
		},
		{
			"title": "Status\nUpgrade",
			"color": Color(0.65, 0.2, 1.0),
			"desc": "Choose a free\nstat upgrade from\nyour level-up pool.",
			"type": "status_upgrade",
		},
	]

	for card_def in cards:
		_build_card(card_container, card_def)

func _build_card(container: HBoxContainer, card_def: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_color = card_def["color"]
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = card_def["title"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(name_lbl)

	var divider := ColorRect.new()
	divider.color = card_def["color"]
	divider.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(divider)

	var desc_lbl := Label.new()
	desc_lbl.text = card_def["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc_lbl)

	var reward_type: String = card_def["type"]
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if not _accepting_input:
			return
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
			_on_card_clicked(reward_type)
	)

	container.add_child(panel)

func _on_card_clicked(type: String) -> void:
	if type == "chomp":
		var free_slot := _get_free_slot()
		if free_slot >= 0:
			reward_chosen.emit(type, free_slot)
			queue_free()
		else:
			_show_slot_picker()
	else:
		reward_chosen.emit(type, -1)
		queue_free()

func _get_free_slot() -> int:
	for i in _player.ability_slots.size():
		if _player.ability_slots[i] == "":
			return i
	return -1

func _show_slot_picker() -> void:
	$Control/CardContainer.modulate.a = 0.3

	var picker := VBoxContainer.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picker.add_theme_constant_override("separation", 10)
	$Control.add_child(picker)

	var title := Label.new()
	title.text = "Replace which ability?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	picker.add_child(title)

	var slot_display := {
		"tail_whip":   "Tail Whip",
		"bubble_beam": "Bubble Beam",
		"chomp":       "Chomp",
		"":             "—",
	}

	for i in _player.ability_slots.size():
		var ability: String = _player.ability_slots[i]
		var btn := Button.new()
		btn.text = "[%d]  %s" % [i + 1, slot_display.get(ability, ability.capitalize())]
		btn.custom_minimum_size = Vector2(240, 40)
		var slot_index :int = i
		btn.pressed.connect(func() -> void:
			reward_chosen.emit("chomp", slot_index)
			queue_free()
		)
		picker.add_child(btn)
