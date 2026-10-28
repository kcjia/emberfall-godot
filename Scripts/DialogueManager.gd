extends CanvasLayer

signal dialogue_finished
signal dialogue_started

@onready var panel: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var content_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ContentLabel
@onready var avatar_rect: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Avatar

var dialogue_queue: Array[Dictionary] = []
var is_typing: bool = false
var is_dialogue_active: bool = false
var current_text: String = ""
var text_tween: Tween

func _ready() -> void:
	panel.visible = false

# 外部调用接口：启动一段对话
func start_dialogue(dialogues: Array[Dictionary]) -> void:
	dialogue_queue = dialogues.duplicate()
	is_dialogue_active = true
	dialogue_started.emit()
	panel.visible = true
	# 对话时暂停游戏物理逻辑（可选）
	# get_tree().paused = true
	_show_next()

# 处理确认键或鼠标点击，推进对话内容
func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if is_typing:
			# 如果还在打字机播放中，点击直接跳到全句
			if text_tween:
				text_tween.kill()
			content_label.visible_characters = -1
			is_typing = false
		else:
			_show_next()

# 显示队列中的下一句对话
func _show_next() -> void:
	if dialogue_queue.is_empty():
		is_dialogue_active = false
		panel.visible = false
		# get_tree().paused = false
		dialogue_finished.emit()
		return
	
	var data = dialogue_queue.pop_front()
	name_label.text = data.get("name", "")
	current_text = data.get("text", "")
	content_label.text = current_text
	
	# 如果有头像纹理
	if data.has("avatar") and data["avatar"]:
		avatar_rect.texture = data["avatar"]
		avatar_rect.visible = true
	else:
		avatar_rect.visible = false

	# 打字机效果
	content_label.visible_ratio = 0.0
	is_typing = true
	var type_speed = 0.03 * current_text.length()
	text_tween = create_tween()
	text_tween.tween_property(content_label, "visible_ratio", 1.0, type_speed)
	text_tween.finished.connect(func():
		is_typing = false
	)
	# 确保在打字机效果完成后显示全部文本
	content_label.visible_characters = -1
