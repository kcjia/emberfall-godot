extends "res://Scripts/enemy_base.gd"

const PRIEST_HARM_SCENE: PackedScene = preload("res://Scene/SkillScene/Priest_Harm.tscn")
const PRIEST_TREAT_SCENE: PackedScene = preload("res://Scene/SkillScene/Priest_Treat.tscn")

# 敌人存活时保持锁定；无敌人时选择需要治疗的友军。
func _update_target_detection() -> void:
	if _has_valid_target():
		return
	target = _find_nearest_enemy()
	if not is_instance_valid(target):
		target = _find_lowest_health_ally()

# 判断目标是否在牧师的侦测施法范围内（复用基类同帧重叠缓存）。
func _is_any_attack_range_reaching_target() -> bool:
	if not is_instance_valid(target) or not is_instance_valid(detection_area):
		return false
	return _get_all_targets(detection_area).has(target)

# 让 DetectionArea 同时检测敌人和同阵营友军。
func _apply_custom_layer_config(target_mask: int) -> void:
	if not is_instance_valid(detection_area):
		return
	var own_layer_mask := 1 << (2 if is_system_spawned else 1)
	detection_area.collision_mask = target_mask | own_layer_mask

# 根据检测范围内可用目标选择攻击或治疗招式。
func _try_select_and_perform_attack() -> bool:
	if not can_attack or not is_instance_valid(detection_area):
		return false

	var has_enemy := is_instance_valid(_find_nearest_enemy())
	var has_ally := is_instance_valid(_find_lowest_health_ally())
	if not has_enemy and not has_ally:
		return false

	var available_states: Array[State] = []
	var available_weights: Array[float] = []
	if has_enemy and attack1_weight > 0.0:
		available_states.append(State.ATTACK1)
		available_weights.append(attack1_weight)
	if has_ally and attack2_weight > 0.0:
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

# 在 DetectionArea 内查找距离最近的敌方目标。
func _find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF
	for candidate in _get_all_targets(detection_area):
		if not _is_valid_enemy(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = candidate
	return nearest_enemy

# 在 DetectionArea 内查找当前生命值最低且未满血的友军。
func _find_lowest_health_ally() -> Node2D:
	var lowest_ally: Node2D = null
	var lowest_health := INF
	for candidate in _get_all_targets(detection_area):
		if not _is_valid_ally(candidate):
			continue
		var current_value = candidate.get("current_health")
		var max_value = candidate.get("max_health")
		if current_value == null or max_value == null or current_value >= max_value:
			continue
		if current_value < lowest_health:
			lowest_health = current_value
			lowest_ally = candidate
	return lowest_ally

# 判断候选节点是否为可攻击的敌方目标。
func _is_valid_enemy(candidate: Node2D) -> bool:
	if candidate == self or not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
		return false
	return not ("is_system_spawned" in candidate and candidate.is_system_spawned == is_system_spawned)

# 判断候选节点是否为同阵营且可治疗的友军；排除基地，只治疗士兵单位。
func _is_valid_ally(candidate: Node2D) -> bool:
	if candidate == self or not is_instance_valid(candidate) or not candidate is EnemyBase:
		return false
	if not ("is_system_spawned" in candidate and candidate.is_system_spawned == is_system_spawned):
		return false
	return "current_health" in candidate and "max_health" in candidate

# 在动画结束后按招式生成治疗或伤害特效并结算效果。
func _on_custom_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Attack1":
		_cast_priest_harm()
	elif anim_name == &"Attack2":
		_cast_priest_treat()

# 在锁定敌人的当前位置生成 Priest_Harm 并造成攻击伤害。
func _cast_priest_harm() -> void:
	if not _has_valid_target():
		return
	_spawn_priest_effect(PRIEST_HARM_SCENE, target.global_position)
	target.take_damage(attack_damage)

# 在最低血量友军的当前位置生成 Priest_Treat 并恢复攻击伤害数值的生命。
func _cast_priest_treat() -> void:
	var ally := _find_lowest_health_ally()
	if not is_instance_valid(ally):
		return
	_spawn_priest_effect(PRIEST_TREAT_SCENE, ally.global_position)
	var current_value: float = ally.get("current_health")
	var max_value: float = ally.get("max_health")
	ally.set("current_health", minf(current_value + attack_damage, max_value))
	var health_bar = ally.get("currenthealth")
	if is_instance_valid(health_bar):
		health_bar.value = ally.get("current_health")
	var progress_bar = ally.get("progress_bar")
	if is_instance_valid(progress_bar):
		progress_bar.value = ally.get("current_health")
	if ally.has_signal("health_changed"):
		ally.emit_signal("health_changed", ally.get("current_health"), max_value)

# 在指定位置生成牧师技能特效，并在特效播放后清理节点。
func _spawn_priest_effect(effect_scene: PackedScene, effect_position: Vector2) -> void:
	var effect = effect_scene.instantiate()
	get_parent().add_child(effect)
	effect.global_position = effect_position
	var effect_sprite = effect.get_node_or_null("AnimatedSprite2D")
	if effect_sprite:
		effect_sprite.play("default")
	get_tree().create_timer(0.5).timeout.connect(effect.queue_free)


# 锁定攻击状态并清空本次挥砍的已命中记录。
func start_attack() -> void:
	if not can_attack or current_state == State.HURT or current_state == State.DEATH:
		return
	is_attacking = true
	if randf() < 0.25: # 25% 概率触发说话
		var battle_cries: Array[String] = []
		match current_state:
			State.ATTACK1:
				battle_cries = ["赎罪吧！", "无痛！", "看招！"]
			State.ATTACK2:
				battle_cries = ["退后！", "身残志坚！", "进攻！"]
			State.ATTACK3:
				battle_cries = ["结束了！", "接下这一击！", "毁灭吧！"]
		if not battle_cries.is_empty():
			pop_speech_bubble(battle_cries.pick_random())
	# 重置受击敌人列表
	hit_enemies_in_current_swing.clear()