# res://Scripts/hud.gd
extends CanvasLayer

signal spawn_monster_requested(monster_id: String)
signal player_attack_requested(attack_name: String)

const GAME_OVER_MUSIC: AudioStream = preload("res://Sound/Game Over.ogg")

# 下排召唤与攻击按钮
@onready var monster_button1: TextureButton = %MonsterButton1
@onready var monster_button2: TextureButton = %MonsterButton2
@onready var monster_button3: TextureButton = %MonsterButton3
@onready var monster_button4: TextureButton = %MonsterButton4
@onready var monster_button5: TextureButton = %MonsterButton5
@onready var monster_button6: TextureButton = %MonsterButton6
@onready var monster_button7: TextureButton = %MonsterButton7
@onready var monster_button8: TextureButton = %MonsterButton8
@onready var attack2_button: TextureButton = %Attack2Button
@onready var attack3_button: TextureButton = %Attack3Button
@onready var attack2_cooldown_overlay: Control = $Up/HBoxContainer/Attack2Button/CooldownOverlay
@onready var attack3_cooldown_overlay: Control = $Up/HBoxContainer/Attack3Button/CooldownOverlay
@onready var repair_button: Button = $Up/HBoxContainer/RepairButton

# 顶部资源与计时
@onready var gold_label: Label = $Up/HBoxContainer/Sprite2D/GoldLabel
@onready var gold_timer: Timer = $Up/HBoxContainer/Sprite2D/GoldTimer
@onready var time_label: Label = $Up/HBoxContainer/TimerLabel
@onready var skill_tree_btn: Button = $Up/HBoxContainer/SkillTreeButton
@onready var settings_btn: Button = $Up/HBoxContainer/SettingsButton

# 弹窗与控制面板
@onready var game_over_dialog: Control = $GameOverDialog
@onready var restart_button: Button = $GameOverDialog/PanelContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $GameOverDialog/PanelContainer/VBoxContainer/QuitButton
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_restart_btn: Button = $VictoryPanel/VBoxContainer/VictoryRestartBtn

# 技能树弹窗控件
@onready var skill_tree_dialog: Window = $SkillTreeDialog
@onready var skill_points_label: Label = $SkillTreeDialog/ScrollContainer/VBoxContainer/SkillPointsLabel
@onready var btn_gold_rate: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnGoldRate
@onready var player_skill1_power: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnPlayerPower1
@onready var player_skill2_power: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnPlayerPower2
@onready var btn_unlock_1: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock1
@onready var btn_damage_1: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage1
@onready var btn_unlock_2: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock2
@onready var btn_damage_2: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage2
@onready var btn_unlock_3: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock3
@onready var btn_damage_3: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage3
@onready var btn_unlock_4: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock4
@onready var btn_damage_4: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage4
@onready var btn_unlock_5: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock5
@onready var btn_damage_5: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage5
@onready var btn_unlock_6: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock6
@onready var btn_damage_6: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage6
@onready var btn_unlock_7: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock7
@onready var btn_damage_7: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage7
@onready var btn_unlock_8: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnUnlock8
@onready var btn_damage_8: Button = $SkillTreeDialog/ScrollContainer/VBoxContainer/BtnDamage8

# 设置弹窗控件
@onready var settings_dialog: Window = $SettingsDialog
@onready var lang_option: OptionButton = $SettingsDialog/VBoxContainer/HBoxLang/LangOption
@onready var scale_option: OptionButton = $SettingsDialog/VBoxContainer/HBoxScale/ScaleOption
@onready var lang_label: Label = $SettingsDialog/VBoxContainer/HBoxLang/Label
@onready var scale_label: Label = $SettingsDialog/VBoxContainer/HBoxScale/Label

# 语言切换时需要重设文本的静态标签（翻译来自 Localization/ocalization.csv）。
@onready var game_over_title: Label = $GameOverDialog/PanelContainer/VBoxContainer/Title
@onready var victory_title: Label = $VictoryPanel/VBoxContainer/Title
@onready var victory_subtitle: Label = $VictoryPanel/VBoxContainer/SubTitle
@onready var eco_label: Label = $SkillTreeDialog/ScrollContainer/VBoxContainer/EcoLabel
@onready var eco_label2: Label = $SkillTreeDialog/ScrollContainer/VBoxContainer/EcoLabel2
@onready var soldier_label: Label = $SkillTreeDialog/ScrollContainer/VBoxContainer/SoldierLabel

@export var attack2_cooldown: float = 20.0
@export var attack3_cooldown: float = 30.0
@export_group("金币消耗")
@export var monster_unlock_costs: Dictionary = {
	"Armored_Axeman": 0,
	"Knight_Templar": 0,
	"Knight": 20,
	"Lancer": 20,
	"Archer": 50,
	"Wizard": 50,
	"Swordsman": 30,
	"Priest": 30
}
@export var attack2_gold_cost: int = 30
@export var attack3_gold_cost: int = 50
# 基地修复配置（金币新用途之一：花金币回基地生命）。
@export var base_repair_cost: int = 50
@export var base_repair_amount: float = 250.0

var remaining_seconds: float = 30.0 * 60.0 # 30分钟 = 1800秒
var is_game_active: bool = true
var game_over_music_player: AudioStreamPlayer

func _ready() -> void:
	# 初始化界面、金币系统、按钮事件和弹窗状态。
	victory_panel.visible = false
	game_over_dialog.visible = false
	game_over_music_player = AudioStreamPlayer.new()
	game_over_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_music_player.stream = GAME_OVER_MUSIC
	add_child(game_over_music_player)
	
	# 连接并同步金币
	GameManager.gold_updated.connect(_update_gold_display)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	GameManager.start_new_battle()
	
	# 依据技能树动态调整金币增长计时器频率 (金币增长速度增加)
	_update_gold_rate()
	gold_timer.paused = DialogueManager.is_dialogue_active
	gold_timer.start()

	# 按钮点击用于解锁兵种或切换当前持续生产兵种。
	monster_button1.pressed.connect(func(): _try_spawn("Armored_Axeman"))
	monster_button2.pressed.connect(func(): _try_spawn("Knight_Templar"))
	monster_button3.pressed.connect(func(): _try_spawn("Knight"))
	monster_button4.pressed.connect(func(): _try_spawn("Lancer"))
	monster_button5.pressed.connect(func(): _try_spawn("Archer"))
	monster_button6.pressed.connect(func(): _try_spawn("Wizard"))
	monster_button7.pressed.connect(func(): _try_spawn("Swordsman"))
	monster_button8.pressed.connect(func(): _try_spawn("Priest"))

	# 技能释放
	attack2_button.pressed.connect(_start_attack2_cooldown)
	attack3_button.pressed.connect(_start_attack3_cooldown)
	repair_button.pressed.connect(_on_repair_button_pressed)

	# 弹窗按钮响应
	restart_button.pressed.connect(_on_restart_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	victory_restart_btn.pressed.connect(_on_restart_button_pressed)

	# 顶部功能按钮
	skill_tree_btn.pressed.connect(_open_skill_tree)
	settings_btn.pressed.connect(_open_settings)
	skill_tree_dialog.close_requested.connect(func(): skill_tree_dialog.hide())
	settings_dialog.close_requested.connect(func(): settings_dialog.hide())

	_init_settings_options()
	_init_skill_tree_signals()
	_refresh_button_locks()
	_apply_language()

func _process(delta: float) -> void:
	# 倒计时并在时间结束时触发胜利状态。
	if not is_game_active or DialogueManager.is_dialogue_active:
		return

	remaining_seconds -= delta
	if remaining_seconds <= 0.0:
		remaining_seconds = 0.0
		_trigger_victory()

	var minutes: int = int(remaining_seconds / 60.0)
	var seconds: int = int(remaining_seconds) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

func _trigger_victory() -> void:
	# 显示胜利面板并暂停战斗场景，奖励技能点。
	is_game_active = false
	victory_panel.visible = true
	get_tree().paused = true
	GameManager.add_skill_points(5)
	GameManager.game_victory.emit()

func _update_gold_display(val: int) -> void:
	# 更新顶部金币文本。
	gold_label.text = str(val)
	_refresh_repair_button()

func _on_gold_timer_timeout() -> void:
	# 按金币计时器周期增加金币。
	if DialogueManager.is_dialogue_active:
		return
	GameManager.add_gold(1)

func _on_dialogue_started() -> void:
	# 对话期间暂停金币增长计时器。
	gold_timer.paused = true

func _on_dialogue_finished() -> void:
	# 对话结束后恢复金币增长计时器。
	gold_timer.paused = false

func _update_gold_rate() -> void:
	# 根据技能树等级调整金币增长间隔。
	# 初始 1 秒一次，每升 1 级间隔缩短 15%
	var rate_lvl: int = GameManager.upgrades["gold_rate_lvl"]
	gold_timer.wait_time = max(0.2, 1.0 / (1.0 + rate_lvl * 0.2))

func _try_spawn(monster_id: String) -> void:
	# 未解锁时消耗金币解锁；已解锁时只切换持续生产兵种，不再重复扣费。
	if GameManager.battle_unlocked_monsters.get(monster_id, false):
		spawn_monster_requested.emit(monster_id)
		return
	var unlock_cost: int = int(monster_unlock_costs.get(monster_id, 0))
	if GameManager.player_gold < unlock_cost:
		print("金币不足，无法解锁: ", monster_id)
		return
	GameManager.add_gold(-unlock_cost)
	GameManager.battle_unlocked_monsters[monster_id] = true
	_refresh_button_locks()
	spawn_monster_requested.emit(monster_id)

func _start_attack2_cooldown() -> void:
	# 金币足够时释放技能 1 并进入冷却。
	if attack2_button.disabled or GameManager.player_gold < attack2_gold_cost:
		return
	GameManager.add_gold(-attack2_gold_cost)
	attack2_button.disabled = true
	attack2_cooldown_overlay.start_cooldown(attack2_cooldown)
	player_attack_requested.emit("Attack2")
	await get_tree().create_timer(attack2_cooldown).timeout
	attack2_button.disabled = false

func _start_attack3_cooldown() -> void:
	# 金币足够时释放技能 2 并进入冷却。
	if attack3_button.disabled or GameManager.player_gold < attack3_gold_cost:
		return
	GameManager.add_gold(-attack3_gold_cost)
	attack3_button.disabled = true
	attack3_cooldown_overlay.start_cooldown(attack3_cooldown)
	player_attack_requested.emit("Attack3")
	await get_tree().create_timer(attack3_cooldown).timeout
	attack3_button.disabled = false

func _on_repair_button_pressed() -> void:
	# 花金币修复玩家基地：金币新用途之一。
	if GameManager.player_gold < base_repair_cost:
		return
	var base = get_tree().get_first_node_in_group("player_base")
	if base == null or not base.has_method("heal"):
		return
	if "current_health" in base and "max_health" in base and base.current_health >= base.max_health:
		return
	GameManager.add_gold(-base_repair_cost)
	base.heal(base_repair_amount)

func _refresh_repair_button() -> void:
	# 刷新修复按钮的可用状态：金币不足、找不到基地或基地满血时禁用。
	var base = get_tree().get_first_node_in_group("player_base")
	var full_hp := false
	if base != null and "current_health" in base and "max_health" in base:
		full_hp = base.current_health >= base.max_health
	repair_button.disabled = GameManager.player_gold < base_repair_cost or base == null or full_hp
	repair_button.tooltip_text = tr("UI_REPAIR_TOOLTIP") % [base_repair_cost, int(base_repair_amount)]

func show_game_over() -> void:
	# 显示游戏结束弹窗并聚焦重开按钮，奖励技能点。
	GameManager.add_skill_points(1)
	game_over_dialog.visible = true
	if not game_over_music_player.playing:
		game_over_music_player.play()
	restart_button.grab_focus()

# 显示敌方基地被摧毁后的胜利面板并暂停战斗。
func show_victory() -> void:
	if not is_game_active:
		return
	_trigger_victory()

func _on_restart_button_pressed() -> void:
	# 解除暂停并重新载入当前战斗场景。
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	# 解除暂停并退出游戏。
	get_tree().paused = false
	get_tree().quit()

# ----------------- 技能树交互逻辑 -----------------
func _open_skill_tree() -> void:
	# 刷新并打开技能树窗口。
	_update_skill_tree_ui()
	skill_tree_dialog.popup_centered()

const MAX_UPGRADE_LEVEL: int = 10
func _init_skill_tree_signals() -> void:
	# 连接技能树各升级按钮的购买逻辑。
	# 金币增速提升 (上限 10 级)
	btn_gold_rate.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["gold_rate_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["gold_rate_lvl"] += 1
			_update_gold_rate()
			_after_upgrade()
	)
	player_skill1_power.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["player_skill_1_power_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["player_skill_1_power_lvl"] += 1
			_after_upgrade()
	)
	player_skill2_power.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["player_skill_2_power_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["player_skill_2_power_lvl"] += 1
			_after_upgrade()
	)
	
	# 兵种解锁 (单次解锁)
	btn_unlock_1.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn1_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_1.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage1_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage1_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_2.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn2_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_2.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage2_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage2_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_3.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn3_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_3.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage3_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage3_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_4.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn4_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_4.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage4_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage4_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_5.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn5_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_5.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage5_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage5_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_6.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn6_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_6.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage6_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage6_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_7.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn7_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_7.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage7_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage7_lvl"] += 1
			_after_upgrade()
	)

	# 兵种解锁 (单次解锁)
	btn_unlock_8.pressed.connect(func():
		if _buy_upgrade(1):
			GameManager.upgrades["soldier_Btn8_unlocked"] = true
			_after_upgrade()
	)
	# 兵种伤害强化 (上限 10 级)
	btn_damage_8.pressed.connect(func():
		if _buy_upgrade(1):
			if GameManager.upgrades["soldier_damage8_lvl"] >= MAX_UPGRADE_LEVEL:
				return
			GameManager.upgrades["soldier_damage8_lvl"] += 1
			_after_upgrade()
	)

func _buy_upgrade(cost: int) -> bool:
	# 检查并扣除升级所需的技能点。
	if GameManager.skill_points >= cost:
		GameManager.add_skill_points(-cost)
		return true
	return false

func _after_upgrade() -> void:
	# 保存升级结果并刷新技能树和技能按钮状态。
	GameManager.save_local_config()
	_update_skill_tree_ui()
	_refresh_button_locks()

func _update_skill_tree_ui() -> void:
	var up = GameManager.upgrades
	skill_points_label.text = tr("UI_SKILL_POINTS") % GameManager.skill_points
	
	# 1. 金币增速等级
	var rate_lvl: int = up["gold_rate_lvl"]
	btn_gold_rate.disabled = (rate_lvl >= MAX_UPGRADE_LEVEL)
	if rate_lvl >= MAX_UPGRADE_LEVEL:
		btn_gold_rate.text = tr("SKILL_GOLD_RATE_MAX")
	else:
		btn_gold_rate.text = tr("SKILL_GOLD_RATE") % rate_lvl

	# 2. 玩家技能1威力等级
	var player_skill1_power_lvl: int = up["player_skill_1_power_lvl"]
	player_skill1_power.disabled = (player_skill1_power_lvl >= MAX_UPGRADE_LEVEL)
	if player_skill1_power_lvl >= MAX_UPGRADE_LEVEL:
		player_skill1_power.text = tr("SKILL_PLAYER_POWER1_MAX")
	else:
		player_skill1_power.text = tr("SKILL_PLAYER_POWER1") % player_skill1_power_lvl

	# 3. 玩家技能2威力等级
	var player_skill2_power_lvl: int = up["player_skill_2_power_lvl"]
	player_skill2_power.disabled = (player_skill2_power_lvl >= MAX_UPGRADE_LEVEL)
	if player_skill2_power_lvl >= MAX_UPGRADE_LEVEL:
		player_skill2_power.text = tr("SKILL_PLAYER_POWER2_MAX")
	else:
		player_skill2_power.text = tr("SKILL_PLAYER_POWER2") % player_skill2_power_lvl
	
	# 4. 兵种与兵种技能
	btn_unlock_1.disabled = up["soldier_Btn1_unlocked"]
	btn_unlock_1.text = tr("SKILL_UNLOCKED") if up["soldier_Btn1_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_2.visible = up["soldier_Btn1_unlocked"]
	btn_unlock_2.disabled = up["soldier_Btn2_unlocked"]
	btn_unlock_2.text = tr("SKILL_UNLOCKED") if up["soldier_Btn2_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_3.visible = up["soldier_Btn2_unlocked"]
	btn_unlock_3.disabled = up["soldier_Btn3_unlocked"]
	btn_unlock_3.text = tr("SKILL_UNLOCKED") if up["soldier_Btn3_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_4.visible = up["soldier_Btn3_unlocked"]
	btn_unlock_4.disabled = up["soldier_Btn4_unlocked"]
	btn_unlock_4.text = tr("SKILL_UNLOCKED") if up["soldier_Btn4_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_5.visible = up["soldier_Btn4_unlocked"]
	btn_unlock_5.disabled = up["soldier_Btn5_unlocked"]
	btn_unlock_5.text = tr("SKILL_UNLOCKED") if up["soldier_Btn5_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_6.visible = up["soldier_Btn5_unlocked"]
	btn_unlock_6.disabled = up["soldier_Btn6_unlocked"]
	btn_unlock_6.text = tr("SKILL_UNLOCKED") if up["soldier_Btn6_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_7.visible = up["soldier_Btn6_unlocked"]
	btn_unlock_7.disabled = up["soldier_Btn7_unlocked"]
	btn_unlock_7.text = tr("SKILL_UNLOCKED") if up["soldier_Btn7_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	btn_unlock_8.visible = up["soldier_Btn7_unlocked"]
	btn_unlock_8.disabled = up["soldier_Btn8_unlocked"]
	btn_unlock_8.text = tr("SKILL_UNLOCKED") if up["soldier_Btn8_unlocked"] else tr("SKILL_UNLOCK_SOLDIER")
	
	
	# 5. 兵种伤害提升
	var dmg_lvl: int = up["soldier_damage1_lvl"]
	btn_damage_1.visible = up["soldier_Btn1_unlocked"]
	btn_damage_1.disabled = (dmg_lvl >= MAX_UPGRADE_LEVEL)
	if dmg_lvl >= MAX_UPGRADE_LEVEL:
		btn_damage_1.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_1.text = tr("SKILL_DAMAGE") % dmg_lvl
	
	var dmg_lvl2: int = up["soldier_damage2_lvl"]
	btn_damage_2.visible = up["soldier_Btn2_unlocked"]
	btn_damage_2.disabled = (dmg_lvl2 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl2 >= MAX_UPGRADE_LEVEL:
		btn_damage_2.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_2.text = tr("SKILL_DAMAGE") % dmg_lvl2

	var dmg_lvl3: int = up["soldier_damage3_lvl"]
	btn_damage_3.visible = up["soldier_Btn3_unlocked"]
	btn_damage_3.disabled = (dmg_lvl3 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl3 >= MAX_UPGRADE_LEVEL:
		btn_damage_3.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_3.text = tr("SKILL_DAMAGE") % dmg_lvl3

	var dmg_lvl4: int = up["soldier_damage4_lvl"]
	btn_damage_4.visible = up["soldier_Btn4_unlocked"]
	btn_damage_4.disabled = (dmg_lvl4 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl4 >= MAX_UPGRADE_LEVEL:
		btn_damage_4.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_4.text = tr("SKILL_DAMAGE") % dmg_lvl4

	var dmg_lvl5: int = up["soldier_damage5_lvl"]
	btn_damage_5.visible = up["soldier_Btn5_unlocked"]
	btn_damage_5.disabled = (dmg_lvl5 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl5 >= MAX_UPGRADE_LEVEL:
		btn_damage_5.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_5.text = tr("SKILL_DAMAGE") % dmg_lvl5

	var dmg_lvl6: int = up["soldier_damage6_lvl"]
	btn_damage_6.visible = up["soldier_Btn6_unlocked"]
	btn_damage_6.disabled = (dmg_lvl6 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl6 >= MAX_UPGRADE_LEVEL:
		btn_damage_6.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_6.text = tr("SKILL_DAMAGE") % dmg_lvl6

	var dmg_lvl7: int = up["soldier_damage7_lvl"]
	btn_damage_7.visible = up["soldier_Btn7_unlocked"]
	btn_damage_7.disabled = (dmg_lvl7 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl7 >= MAX_UPGRADE_LEVEL:
		btn_damage_7.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_7.text = tr("SKILL_DAMAGE") % dmg_lvl7

	var dmg_lvl8: int = up["soldier_damage8_lvl"]
	btn_damage_8.visible = up["soldier_Btn8_unlocked"]
	btn_damage_8.disabled = (dmg_lvl8 >= MAX_UPGRADE_LEVEL)
	if dmg_lvl8 >= MAX_UPGRADE_LEVEL:
		btn_damage_8.text = tr("SKILL_DAMAGE_MAX")
	else:
		btn_damage_8.text = tr("SKILL_DAMAGE") % dmg_lvl8

		
func _refresh_button_locks() -> void:
	monster_button1.visible = GameManager.upgrades["soldier_Btn1_unlocked"]
	monster_button2.visible = GameManager.upgrades["soldier_Btn2_unlocked"] and GameManager.upgrades["soldier_Btn1_unlocked"]
	monster_button3.visible = GameManager.upgrades["soldier_Btn3_unlocked"] and GameManager.upgrades["soldier_Btn2_unlocked"]
	monster_button4.visible = GameManager.upgrades["soldier_Btn4_unlocked"] and GameManager.upgrades["soldier_Btn3_unlocked"]
	monster_button5.visible = GameManager.upgrades["soldier_Btn5_unlocked"] and GameManager.upgrades["soldier_Btn4_unlocked"]
	monster_button6.visible = GameManager.upgrades["soldier_Btn6_unlocked"] and GameManager.upgrades["soldier_Btn5_unlocked"]
	monster_button7.visible = GameManager.upgrades["soldier_Btn7_unlocked"] and GameManager.upgrades["soldier_Btn6_unlocked"]
	monster_button8.visible = GameManager.upgrades["soldier_Btn8_unlocked"] and GameManager.upgrades["soldier_Btn7_unlocked"]
	_update_monster_button(monster_button1, "Armored_Axeman")
	_update_monster_button(monster_button2, "Knight_Templar")
	_update_monster_button(monster_button3, "Knight")
	_update_monster_button(monster_button4, "Lancer")
	_update_monster_button(monster_button5, "Archer")
	_update_monster_button(monster_button6, "Wizard")
	_update_monster_button(monster_button7, "Swordsman")
	_update_monster_button(monster_button8, "Priest")

# 刷新兵种按钮的可点击状态和解锁价格提示。
func _update_monster_button(button: TextureButton, monster_id: String) -> void:
	button.disabled = false
	if GameManager.battle_unlocked_monsters.get(monster_id, false):
		button.tooltip_text = tr("UI_SELECT_PRODUCTION") % monster_id
	else:
		button.tooltip_text = tr("UI_UNLOCK_FOR_GOLD") % [monster_id, int(monster_unlock_costs.get(monster_id, 0))]

# ----------------- 设置与多语言逻辑 -----------------
func _open_settings() -> void:
	# 打开设置窗口。
	settings_dialog.popup_centered()

func _init_settings_options() -> void:
	# 初始化语言和分辨率选项并连接变更事件。
	lang_option.clear()
	lang_option.add_item("简体中文", 0)
	lang_option.add_item("English", 1)
	lang_option.add_item("日本語", 2)
	
	match GameManager.current_language:
		"zh": lang_option.select(0)
		"en": lang_option.select(1)
		"ja": lang_option.select(2)
		
	lang_option.item_selected.connect(func(idx):
		match idx:
			0: GameManager.current_language = "zh"
			1: GameManager.current_language = "en"
			2: GameManager.current_language = "ja"
		GameManager.apply_settings()
		GameManager.save_local_config()
		_apply_language()
	)

	_refresh_scale_option_items()
	scale_option.item_selected.connect(func(idx):
		GameManager.apply_resolution(idx)
		GameManager.save_local_config()
	)

# 根据当前语言刷新所有界面静态文本（翻译来自 Localization/ocalization.csv）。
# 之前语言切换只改了存档里的语言值、没有重设任何文本，所以界面一直停留在中文。
func _apply_language() -> void:
	skill_tree_btn.text = tr("UI_SKILL_TREE")
	settings_btn.text = tr("UI_SETTINGS")
	repair_button.text = tr("UI_REPAIR_BASE")
	attack2_button.tooltip_text = tr("UI_ATTACK2_TOOLTIP")
	attack3_button.tooltip_text = tr("UI_ATTACK3_TOOLTIP")
	settings_dialog.title = tr("UI_SETTINGS_TITLE")
	lang_label.text = tr("UI_LANGUAGE_LABEL")
	scale_label.text = tr("UI_RESOLUTION_LABEL")
	_refresh_scale_option_items()
	skill_tree_dialog.title = tr("UI_SKILL_TREE_TITLE")
	eco_label.text = tr("UI_ECO_SECTION")
	eco_label2.text = tr("UI_SKILL_SECTION")
	soldier_label.text = tr("UI_SOLDIER_SECTION")
	game_over_title.text = tr("UI_GAME_OVER")
	restart_button.text = tr("UI_RESTART")
	quit_button.text = tr("UI_QUIT")
	victory_title.text = tr("UI_VICTORY")
	victory_subtitle.text = tr("UI_VICTORY_DESC")
	victory_restart_btn.text = tr("UI_RESTART")
	_update_skill_tree_ui()
	_refresh_button_locks()
	_refresh_repair_button()

# 按当前语言重建分辨率选项（切换语言时选项文本也跟着翻译）。
func _refresh_scale_option_items() -> void:
	scale_option.clear()
	scale_option.add_item(tr("UI_RES_768"), 0)
	scale_option.add_item(tr("UI_RES_1080"), 1)
	scale_option.add_item(tr("UI_RES_1440"), 2)
	scale_option.add_item(tr("UI_RES_FULLSCREEN"), 3)
	scale_option.select(GameManager.current_window_mode)
