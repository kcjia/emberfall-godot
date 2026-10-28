extends Node2D

const WARLOCK_FIRE_SCENE: PackedScene = preload("res://Scene/SkillScene/Warlock_Fire.tscn")
const WARLOCK_FIRE_DAMAGE: int = 100

# 在 Inspector 中配置玩家单位字典：Key 为按钮 ID，Value 为单位场景 (.tscn)
@export var monster_scenes: Dictionary[String, PackedScene] = {
	"Armored_Axeman": null,
	"Knight_Templar": null,
	"Knight": null,
	"Lancer": null,
	"Archer": null,
	"Wizard": null,
	"Swordsman": null,
	"Priest": null
}
@export var monster_num1: Array[PackedScene] = []
@export var monster_num2: Array[PackedScene] = []
@export var monster_num3: Array[PackedScene] = []
@export_group("系统敌人生成时序")
## 与 monster_num1/2/3 下标对应；不足时使用默认间隔。
@export var monster_num1_intervals: Array[float] = []
@export var monster_num2_intervals: Array[float] = []
@export var monster_num3_intervals: Array[float] = []
@export var monster_num2_unlock_time: float = 60.0
@export var monster_num3_unlock_time: float = 180.0
@export var spawn_point: Marker2D         # 在 Inspector 中拖入固定刷怪点 Marker2D
@export var enemy_point: Marker2D         # 在 Inspector 中拖入固定刷怪点 Marker2D
@export_group("玩家持续生产")
@export var player_spawn_order: Array[String] = ["Armored_Axeman", "Knight_Templar", "Knight", "Lancer", "Archer", "Wizard", "Swordsman", "Priest"]
@export var player_spawn_intervals: Dictionary[String, float] = {
	"Armored_Axeman": 3.0,
	"Knight_Templar": 4.0,
	"Knight": 3.5,
	"Lancer": 5.0,
	"Archer": 6.0,
	"Wizard": 6.0,
	"Swordsman": 4.0,
	"Priest": 6.0
}
@onready var hud: CanvasLayer = $HUD
@onready var spawn_timer: Timer = $SpawnTimer

var game_time: float = 0.0
var player_next_spawn_times: Dictionary[String, float] = {}
var system_next_spawn_times: Dictionary[String, float] = {}
var spawning_enabled: bool = false

# 【生产上限】：玩家与系统同时在场生产的兵种种类上限均为 3 种。
# 玩家：按钮只作生产切换（加入/切换生产队列），点按不直接出兵；
# 系统：12 种敌人按 tier 顺序排成轮换表，同时最多 3 种在场生产，
#   随时间逐步替换（满 3 种时新种加入、最早的退场，退场过的本局不再回来），
#   后期固定为最后 3 种强力兵种。轮换间隔 100 秒。
# 敌方基地半血被动召唤走自己的三兵种间隔，不受此限制。
const MAX_ACTIVE_SPAWN_TYPES: int = 3
var active_player_spawn_types: Array[String] = []
const MAX_ACTIVE_SYSTEM_TYPES: int = 3
const SYSTEM_ROTATION_INTERVAL: float = 100.0
var system_roster: Array[Dictionary] = []
var system_active_keys: Array[String] = []
var system_next_rotation_time: float = SYSTEM_ROTATION_INTERVAL

# 启动敌人生成计时器并连接 HUD 信号。
func _ready() -> void:
	# 旧的单一 Timer 随机生成已停用，改由 _process 中的顺序调度器处理。
	spawn_timer.stop()
	_validate_monster_scenes()
	if hud and hud.has_signal("spawn_monster_requested"):
		# 避免场景内连线与代码重复绑定
		if not hud.spawn_monster_requested.is_connected(_on_spawn_monster_requested):
			hud.spawn_monster_requested.connect(_on_spawn_monster_requested)
	if hud and hud.has_signal("player_attack_requested"):
		if not hud.player_attack_requested.is_connected(_on_player_attack_requested):
			hud.player_attack_requested.connect(_on_player_attack_requested)
	_initialize_player_schedule()
	_build_system_roster()
	_initialize_system_active()
	# 调试打印：确认生成器就绪时的队列状态，定位不出兵后删除。
	print("[生成器] 就绪：玩家队列=", active_player_spawn_types, " 系统队列=", system_active_keys, " 解锁=", GameManager.battle_unlocked_monsters)

# 检查 Inspector 中拖入的玩家单位场景是否完整且类型正确。
func _validate_monster_scenes() -> void:
	for monster_id in monster_scenes:
		var scene: PackedScene = monster_scenes[monster_id]
		if scene == null:
			push_error("玩家单位 [%s] 没有拖入场景资源。" % monster_id)
			continue
		var instance := scene.instantiate()
		if not instance is EnemyBase:
			push_error("玩家单位 [%s] 的场景根节点必须继承 EnemyBase。" % monster_id)
		instance.free()
	
# 累计已开始战斗的时间，并驱动玩家与系统敌人的独立持续生成。
func _process(delta: float) -> void:
	if not spawning_enabled:
		return
	if game_time < 0.1:
		print("[生成器] _process 运行中，game_time=", game_time)
	game_time += delta
	_process_player_schedule()
	_process_system_schedule()

# 由主场景在开场对话结束后调用，开始本局所有持续生成。
func start_spawning() -> void:
	if spawning_enabled:
		return
	spawning_enabled = true
	print("[生成器] 开始生成，spawning_enabled=true")
	_initialize_player_schedule()

# 接收 HUD 的兵种按钮事件：按钮只作生产切换，不直接出兵。
# 已在生产队列中的兵种再点不额外出兵；未在队列中的兵种加入队列，
# 满 3 种时替换最早加入的兵种（被替换的兵种停止生产，计时器清除）。
func _on_spawn_monster_requested(monster_id: String) -> void:
	if not player_spawn_order.has(monster_id):
		return
	if active_player_spawn_types.has(monster_id):
		return
	if active_player_spawn_types.size() >= MAX_ACTIVE_SPAWN_TYPES:
		var removed_id = active_player_spawn_types.pop_front()
		player_next_spawn_times.erase(removed_id)
	active_player_spawn_types.append(monster_id)
	if not player_next_spawn_times.has(monster_id):
		var interval := maxf(player_spawn_intervals.get(monster_id, 3.0), 0.1)
		player_next_spawn_times[monster_id] = game_time + interval

# 初始化开局已解锁兵种的独立生产时间与生产队列。
# 幂等：已在队列或已有计时器的兵种不动，避免对话期间点按钮的状态被二次初始化覆盖。
func _initialize_player_schedule() -> void:
	for monster_id in player_spawn_order:
		if GameManager.battle_unlocked_monsters.get(monster_id, false):
			if not player_next_spawn_times.has(monster_id):
				player_next_spawn_times[monster_id] = 0.0
			if not active_player_spawn_types.has(monster_id) and active_player_spawn_types.size() < MAX_ACTIVE_SPAWN_TYPES:
				active_player_spawn_types.append(monster_id)

# 按指定 ID 实例化一个玩家单位。
func _spawn_player_monster(monster_id: String) -> void:
	if not monster_scenes.has(monster_id) or monster_scenes[monster_id] == null:
		push_error("未找到 ID 为 %s 的怪物场景资源！" % monster_id)
		return
		
	if not spawn_point:
		push_error("未配置 spawn_point！")
		return

	# 1. 根据 ID 提取对应的 PackedScene 并实例化
	var scene_to_spawn: PackedScene = monster_scenes[monster_id]
	var enemy = scene_to_spawn.instantiate() as EnemyBase
	if not enemy:
		push_error("玩家单位 [%s] 场景实例化失败，请检查场景根节点是否为 EnemyBase。" % monster_id)
		return
	
	# 2. 添加到父场景中（与系统怪保持同层级）并设置生成位置
	get_parent().add_child(enemy)
	enemy.global_position = spawn_point.global_position
	enemy.setup_as_player_enemy()
	print("[生成器] 生成玩家兵：", monster_id, " 位置=", enemy.global_position)

# 按按钮顺序持续生产生产队列中的已解锁兵种（同时最多 3 种）。
func _process_player_schedule() -> void:
	for monster_id in player_spawn_order:
		if not active_player_spawn_types.has(monster_id):
			continue
		if not GameManager.battle_unlocked_monsters.get(monster_id, false):
			continue
		var interval := maxf(player_spawn_intervals.get(monster_id, 3.0), 0.1)
		var next_spawn_time: float = player_next_spawn_times.get(monster_id, game_time + interval)
		if game_time < next_spawn_time:
			continue
		_spawn_player_monster(monster_id)
		player_next_spawn_times[monster_id] = game_time + interval

# 将 HUD 技能攻击请求转发给玩家基地。
func _on_player_attack_requested(attack_name: String) -> void:
	# 响应玩家技能按钮并执行全场一次性攻击。
	if attack_name == "Attack2":
		_cast_warlock_fire()
		return

	var player_home = get_parent().get_node_or_null("Area2D")
	if player_home and player_home.has_method("perform_attack"):
		player_home.perform_attack(attack_name)

# 生成火焰技能特效，并对当前场景内所有系统敌人造成一次伤害。
func _cast_warlock_fire() -> void:
	var damage: int = WARLOCK_FIRE_DAMAGE + GameManager.upgrades["player_skill_1_power_lvl"] * 15
	var existing_enemies: Array[EnemyBase] = []
	for child in get_parent().get_children():
		if child is EnemyBase and child.is_system_spawned and child.has_method("take_damage"):
			existing_enemies.append(child)

	for enemy in existing_enemies:
		var fire_effect = WARLOCK_FIRE_SCENE.instantiate()
		get_parent().add_child(fire_effect)
		fire_effect.global_position = enemy.global_position
		if fire_effect.has_method("play_effect"):
			fire_effect.play_effect(damage, enemy)

# 按 tier 顺序把三档敌人排成一张轮换表（解锁时间取 Inspector 配置）。
func _build_system_roster() -> void:
	system_roster.clear()
	_append_system_group(monster_num1, monster_num1_intervals, 0.0, "tier_1")
	_append_system_group(monster_num2, monster_num2_intervals, monster_num2_unlock_time, "tier_2")
	_append_system_group(monster_num3, monster_num3_intervals, monster_num3_unlock_time, "tier_3")

func _append_system_group(scenes: Array[PackedScene], intervals: Array[float], unlock_time: float, group_id: String) -> void:
	for index in scenes.size():
		var scene := scenes[index]
		if scene == null:
			continue
		system_roster.append({
			"scene": scene,
			"interval": intervals[index] if index < intervals.size() else 5.0,
			"unlock_time": unlock_time,
			"key": "%s_%d" % [group_id, index],
			"activated": false,
		})

# 开局激活轮换表前 3 个已解锁的兵种（开局只有一档可解锁）。
func _initialize_system_active() -> void:
	system_active_keys.clear()
	for track in system_roster:
		if system_active_keys.size() >= MAX_ACTIVE_SYSTEM_TYPES:
			break
		if game_time < track["unlock_time"]:
			continue
		system_active_keys.append(track["key"])
		track["activated"] = true

# 按轮换表持续生成在场生产队列中的系统敌人（同时最多 3 种）。
func _process_system_schedule() -> void:
	if not enemy_point:
		return
	_update_system_active_set()
	for track in system_roster:
		if not system_active_keys.has(track["key"]):
			continue
		var next_spawn_time: float = system_next_spawn_times.get(track["key"], game_time)
		if game_time < next_spawn_time:
			continue
		_spawn_system_monster(track["scene"])
		system_next_spawn_times[track["key"]] = game_time + maxf(track["interval"], 0.1)

# 维护系统生产队列：未满 3 种时立即补满已解锁的下一个；
# 已满 3 种且到轮换时间时，最早的退场、下一个加入（退场过的不再回来）。
func _update_system_active_set() -> void:
	var next_track = _find_next_system_track()
	if next_track == null:
		return
	if system_active_keys.size() < MAX_ACTIVE_SYSTEM_TYPES:
		system_active_keys.append(next_track["key"])
		next_track["activated"] = true
		return
	if game_time >= system_next_rotation_time:
		var retired_key = system_active_keys.pop_front()
		system_next_spawn_times.erase(retired_key)
		system_active_keys.append(next_track["key"])
		next_track["activated"] = true
		system_next_rotation_time = game_time + SYSTEM_ROTATION_INTERVAL

# 按轮换表顺序找下一个从未激活且已解锁的兵种，找不到返回 null。
func _find_next_system_track():
	for track in system_roster:
		if track["activated"]:
			continue
		if game_time < track["unlock_time"]:
			continue
		return track
	return null

# 在系统出生点实例化一个敌方单位。
func _spawn_system_monster(scene: PackedScene) -> void:
	if not enemy_point or scene == null:
		return
	var enemy = scene.instantiate() as EnemyBase
	if not enemy:
		return
	get_parent().add_child(enemy)
	enemy.global_position = enemy_point.global_position
	enemy.setup_as_system_enemy()
	print("[生成器] 生成系统兵，位置=", enemy.global_position)
