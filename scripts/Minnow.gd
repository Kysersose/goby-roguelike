extends CharacterBody2D

signal died(counted: bool)

const SPEED: float = 50.0
const DAMAGE: int = 2
const DAMAGE_COOLDOWN: float = 1.0
const RETREAT_SPEED: float = 90.0
const RETREAT_DURATION: float = 0.5
const DASH_SPEED: float = 300.0
const DASH_DURATION: float = 0.3
const DASH_COOLDOWN: float = 5.0
const DASH_RANGE: float = 147.0

var max_hp: float = 5.0
var hp: float = 5.0
var _damage_timer: float = 0.0
var _stun_timer: float = 0.0
var _retreat_timer: float = 0.0
var _dash_cooldown_timer: float = DASH_COOLDOWN
var _dash_active_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _is_dashing: bool = false
var _player: CharacterBody2D = null
var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("normal_enemies")
	_player = get_tree().get_first_node_in_group("player")
	_dash_cooldown_timer = 0.0

func _physics_process(delta: float) -> void:
	if _player == null:
		return

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := (_player.global_position - global_position).normalized()

	if _is_dashing:
		_dash_active_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		if _dash_active_timer <= 0.0:
			_is_dashing = false
			_retreat_timer = RETREAT_DURATION
	elif _retreat_timer > 0.0:
		_retreat_timer -= delta
		velocity = -dir * RETREAT_SPEED
	else:
		_dash_cooldown_timer -= delta
		var dist := global_position.distance_to(_player.global_position)
		if _dash_cooldown_timer <= 0.0 and dist <= DASH_RANGE:
			_is_dashing = true
			_dash_dir = dir
			_dash_active_timer = DASH_DURATION
			_dash_cooldown_timer = DASH_COOLDOWN
		else:
			velocity = dir * SPEED

	move_and_slide()

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() == _player:
				_player.take_damage(DAMAGE)
				_damage_timer = DAMAGE_COOLDOWN
				_is_dashing = false
				_retreat_timer = RETREAT_DURATION
				break

func take_damage(amount: float, counted: bool = true) -> void:
	hp -= amount
	_stun_timer = 0.25
	_spawn_damage_number(amount)
	if hp <= 0.0:
		if _player != null and counted:
			_player.add_experience(10)
		died.emit(counted)
		queue_free()

func _spawn_damage_number(amount: float) -> void:
	var n := _dmg_num_scene.instantiate()
	n.global_position = global_position + Vector2(randf_range(-8, 8), -20)
	get_tree().current_scene.add_child(n)
	n.setup(roundi(amount), Color.YELLOW)
