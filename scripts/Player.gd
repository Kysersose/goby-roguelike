extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int)
signal level_changed(level: int)
signal died

const TAIL_WHIP_COOLDOWN: float = 0.5
const TAIL_WHIP_WIND_UP: float = 0.15
const TAIL_WHIP_KNOCKBACK: float = 400.0
const TAIL_WHIP_HITBOX_OFFSET: float = 60.0
const TAIL_WHIP_RANGE: float = 100.0
const HIT_STOP_DURATION: float = 0.05
const HIT_STOP_SCALE: float = 0.05
const DASH_DURATION: float = 0.25
const DASH_SPEED_MULTIPLIER: float = 2.0
const DASH_COOLDOWN: float = 5.0
const DASH_ANIM_SPEED_SCALE: float = 3.0
const ZOOM_STEP: float = 0.1
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 2.0
const BUBBLE_BEAM_COOLDOWN: float = 4.0
const BUBBLE_BEAM_MANA_COST: int = 3
const BUBBLE_BEAM_COUNT: int = 3
const BUBBLE_BEAM_INTERVAL: float = 0.2

var speed: float = 200.0
var tail_whip_damage: float = 2.5
var special_damage: float = 0.0
var intelligence: int = 0
var defense: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var tail_whip_hitbox: Area2D = $TailWhipHitbox
@onready var tail_whip_hitbox_shape: CollisionShape2D = $TailWhipHitbox/CollisionShape2D

var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")
var _bubble_scene: PackedScene = preload("res://scenes/Bubble.tscn")

var max_hp: int = 20
var hp: int = 20
var max_mp: int = 10
var mp: int = 10
var xp: int = 0
var level: int = 1
var _last_anim: String = "swim_down"
var _whip_timer: float = 0.0
var _whip_damage_pending: bool = false
var _whip_damage_timer: float = 0.0
var _attacking: bool = false
var _dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.DOWN
var _bubble_beam_timer: float = 0.0
var _bubble_shots_remaining: int = 0
var _bubble_shot_timer: float = 0.0
var _bubble_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("player")
	_play_anim(_last_anim)
	sprite.pause()
	health_changed.emit(hp, max_hp)
	mana_changed.emit(mp, max_mp)
	experience_changed.emit(xp, _xp_for_level(level))
	sprite.animation_finished.connect(_on_animation_finished)

# idle_right and swim_right reuse the left-facing frames mirrored — all other
# animations must render unflipped.
func _play_anim(anim_name: String) -> void:
	sprite.flip_h = (anim_name == "idle_right" or anim_name == "swim_right")
	sprite.play(anim_name)

func take_damage(amount: int) -> void:
	if _dashing:
		return
	var reduction := clampf(defense * 0.05, 0.0, 0.95)
	var actual := maxi(roundi(amount * (1.0 - reduction)), 1)
	hp = maxi(hp - actual, 0)
	health_changed.emit(hp, max_hp)
	_spawn_damage_number(actual)
	if hp <= 0:
		died.emit()

func _spawn_damage_number(amount: int) -> void:
	var n := _dmg_num_scene.instantiate()
	n.global_position = global_position + Vector2(randf_range(-12, 12), -40)
	get_tree().current_scene.add_child(n)
	n.setup(amount, Color(1.0, 0.25, 0.1))

func _xp_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 50

func add_experience(amount: int) -> void:
	xp += amount
	var needed := _xp_for_level(level)
	while xp >= needed:
		xp -= needed
		level += 1
		level_changed.emit(level)
		needed = _xp_for_level(level)
	experience_changed.emit(xp, needed)

func apply_upgrade(stat: String, amount: float) -> void:
	match stat:
		"tail_whip_damage":
			tail_whip_damage += amount
		"max_hp":
			max_hp += int(amount)
			hp = mini(hp + int(amount), max_hp)
			health_changed.emit(hp, max_hp)
		"intelligence":
			intelligence += int(amount)
			max_mp += int(amount) * 2
			mp = mini(mp + int(amount) * 2, max_mp)
			mana_changed.emit(mp, max_mp)
		"defense":
			defense += int(amount)
		"speed":
			speed += amount
		"special_damage":
			special_damage += amount

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

func use_mana(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	mana_changed.emit(mp, max_mp)
	return true

func restore_mana(amount: int) -> void:
	mp = mini(mp + amount, max_mp)
	mana_changed.emit(mp, max_mp)

func _on_animation_finished() -> void:
	if sprite.animation == "tail_whip":
		_attacking = false
		tail_whip_hitbox_shape.disabled = true
		_play_anim(_last_anim)
		sprite.pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				if not _dashing and _whip_timer <= 0.0:
					_tail_whip()
					_whip_timer = TAIL_WHIP_COOLDOWN
			KEY_2:
				_activate_bubble_beam()
			KEY_3, KEY_4, KEY_5:
				pass # reserved for future abilities
			KEY_SPACE:
				_dash()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var z := clampf(camera.zoom.x - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			camera.zoom = Vector2(z, z)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var z := clampf(camera.zoom.x + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			camera.zoom = Vector2(z, z)

func _dash() -> void:
	if _dashing or _dash_cooldown_timer > 0.0:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		_dash_direction = to_mouse.normalized()
	else:
		match _last_anim:
			"swim_right": _dash_direction = Vector2.RIGHT
			"swim_left":  _dash_direction = Vector2.LEFT
			"swim_up":    _dash_direction = Vector2.UP
			_:            _dash_direction = Vector2.DOWN
	_dashing = true
	_dash_timer = DASH_DURATION
	_dash_cooldown_timer = DASH_COOLDOWN
	var dash_anim: String
	if absf(_dash_direction.x) > absf(_dash_direction.y):
		dash_anim = "swim_right" if _dash_direction.x > 0.0 else "swim_left"
	else:
		dash_anim = "swim_down" if _dash_direction.y > 0.0 else "swim_up"
	_last_anim = dash_anim
	_play_anim(dash_anim)
	sprite.speed_scale = DASH_ANIM_SPEED_SCALE

func _physics_process(delta: float) -> void:
	if _dashing:
		_dash_timer -= delta
		velocity = _dash_direction * speed * DASH_SPEED_MULTIPLIER
		if _dash_timer <= 0.0:
			_dashing = false
			sprite.speed_scale = 1.0
		move_and_slide()
		return

	var to_mouse := get_global_mouse_position() - global_position
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not _attacking:
		if holding and to_mouse.length() > 1.0:
			var dir := to_mouse.normalized()
			velocity = velocity.lerp(dir * speed, delta * 4.0)

			var anim: String
			if absf(dir.x) > absf(dir.y):
				anim = "swim_right" if dir.x > 0.0 else "swim_left"
			else:
				anim = "swim_down" if dir.y > 0.0 else "swim_up"

			if anim != _last_anim:
				_last_anim = anim
				_play_anim(anim)
			elif not sprite.is_playing():
				_play_anim(anim)
		else:
			velocity = velocity.lerp(Vector2.ZERO, delta * 2.5)
			if not holding:
				var anim: String
				if absf(to_mouse.y) > absf(to_mouse.x):
					anim = "idle_up" if to_mouse.y < 0.0 else "idle_down"
				else:
					anim = "idle_right" if to_mouse.x >= 0.0 else "idle_left"
				if anim != _last_anim:
					_last_anim = anim
					_play_anim(anim)
				elif not sprite.is_playing():
					_play_anim(anim)
			else:
				sprite.pause()

	move_and_slide()
	_whip_timer -= delta
	if _whip_damage_pending:
		_whip_damage_timer -= delta
		if _whip_damage_timer <= 0.0:
			_whip_damage_pending = false
			_resolve_tail_whip()
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _bubble_beam_timer > 0.0:
		_bubble_beam_timer -= delta
	if _bubble_shots_remaining > 0:
		_bubble_shot_timer -= delta
		if _bubble_shot_timer <= 0.0:
			_fire_bubble()
			_bubble_shots_remaining -= 1
			_bubble_shot_timer = BUBBLE_BEAM_INTERVAL

func _activate_bubble_beam() -> void:
	if _bubble_beam_timer > 0.0 or _bubble_shots_remaining > 0:
		return
	if not use_mana(BUBBLE_BEAM_MANA_COST):
		return
	_bubble_direction = (get_global_mouse_position() - global_position).normalized()
	_bubble_beam_timer = BUBBLE_BEAM_COOLDOWN
	_fire_bubble()
	_bubble_shots_remaining = BUBBLE_BEAM_COUNT - 1
	_bubble_shot_timer = BUBBLE_BEAM_INTERVAL

func _fire_bubble() -> void:
	var b := _bubble_scene.instantiate()
	b.global_position = global_position
	b.setup(_bubble_direction, special_damage)
	get_tree().current_scene.add_child(b)

func _tail_whip() -> void:
	_attacking = true
	_play_anim("tail_whip")
	_whip_damage_pending = true
	_whip_damage_timer = TAIL_WHIP_WIND_UP
	var aim := get_global_mouse_position() - global_position
	var aim_dir := aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	tail_whip_hitbox.rotation = aim_dir.angle()
	tail_whip_hitbox.position = aim_dir * TAIL_WHIP_HITBOX_OFFSET
	tail_whip_hitbox_shape.disabled = false
	_spawn_tail_whip_vfx(aim_dir)

func _spawn_tail_whip_vfx(aim_dir: Vector2) -> void:
	var scene_root := get_tree().current_scene
	var origin := global_position
	var impact_point := origin + aim_dir * TAIL_WHIP_HITBOX_OFFSET
	var base_angle := aim_dir.angle()

	# Main slash cone — 5 aqua spread lines plus 2 white edge borders.
	var slash := Node2D.new()
	slash.position = origin
	slash.scale = Vector2(0.3, 0.3)
	scene_root.add_child(slash)

	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 1.0 / 5.0))
	var slash_color := Color(0.2, 0.9, 0.85, 0.9)
	var border_color := Color(1.0, 1.0, 1.0, 0.5)

	for offset_deg in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var line := Line2D.new()
		line.rotation = base_angle + deg_to_rad(offset_deg)
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(TAIL_WHIP_RANGE, 0.0)])
		line.width = 5.0
		line.width_curve = taper
		line.default_color = slash_color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		slash.add_child(line)

	for offset_deg in [-60.0, 60.0]:
		var border := Line2D.new()
		border.rotation = base_angle + deg_to_rad(offset_deg)
		border.points = PackedVector2Array([Vector2.ZERO, Vector2(TAIL_WHIP_RANGE, 0.0)])
		border.width = 2.0
		border.default_color = border_color
		border.begin_cap_mode = Line2D.LINE_CAP_ROUND
		border.end_cap_mode = Line2D.LINE_CAP_ROUND
		slash.add_child(border)

	var slash_tween := slash.create_tween()
	slash_tween.tween_property(slash, "scale", Vector2(1.0, 1.0), 0.06)
	slash_tween.tween_property(slash, "modulate:a", 0.0, 0.12)
	slash_tween.tween_callback(slash.queue_free)

	# Hit spark — 5 short white lines radiating from the impact point.
	var burst := Node2D.new()
	burst.position = impact_point
	scene_root.add_child(burst)

	var burst_color := Color(1.0, 1.0, 1.0, 0.8)
	for i in 5:
		var line := Line2D.new()
		line.rotation = deg_to_rad(i * 72.0)
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(18.0, 0.0)])
		line.width = 3.0
		line.default_color = burst_color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		burst.add_child(line)

	var burst_tween := burst.create_tween()
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.08)
	burst_tween.tween_callback(burst.queue_free)

func _resolve_tail_whip() -> void:
	var hit_any := false
	for area in tail_whip_hitbox.get_overlapping_areas():
		var enemy := area.get_parent()
		if enemy == null or not enemy.is_in_group("enemies"):
			continue
		enemy.take_damage(tail_whip_damage)
		if enemy.has_method("apply_knockback"):
			var enemy_dir: Vector2 = (enemy.global_position - global_position).normalized()
			enemy.apply_knockback(enemy_dir * TAIL_WHIP_KNOCKBACK)
		hit_any = true
	if hit_any:
		_do_hit_stop()

func _do_hit_stop() -> void:
	Engine.time_scale = HIT_STOP_SCALE
	var t := get_tree().create_timer(HIT_STOP_DURATION, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)
