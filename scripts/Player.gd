extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal experience_changed(current: int, needed: int)
signal level_changed(level: int)
signal died
signal ability_slot_changed(slot_index: int, ability_name: String)

const TAIL_WHIP_COOLDOWN: float = 0.5
const TAIL_WHIP_WIND_UP: float = 0.15
const TAIL_WHIP_KNOCKBACK: float = 400.0
const TAIL_WHIP_HITBOX_OFFSET: float = 90.0
const TAIL_WHIP_RANGE: float = 150.0
const HIT_STOP_DURATION: float = 0.05
const HIT_STOP_SCALE: float = 0.05
const DASH_DURATION: float = 0.25
const DASH_SPEED_MULTIPLIER: float = 2.0
const DASH_ANIM_SPEED_SCALE: float = 3.0
const ZOOM_STEP: float = 0.1
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 2.0
const BUBBLE_BEAM_COOLDOWN: float = 4.0
const BUBBLE_BEAM_MANA_COST: int = 3
const BUBBLE_BEAM_COUNT: int = 3
const BUBBLE_BEAM_INTERVAL: float = 0.2
const HP_REGEN_INTERVAL: float = 10.0
const MP_REGEN_INTERVAL: float = 10.0
const STAMINA_REGEN_INTERVAL: float = 1.0
const DASH_STAMINA_COST: float = 50.0
const CHOMP_COOLDOWN: float = 4.0
const CHOMP_MANA_COST: int = 3
const CHOMP_DAMAGE: float = 5.0
const CHOMP_RANGE: float = 90.0
const CHOMP_WINDUP_TIME: float = 0.25

var speed: float = 200.0
var tail_whip_damage: float = 2.5
var special_damage: float = 0.0
var intelligence: int = 0
var defense: int = 0
var stamina_regen_bonus: int = 0
var luck: int = 0
var ability_slots: Array = ["tail_whip", "bubble_beam", "", "", ""]
var has_rapid_dash: bool = false
var _rapid_dash_queued: bool = false

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
var max_stamina: float = 100.0
var stamina: float = 100.0
var xp: int = 0
var level: int = 1
var _last_anim: String = "swim_down"
var _whip_timer: float = 0.0
var _whip_damage_pending: bool = false
var _whip_damage_timer: float = 0.0
var _attacking: bool = false
var _dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.DOWN
var _bubble_beam_timer: float = 0.0
var _bubble_shots_remaining: int = 0
var _bubble_shot_timer: float = 0.0
var _bubble_direction: Vector2 = Vector2.RIGHT
var _hp_regen_timer: float = 0.0
var _mp_regen_timer: float = 0.0
var _stamina_regen_timer: float = 0.0
var _chomp_cooldown_timer: float = 0.0
var _chomp_windup_active: bool = false
var _chomp_windup_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_play_anim(_last_anim)
	sprite.pause()
	health_changed.emit(hp, max_hp)
	mana_changed.emit(mp, max_mp)
	stamina_changed.emit(stamina, max_stamina)
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
		"stamina_regen_rate":
			stamina_regen_bonus += int(amount)
		"luck":
			luck += int(amount)

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
			KEY_1: _activate_slot(0)
			KEY_2: _activate_slot(1)
			KEY_3: _activate_slot(2)
			KEY_4: _activate_slot(3)
			KEY_5: _activate_slot(4)
			KEY_SPACE:
				if has_rapid_dash and _dashing and not _rapid_dash_queued:
					_rapid_dash_queued = true
				else:
					_dash()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var z := clampf(camera.zoom.x - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			camera.zoom = Vector2(z, z)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var z := clampf(camera.zoom.x + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			camera.zoom = Vector2(z, z)

func _cancel_dash() -> void:
	if not _dashing:
		return
	_dashing = false
	_dash_timer = 0.0
	_rapid_dash_queued = false
	sprite.speed_scale = 1.0
	sprite.pause()

func _dash(free: bool = false) -> void:
	if _dashing:
		return
	if not free and stamina < DASH_STAMINA_COST:
		return
	if not free:
		stamina -= DASH_STAMINA_COST
		stamina_changed.emit(stamina, max_stamina)
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
			sprite.pause()
			if _rapid_dash_queued:
				_rapid_dash_queued = false
				_dash(true)
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
	if _bubble_beam_timer > 0.0:
		_bubble_beam_timer -= delta
	if _bubble_shots_remaining > 0:
		_bubble_shot_timer -= delta
		if _bubble_shot_timer <= 0.0:
			_fire_bubble()
			_bubble_shots_remaining -= 1
			_bubble_shot_timer = BUBBLE_BEAM_INTERVAL

	_hp_regen_timer += delta
	if _hp_regen_timer >= HP_REGEN_INTERVAL:
		_hp_regen_timer = 0.0
		if hp < max_hp:
			heal(maxi(roundi(max_hp * 0.05), 1))

	_mp_regen_timer += delta
	if _mp_regen_timer >= MP_REGEN_INTERVAL:
		_mp_regen_timer = 0.0
		if mp < max_mp:
			restore_mana(maxi(roundi(max_mp * 0.05), 1))

	_stamina_regen_timer += delta
	if _stamina_regen_timer >= STAMINA_REGEN_INTERVAL:
		_stamina_regen_timer = 0.0
		if stamina < max_stamina:
			stamina = minf(stamina + max_stamina * (0.05 + stamina_regen_bonus / 100.0), max_stamina)
			stamina_changed.emit(stamina, max_stamina)

	if _chomp_cooldown_timer > 0.0:
		_chomp_cooldown_timer -= delta
	if _chomp_windup_active:
		_chomp_windup_timer -= delta
		if _chomp_windup_timer <= 0.0:
			_execute_chomp()

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
	var base_angle := aim_dir.angle()
	var light_color := Color(0.55, 0.85, 1.0, 0.75)
	var dark_color := Color(0.1, 0.3, 0.75, 0.75)

	var slash := Node2D.new()
	slash.position = origin
	slash.scale = Vector2(0.3, 0.3)
	scene_root.add_child(slash)

	for _c in 12:
		var offset_angle := randf_range(-25.0, 25.0)
		var dist := randf_range(15.0, TAIL_WHIP_RANGE)
		var cluster_center := Vector2(cos(base_angle + deg_to_rad(offset_angle)), sin(base_angle + deg_to_rad(offset_angle))) * dist

		for _p in 9:
			var pt := cluster_center + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
			var dot := Line2D.new()
			dot.points = PackedVector2Array([pt, pt + Vector2(3.0, 3.0)])
			dot.width = 3.0
			dot.default_color = light_color
			dot.begin_cap_mode = Line2D.LINE_CAP_BOX
			dot.end_cap_mode = Line2D.LINE_CAP_BOX
			slash.add_child(dot)

		for _p in 3:
			var pt := cluster_center + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
			var dot := Line2D.new()
			dot.points = PackedVector2Array([pt, pt + Vector2(3.0, 3.0)])
			dot.width = 3.0
			dot.default_color = dark_color
			dot.begin_cap_mode = Line2D.LINE_CAP_BOX
			dot.end_cap_mode = Line2D.LINE_CAP_BOX
			slash.add_child(dot)

	var slash_tween := slash.create_tween()
	slash_tween.tween_property(slash, "scale", Vector2(1.0, 1.0), 0.06)
	slash_tween.tween_property(slash, "modulate:a", 0.0, 0.12)
	slash_tween.tween_callback(slash.queue_free)

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

func _activate_slot(idx: int) -> void:
	match ability_slots[idx]:
		"tail_whip":
			if _whip_timer <= 0.0:
				_cancel_dash()
				_tail_whip()
				_whip_timer = TAIL_WHIP_COOLDOWN
		"bubble_beam":
			_cancel_dash()
			_activate_bubble_beam()
		"chomp":
			_cancel_dash()
			_activate_chomp()

func _activate_chomp() -> void:
	if _chomp_cooldown_timer > 0.0 or _chomp_windup_active:
		return
	if not use_mana(CHOMP_MANA_COST):
		return
	_chomp_cooldown_timer = CHOMP_COOLDOWN
	_chomp_windup_active = true
	_chomp_windup_timer = CHOMP_WINDUP_TIME

func _execute_chomp() -> void:
	_chomp_windup_active = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= CHOMP_RANGE:
			enemy.take_damage(CHOMP_DAMAGE + special_damage)
			if enemy.has_method("apply_knockback"):
				var dir: Vector2 = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(dir * TAIL_WHIP_KNOCKBACK)

func get_first_free_slot() -> int:
	for i in ability_slots.size():
		if ability_slots[i] == "":
			return i
	return -1

func assign_ability_to_slot(slot_index: int, ability: String) -> void:
	ability_slots[slot_index] = ability
	ability_slot_changed.emit(slot_index, ability)
