extends Control

var cooldown_duration: float = 0.0
var cooldown_remaining: float = 0.0

# 初始化覆盖层并隐藏冷却显示。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# 启动指定时长的顺时针冷却遮罩。
func start_cooldown(duration: float) -> void:
	cooldown_duration = maxf(duration, 0.01)
	cooldown_remaining = cooldown_duration
	visible = true
	queue_redraw()

# 每帧减少剩余冷却时间并刷新遮罩。
func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return

	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if cooldown_remaining == 0.0:
		visible = false
	queue_redraw()

# 绘制随冷却时间顺时针消退的灰色圆形遮罩。
func _draw() -> void:
	if cooldown_remaining <= 0.0:
		return

	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var remaining_ratio := cooldown_remaining / cooldown_duration
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * remaining_ratio
	var points := PackedVector2Array([center])
	var segments := 48
	for index in range(segments + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.2, 0.2, 0.2, 0.7))