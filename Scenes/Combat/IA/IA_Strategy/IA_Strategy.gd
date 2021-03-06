extends Object
class_name IA_Strategy

export var action_list := PoolStringArray() 

export var default_coef : Dictionary = {
	"wait" : 20.0,
	"attack" : 0.0,
	"move" : 30.0,
	"skill": 0.0,
	"item": 0.0
}

export var target_coef_mod : Dictionary = {
	"ally": -50.0,
	"enemy": 30.0,
	"obstacle": 10.0
}

export var attack_result_coef_mod : Dictionary = {
	"kill": 30.0,
	"low_hp": 15.0,
	"high_damage": 10.0
}

#### ACCESSORS ####

func is_class(value: String): return value == "IA_Strategy" or .is_class(value)
func get_class() -> String: return "IA_Strategy"


#### BUILT-IN ####



#### VIRTUALS ####

func wait(actor: TRPG_Actor, _map: CombatIsoMap) -> Array:
	return [ActorActionRequest.new(actor, "wait")]


func attack(actor: TRPG_Actor, map: CombatIsoMap) -> Array:
	var actions = actor.get_current_actions()
	var movements = actor.get_current_movements()
	var attack_range = actor.get_current_range()
	var total_range = (actions - 1) * movements + attack_range
	
	var targetables = map.get_targetables_in_range(actor, total_range)
	var reacheable_targets = map.get_reachable_targets(actor, total_range, targetables)
	
	var AOE_target = _choose_AOE_target(actor, reacheable_targets)
	
	if AOE_target == null:
		return []
	else:
		return _create_action_from_target(actor, map, AOE_target)


func move(_actor: TRPG_Actor, _map: CombatIsoMap) -> Array:
	return []


func item(_actor: TRPG_Actor, _map: CombatIsoMap) -> Array:
	return [] 


func skill(_actor: TRPG_Actor, _map: CombatIsoMap) -> Array:
	return [] 


#### LOGIC ####


func choose_best_action(actor: TRPG_Actor, map: CombatIsoMap) -> Array:
	var actions = _sort_actions_by_priority()
	
	var i = 0
	var best_action = []
	while(best_action == []):
		best_action = callv(actions[i], [actor, map])
		i += 1
		if i >= actions.size():
			break
	
	return best_action


func _find_biggest_coef(array: Array) -> int:
	var best_coef_id = -1
	var biggest_coef = -INF
	
	for i in range(array.size()):
		var value = array[i]
		if value > biggest_coef:
			biggest_coef = value
			best_coef_id = i

	return best_coef_id


func _sort_actions_by_priority() -> Array:
	var actions = default_coef.duplicate()
	var sorted_actions = Array()
	
	while(!actions.empty()):
		var best_action_id = _find_biggest_coef(actions.values())
		var key = actions.keys()[best_action_id]
		sorted_actions.append(key)
		
		actions.erase(key)
	
	return sorted_actions


func _create_action_from_target(actor: TRPG_Actor, map: IsoMap, aoe_target: AOE_Target) -> Array:
	var actions_array = [ActorActionRequest.new(actor, "attack", [aoe_target])]
	var actor_range = actor.get_current_range()
	var actor_cell = actor.get_current_cell()
	var target_dist = IsoLogic.iso_2D_dist(actor_cell, aoe_target.target_cell)
	
	# Move towards the target if needed
	if target_dist > actor_range:
		var path = map.find_approch_cell_path(actor, aoe_target.target_cell)
		var action = ActorActionRequest.new(actor, "move", [path])
		actions_array.push_front(action)
	
	return actions_array


func _convert_targetables_to_aoe_targets(actor: TRPG_Actor, targetables: Array) -> Array:
	var aoe_targets_array := Array()
	for target in targetables:
		aoe_targets_array.append(AOE_Target.new(actor.get_current_cell(), 
				target.get_current_cell(), 
				actor.get_attack_aoe()))
	
	return aoe_targets_array


func _choose_AOE_target(actor: TRPG_Actor, targetables: Array) -> AOE_Target:
	var target = null
	
	if !targetables.empty():
		var combat_effect_obj = actor.get_current_attack_combat_effect_object()
		target = _choose_best_target(actor, targetables, combat_effect_obj)
	else:
		return null
	
	return AOE_Target.new(actor.get_current_cell(), target.get_current_cell(), 
		actor.get_default_attack_aoe())


func _compute_attack_coefficient(attack_request: ActorActionRequest, map: IsoMap) -> int:
	var coefficient : int = 0
	var attacker : TRPG_Actor = attack_request.actor
	var attacker_team = attacker.get_team()
	var aoe_target : AOE_Target = attack_request.arguments[0]
	var targets_array = map.get_damagable_in_area(aoe_target)
	var attack_effect = attacker.get_current_attack_effect()
	
	for target in targets_array:
		var target_type_name = ""
		var coef_modifier : int = 0 
		if target.is_class("TRPG_Actor"):
			target_type_name = "ally" if target.get_team() == attacker_team else "enemy"
			
			var coef_mod_dict = attack_result_coef_mod
			var avg_damage = attack_effect.damage
			var received_damage = CombatEffectHandler.compute_received_damage(avg_damage, target)
			var target_max_HP = target.get_max_HP()
			var HP_lost_ratio : float = float(received_damage) / float(target_max_HP)
			var HP_left = clamp(target_max_HP - received_damage, 0.0, target_max_HP)
			var HP_left_ratio : float = HP_left / target_max_HP
			
			if HP_left_ratio < 0.25:
				coef_modifier = coef_mod_dict["low_hp"]
			elif HP_left_ratio == 0.0:
				coef_modifier = coef_mod_dict["kill"]
			elif HP_lost_ratio > 0.2:
				coef_modifier = coef_mod_dict["high_damage"]
			
		else:
			target_type_name = "obstacle"
		coefficient += target_coef_mod[target_type_name] + coef_modifier
	
	return coefficient


func _choose_best_target(actor: TRPG_Actor, targets_array: Array, effect: CombatEffectObject) -> TRPG_DamagableObject:
	var indirect_targets = []
	var direct_targets = _find_direct_targets(actor, targets_array, effect)
	
	for target in targets_array:
		if not target in direct_targets:
			indirect_targets.append(target)
	
	var array_to_check = direct_targets if !direct_targets.empty() else indirect_targets
	var lowest_hp_target = _find_lowest_HP_target(array_to_check)
	
	return lowest_hp_target


func _find_lowest_HP_target(target_array: Array) -> TRPG_DamagableObject:
	var lowest_HP_target = null
	var lowest_HP = INF
	
	for target in target_array:
		var hp = target.get_current_HP()
		if hp < lowest_HP:
			lowest_HP = hp
			lowest_HP_target = target
	
	return lowest_HP_target


# Returns an array containing every targets targettable this turn
func _find_direct_targets(actor: TRPG_Actor, target_array: Array, effect: CombatEffectObject) -> Array:
	var direct_targets = []
	var aoe = effect.aoe
	var actor_cell = actor.get_current_cell()
	
	#  Should be done dynamicly
	var left_actions = actor.get_current_actions() - 1
	
	var movement_range = actor.get_current_movements() * left_actions
	var effect_range = aoe.range_size + aoe.area_size
	var total_range = effect_range + movement_range
	
	for target in target_array:
		var dist = IsoLogic.iso_2D_dist(actor_cell, target.get_current_cell())
		if dist <= total_range:
			direct_targets.append(target)
	
	return direct_targets


func _split_move_path(path: PoolVector3Array, segment_size: int) -> Array:
	var path_a = Array(path)
	var slices_array = []
	#warning-ignore:integer_division
	var nb_sub_path = int(path.size() / segment_size)
	var rest = path.size() % segment_size
	var is_rest = bool(rest)
	
	for i in range(nb_sub_path + 1 * int(is_rest)):
		var nb_elem = segment_size if i < nb_sub_path else rest
		var sub_path = []
		for j in range(nb_elem):
			sub_path.append(path_a[i * segment_size + j])
		slices_array.append(sub_path)
	
	return slices_array


#### INPUTS ####



#### SIGNAL RESPONSES ####
