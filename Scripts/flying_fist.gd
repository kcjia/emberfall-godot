class_name Projectile
extends Area2D

@export var speed: float = 240.0
@export var damage: int = 15
@export var max_lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var is_from_system: bool = false
var has_entered_screen: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# 连接命中与屏幕事件，并启动生命周期计时。
func _ready() -> void:
	sprite.play()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if screen_notifier:
		screen_notifier.screen_entered.connect(_on_screen_entered)
		screen_notifier.screen_exited.connect(_on_screen_exited)
	
	# 超出最大存活时间自动销毁
	get_tree().create_timer(max_lifetime).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

# 设置飞拳的位置、方向、阵营和伤害。
func setup(spawn_pos: Vector2, shoot_dir: Vector2, from_system: bool, dmg: int) -> void:
	global_position = spawn_pos
	direction = shoot_dir.normalized()
	is_from_system = from_system
	damage = dmg

	# 阵营碰撞掩码配置：仅检测目标阵营，避免地面碰撞提前销毁投射物。
	var enemy_target_layer = 2 if is_from_system else 3
	collision_layer = 0
	collision_mask = 1 << (enemy_target_layer - 1)

	# 旋转飞拳，使其沿锁定目标方向直线飞行。
	if sprite:
		rotation = direction.angle()

# 按固定速度推进飞拳位置。
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

# 记录飞拳已进入可视区域，允许之后离屏时清理。
func _on_screen_entered() -> void:
	has_entered_screen = true

# 仅销毁已进入过屏幕、随后飞出屏幕的飞拳。
func _on_screen_exited() -> void:
	if has_entered_screen:
		queue_free()

# 处理飞拳与物理角色的碰撞。
func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

# 处理飞拳与区域目标的碰撞。
func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

# 对第一个有效敌方目标造成伤害并销毁飞拳。
func _hit_target(target: Node2D) -> void:
	if not is_instance_valid(target) or target == self:
		return
	if not target.has_method("take_damage"):
		return
	if "is_system_spawned" in target and target.is_system_spawned == is_from_system:
		return
	target.take_damage(damage)
	queue_free()