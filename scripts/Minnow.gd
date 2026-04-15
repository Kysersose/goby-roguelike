extends CharacterBody2D

signal died(counted: bool)

const SPEED: float = 25.0
const DAMAGE: int = 2
const DAMAGE_COOLDOWN: float = 1.0

var max_hp: float = 5.0
var hp: float = 5.0
var _damage_timer: float = 0.0
var _stun_timer: float = 0.0
var _player: CharacterBody2D = null
var _dmg_num_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("normal_enemies")
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _player == null:
		return

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * SPEED
	move_and_slide()

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() == _player:
				_player.take_damage(DAMAGE)
				_damage_timer = DAMAGE_COOLDOWN
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
