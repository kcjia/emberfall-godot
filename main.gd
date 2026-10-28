extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DialogueManager.start_dialogue([
		{"name": "魔王基地", "text": "愚蠢的人类，地狱的熔岩将吞噬你们的防线！"},
		{"name": "圣殿骑士", "text": "全军列队！守护主水晶，击退恶魔！"}
	])
	await DialogueManager.dialogue_finished
	# 对话结束后，开启玩家与系统敌人的持续生成调度。
	$EnemySpawner.start_spawning()

