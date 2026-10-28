extends Area2D

signal health_changed(current_hp: float, max_hp: float)
signal died

enum Attack3TargetMode {
	SINGLE_TARGET,
	AREA
}

@export_group("基础属性")
@export var max_health: float = 1000.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 3.0  ## 攻击间隔
@export var is_system_spawned: bool = false

@export_group("Attack3 伤害目标")
## 单体使用施放时锁定的目标；范围伤害 Attack3Area 内所有敌人。
@export var attack3_target_mode: Attack3TargetMode = Attack3TargetMode.AREA

@export_group("远程攻击配置")
@export var projectile_scene: PackedScene 
@onready var shoot_offset = get_node_or_null("Marker2D")

var current_health: float
var can_attack: bool = true
# 不声明强类型，避免已释放节点在传入有效性检查前触发类型转换错误。
var target = null
var attack_cooldown_complete: bool = true
var attack_animation_complete: bool = true
var attack_sequence_id: int = 0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var laser_skill = get_node_or_null("LaserSkill")

@onready var attack_areas: Dictionary = {
	"Attack1": $Attack1Area,
	"Attack2": $Attack2Area,
	"Attack3": $Attack3Area
}

# 初始化基地状态、阵营碰撞与动画。
func _ready() -> void:
	add_to_group("player_base")
	current_health = max_health
	_init_progress_bar()
	_setup_faction_collision()
	_setup_attack_areas()
	
	if is_system_spawned:
		scale.x = -abs(scale.x)
	
	# 连接自身检测信号，检测进入射程的敌人
	area_entered.connect(_on_target_detected)
	body_entered.connect(_on_target_detected)
	
	if anim_player.has_animation("Start"):
		_play_animation("Start")
		anim_player.animation_finished.connect(_on_start_finished, CONNECT_ONE_SHOT)
	elif anim_player.has_animation("Idle"):
		_play_animation("Idle")

# 开场动画结束后切换为待机动画。
func _on_start_finished(_anim_name: StringName) -> void:
	if anim_player.has_animation("Idle"):
		_play_animation("Idle")

# 按 Attack1 近距离优先、Attack2 中距离次之的规则自动攻击。
func _physics_process(_delta: float) -> void:
	if not can_attack:
		return
	
	# 目标存活时持续锁定，仅在失效后按距离选择最近敌人。
	if not _is_valid_locked_enemy(target):
		target = _find_valid_enemy()
	if is_instance_valid(target) and _area_contains_target("Attack1", target):
		perform_attack("Attack1")
		return

	if not is_instance_valid(target):
		target = _find_valid_enemy_in_area("Attack2")
	if is_instance_valid(target) and _area_contains_target("Attack2", target):
		perform_attack("Attack2")

# 查找 Attack1 范围内最近的有效敌人。
func _find_valid_enemy() -> Node2D:
	return _find_valid_enemy_in_area("Attack1")

# 查找指定攻击范围内最近的有效敌人。
func _find_valid_enemy_in_area(area_name: String) -> Node2D:
	var attack_area: Area2D = attack_areas.get(area_name)
	if not is_instance_valid(attack_area):
		return null

	var nearest_target: Node2D = null
	var nearest_distance := INF
	for candidate in attack_area.get_overlapping_bodies() + attack_area.get_overlapping_areas():
		if not _is_valid_locked_enemy(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = candidate
	return nearest_target

# 判断指定攻击范围是否仍覆盖当前锁定目标。
func _area_contains_target(area_name: String, candidate) -> bool:
	var attack_area: Area2D = attack_areas.get(area_name)
	if not is_instance_valid(attack_area) or not is_instance_valid(candidate):
		return false
	if candidate is Area2D:
		return attack_area.get_overlapping_areas().has(candidate)
	return attack_area.get_overlapping_bodies().has(candidate)

# 判断候选节点是否属于敌方且可受伤；参数不强制类型以安全处理已释放对象。
func _is_enemy_target(candidate) -> bool:
	return is_instance_valid(candidate) and candidate is Node2D and candidate != self and candidate.has_method("take_damage") and "is_system_spawned" in candidate and candidate.is_system_spawned != is_system_spawned

# 判断敌方目标是否仍存活，可继续保持锁定。
func _is_valid_locked_enemy(candidate) -> bool:
	return _is_enemy_target(candidate) and (not ("current_health" in candidate) or candidate.current_health > 0)

# 处理基地自身检测区域进入的敌方目标。
func _on_target_detected(node: Node2D) -> void:
	if not is_instance_valid(target) and _is_enemy_target(node):
		target = node

# 按攻击范围限制启动指定攻击、锁定目标并进入公共冷却。
func perform_attack(attack_anim: String) -> void:
	if not anim_player.has_animation(attack_anim):
		return
	if attack_anim != "Attack3" and not can_attack:
		return
	if attack_anim == "Attack2":
		target = _find_valid_enemy_in_area(attack_anim)
	if attack_anim != "Attack3" and not is_instance_valid(target):
		return

	# Attack3 强制中断当前攻击，并使旧攻击协程不再影响状态。
	attack_sequence_id += 1
	var current_sequence_id := attack_sequence_id
	if attack_anim == "Attack3":
		stop_laser()
	can_attack = false
	attack_cooldown_complete = false
	attack_animation_complete = false
	_play_animation(attack_anim)
	_wait_for_attack_animation(current_sequence_id)
	_wait_for_attack_cooldown(current_sequence_id)

# 等待攻击动画结束后切换回待机。
func _wait_for_attack_animation(sequence_id: int) -> void:
	await anim_player.animation_finished
	if sequence_id != attack_sequence_id:
		return
	attack_animation_complete = true
	if anim_player.has_animation("Idle"):
		_play_animation("Idle")
	_finish_attack_if_ready()

# 等待攻击冷却结束后恢复攻击资格。
func _wait_for_attack_cooldown(sequence_id: int) -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	if sequence_id != attack_sequence_id:
		return
	attack_cooldown_complete = true
	_finish_attack_if_ready()

# 在动画和冷却均完成后解除攻击锁。
func _finish_attack_if_ready() -> void:
	if not attack_animation_complete or not attack_cooldown_complete:
		return

	can_attack = true

# 同步播放 AnimationPlayer 与精灵帧动画。
func _play_animation(animation_name: String) -> void:
	anim_player.play(animation_name)
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(animation_name):
		anim_sprite.play(animation_name)

# ----------------- 伤害与生命值 -----------------
# 扣除基地生命值并处理死亡。
func take_damage(amount: float) -> void:
	if current_health <= 0:
		return
	current_health = maxf(current_health - amount, 0.0)
	if progress_bar:
		progress_bar.value = current_health
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()

# 停止技能、广播死亡并销毁基地。
func _die() -> void:
	died.emit()
	stop_laser()
	_show_game_over_dialog()
	get_tree().paused = true
	queue_free()

# 通知主场景内的 HUD 显示游戏结束弹窗。
func _show_game_over_dialog() -> void:
	var hud = get_tree().current_scene.get_node_or_null("EnemySpawner/HUD")
	if hud and hud.has_method("show_game_over"):
		hud.show_game_over()

# 使用最大生命值初始化血条显示。
func _init_progress_bar() -> void:
	if progress_bar:
		progress_bar.min_value = 0.0
		progress_bar.max_value = max_health
		progress_bar.value = current_health

# ----------------- 攻击判定开关 -----------------
# 启用所有攻击范围的重叠检测。
func _setup_attack_areas() -> void:
	for area_name in attack_areas:
		var area: Area2D = attack_areas[area_name]
		if area:
			area.monitoring = true

# 按阵营配置基地与攻击范围的碰撞层。
func _setup_faction_collision() -> void:
	var own_layer = 3 if is_system_spawned else 2
	var enemy_layer = 2 if is_system_spawned else 3
	collision_layer = 1 << (own_layer - 1)
	collision_mask = (1 << 0) | (1 << (enemy_layer - 1))

	for area in attack_areas.values():
		area.collision_layer = 0
		area.collision_mask = 1 << (enemy_layer - 1)

# 旧攻击区手动开关接口已停用：当前攻击区始终保持检测。
# func enable_attack_area(area_name: String) -> void:
# 	if attack_areas.has(area_name) and attack_areas[area_name]:
# 		attack_areas[area_name].monitoring = true
#
# func disable_attack_area(area_name: String) -> void:
# 	if attack_areas.has(area_name) and attack_areas[area_name]:
# 		attack_areas[area_name].monitoring = false

# 对当前锁定的单个敌人结算一次伤害。
func activate_attack_hitbox(area_name: String) -> void:
	if not attack_areas.has(area_name):
		return
	_damage_enemy(target)

# 对单个非同阵营目标造成基地攻击伤害。
func _damage_enemy(target_node) -> void:
	if not is_instance_valid(target_node) or target_node == self or not target_node.has_method("take_damage"):
		return
	if "is_system_spawned" in target_node and target_node.is_system_spawned == is_system_spawned:
		return
	target_node.take_damage(attack_damage)

# 配置并启动 Attack3 的持续激光技能。
func fire_laser() -> void:
	if laser_skill and laser_skill.has_method("activate"):
		if laser_skill.has_method("setup"):
			laser_skill.setup(is_system_spawned, attack_damage * 3, attack3_target_mode, target)
		laser_skill.activate()

# 停止当前激光技能。
func stop_laser() -> void:
	if laser_skill and laser_skill.has_method("deactivate"):
		laser_skill.deactivate()

# 按锁定目标方向实例化并发射 Attack2 的飞拳投射物。
func shoot_projectile() -> void:
	if not projectile_scene or not is_instance_valid(target) or not is_instance_valid(shoot_offset):
		return
	var scene_root = get_tree().current_scene if get_tree().current_scene else get_parent()
	var projectile = projectile_scene.instantiate()
	if not projectile:
		return
	var spawn_pos = shoot_offset.global_position
	var shoot_dir = (target.global_position - spawn_pos).normalized()
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.LEFT if is_system_spawned else Vector2.RIGHT
	if projectile.has_method("setup"):
		projectile.setup(spawn_pos, shoot_dir, is_system_spawned, attack_damage*2)
	scene_root.add_child(projectile)
