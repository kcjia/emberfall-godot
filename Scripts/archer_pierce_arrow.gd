extends Area2D

# 直线穿透箭矢：沿固定方向直线飞行，命中敌人后不消失、继续穿透，
# 每个目标只结算一次伤害（靠已命中集合防重复触发）。
@export var max_lifetime: float = 3.0

var damage: int = 10
var is_from_system: bool = false
var flight_speed: float = 500.0
var max_distance: float = 600.0
var has_entered_screen: bool = false

var _direction: Vector2 = Vector2.RIGHT
var _traveled_distance: float = 0.0
var _hit_ids: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if screen_notifier:
		screen_notifier.screen_entered.connect(_on_screen_entered)
		screen_notifier.screen_exited.connect(_on_screen_exited)
	get_tree().create_timer(max_lifetime).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

# 发射：起点、直线方向、阵营、伤害、飞行速度、最大距离、箭矢贴图。
func setup(spawn_pos: Vector2, shoot_dir: Vector2, from_system: bool, dmg: int, travel_speed: float, travel_distance: float, arrow_texture: Texture2D) -> void:
	global_position = spawn_pos
	_direction = shoot_dir.normalized()
	is_from_system = from_system
	damage = dmg
	flight_speed = travel_speed
	max_distance = travel_distance
	_traveled_distance = 0.0
	_hit_ids.clear()
	if sprite and arrow_texture:
		sprite.texture = arrow_texture
	var enemy_target_layer = 2 if is_from_system else 3
	collision_layer = 0
	collision_mask = 1 << (enemy_target_layer - 1)
	if sprite:
		rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	var movement := _direction * flight_speed * delta
	global_position += movement
	_traveled_distance += movement.length()
	if _traveled_distance >= max_distance:
		queue_free()

func _on_screen_entered() -> void:
	has_entered_screen = true

func _on_screen_exited() -> void:
	if has_entered_screen:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

# 穿透命中：同一目标只结算一次，不销毁箭矢，继续飞行。
func _hit_target(target: Node2D) -> void:
	if not is_instance_valid(target) or target == self:
		return
	if not target.has_method("take_damage"):
		return
	if "is_system_spawned" in target and target.is_system_spawned == is_from_system:
		return
	var target_id := target.get_instance_id()
	if _hit_ids.has(target_id):
		return
	_hit_ids[target_id] = true
	target.take_damage(damage)
