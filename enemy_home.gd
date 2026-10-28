extends Area2D

signal health_changed(current_hp: float, max_hp: float)
signal died

@export_group("基础属性")
@export var max_health: float = 1000.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 3.0  ## 攻击间隔
@export var is_system_spawned: bool = true

@export_group("被动召唤")
@export var summon_scenes: Array[PackedScene] = [
	preload("res://Scene/EnemyScene/Demon_A.tscn"),
	preload("res://Scene/EnemyScene/Demon_D.tscn"),
	preload("res://Scene/EnemyScene/Demon_E.tscn")
]
## 与 summon_scenes 下标对应；每种小兵独立持续生成。
@export var summon_intervals: Array[float] = [5.0, 7.0, 10.0]
## 从被动召唤触发时开始计时，与 summon_scenes 下标对应。
@export var summon_unlock_times: Array[float] = [0.0, 60.0, 120.0]
@export var summon_trigger_time: float = 900.0

var current_health: float
var summon_triggered: bool = false
var can_attack: bool = true
# 不声明强类型，避免已释放目标在传入有效性检查前触发类型转换错误。
var target = null
var summon_elapsed_time: float = 0.0
var summon_next_spawn_times: Array[float] = []
# HUD 节点缓存：原先每帧都走一次场景树路径查找，改为首次成功后复用。
var _hud_cache: Node = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var progress_bar: ProgressBar = $ProgressBar

# 血条表现：主条按血量变色（绿→黄→红）+ 白色残影条 + 受击闪白 + 飘字。
var _base_fill_stylebox: StyleBoxFlat = null
var _base_ghost_bar: ProgressBar = null
var _base_flash_tween: Tween = null
var _base_damage_label: Label = null
var _base_damage_tween: Tween = null
@onready var attack_area: Area2D = $Attack1Area
@onready var summon_point: Marker2D = $Marker2D
@onready var summon_timer: Timer = $SummonTimer

# 初始化基地生命、碰撞阵营、动画和被动召唤计时器。
func _ready() -> void:
	current_health = max_health
	_init_progress_bar()
	_setup_faction_collision()
	if anim_player.has_animation("Idle"):
		_play_animation("Idle")
	# 旧 SummonTimer 已停用，改由 _process 按兵种独立时序生成。
	summon_timer.stop()

# 处理时间过半和血量过半以下的被动触发条件。
func _process(delta: float) -> void:
	_update_base_ghost_bar(delta)
	if not summon_triggered and (summon_trigger_time <= 0.0 or _get_elapsed_battle_time() >= summon_trigger_time):
		_start_summoning()
	if summon_triggered:
		summon_elapsed_time += delta
		_process_summon_schedule()

# 查找主场景 HUD 的战斗计时，找不到时返回零并交由血量条件触发。
# 首次成功查找到后缓存节点，避免每帧重复走场景树路径。
func _get_hud() -> Node:
	if is_instance_valid(_hud_cache):
		return _hud_cache
	_hud_cache = get_tree().current_scene.get_node_or_null("EnemySpawner/HUD")
	return _hud_cache

func _get_elapsed_battle_time() -> float:
	var hud := _get_hud()
	if hud and "remaining_seconds" in hud:
		return maxf(30.0 * 60.0 - hud.remaining_seconds, 0.0)
	return 0.0

# 受到玩家单位伤害并在生命归零时结束战斗。
func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	progress_bar.value = current_health
	health_changed.emit(current_health, max_health)
	_update_base_bar_color()
	_flash_base_hit()
	_show_base_damage_number(amount)
	if current_health <= max_health * 0.5:
		_start_summoning()
	if current_health <= 0.0:
		_die()

# 显示玩家摧毁敌方基地后的胜利面板并销毁基地。
func _die() -> void:
	died.emit()
	var hud := _get_hud()
	if hud and hud.has_method("show_victory"):
		hud.show_victory()
	queue_free()

# 初始化基地血条的范围和当前值。
func _init_progress_bar() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = max_health
	progress_bar.value = current_health
	_setup_base_bar_juice()

func _setup_base_bar_juice() -> void:
	if not is_instance_valid(progress_bar):
		return
	var orig_fill := progress_bar.get_theme_stylebox("fill")
	if orig_fill is StyleBoxFlat:
		_base_fill_stylebox = orig_fill.duplicate() as StyleBoxFlat
	else:
		_base_fill_stylebox = StyleBoxFlat.new()
	progress_bar.add_theme_stylebox_override("fill", _base_fill_stylebox)
	_base_ghost_bar = ProgressBar.new()
	_base_ghost_bar.position = progress_bar.position
	_base_ghost_bar.size = progress_bar.size
	_base_ghost_bar.min_value = 0.0
	_base_ghost_bar.max_value = max_health
	_base_ghost_bar.value = current_health
	_base_ghost_bar.show_percentage = false
	var ghost_bg := StyleBoxFlat.new()
	ghost_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_base_ghost_bar.add_theme_stylebox_override("background", ghost_bg)
	var ghost_fill := StyleBoxFlat.new()
	ghost_fill.bg_color = Color(1.0, 1.0, 1.0, 0.9)
	_base_ghost_bar.add_theme_stylebox_override("fill", ghost_fill)
	add_child(_base_ghost_bar)
	move_child(_base_ghost_bar, progress_bar.get_index())
	_update_base_bar_color()

func _update_base_bar_color() -> void:
	if _base_fill_stylebox == null:
		return
	var hp_ratio := 0.0
	if max_health > 0:
		hp_ratio = clampf(current_health / max_health, 0.0, 1.0)
	if hp_ratio > 0.5:
		_base_fill_stylebox.bg_color = Color(0.3, 0.85, 0.4)
	elif hp_ratio > 0.25:
		_base_fill_stylebox.bg_color = Color(1.0, 0.8, 0.2)
	else:
		_base_fill_stylebox.bg_color = Color(1.0, 0.25, 0.2)

func _update_base_ghost_bar(delta: float) -> void:
	if not is_instance_valid(_base_ghost_bar) or not is_instance_valid(progress_bar):
		return
	if progress_bar.value > _base_ghost_bar.value:
		_base_ghost_bar.value = progress_bar.value
	else:
		_base_ghost_bar.value = move_toward(_base_ghost_bar.value, progress_bar.value, max_health * delta * 0.5)

func _flash_base_hit() -> void:
	if not is_instance_valid(anim_sprite):
		return
	if _base_flash_tween and _base_flash_tween.is_running():
		_base_flash_tween.kill()
	anim_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	_base_flash_tween = create_tween()
	_base_flash_tween.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

# 基地受击飘字（与单位飘字同款分档：小黄、中橙、大红放大）。
func _show_base_damage_number(amount: float) -> void:
	if _base_damage_label == null:
		_base_damage_label = Label.new()
		_base_damage_label.position = Vector2(-25.0, -70.0)
		_base_damage_label.add_theme_font_size_override("font_size", 20)
		_base_damage_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		_base_damage_label.add_theme_constant_override("outline_size", 3)
		_base_damage_label.visible = false
		add_child(_base_damage_label)
	if _base_damage_tween and _base_damage_tween.is_running():
		_base_damage_tween.kill()
	var dmg_color := Color(1.0, 0.85, 0.4, 1.0)
	var pop_scale := Vector2(1.1, 1.1)
	var rise := 24.0
	var fade_time := 0.5
	if amount >= 100:
		dmg_color = Color(1.0, 0.25, 0.2, 1.0)
		pop_scale = Vector2(1.5, 1.5)
		rise = 36.0
		fade_time = 0.7
	elif amount >= 30:
		dmg_color = Color(1.0, 0.6, 0.15, 1.0)
		pop_scale = Vector2(1.25, 1.25)
	_base_damage_label.text = "-%d" % int(amount)
	_base_damage_label.modulate = dmg_color
	_base_damage_label.visible = true
	var base_y: float = -70.0
	var random_x: float = randf_range(-31.0, -19.0)
	_base_damage_label.position = Vector2(random_x, base_y)
	_base_damage_label.scale = Vector2(0.8, 0.8)
	_base_damage_tween = create_tween()
	_base_damage_tween.set_parallel(true)
	_base_damage_tween.tween_property(_base_damage_label, "position:y", base_y - rise, fade_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_base_damage_tween.tween_property(_base_damage_label, "scale", pop_scale, 0.12)
	_base_damage_tween.tween_property(_base_damage_label, "modulate:a", 0.0, fade_time).set_delay(0.15)
	_base_damage_tween.chain().tween_callback(func():
		if is_instance_valid(_base_damage_label):
			_base_damage_label.visible = false
	)

# 将基地和范围攻击设置为敌方阵营碰撞层。
func _setup_faction_collision() -> void:
	collision_layer = 1 << 2
	collision_mask = 1 << 1
	attack_area.collision_layer = 0
	attack_area.collision_mask = 1 << 1
	attack_area.monitoring = true

# 启动按数组顺序、独立间隔持续生成的小怪调度。
func _start_summoning() -> void:
	if summon_triggered:
		return
	summon_triggered = true
	summon_elapsed_time = 0.0
	summon_next_spawn_times.resize(summon_scenes.size())
	for index in summon_scenes.size():
		summon_next_spawn_times[index] = 0.0

# 按数组顺序处理每种已解锁小怪的独立生成时间。
func _process_summon_schedule() -> void:
	for index in summon_scenes.size():
		var unlock_time := summon_unlock_times[index] if index < summon_unlock_times.size() else 0.0
		if summon_elapsed_time < unlock_time or summon_elapsed_time < summon_next_spawn_times[index]:
			continue
		_spawn_minion(summon_scenes[index])
		var interval := summon_intervals[index] if index < summon_intervals.size() else 5.0
		summon_next_spawn_times[index] = summon_elapsed_time + maxf(interval, 0.1)

# 在基地 Marker2D 位置实例化一个敌方小兵。
func _spawn_minion(scene: PackedScene) -> void:
	if scene == null:
		return
	var minion := scene.instantiate() as EnemyBase
	if not minion:
		push_error("敌方基地召唤数组中的场景根节点必须继承 EnemyBase。")
		return
	get_parent().add_child(minion)
	minion.global_position = summon_point.global_position
	minion.setup_as_system_enemy()

# 在 AnimationPlayer 的 Attack1 关键帧对范围内所有玩家目标结算范围伤害。
func activate_attack_hitbox(attack_name: String) -> void:
	if attack_name != "Attack1":
		return
	for target_node in attack_area.get_overlapping_bodies() + attack_area.get_overlapping_areas():
		_damage_player_target(target_node)

# 对范围内的玩家单位或玩家基地造成伤害，避免误伤己方小怪。
func _damage_player_target(target_node) -> void:
	if not is_instance_valid(target_node) or target_node == self or not target_node.has_method("take_damage"):
		return
	if "is_system_spawned" in target_node and target_node.is_system_spawned:
		return
	target_node.take_damage(int(attack_damage))

# 检查范围内玩家目标并启动基地攻击动画。
func _physics_process(_delta: float) -> void:
	if not can_attack:
		return
	if not _is_valid_player_target(target):
		target = _find_player_target()
	if not is_instance_valid(target):
		return
	if not anim_player.has_animation("Attack1"):
		return
	can_attack = false
	_play_animation("Attack1")
	_wait_for_attack()

# 查找 Attack1 范围内最近的可受伤玩家目标。
func _find_player_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance := INF
	for target_node in attack_area.get_overlapping_bodies() + attack_area.get_overlapping_areas():
		if not _is_valid_player_target(target_node):
			continue
		var distance := global_position.distance_squared_to(target_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = target_node
	return nearest_target

# 判断目标是否属于玩家阵营且具备受伤接口。
func _is_player_target(target_node) -> bool:
	return is_instance_valid(target_node) and target_node != self and target_node.has_method("take_damage") and (not ("is_system_spawned" in target_node) or not target_node.is_system_spawned)

# 判断玩家目标是否仍存活，可继续保持锁定。
func _is_valid_player_target(target_node) -> bool:
	return _is_player_target(target_node) and (not ("current_health" in target_node) or target_node.current_health > 0)

# 等待基地攻击动画和冷却完成后恢复攻击资格。
func _wait_for_attack() -> void:
	await anim_player.animation_finished
	if anim_player.has_animation("Idle"):
		_play_animation("Idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# 同步播放 AnimationPlayer 与精灵帧动画。
func _play_animation(animation_name: String) -> void:
	anim_player.play(animation_name)
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(animation_name):
		anim_sprite.play(animation_name)
