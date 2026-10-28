extends Area2D

enum TargetMode {
	SINGLE_TARGET,
	AREA
}

@export var duration: float = 2.0
@export var damage_interval: float = 0.25
@export var damage_start_frame: int = 7

var is_system_spawned: bool = false
var damage: float = 0.0
var active: bool = false
var damage_enabled: bool = false
var target_mode: TargetMode = TargetMode.AREA
# 用弱引用保存单体目标，目标释放后会自动解析为空。
var designated_target_ref: WeakRef

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_timer: Timer = $DamageTickTimer

# 初始化隐藏状态并绑定周期伤害计时器。
func _ready() -> void:
	monitoring = false
	visible = false
	damage_timer.timeout.connect(_deal_damage)
	anim_sprite.frame_changed.connect(_on_animation_frame_changed)

# 设置施放阵营、单次伤害、目标模式与施放时锁定的单体目标。
func setup(from_system: bool, damage_amount: float, mode: TargetMode = TargetMode.AREA, locked_target = null) -> void:
	is_system_spawned = from_system
	damage = damage_amount
	target_mode = mode
	designated_target_ref = weakref(locked_target) if is_instance_valid(locked_target) else null
	var enemy_layer = 2 if is_system_spawned else 3
	collision_layer = 0
	collision_mask = 1 << (enemy_layer - 1)
	scale.x = abs(scale.x) * (-1.0 if is_system_spawned else 1.0)

# 显示激光并在持续时间内周期性伤害敌人。
func activate() -> void:
	if active:
		return

	active = true
	damage_enabled = false
	visible = true
	monitoring = true
	if anim_sprite:
		anim_sprite.frame = 0
		anim_sprite.frame_progress = 0.0
		anim_sprite.play(&"default")
	await get_tree().create_timer(duration).timeout
	deactivate()

# 停止激光显示、动画与伤害检测。
func deactivate() -> void:
	active = false
	damage_enabled = false
	monitoring = false
	visible = false
	damage_timer.stop()
	if anim_sprite:
		anim_sprite.stop()

# 根据目标模式对激光伤害范围内的目标结算一次伤害。
func _deal_damage() -> void:
	if not active or not damage_enabled:
		return
	if target_mode == TargetMode.SINGLE_TARGET:
		var designated_target = designated_target_ref.get_ref() if designated_target_ref else null
		_apply_damage_if_valid(designated_target)
		return

	for body in get_overlapping_bodies():
		_apply_damage_if_valid(body)
	for area in get_overlapping_areas():
		_apply_damage_if_valid(area)

# 在精灵播放到第八帧后启用周期性激光伤害。
func _on_animation_frame_changed() -> void:
	if not active or damage_enabled or anim_sprite.frame < damage_start_frame:
		return

	damage_enabled = true
	damage_timer.start(damage_interval)
	_deal_damage()

# 对单个有效敌方目标造成激光伤害。
func _apply_damage_if_valid(target_node) -> void:
	if not is_instance_valid(target_node) or target_node == get_parent() or not target_node.has_method("take_damage"):
		return
	if "is_system_spawned" in target_node and target_node.is_system_spawned == is_system_spawned:
		return
	target_node.take_damage(damage)
