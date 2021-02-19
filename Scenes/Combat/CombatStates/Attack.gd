extends CombatStateBase

const DAMAGE_LABEL_SCENE := preload("res://Scenes/Combat/DamageLabel/DamageLabel.tscn")

#### COMBAT ATTACK STATE ####


#### BUILT-IN ####

func _ready():
	var _err = EVENTS.connect("cursor_cell_changed", self, "on_cursor_changed_cell")


#### VIRTUAL FUNCTIONS ####

func enter_state():
	generate_reachable_aera()
	combat_loop.HUD_node.set_every_action_disabled()


func exit_state():
	combat_loop.area_node.clear()


#### LOGIC ####

# Order the area to draw the reachable cells
func generate_reachable_aera():
	var active_actor : Actor = combat_loop.active_actor
	var actor_cell = active_actor.get_current_cell()
	var actor_range = active_actor.get_current_range()
	var actor_height = active_actor.get_height()
	var reachables = combat_loop.map_node.get_reachable_cells(actor_cell, actor_height, actor_range)
	combat_loop.area_node.draw_area(reachables, "damage")


# Target choice
func _unhandled_input(event):
	if event is InputEventMouseButton && get_parent().get_state() == self:
		if event.get_button_index() == BUTTON_LEFT && event.pressed:
			
			var active_actor = combat_loop.active_actor
			var target = get_cursor_target()
			var target_cell = target.get_current_cell()
			var reachables_cells = combat_loop.area_node.get_area_cells()
			
			# Check if the target is reachable
			if !target is DamagableObject or !target_cell in reachables_cells or\
				!owner.allies_team.is_cell_in_view_field(target_cell):
				return null
			
			if target:
				var damage = compute_damage(active_actor, target)
				instance_damage_label(damage, target)
				target.hurt(damage)
				combat_loop.active_actor.decrement_current_action()
				
				yield(target, "hurt_animation_finished")
				owner.emit_signal("actor_action_finished", active_actor)


# Instanciate a damage label with the given amount on top of the given target
func instance_damage_label(damage: int, target: DamagableObject):
	var damage_label = DAMAGE_LABEL_SCENE.instance()
	damage_label.set_global_position(target.get_global_position())
	damage_label.set_damage(damage)
	
	combat_loop.call_deferred("add_child", damage_label)


# Return the target designated by the cursor
func get_cursor_target() -> DamagableObject:
	var cursor_cell = combat_loop.cursor_node.get_current_cell()
	var object = combat_loop.map_node.get_object_on_cell(cursor_cell)
	
	return object


# Return the amount of damage the attacker inflict to the target
func compute_damage(attacker: Actor, target: DamagableObject) -> int:
	var att = attacker.get_weapon().get_attack()
	var def = target.get_defense()
	
	return int(clamp(att - def, 0.0, INF))


#### SIGNAL RESPONSES ####

# Adapt the cursor color
func on_cursor_changed_cell(cursor : Cursor, _cell: Vector3):
	if get_parent().get_state() != self:
		return
	
	if get_cursor_target():
		cursor.change_color(Color.white)
	else:
		cursor.change_color(Color.red)
