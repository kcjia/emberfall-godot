extends "res://Scripts/enemy_base.gd"

const WIZARD_HARM_SCENE: PackedScene = preload("res://Scene/SkillScene/Wizard_Harm.tscn")
const WIZARD_FIREBALL_SCENE: PackedScene = preload("res://Scene/SkillScene/Wizard_FireBall.tscn")

@export_group("法师技能伤害")
@export var attack1_damage: int = 250
@export var attack2_damage: int = 100

@export_group("法师技能节点")
@export var fireball_speed: float = 300.0
@export var fireball_max_distance: float = 600.0

@onready var spell_marker: Marker2D = get_node_or_null("Marker2D")

# 仅在当前目标失效时锁定侦测范围内最近的敌人。
func _update_target_detection() -> void:
	if not _has_valid_target():
		target = _find_nearest_enemy()

# 判断敌人是否位于法师的侦测施法范围内（复用基类同帧重叠缓存）。
func _is_any_attack_range_reaching_target() -> bool:
	if not is_instance_valid(target) or not is_instance_valid(detection_area):
		return false
	return _get_all_targets(detection_area).has(target)

# 按攻击权重选择一种法术并开始播放对应动画。
func _try_select_and_perform_attack() -> bool:
	if not can_attack or not is_instance_valid(target):
		return false
	var available_states: Array[State] = []
	var available_weights: Array[float] = []
	if attack1_weight > 0.0:
		available_states.append(State.ATTACK1)
		available_weights.append(attack1_weight)
	if attack2_weight > 0.0:
		available_states.append(State.ATTACK2)
		available_weights.append(attack2_weight)
	if available_states.is_empty():
		return false

	var total_weight := 0.0
	for weight in available_weights:
		total_weight += weight
	var roll := randf_range(0.0, total_weight)
	var accumulated_weight := 0.0
	var chosen_state: State = available_states[0]
	for index in range(available_states.size()):
		accumulated_weight += available_weights[index]
		if roll <= accumulated_weight:
			chosen_state = available_states[index]
			break

	change_state(chosen_state)
	start_attack()
	return true

# 返回侦测范围内最近的敌方目标。
func _find_nearest_enemy() -> Node2D:
	if not is_instance_valid(detection_area):
		return null
	var nearest_enemy: Node2D = null
	var nearest_distance := INF
	for candidate in _get_all_targets(detection_area):
		if not _is_valid_candidate(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = candidate
	return nearest_enemy

# 在动画结束时释放对应法术并结算伤害。
func _on_custom_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Attack1":
		_cast_attack1_harm()
	elif anim_name == &"Attack2":
		_cast_attack2_fireball()

# 在锁定目标的位置生成法师的 Attack1 伤害特效。
func _cast_attack1_harm() -> void:
	if not _has_valid_target():
		return
	var effect = WIZARD_HARM_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = target.global_position
	target.take_damage(int(attack1_damage * _get_player_damage_multiplier()))
	get_tree().create_timer(0.7).timeout.connect(effect.queue_free)

# 从 Marker2D 位置生成火球，并沿法师朝向飞行。
func _cast_attack2_fireball() -> void:
	if not is_instance_valid(spell_marker):
		return
	var fireball = WIZARD_FIREBALL_SCENE.instantiate()
	get_parent().add_child(fireball)
	var direction := Vector2(-1.0 if is_system_spawned else 1.0, 0.0)
	if fireball.has_method("setup"):
		fireball.setup(spell_marker.global_position, direction, is_system_spawned, int(attack2_damage * _get_player_damage_multiplier()), fireball_speed, fireball_max_distance)
	else:
		fireball.global_position = spell_marker.global_position
