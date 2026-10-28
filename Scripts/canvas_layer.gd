# 已弃用：旧版单按钮、无参数召唤接口。
# 当前 HUD 使用 `Scripts/hud.gd`，并向 EnemySpawner 发送带兵种 ID 的持续生产请求。
extends RefCounted
#
# extends CanvasLayer
# signal spawn_monster_requested
#
# @onready var monster_button: TextureButton = get_node_or_null("MonsterButton")
#
# func _ready() -> void:
# 	if monster_button:
# 		monster_button.pressed.connect(_on_monster_button_pressed)
#
# func _on_monster_button_pressed() -> void:
# 	spawn_monster_requested.emit()