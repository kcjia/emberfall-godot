extends "res://Scripts/enemy_base.gd"

@export_group("Attack2 位移")
@export var attack2_dash_duration: float = 0.5
@export var attack2_dash_speed: float = 240.0

var attack2_dash_time_left: float = 0.0
var attack2_dash_collision_mask: int = 0
var is_ignoring_enemy_collision: bool = false

# 在 Attack2 第二段伤害时触发冲刺，并执行父类伤害逻辑。
func deal_swing_damage(is_new_segment: bool = false, custom_multiplier: float = 1.0) -> void:
	super.deal_swing_damage(is_new_segment, custom_multiplier)

	if current_state == State.ATTACK2 and is_new_segment:
		attack2_dash_time_left = attack2_dash_duration
		_disable_enemy_collision_for_dash()

# 在冲刺期间控制前进，并在攻击结束后清理状态。
func _custom_physics_process(delta: float) -> bool:
	if current_state != State.ATTACK2:
		attack2_dash_time_left = 0.0
		_restore_enemy_collision_after_dash()
		return false

	if attack2_dash_time_left <= 0.0:
		_restore_enemy_collision_after_dash()
		return false

	attack2_dash_time_left -= delta
	velocity.x = (-1.0 if is_system_spawned else 1.0) * attack2_dash_speed
	return true

# 缓存碰撞掩码并临时忽略敌方单位碰撞。
func _disable_enemy_collision_for_dash() -> void:
	if is_ignoring_enemy_collision:
		return

	attack2_dash_collision_mask = collision_mask
	var enemy_layer = 2 if is_system_spawned else 3
	collision_mask &= ~(1 << (enemy_layer - 1))
	is_ignoring_enemy_collision = true

# 恢复冲刺前缓存的碰撞掩码。
func _restore_enemy_collision_after_dash() -> void:
	if not is_ignoring_enemy_collision:
		return

	collision_mask = attack2_dash_collision_mask
	is_ignoring_enemy_collision = false

