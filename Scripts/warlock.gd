extends "res://Scripts/enemy_base.gd"

const WARLOCK_FIRE_SCENE: PackedScene = preload("res://Scene/SkillScene/Warlock_Fire.tscn")

## Attack1 保持基类的近战伤害；Attack2 对锁定敌人施放火焰。
func deal_swing_damage(is_new_segment: bool = false, custom_multiplier: float = 1.0) -> void:
	if current_state == State.ATTACK1:
		super.deal_swing_damage(is_new_segment, custom_multiplier)

func _on_custom_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Attack2":
		_cast_attack2_fire()

func _cast_attack2_fire() -> void:
	if not _has_valid_target():
		return
	var fire_effect = WARLOCK_FIRE_SCENE.instantiate()
	get_parent().add_child(fire_effect)
	fire_effect.global_position = target.global_position
	if fire_effect.has_method("play_effect"):
		fire_effect.play_effect(attack_damage, target)

