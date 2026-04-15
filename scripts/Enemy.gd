extends CharacterBody2D

const SPEED: float = 60.0
const DAMAGE: int = 2
const DAMAGE_COOLDOWN: float = 1.0

var max_hp: int = 5
var hp: int = 5
var _damage_timer: float = 0.0
var _player: CharacterBody2D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _player == null:
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
