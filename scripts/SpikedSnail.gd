extends CharacterBody2D

signal died

const SPEED: float = 18.0
const STOP_DIST: float = 55.0
const CONTACT_DAMAGE: int = 6
const DAMAGE_COOLDOWN: float = 1.0
const XP_REWARD: int = 25

const SHELL_INTERVAL: float = 7.0
const SHELL_DURATION: float = 3.0
const SPIKE_FIRE_INTERVAL: float = 1.5
const SPIKE_COUNT: int = 8

const COLOR_NORMAL: Color = Color(0.5, 0.38, 0.28)
const COLOR_IMMUNE: Color = Color(0.72, 0.2, 0.9)

var max_hp: float = 12.5
var hp: float = 12.5
var _damage_timer: float = 0.0
var _stun_timer: float = 0.0
var _shell_timer: float = 0.0
var _in_shell: bool = false
var _shell_duration_timer: float = 0.0
var _spike_fire_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0
var _player: CharacterBody2D = null

@onready var body: Polygon2D = $Body

var _spike_scene: PackedScene = preload("res://scenes/Spike.tscn")
var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("elite_enemies")
	_player = get_tree().get_first_node_in_group("player")
	body.color = COLOR_NORMAL

func _physics_process(delta: float) -> void:
	if _player == null:
		return

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 6.0)
		velocity = _knockback_velocity
		move_and_slide()
		if _stun_timer > 0.0:
			_stun_timer -= delta
		return

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _in_shell:
		_shell_duration_timer -= delta
		_spike_fire_timer -= delta
		if _spike_fire_timer <= 0.0:
			_shoot_spikes()
			_spike_fire_timer = SPIKE_FIRE_INTERVAL
		if _shell_duration_timer <= 0.0:
			_exit_shell()
		velocity = Vector2.ZERO
	else:
		_shell_timer -= delta
		if _shell_timer <= 0.0:
			_enter_shell()
		var dir := (_player.global_position - global_position).normalized()
		var dist := global_position.distance_to(_player.global_position)
		velocity = dir * SPEED if dist > STOP_DIST else Vector2.ZERO

	move_and_slide()

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() == _player:
				_player.take_damage(CONTACT_DAMAGE)
				_damage_timer = DAMAGE_COOLDOWN
				break

func _enter_shell() -> void:
	_in_shell = true
	_shell_duration_timer = SHELL_DURATION
	_spike_fire_timer = 0.0
	body.color = COLOR_IMMUNE

func _exit_shell() -> void:
	_in_shell = false
	_shell_timer = SHELL_INTERVAL
	body.color = COLOR_NORMAL

func _shoot_spikes() -> void:
	if _player == null:
		return
	var base_angle := (_player.global_position - global_position).angle()
	var half_cone := deg_to_rad(32.5)
	for i in SPIKE_COUNT:
		var t := float(i) / float(SPIKE_COUNT - 1)
		var angle: float = base_angle + lerp(-half_cone, half_cone, t)
		var dir := Vector2(cos(angle), sin(angle))
		var spike = _spike_scene.instantiate()
		spike.global_position = global_position
		spike.direction = dir
		spike.source = self
		get_tree().current_scene.add_child(spike)

func hide_in_sand() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8)
	tween.tween_callback(queue_free)

func apply_knockback(impulse: Vector2) -> void:
	if _in_shell:
		return
	_knockback_velocity = impulse
	_knockback_timer = 0.2

func take_damage(amount: float, _counted: bool = true) -> void:
	if _in_shell:
		return
	hp -= amount
	_stun_timer = 0.25
	_spawn_damage_number(amount)
	if hp <= 0.0:
		if _player != null:
			_player.add_experience(XP_REWARD)
		died.emit()
		queue_free()

func _spawn_damage_number(amount: float) -> void:
	var n := _dmg_num_scene.instantiate()
	n.global_position = global_position + Vector2(randf_range(-10, 10), -25)
	get_tree().current_scene.add_child(n)
	n.setup(roundi(amount), Color(1.0, 0.85, 0.2))
