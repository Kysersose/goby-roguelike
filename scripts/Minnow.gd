extends CharacterBody2D

const SPEED: float = 20.0
const DAMAGE: int = 2
const DAMAGE_COOLDOWN: float = 1.0

var max_hp: float = 5.0
var hp: float = 5.0
var _damage_timer: float = 0.0
var _stun_timer: float = 0.0
var _player: CharacterBody2D = null

func _ready() -> void:
	add_to_group("enemies")
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

func take_damage(amount: float) -> void:
	hp -= amount
	_stun_timer = 0.25
	if hp <= 0.0:
		if _player != null:
			_player.add_experience(10)
		queue_free()
