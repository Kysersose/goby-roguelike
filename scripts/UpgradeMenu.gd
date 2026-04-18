extends CanvasLayer

signal upgrade_chosen(stat: String, amount: float)

const UPGRADES := [
	{"name": "Tail Fin",     "stat": "tail_whip_damage",  "label": "Damage",
	 "values": {"Common": 0.5, "Rare": 1.0, "Epic": 1.5, "Legendary": 2.5}},
	{"name": "Girth",        "stat": "max_hp",            "label": "Max HP",
	 "values": {"Common": 2,   "Rare": 4,   "Epic": 6,   "Legendary": 10}},
	{"name": "Forehead",     "stat": "intelligence",      "label": "Intelligence",
	 "values": {"Common": 1,   "Rare": 2,   "Epic": 3,   "Legendary": 5}},
	{"name": "Scales",       "stat": "defense",           "label": "Defense",
	 "values": {"Common": 1,   "Rare": 2,   "Epic": 3,   "Legendary": 5}},
	{"name": "Aerodynamics", "stat": "speed",             "label": "Speed",
	 "values": {"Common": 10,  "Rare": 20,  "Epic": 35,  "Legendary": 50}},
	{"name": "Big Brain",    "stat": "special_damage",    "label": "Ability Damage",
	 "values": {"Common": 0.5, "Rare": 1.0, "Epic": 1.5, "Legendary": 2.5}},
	{"name": "Gills",        "stat": "stamina_regen_rate","label": "Stamina Regen %",
	 "values": {"Common": 3,   "Rare": 5,   "Epic": 8,   "Legendary": 15}},
	{"name": "Luck",         "stat": "luck",              "label": "Luck",
	 "values": {"Common": 1,   "Rare": 2,   "Epic": 3,   "Legendary": 5}},
]

const RARITIES        := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_WEIGHTS  := [60,       25,      12,      3]
const RARITY_COLORS   := {
	"Common":    Color(0.2,  0.75, 0.2),
	"Rare":      Color(0.2,  0.5,  1.0),
	"Epic":      Color(0.65, 0.2,  1.0),
	"Legendary": Color(1.0,  0.55, 0.1),
}

const INPUT_GRACE_PERIOD: float = 0.35

@onready var card_container: HBoxContainer = $Control/CardContainer

var luck: int = 0
var _accepting_input: bool = false

func _ready() -> void:
	card_container.add_theme_constant_override("separation", 24)
	var picks := _generate_picks()
	for pick in picks:
		_build_card(pick)
	get_tree().create_timer(INPUT_GRACE_PERIOD).timeout.connect(func() -> void:
		_accepting_input = true
	)

func _generate_picks() -> Array:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	var picks := []
	for i in 3:
		picks.append({"upgrade": pool[i], "rarity": _random_rarity()})
	return picks

func _random_rarity() -> String:
	# Each luck point shifts 3 weight from Common to the higher rarities (+1 each).
	var weights := []
	for i in RARITY_WEIGHTS.size():
		if i == 0:
			weights.append(maxi(RARITY_WEIGHTS[i] - luck * 3, 0))
		else:
			weights.append(RARITY_WEIGHTS[i] + luck)
	var total := 0
	for w in weights:
		total += w
	var roll := randi() % total
	var cumulative := 0
	for i in RARITIES.size():
		cumulative += weights[i]
		if roll < cumulative:
			return RARITIES[i]
	return "Common"

func _build_card(pick: Dictionary) -> void:
	var upgrade: Dictionary = pick["upgrade"]
	var rarity: String      = pick["rarity"]
	var amount: float       = upgrade["values"][rarity]
	var color: Color        = RARITY_COLORS[rarity]

	var amount_str: String
	if amount == int(amount):
		amount_str = "+%d" % int(amount)
	else:
		amount_str = "+%.1f" % amount

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.border_color = color
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
	name_lbl.text = upgrade["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity.to_upper()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_color_override("font_color", color)
	rarity_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(rarity_lbl)

	var divider := ColorRect.new()
	divider.color = color
	divider.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(divider)

	var value_lbl := Label.new()
	value_lbl.text = "%s %s" % [amount_str, upgrade["label"]]
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(value_lbl)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if not _accepting_input:
			return
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
			upgrade_chosen.emit(upgrade["stat"], amount)
			queue_free()
	)

	card_container.add_child(panel)
