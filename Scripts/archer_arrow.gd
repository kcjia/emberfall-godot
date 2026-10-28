extends Area2D

# 抛物线箭矢：沿二次贝塞尔弧线飞向目标当前位置，箭头始终朝向切线方向。
# 箭矢贴图朝右（箭头在右、尾羽在左）时 rotation = 速度方向角即正确。
@export var max_lifetime: float = 4.0

var damage: int = 10
var is_from_system: bool = false
var flight_speed: float = 400.0
var arc_height: float = 60.0
var has_entered_screen: bool = false

var _start_pos: Vector2
var _target: Node2D
var _last_end_pos: Vector2
var _flight_time: float = 1.0
var _elapsed: float = 0.0
var _finished: bool = false

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

# 发射：起点、目标节点、阵营、伤害、飞行速度、弧高、箭矢贴图。
func setup(spawn_pos: Vector2, target_node: Node2D, from_system: bool, dmg: int, travel_speed: float, arc_h: float, arrow_texture: Texture2D) -> void:
	global_position = spawn_pos
	_start_pos = spawn_pos
	_target = target_node
	is_from_system = from_system
	damage = dmg
	flight_speed = travel_speed
	arc_height = arc_h
	if sprite and arrow_texture:
		sprite.texture = arrow_texture
	var enemy_target_layer = 2 if is_from_system else 3
	collision_layer = 0
	collision_mask = 1 << (enemy_target_layer - 1)
	if is_instance_valid(target_node):
		_last_end_pos = target_node.global_position
	else:
		_last_end_pos = spawn_pos
	var dist := spawn_pos.distance_to(_last_end_pos)
	_flight_time = maxf(dist / maxf(flight_speed, 1.0), 0.1)
	_elapsed = 0.0

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var t := clampf(_elapsed / _flight_time, 0.0, 1.0)
	if is_instance_valid(_target):
		_last_end_pos = _target.global_position
	var mid := (_start_pos + _last_end_pos) * 0.5
	var ctrl := mid + Vector2(0, -arc_height * 2.0)
	var u := 1.0 - t
	var pos := u * u * _start_pos + 2.0 * u * t * ctrl + t * t * _last_end_pos
	var vel := 2.0 * u * (ctrl - _start_pos) + 2.0 * t * (_last_end_pos - ctrl)
	if vel.length_squared() > 0.001:
		rotation = vel.angle()
	global_position = pos
	if t >= 1.0:
		_land()

# 落地：目标仍在落点附近则命中，否则直接消失。
func _land() -> void:
	_finished = true
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= 50.0:
		if _target.has_method("take_damage"):
			_target.take_damage(damage)
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

func _hit_target(target: Node2D) -> void:
	if _finished or not is_instance_valid(target) or target == self:
		return
	if not target.has_method("take_damage"):
		return
	if "is_system_spawned" in target and target.is_system_spawned == is_from_system:
		return
	_finished = true
	target.take_damage(damage)
	queue_free()
