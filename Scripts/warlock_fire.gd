extends Area2D

@export var effect_duration: float = 1.0
@export var damage_interval: float = 0.25

var target_enemy: Node2D

# 初始化火焰特效并保持技能节点待命。
func _ready() -> void:
	visible = false

# 播放火焰特效并在持续时间内周期性伤害锁定目标。
func play_effect(damage_amount: int, target: Node2D) -> void:
	visible = true
	target_enemy = target
	var anim_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not anim_sprite:
		queue_free()
		return
	anim_sprite.play(&"default")

	var elapsed := 0.0
	while elapsed < effect_duration:   
		_deal_damage_to_enemies(damage_amount)
		await get_tree().create_timer(damage_interval).timeout
		elapsed += damage_interval
	queue_free()

# 对绑定的敌方目标持续造成伤害。
func _deal_damage_to_enemies(damage_amount: int) -> void:
	if not is_instance_valid(target_enemy):
		return
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage_amount)
