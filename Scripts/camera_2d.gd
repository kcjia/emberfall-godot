extends Camera2D

@export var min_zoom: float = 1  # 最远可拉到的缩小极限（视野最大）
@export var max_zoom: float = 2.0  # 最近可放大到的极限
@export var zoom_speed: float = 0.1

# --- 键盘移动配置 ---
@export var move_speed: float = 600.0   # 摄像机移动速度
@export var smoothness: float = 25.0  # 平滑度（数值越大按键响应越快）

# 内部速度变量，用于实现物理惯性减速
var current_velocity: Vector2 = Vector2.ZERO

# 根据方向键输入平滑移动镜头。
func _process(delta: float) -> void:
	var target_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# 计算目标速度
	var target_velocity = target_dir * move_speed

	# 使用帧率无关的指数插值实现速度的渐入渐出。
	var interpolation_weight = 1.0 - exp(-smoothness * delta)
	current_velocity = current_velocity.lerp(target_velocity, interpolation_weight)

	# 应用位置移动
	global_position += current_velocity * delta
		

# 响应鼠标滚轮输入以调整镜头缩放。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# 滚轮向下：缩小镜头（拉远，看更大范围）
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_level(zoom.x - zoom_speed)
		# 滚轮向上：放大镜头（拉近）
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_level(zoom.x + zoom_speed)

# 将镜头缩放限制在允许范围内后应用。
func set_zoom_level(value: float) -> void:
	# 限制缩放区间，防止缩小或放大过度
	var clamped_value = clamp(value, min_zoom, max_zoom)
	zoom = Vector2(clamped_value, clamped_value)