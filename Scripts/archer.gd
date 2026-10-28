extends "res://Scripts/enemy_base.gd"

const ARCHER_ARROW_SCENE: PackedScene = preload("res://Scene/SkillScene/Archer_Arrow.tscn")
const ARROW_TEXTURE_01: Texture2D = preload("res://Image/Arrow01.png")
const ARROW_TEXTURE_02: Texture2D = preload("res://Image/Arrow02.png")
const ARROW_TEXTURE_03: Texture2D = preload("res://Image/Arrow03.png")

@export_group("弓兵技能伤害")
@export var attack1_damage: int = 120
@export var attack2_damage: int = 80
@export var attack3_damage: int = 180

@export_group("弓兵箭矢飞行")
@export var arrow1_speed: float = 400.0
@export var arrow1_arc: float = 60.0
@export var arrow2_speed: float = 500.0
@export var arrow2_arc: float = 40.0
@export var arrow3_speed: float = 300.0
@export var arrow3_arc: float = 100.0

@onready var spell_marker: Marker2D = get_node_or_null("Marker2D")

# 仅在当前目标失效时锁定侦测范围内最近的敌人。
func _update_target_detection() -> void:
	if not _has_valid_target():
		target = _find_nearest_enemy()

# 判断敌人是否位于弓兵的侦测射击范围内（复用基类同帧重叠缓存）。
func _is_any_attack_range_reaching_target() -> bool:
	if not is_instance_valid(target) or not is_instance_valid(detection_area):
		return false
	return _get_all_targets(detection_area).has(target)

# 按攻击权重选择一种射击并开始播放对应动画。
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
	if attack3_weight > 0.0:
		available_states.append(State.ATTACK3)
		available_weights.append(attack3_weight)
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

# 在动画结束时发射对应箭矢。
func _on_custom_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Attack1":
		_cast_arrow(ARROW_TEXTURE_01, attack1_damage, arrow1_speed, arrow1_arc)
	elif anim_name == &"Attack2":
		_cast_arrow(ARROW_TEXTURE_02, attack2_damage, arrow2_speed, arrow2_arc)
	elif anim_name == &"Attack3":
		_cast_arrow(ARROW_TEXTURE_03, attack3_damage, arrow3_speed, arrow3_arc)

# 从 Marker2D 位置发射一支抛物线箭矢，飞向当前锁定目标。
func _cast_arrow(arrow_texture: Texture2D, base_damage: int, speed: float, arc_height: float) -> void:
	if not _has_valid_target() or not is_instance_valid(spell_marker):
		return
	var arrow = ARCHER_ARROW_SCENE.instantiate()
	get_parent().add_child(arrow)
	if arrow.has_method("setup"):
		arrow.setup(spell_marker.global_position, target, is_system_spawned, int(base_damage * _get_player_damage_multiplier()), speed, arc_height, arrow_texture)
	else:
		arrow.global_position = spell_marker.global_position
