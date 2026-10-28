class_name EnemyBase
extends CharacterBody2D

# --- 1. 枚举与状态管理 ---
enum State { 
	IDLE,    # 待机状态
	WALK,    # 移动/行军状态
	ATTACK1, # 攻击方式1
	ATTACK2, # 攻击方式2
	ATTACK3, # 攻击方式3
	HURT,    # 受击硬直状态
	DEATH    # 死亡状态
}

enum Attack3TargetMode {
	SINGLE_TARGET,
	AREA
}

var current_state: State = State.IDLE

# --- 2. 基础属性设置 ---
@export_group("基础属性")
@export var character_name: String = ""
#@export var defense_value: int = 10
@export var attack_cooldown: float = 1.0

@export_group("Attack3 伤害目标")
## 单体使用当前锁定目标；范围使用 Attack3Area 内的所有敌人。
@export var attack3_target_mode: Attack3TargetMode = Attack3TargetMode.SINGLE_TARGET

@export_group("攻击权重设置")
## Attack1 (普攻) 触发权重
@export var attack1_weight: float = 50.0
## Attack2 触发权重
@export var attack2_weight: float = 30.0
## Attack3 (重击/大招) 触发权重 (调低此数值以降低触发概率)
@export var attack3_weight: float = 20.0

# --- 阵营与战斗控制变量 ---
var max_health: int = 100
var move_speed: float = 80.0
var attack_damage: int = 10
var is_system_spawned: bool = false
var is_attacking: bool = false
var current_health: int
# 不声明强类型，避免已释放节点在传入有效性检查前触发类型转换错误。
var target = null
var can_attack: bool = true
var is_invincible: bool = false

## 【核心改进】：记录本次挥砍中已经受到过伤害的敌人列表，支持 AoE 群伤且防止单次挥砍重复扣血
var hit_enemies_in_current_swing: Array[Node2D] = []

## 同一物理帧内复用重叠查询结果：每帧多次调用 get_overlapping_* 会重复分配数组，
## 单位多时开销明显；缓存以物理帧号为键，帧切换时自动失效。
var _overlap_frame: int = -1
var _overlap_cache: Dictionary = {}

# --- 3. 节点引用 ---
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var currenthealth: ProgressBar = get_node_or_null("CurrentHealth")

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var attack_detector: Area2D = get_node_or_null("AttackArea")
@onready var attack2_area: Area2D = get_node_or_null("Attack2Area")
@onready var attack3_area: Area2D = get_node_or_null("Attack3Area")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var damage_label: Label = get_node_or_null("DamageLabel")
# 预加载气泡预制体
const SPEECH_BUBBLE = preload("res://Scene/speech_bubble.tscn")

# 初始化生命、阵营碰撞、信号连接与初始行军状态。
func _ready() -> void:
	character_name = _resolve_character_name()
	_apply_character_attributes()
	currenthealth.max_value = max_health
	currenthealth.value = max_health
	current_health = max_health
	_setup_health_bar_juice()
	

	apply_layer_config(3 if is_system_spawned else 2)
	update_facing_direction()

	if attack_detector:
		attack_detector.body_entered.connect(_on_attack_detector_body_entered)
		attack_detector.body_exited.connect(_on_attack_detector_body_exited)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)


	_setup_custom_nodes()
	change_state(State.WALK)

# 优先使用 Inspector 中的角色名，否则使用角色场景文件名。
func _resolve_character_name() -> String:
	if not character_name.is_empty():
		return character_name
	var scene_path := scene_file_path
	if not scene_path.is_empty():
		return scene_path.get_file().get_basename()
	return name

# 按“角色名_属性名”从集中配置表加载已登记的基础属性。
func _apply_character_attributes() -> void:
	var configured_health = CharacterStats.get_attribute(character_name, "max_health")
	var configured_speed = CharacterStats.get_attribute(character_name, "move_speed")
	var configured_damage = CharacterStats.get_attribute(character_name, "attack_damage")
	var configured_cooldown = CharacterStats.get_attribute(character_name, "attack_cooldown")
	if configured_health != null:
		max_health = int(configured_health)
	if configured_speed != null:
		move_speed = float(configured_speed)
	if configured_damage != null:
		attack_damage = int(configured_damage)
	if configured_cooldown != null:
		attack_cooldown = float(configured_cooldown)

# 配置自身和攻击区域的阵营碰撞层，友军之间不产生物理阻挡。
func apply_layer_config(layer_num: int) -> void:
	collision_layer = 1 << (layer_num - 1)
	var enemy_target_layer = 2 if layer_num == 3 else 3
	
	collision_mask = (1 << 0) | (1 << (enemy_target_layer - 1))
	
	var target_mask = 1 << (enemy_target_layer - 1)
	var all_areas = [attack_detector, attack2_area, attack3_area, detection_area]
	for a in all_areas:
		if is_instance_valid(a):
			a.collision_layer = 0
			a.collision_mask = target_mask
			a.monitoring = true
			a.monitorable = true

	# 通知子类配置特有区域 (如 Attack2Area, Attack3Area)
	_apply_custom_layer_config(target_mask)

# 将单位设为系统阵营并刷新场景内的碰撞和朝向。
func setup_as_system_enemy() -> void:
	is_system_spawned = true
	if is_inside_tree():
		apply_layer_config(3)
		update_facing_direction()
	
# 外部调用的玩家刷怪配置接口
# 将单位设为玩家阵营并刷新碰撞和朝向。
func setup_as_player_enemy() -> void:
	is_system_spawned = false
	apply_layer_config(2)
	update_facing_direction()

# 根据阵营翻转精灵、碰撞体和攻击区域方向。
func update_facing_direction() -> void:
	var facing_left = is_system_spawned
	if sprite:
		sprite.flip_h = facing_left
	
	var dir_sign = -1.0 if facing_left else 1.0
	
	# 翻转角色自身的碰撞体中心（如果有偏移）
	if collision_shape:
		collision_shape.position.x = abs(collision_shape.position.x) * dir_sign
	
	# 翻转所有 Area2D 内部的 CollisionShape2D / CollisionPolygon2D
	var all_areas = [attack_detector, attack2_area, attack3_area, detection_area]
	for a in all_areas:
		if is_instance_valid(a):
			if a.position.x != 0:
				a.position.x = abs(a.position.x) * dir_sign
			for child in a.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.position.x = abs(child.position.x) * dir_sign

	_update_custom_facing_direction(dir_sign)

## 物理帧主循环
# 驱动敌人的重力、寻敌、行军、攻击和自定义移动状态机。
func _physics_process(delta: float) -> void:
	if currenthealth:
		currenthealth.value = clamp(current_health, 0, max_health)
		_update_health_bar_juice(delta)

	if current_state == State.DEATH or current_state == State.HURT:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if _custom_physics_process(delta):
		move_and_slide()
		return

	if not is_attacking:
		_update_target_detection()

		if is_instance_valid(target):
			var can_reach = _is_any_attack_range_reaching_target()
			if can_reach:
				velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)
				if can_attack:
					_try_select_and_perform_attack()
				elif current_state != State.IDLE:
					change_state(State.IDLE)
			else:
				_move_towards_target(delta)
		else:
			var move_direction = -1.0 if is_system_spawned else 1.0
			velocity.x = move_direction * move_speed
			if current_state != State.WALK:
				change_state(State.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)

	move_and_slide()

# 判断基础攻击范围是否已接触当前目标。
func _is_any_attack_range_reaching_target() -> bool:
	if not is_instance_valid(target):
		return false
	if _attack_area_contains_target(attack_detector):
		return true
	# if attack2_area and attack2_area.get_overlapping_bodies().has(target):
	# 	return true
	# if attack3_area and attack3_area.get_overlapping_bodies().has(target):
	# 	return true
	return false

# 按目标类型检查指定攻击区域是否包含当前目标（复用同帧重叠缓存）。
func _attack_area_contains_target(area: Area2D) -> bool:
	if not is_instance_valid(area) or not is_instance_valid(target):
		return false
	return _get_all_targets(area).has(target)

# --- 1. 目标检测与刷新 ---
# 仅在当前目标死亡或失效时，锁定侦测范围内最近的敌方目标。
func _update_target_detection() -> void:
	if _has_valid_target():
		return
	target = null
	var check_area = detection_area if detection_area else attack_detector
	if not is_instance_valid(check_area):
		return

	var nearest_distance := INF
	for candidate in _get_all_targets(check_area):
		if not _is_valid_candidate(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = candidate

# 判断成员目标是否仍存活、敌对且可继续锁定。
func _has_valid_target() -> bool:
	return _is_valid_candidate(target)

# 判断候选节点是否存活、敌对且可成为锁定目标。
func _is_valid_candidate(candidate) -> bool:
	if not is_instance_valid(candidate) or not candidate is Node2D:
		return false
	if candidate == self or not candidate.has_method("take_damage"):
		return false
	if "is_system_spawned" in candidate and candidate.is_system_spawned == is_system_spawned:
		return false
	if "current_health" in candidate and candidate.current_health <= 0:
		return false
	return true

# --- 2. 招式选择 ---
# 按攻击范围与权重随机选择并启动一次攻击。
func _try_select_and_perform_attack() -> bool:
	if not can_attack or not is_instance_valid(target):
		return false
		# 记录所有距离够得着的招式及其对应的配置权重
	var valid_attacks: Array[State] = []
	var valid_weights: Array[float] = []
	var total_weight: float = 0.0	# 1. 检查 Attack1
	if _attack_area_contains_target(attack_detector):
		if attack1_weight > 0:
			valid_attacks.append(State.ATTACK1)
			valid_weights.append(attack1_weight)
			total_weight += attack1_weight

	# 2. 检查 Attack2
	if _attack_area_contains_target(attack2_area):
		if attack2_weight > 0:
			valid_attacks.append(State.ATTACK2)
			valid_weights.append(attack2_weight)
			total_weight += attack2_weight

	# 3. 检查 Attack3
	if _attack_area_contains_target(attack3_area):
		if attack3_weight > 0:
			valid_attacks.append(State.ATTACK3)
			valid_weights.append(attack3_weight)
			total_weight += attack3_weight

	# 4. 如果没有可用招式，返回 false
	if valid_attacks.is_empty() or total_weight <= 0.0:
		return false

	# 5. 加权随机抽取
	var roll = randf_range(0.0, total_weight)
	var accumulated_weight = 0.0
	var chosen_attack: State = valid_attacks[0]

	for i in range(valid_attacks.size()):
		accumulated_weight += valid_weights[i]
		if roll <= accumulated_weight:
			chosen_attack = valid_attacks[i]
			break

	change_state(chosen_attack)
	start_attack()
	return true

# 朝当前目标行军。
func _move_towards_target(_delta: float) -> void:
	var dir = -1.0 if target.global_position.x < global_position.x else 1.0
	if current_state != State.WALK:
		change_state(State.WALK)
		
	velocity.x = dir * move_speed

# --- 3. 状态机与攻击 ---
# 切换战斗状态并播放对应动画。
func change_state(new_state: State) -> void:
	if current_state == State.DEATH:
		return
		
	current_state = new_state
	
	match current_state:
		State.IDLE: play_animation("Idle")
		State.WALK: play_animation("Walk")
		State.ATTACK1: play_animation("Attack1")
		State.ATTACK2: play_animation("Attack2")
		State.ATTACK3: play_animation("Attack3")
		State.HURT: play_animation("Hurt")
		State.DEATH: play_animation("Death")

# 锁定攻击状态并清空本次挥砍的已命中记录。
func start_attack() -> void:
	if not can_attack or current_state == State.HURT or current_state == State.DEATH:
		return
	is_attacking = true
	if randf() < 0.25: # 25% 概率触发说话
		var battle_cries: Array[String] = []
		match current_state:
			State.ATTACK1:
				battle_cries = ["受死吧！", "斩！", "看招！"]
			State.ATTACK2:
				battle_cries = ["退后！", "尝尝这个！", "别想逃！"]
			State.ATTACK3:
				battle_cries = ["结束了！", "接下这一击！", "毁灭吧！"]
		if not battle_cries.is_empty():
			pop_speech_bubble(battle_cries.pick_random())
	# 重置受击敌人列表
	hit_enemies_in_current_swing.clear()

# 在 AnimationPlayer 的关键帧调用，结算当前招式选择的伤害目标。
func deal_swing_damage(is_new_segment: bool = false, custom_multiplier: float = 1.0) -> void:
	if not is_attacking:
		return
		
	# 如果是新的一段攻击，先重置受击名单
	if is_new_segment:
		hit_enemies_in_current_swing.clear()

	for damage_target in _get_damage_targets():
		_apply_damage_to_target(damage_target, custom_multiplier)

# 获取本次伤害目标；子类可覆写此方法实现技能特有选敌逻辑。
func _get_damage_targets() -> Array[Node2D]:
	if current_state == State.ATTACK3 and attack3_target_mode == Attack3TargetMode.AREA:
		return _get_all_targets(attack3_area)
	if is_instance_valid(target):
		return [target]
	return []

# 对单个目标结算一次伤害并防止同一段攻击重复命中。
func _apply_damage_to_target(entity: Node2D, custom_multiplier: float) -> void:
	if entity == self or not is_instance_valid(entity) or not entity.has_method("take_damage"):
		return
	if entity is EnemyBase and entity.is_system_spawned == is_system_spawned:
		return
	if hit_enemies_in_current_swing.has(entity):
		return
	hit_enemies_in_current_swing.append(entity)
	entity.take_damage(int(attack_damage * custom_multiplier))

# 供自定义技能按指定区域结算范围伤害。
func _apply_aoe_damage_to_area(area: Area2D, custom_multiplier: float) -> void:
	if not area:
		return
	for entity in _get_all_targets(area):
		_apply_damage_to_target(entity, custom_multiplier)

# 在冷却计时结束后重新允许攻击。
func start_attack_cooldown() -> void:
	can_attack = false
	var tree = get_tree()
	if tree:
		await tree.create_timer(attack_cooldown).timeout
	can_attack = true

# 扣除生命、显示伤害并处理受击或死亡状态。
func take_damage(amount: int) -> void:
	if current_state == State.DEATH or is_invincible:
		return
		
	current_health -= amount
	_flash_hit()
	show_damage_number(amount)

	if current_health <= 0:
		die()
	else:
		if _can_enter_hurt():
			is_attacking = false
			change_state(State.HURT)

# 切换技能期间的无敌状态，可在 AnimationPlayer 中调用两次开关。
func toggle_invincibility() -> void:
	is_invincible = not is_invincible

var damage_tween: Tween

# 血条表现：主条按血量变色（绿→黄→红）+ 白色残影条（掉血后缓慢追赶，补血瞬间跟上）。
var _health_fill_stylebox: StyleBoxFlat = null
var _ghost_health_bar: ProgressBar = null
var _flash_tween: Tween = null

func _setup_health_bar_juice() -> void:
	if not is_instance_valid(currenthealth):
		return
	# 沿用场景里原有的填充样式，只改颜色，避免覆盖圆角等外观。
	var orig_fill := currenthealth.get_theme_stylebox("fill")
	if orig_fill is StyleBoxFlat:
		_health_fill_stylebox = orig_fill.duplicate() as StyleBoxFlat
	else:
		_health_fill_stylebox = StyleBoxFlat.new()
		# 原填充不是扁平样式时，从背景偷圆角，避免方形填充从圆角背景里漏出来。
		var orig_bg := currenthealth.get_theme_stylebox("background")
		if orig_bg is StyleBoxFlat:
			_health_fill_stylebox.corner_radius_top_left = orig_bg.corner_radius_top_left
			_health_fill_stylebox.corner_radius_top_right = orig_bg.corner_radius_top_right
			_health_fill_stylebox.corner_radius_bottom_right = orig_bg.corner_radius_bottom_right
			_health_fill_stylebox.corner_radius_bottom_left = orig_bg.corner_radius_bottom_left
	currenthealth.add_theme_stylebox_override("fill", _health_fill_stylebox)
	# 残影条：直接复制主条节点（布局与主条完全一致，避免新建节点尺寸走样），
	# 改名防重名、自带染色清零、强制垫底，掉血时慢慢追赶。
	_ghost_health_bar = currenthealth.duplicate() as ProgressBar
	_ghost_health_bar.name = "GhostHealthBar"
	_ghost_health_bar.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	_ghost_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_health_bar.z_index = -1
	_ghost_health_bar.min_value = 0.0
	_ghost_health_bar.max_value = max_health
	_ghost_health_bar.value = max_health
	_ghost_health_bar.show_percentage = false
	var ghost_bg := StyleBoxFlat.new()
	ghost_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_ghost_health_bar.add_theme_stylebox_override("background", ghost_bg)
	# 残影填充直接复制主条填充再改白，圆角与主条完全一致，不会从圆角外漏出白角。
	var ghost_fill := _health_fill_stylebox.duplicate() as StyleBoxFlat
	ghost_fill.bg_color = Color(1.0, 1.0, 1.0, 0.9)
	_ghost_health_bar.add_theme_stylebox_override("fill", ghost_fill)
	add_child(_ghost_health_bar)
	move_child(_ghost_health_bar, currenthealth.get_index())
	if is_instance_valid(damage_label):
		damage_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		damage_label.add_theme_constant_override("outline_size", 3)

func _update_health_bar_juice(delta: float) -> void:
	if not is_instance_valid(currenthealth):
		return
	var hp_ratio := 0.0
	if max_health > 0:
		hp_ratio = clampf(current_health / max_health, 0.0, 1.0)
	if _health_fill_stylebox != null:
		if hp_ratio > 0.5:
			_health_fill_stylebox.bg_color = Color(0.3, 0.85, 0.4)
		elif hp_ratio > 0.25:
			_health_fill_stylebox.bg_color = Color(1.0, 0.8, 0.2)
		else:
			_health_fill_stylebox.bg_color = Color(1.0, 0.25, 0.2)
	if is_instance_valid(_ghost_health_bar):
		if currenthealth.value > _ghost_health_bar.value:
			_ghost_health_bar.value = currenthealth.value
		else:
			_ghost_health_bar.value = move_toward(_ghost_health_bar.value, currenthealth.value, max_health * delta * 0.5)

# 受击瞬间把精灵调成过曝白，0.15 秒内恢复（受击闪白）。
func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

# 显示并播放受伤数字的浮动淡出动画。
# 按伤害量分档：小伤害黄白小字，中伤害橙字，大伤害（≥100）红字放大、飘得更高更久。
func show_damage_number(amount: int) -> void:
	if not is_instance_valid(damage_label):
		return

	if damage_tween and damage_tween.is_running():
		damage_tween.kill()

	# 1. 按伤害量定颜色与弹字大小
	var dmg_color := Color(1.0, 0.85, 0.4, 1.0)
	var pop_scale := Vector2(1.1, 1.1)
	var rise := 20.0
	var fade_time := 0.5
	if amount >= 100:
		dmg_color = Color(1.0, 0.25, 0.2, 1.0)
		pop_scale = Vector2(1.5, 1.5)
		rise = 32.0
		fade_time = 0.7
	elif amount >= 30:
		dmg_color = Color(1.0, 0.6, 0.15, 1.0)
		pop_scale = Vector2(1.25, 1.25)

	# 2. 设置文本与显示状态
	damage_label.text = "-%d" % amount
	damage_label.modulate = dmg_color
	damage_label.visible = true

	# 3. 初始位置：复位到头顶默认相对位置（带微小水平随机偏移）
	var base_y: float = -25.0
	var random_x: float = randf_range(-6.0, 6.0)
	damage_label.position = Vector2(random_x, base_y)
	damage_label.scale = Vector2(0.8, 0.8)

	# 4. 创建 Tween 动画（如果前一个飘字动画没播完，先杀掉旧动画）
	damage_tween = create_tween()
	damage_tween.set_parallel(true)

	# 向上漂浮
	damage_tween.tween_property(damage_label, "position:y", base_y - rise, fade_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 瞬间拉大字号弹效果
	damage_tween.tween_property(damage_label, "scale", pop_scale, 0.12)
	# 淡出消失
	damage_tween.tween_property(damage_label, "modulate:a", 0.0, fade_time).set_delay(0.15)

	# 5. 动画结束后隐藏 Label 备用
	damage_tween.chain().tween_callback(func():
		if is_instance_valid(damage_label):
			damage_label.visible = false
	)

# 处理死亡奖励、禁用碰撞和子类死亡扩展。
func die() -> void:
	is_attacking = false
	change_state(State.DEATH)
	
	# 如果击杀的是系统敌怪，按击杀金币给玩家奖励金币并保存。
	# 基础 1 金 + 击杀金币等级（每级 +1），0 级也不再是 0 金。
	if is_system_spawned:
		GameManager.add_gold(1 + GameManager.upgrades["kill_gold_lvl"])
		GameManager.save_local_config()
	
	# 【核心】：死亡时隐藏手动添加的扣血 Label
	if is_instance_valid(damage_label):
		damage_label.visible = false
		
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if attack_detector:
		attack_detector.set_deferred("monitoring", false)
		attack_detector.set_deferred("monitorable", false)
	_custom_die()

# 同步播放 AnimationPlayer 与 AnimatedSprite2D 的指定动画。
func play_animation(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

# 根据已结束动画恢复攻击、受击或死亡后的状态。
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Death" and current_state == State.DEATH:
		queue_free()
		return
	if anim_name == &"Hurt" and current_state == State.HURT:
		if is_instance_valid(target) and _is_any_attack_range_reaching_target():
			change_state(State.IDLE)
		else:
			change_state(State.WALK)
		return

	match anim_name:
		"Attack1", "Attack2", "Attack3", "Attack":
			is_attacking = false
			start_attack_cooldown()
			if is_instance_valid(target) and _is_any_attack_range_reaching_target():
				change_state(State.IDLE)
			else:
				change_state(State.WALK)
		"Death":
			queue_free()
	_on_custom_animation_finished(anim_name)

# 已停用 AnimatedSprite2D.animation_finished 转发，攻击状态机只使用 AnimationPlayer。
# func _on_sprite_animation_finished() -> void:
# 	_on_animation_finished(sprite.animation)

# --- 碰撞判定（碰撞进入即触发 AoE 检测） ---
# 旧碰撞回调不再覆盖已锁定目标，目标刷新统一由最近目标逻辑处理。
func _on_attack_detector_body_entered(body: Node2D) -> void:
	if not _has_valid_target() and _is_valid_candidate(body):
		_update_target_detection()

# 当前目标离开基础攻击区域时清空目标。
func _on_attack_detector_body_exited(_body: Node2D) -> void:
	pass

# 旧碰撞回调不再覆盖已锁定目标，目标刷新统一由最近目标逻辑处理。
func _on_detection_area_body_entered(body: Node2D) -> void:
	if not _has_valid_target() and _is_valid_candidate(body):
		_update_target_detection()

# 当前目标离开侦测区域时清空目标。
func _on_detection_area_body_exited(_body: Node2D) -> void:
	pass
		
# 收集指定区域内重叠的物理体和区域目标；同一物理帧内复用缓存结果。
func _get_all_targets(area: Area2D) -> Array[Node2D]:
	if not is_instance_valid(area):
		return []
	var frame := Engine.get_physics_frames()
	if frame != _overlap_frame:
		_overlap_frame = frame
		_overlap_cache.clear()
	if _overlap_cache.has(area):
		return _overlap_cache[area]
	var results: Array[Node2D] = []
	for b in area.get_overlapping_bodies():
		results.append(b)
	for a in area.get_overlapping_areas():
		results.append(a)
	_overlap_cache[area] = results
	return results

# 弹出气泡文本
func pop_speech_bubble(text: String, duration: float = 1.5) -> void:
	var bubble_instance = SPEECH_BUBBLE.instantiate() as Node2D
	add_child(bubble_instance)
	bubble_instance.position = Vector2(0, -50) # 根据需要调整气泡位置
	if bubble_instance.has_method("pop_text"):
		bubble_instance.call("pop_text", text, duration)

# --- 虚函数 Hooks ---
# 供子类初始化自定义节点。
func _setup_custom_nodes() -> void: pass
# 供子类补充自定义碰撞层配置。
func _apply_custom_layer_config(_target_mask: int) -> void: pass
# 供子类同步自定义节点的朝向。
func _update_custom_facing_direction(_dir_scale: float) -> void: pass
# 供子类接管额外物理行为；返回 true 时跳过基类移动逻辑。
func _custom_physics_process(_delta: float) -> bool: return false
# 供子类决定受击时是否进入硬直状态。
func _can_enter_hurt() -> bool: return true
# 供子类处理死亡附加行为。
func _custom_die() -> void: pass
# 供子类响应动画播放结束事件。
func _on_custom_animation_finished(_anim_name: StringName) -> void: pass
