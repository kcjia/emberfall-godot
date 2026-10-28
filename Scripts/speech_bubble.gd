# SpeechBubble.gd
extends Node2D

@onready var label: Label = $Label

func pop_text(text: String, duration: float = 1.5) -> void:
	label.text = text
	modulate.a = 0.0
	position.y = 0.0
	scale = Vector2(0.8, 0.8)
	
	var tween = create_tween().set_parallel(true)
	# 向上轻微漂浮 + 放大淡入
	tween.tween_property(self, "position:y", -20.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# 停留后淡出销毁
	var end_tween = create_tween()
	end_tween.tween_interval(duration)
	end_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	end_tween.finished.connect(queue_free)