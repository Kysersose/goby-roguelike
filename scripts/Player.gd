extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int)
signal level_changed(level: int)
signal died

const SPEED: float = 150.0
const TARGET_SIZE: float = 128.0
const TAIL_WHIP_DAMAGE: float = 2.5
const TAIL_WHIP_RANGE: float = 100.0
const TAIL_WHIP_COOLDOWN: float = 0.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var max_hp: int = 20
var hp: int = 20
var xp: int = 0
var level: int = 1
var _last_anim: String = "swim_down"
var _whip_timer: float = 0.0
var _attacking: bool = false

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
	experience_changed.emit(xp, _xp_for_level(level))
	sprite.animation_finished.connect(_on_animation_finished)

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()

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

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

func _on_animation_finished() -> void:
	if sprite.animation == "tail_whip":
		_attacking = false
		sprite.play(_last_anim)
		sprite.pause()

func _physics_process(delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not _attacking:
		if holding and to_mouse.length() > 1.0:
			var dir := to_mouse.normalized()
			velocity = dir * SPEED

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
	if Input.is_action_just_pressed("ui_accept") and _whip_timer <= 0.0:
		_tail_whip()
		_whip_timer = TAIL_WHIP_COOLDOWN

func _tail_whip() -> void:
	_attacking = true
	sprite.play("tail_whip")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= TAIL_WHIP_RANGE:
			enemy.take_damage(TAIL_WHIP_DAMAGE)
