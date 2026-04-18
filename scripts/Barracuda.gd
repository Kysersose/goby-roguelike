extends CharacterBody2D

signal died

enum State { CHASE, RAPID_DASH, CHOMP_WINDUP }

const SPEED: float = 175.0
const RAPID_DASH_SPEED: float = 800.0
const RAPID_DASH_DURATION: float = 1.0
const RAPID_DASH_COOLDOWN: float = 10.0
const RAPID_DASH_CHARGES: int = 2
const RAPID_DASH_RANGE: float = 350.0
const CHOMP_WINDUP: float = 0.75
const CHOMP_DAMAGE: int = 7
const CHOMP_REACH: float = 90.0
const XP_REWARD: int = 150

var max_hp: float = 200.0
var hp: float = 200.0

var _state: int = State.CHASE
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_charges: int = RAPID_DASH_CHARGES
var _dash_dir: Vector2 = Vector2.ZERO
var _chomp_timer: float = 0.0

var _stun_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0
var _player: CharacterBody2D = null

@onready var body: Polygon2D = $Body
var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _player == null:
		return

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, delta * 4.0)
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

	match _state:
		State.CHOMP_WINDUP:
			_chomp_timer -= delta
			velocity = Vector2.ZERO
			move_and_slide()
			if _chomp_timer <= 0.0:
				_execute_chomp()

		State.RAPID_DASH:
			_dash_timer -= delta
			velocity = _dash_dir * RAPID_DASH_SPEED
			move_and_slide()
			_check_chomp_contact()
			if _dash_timer <= 0.0 and _state == State.RAPID_DASH:
				_end_dash()

		State.CHASE:
			if _dash_cooldown_timer > 0.0:
				_dash_cooldown_timer -= delta
				if _dash_cooldown_timer <= 0.0:
					_dash_charges = RAPID_DASH_CHARGES
			var dir := (_player.global_position - global_position).normalized()
			velocity = dir * SPEED
			move_and_slide()
			_check_chomp_contact()
			var dist := global_position.distance_to(_player.global_position)
			if _dash_charges > 0 and _dash_cooldown_timer <= 0.0 and dist <= RAPID_DASH_RANGE:
				_start_rapid_dash()

func _start_rapid_dash() -> void:
	_state = State.RAPID_DASH
	_dash_dir = (_player.global_position - global_position).normalized()
	_dash_timer = RAPID_DASH_DURATION
	_dash_charges -= 1

func _end_dash() -> void:
	# Use second charge immediately in succession
	if _dash_charges > 0:
		_start_rapid_dash()
		return
	_dash_cooldown_timer = RAPID_DASH_COOLDOWN
	_state = State.CHASE

func _check_chomp_contact() -> void:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == _player:
			_state = State.CHOMP_WINDUP
			_chomp_timer = CHOMP_WINDUP
			velocity = Vector2.ZERO
			return

func _execute_chomp() -> void:
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= CHOMP_REACH:
		_player.take_damage(CHOMP_DAMAGE)
	_state = State.CHASE

func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity = impulse * 0.5
	_knockback_timer = 0.15

func take_damage(amount: float, _counted: bool = true) -> void:
	hp -= amount
	_stun_timer = 0.1
	_spawn_damage_number(amount)
	if hp <= 0.0:
		if _player != null:
			_player.add_experience(XP_REWARD)
		died.emit()
		queue_free()

func _spawn_damage_number(amount: float) -> void:
	var n := _dmg_num_scene.instantiate()
	n.global_position = global_position + Vector2(randf_range(-15, 15), -40)
	get_tree().current_scene.add_child(n)
	n.setup(roundi(amount), Color(1.0, 0.5, 0.0))
