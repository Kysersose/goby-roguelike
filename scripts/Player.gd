extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int)
signal level_changed(level: int)
signal died

const TARGET_SIZE: float = 128.0
const TAIL_WHIP_RANGE: float = 100.0
const TAIL_WHIP_COOLDOWN: float = 0.5
const DASH_DURATION: float = 0.25
const DASH_SPEED_MULTIPLIER: float = 2.0
const DASH_COOLDOWN: float = 5.0
const ZOOM_STEP: float = 0.1
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 2.0

var speed: float = 150.0
var tail_whip_damage: float = 2.5
var intelligence: int = 0
var defense: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

var max_hp: int = 20
var hp: int = 20
var max_mp: int = 10
var mp: int = 10
var xp: int = 0
var level: int = 1
var _last_anim: String = "swim_down"
var _whip_timer: float = 0.0
var _attacking: bool = false
var _dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	var tex := sprite.sprite_frames.get_frame_texture(_last_anim, 0)
	if tex != null:
		var size := tex.get_size()
		var longest := maxf(size.x, size.y)
		if longest > 0.0:
			var s := TARGET_SIZE / longest
			sprite.scale = Vector2(s, s)
	sprite.play(_last_anim)
	sprite.pause()
	health_changed.emit(hp, max_hp)
	mana_changed.emit(mp, max_mp)
	experience_changed.emit(xp, _xp_for_level(level))
	sprite.animation_finished.connect(_on_animation_finished)

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
		sprite.play(_last_anim)
		sprite.pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				if not _dashing and _whip_timer <= 0.0:
					_tail_whip()
					_whip_timer = TAIL_WHIP_COOLDOWN
			KEY_2, KEY_3, KEY_4, KEY_5:
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

func _physics_process(delta: float) -> void:
	if _dashing:
		_dash_timer -= delta
		velocity = _dash_direction * speed * DASH_SPEED_MULTIPLIER
		if _dash_timer <= 0.0:
			_dashing = false
		move_and_slide()
		return

	var to_mouse := get_global_mouse_position() - global_position
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not _attacking:
		if holding and to_mouse.length() > 1.0:
			var dir := to_mouse.normalized()
			velocity = dir * speed

			var anim: String
			if absf(dir.x) > absf(dir.y):
				anim = "swim_right" if dir.x > 0.0 else "swim_left"
			else:
				anim = "swim_down" if dir.y > 0.0 else "swim_up"

			if anim != _last_anim:
				_last_anim = anim
				sprite.play(anim)
			elif not sprite.is_playing():
				sprite.play(anim)
		else:
			velocity = Vector2.ZERO
			sprite.pause()

	move_and_slide()
	_whip_timer -= delta
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

func _tail_whip() -> void:
	_attacking = true
	sprite.play("tail_whip")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= TAIL_WHIP_RANGE:
			enemy.take_damage(tail_whip_damage)
