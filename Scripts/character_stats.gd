class_name CharacterStats
extends RefCounted

# 集中管理所有角色的基础属性，键名格式为“角色名_属性名”。
# 唯一生效处：单位出生时按角色名查表覆盖，场景根节点里的同名属性会被覆盖、改了也没用，改数值只改这里。
const DATA: Dictionary = {
    #玩家兵种属性
	"Armored_Axeman_max_health": 280,
	"Armored_Axeman_move_speed": 120.0,
	"Armored_Axeman_attack_damage": 40,
	"Knight_max_health": 300,
	"Knight_move_speed": 100.0,
	"Knight_attack_damage": 50,
	"Knight_Templar_max_health": 100,
	"Knight_Templar_move_speed": 80.0,
	"Knight_Templar_attack_damage": 10,
	"Knight_Templar_attack_cooldown": 1.0,
	"Lancer_max_health": 500,
	"Lancer_move_speed": 200.0,
	"Lancer_attack_damage": 80,
	"Priest_max_health": 250,
	"Priest_move_speed": 150.0,
	"Priest_attack_damage": 50,
	"Priest_attack_cooldown": 0.5,
	"Swordsman_max_health": 500,
	"Swordsman_move_speed": 120.0,
	"Swordsman_attack_damage": 60,
	"Wizard_max_health": 300,
	"Wizard_move_speed": 120.0,
	"Wizard_attack_cooldown": 2.0,


    #小怪属性
	"black_knight_a_max_health": 200,
	"black_knight_a_attack_damage": 40,
	"black_knight_b_max_health": 1000,
	"black_knight_b_attack_damage": 20,
	"black_knight_b_attack_cooldown": 4.0,
	"black_knight_C_max_health": 800,
	"black_knight_C_move_speed": 150.0,
	"black_knight_C_attack_damage": 40,
	"black_knight_C_attack_cooldown": 1.5,
	"Demon_A_max_health": 100,
	"Demon_A_move_speed": 80.0,
	"Demon_A_attack_damage": 10,
	"Demon_A_attack_cooldown": 1.0,
	"Demon_D_max_health": 1000,
	"Demon_D_move_speed": 50.0,
	"Demon_D_attack_damage": 100,
	"Demon_E_max_health": 500,
	"Demon_E_move_speed": 120.0,
	"Demon_E_attack_damage": 50,
	"Elite_Orc_max_health": 650,
	"Elite_Orc_move_speed": 180.0,
	"Elite_Orc_attack_damage": 100,
	"Flame_Golem_max_health": 2000,
	"Flame_Golem_move_speed": 25.0,
	"Flame_Golem_attack_damage": 100,
	"Flame_Golem_attack_cooldown": 4.0,
	"Minotaur_max_health": 1000,
	"Minotaur_move_speed": 100.0,
	"Minotaur_attack_damage": 200,
	"Slime_max_health": 150,
	"Slime_attack_damage": 20,
	"Warlock_max_health": 500,
	"Warlock_attack_damage": 100,
	"Orc_rider_max_health": 100,
	"Orc_rider_move_speed": 80.0,
	"Orc_rider_attack_damage": 10,
	"Orc_rider_attack_cooldown": 1.0,
	"Werebear_max_health": 100,
	"Werebear_move_speed": 80.0,
	"Werebear_attack_damage": 10,
	"Werebear_attack_cooldown": 1.0,
	"Werewolf_max_health": 100,
	"Werewolf_move_speed": 80.0,
	"Werewolf_attack_damage": 10,
	"Werewolf_attack_cooldown": 1.0
}

# 按角色名和属性名读取一个基础属性。
static func get_attribute(character_name: String, attribute_name: String, default_value = null):
	return DATA.get("%s_%s" % [character_name, attribute_name], default_value)

# 返回角色当前已配置的全部基础属性。
static func get_character_attributes(character_name: String) -> Dictionary:
	var attributes: Dictionary = {}
	var prefix := "%s_" % character_name
	for key in DATA:
		if key.begins_with(prefix):
			attributes[key.trim_prefix(prefix)] = DATA[key]
	return attributes
