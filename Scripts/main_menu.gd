extends Control

# 在检查器 (Inspector) 中可选择游戏主场景文件路径
@export_file("*.tscn") var game_scene_path: String = "res://main.tscn"

# 引用 UI 按钮节点
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton

# 初始化菜单焦点并绑定开始、退出按钮。
func _ready() -> void:
	# 抓取按钮焦点（支持键盘/手柄操作）
	start_button.grab_focus()
	
	# 连接按钮点击信号
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

# 切换到配置的游戏主场景。
func _on_start_button_pressed() -> void:
	# 切换到游戏主场景
	if game_scene_path != "":
		get_tree().change_scene_to_file(game_scene_path)
	else:
		printerr("错误：未在检查器中指定 game_scene_path！")

# 请求关闭游戏进程。
func _on_quit_button_pressed() -> void:
	# 退出游戏（在导出后的游戏或桌面平台有效）
	get_tree().quit()