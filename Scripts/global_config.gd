# GameManager.gd (或你的 Autoload 全局配置脚本)
extends Node

signal gold_updated(current_gold: int)
signal skill_points_updated(current_points: int)
@warning_ignore("unused_signal")
signal game_victory

const SAVE_PATH = "user://game_config.cfg"
const MAX_PLAYER_GOLD: int = 200
# 仅用于本地存档加密，防止玩家直接编辑存档文件修改数据。
const SAVE_PASSWORD: String = "hbzb_save_key_2026"

# --- 1. 玩家核心数据 ---
var player_gold: int = 0
var skill_points: int = 0
var battle_unlocked_monsters: Dictionary[String, bool] = {}
var player_level: int = 1
var unlocked_monsters: Array = ["blackA", "blackB", "blackC", "DemonE", "Flame_Golem", "Minotaur"]
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var user_token: String = ""
var server_url: String = "https://api.yourgame.com"

# --- 2. 技能树强化字典 ---
var upgrades: Dictionary = {
	"kill_gold_lvl": 0,           # 击杀金币等级 (+1/级，最高10)
	"gold_rate_lvl": 0,           # 金币增长速率等级
	"player_skill_1_power_lvl": 0,    # 玩家技能1威力等级
	"player_skill_2_power_lvl": 0,    # 玩家技能2威力等级
	"soldier_damage1_lvl": 0,          # 兵种1威力增幅
	"soldier_Btn1_unlocked": true, # 兵种1解锁
	"soldier_skill1_unlocked": false,  # 兵种技能
	"soldier_damage2_lvl": 0,          # 兵种2威力增幅
	"soldier_Btn2_unlocked": false, # 兵种2解锁
	"soldier_skill2_unlocked": false,  # 兵种技能
	"soldier_damage3_lvl": 0,          # 兵种3威力增幅
	"soldier_Btn3_unlocked": false, # 兵种3解锁
	"soldier_skill3_unlocked": false,  # 兵种技能
	"soldier_damage4_lvl": 0,          # 兵种4威力增幅
	"soldier_Btn4_unlocked": false, # 兵种4解锁
	"soldier_skill4_unlocked": false,  # 兵种技能
	"soldier_damage5_lvl": 0,          # 兵种5威力增幅
	"soldier_Btn5_unlocked": false, # 兵种5解锁
	"soldier_skill5_unlocked": false,  # 兵种技能
	"soldier_damage6_lvl": 0,          # 兵种6威力增幅
	"soldier_Btn6_unlocked": false, # 兵种6解锁
	"soldier_skill6_unlocked": false,  # 兵种技能
	"soldier_damage7_lvl": 0,          # 兵种7威力增幅
	"soldier_Btn7_unlocked": false, # 兵种7解锁
	"soldier_skill7_unlocked": false,  # 兵种技能
	"soldier_damage8_lvl": 0,          # 兵种8威力增幅
	"soldier_Btn8_unlocked": false, # 兵种8解锁
	"soldier_skill8_unlocked": false,  # 兵种技能

}

# --- 3. 系统配置 ---
var current_language: String = "zh"
var current_window_mode: int = 0

func _ready() -> void:
	# 初始化本地配置并应用系统设置。
	load_local_config()
	apply_settings()

func start_new_battle() -> void:
	# 重置本局金币和兵种解锁，按钮 1、2 默认可用。
	player_gold = 0
	battle_unlocked_monsters = {
		"Armored_Axeman": upgrades["soldier_Btn1_unlocked"],
		"Knight_Templar": upgrades["soldier_Btn2_unlocked"],
		"Knight": upgrades["soldier_Btn3_unlocked"]
	}
	gold_updated.emit(player_gold)

func add_gold(amount: int) -> void:
	# 增减金币并通知界面刷新显示。
	player_gold = clampi(player_gold + amount, 0, MAX_PLAYER_GOLD)
	gold_updated.emit(player_gold)

# 增减技能点并持久化保存；技能点不随局内金币重置。
func add_skill_points(amount: int) -> void:
	skill_points = maxi(skill_points + amount, 0)
	skill_points_updated.emit(skill_points)
	save_local_config()

func save_local_config() -> void:
	# 将玩家进度、技能树和系统设置写入本地加密配置。
	var config = ConfigFile.new()
	config.set_value("Player", "gold", player_gold)
	config.set_value("Player", "skill_points", skill_points)
	config.set_value("Player", "level", player_level)
	config.set_value("Player", "unlocked_monsters", unlocked_monsters)
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Audio", "sfx_volume", sfx_volume)
	config.set_value("Network", "user_token", user_token)

	# 存储技能树各节点状态
	for k in upgrades.keys():
		config.set_value("SkillTree", k, upgrades[k])

	config.set_value("System", "language", current_language)
	config.set_value("System", "window_mode", current_window_mode)

	config.save_encrypted_pass(SAVE_PATH, SAVE_PASSWORD)

func load_local_config() -> void:
	# 从本地加密配置读取玩家进度和系统设置。
	var config = ConfigFile.new()
	if config.load_encrypted_pass(SAVE_PATH, SAVE_PASSWORD) != OK:
		save_local_config()
		return

	player_gold = clampi(config.get_value("Player", "gold", 50), 0, MAX_PLAYER_GOLD)
	skill_points = maxi(config.get_value("Player", "skill_points", 0), 0)
	player_level = config.get_value("Player", "level", 1)
	unlocked_monsters = config.get_value("Player", "unlocked_monsters", ["blackA", "blackB", "blackC", "DemonE", "Flame_Golem", "Minotaur"])
	master_volume = config.get_value("Audio", "master_volume", 1.0)
	sfx_volume = config.get_value("Audio", "sfx_volume", 0.8)
	user_token = config.get_value("Network", "user_token", "")

	for k in upgrades.keys():
		upgrades[k] = config.get_value("SkillTree", k, upgrades[k])

	current_language = config.get_value("System", "language", "zh")
	current_window_mode = config.get_value("System", "window_mode", 0)

func apply_settings() -> void:
	# 应用语言和窗口显示设置。
	TranslationServer.set_locale(current_language)
	apply_resolution(current_window_mode)

func apply_resolution(mode_idx: int) -> void:
	# 根据选项设置窗口模式、尺寸和屏幕居中位置。
	# 注意：选项 0 的标签是 1280×768（与工程视口一致），之前代码错写成 1280×720，已修正；
	# 尺寸超过当前屏幕时钳制到屏幕内，避免大尺寸选项在小屏幕上看起来“没反应”。
	# 渲染分辨率也跟随选项（content_scale_size），避免窗口放大后仍用 1280×768 拉伸导致模糊；
	# 编辑器内嵌游戏视图时窗口尺寸由编辑器控制、改不了大小，但渲染分辨率仍会跟随变化。
	current_window_mode = mode_idx
	var window := get_window()
	var screen_size := DisplayServer.screen_get_size(window.current_screen)
	match mode_idx:
		0:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(mini(1280, screen_size.x), mini(768, screen_size.y))
			window.content_scale_size = window.size
		1:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(mini(1920, screen_size.x), mini(1080, screen_size.y))
			window.content_scale_size = window.size
		2:
			window.mode = Window.MODE_WINDOWED
			window.size = Vector2i(mini(2560, screen_size.x), mini(1440, screen_size.y))
			window.content_scale_size = window.size
		3:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			window.content_scale_size = screen_size

	if mode_idx != 3:
		window.position = (screen_size - window.size) / 2