extends CombatStateBase

#### COMBAT OVERLOOK STATE ####

#### BUILT-IN ####

func _ready():
	yield(owner, "ready")
	var _err = EVENTS.connect("cursor_cell_changed", self, "_on_cursor_changed_cell")


#### VIRTUALS ####

# Called when the current state of the state machine is set to this node
func enter_state():
	if !owner.is_ready:
		yield(owner, "ready")
	
	var active_actor = combat_loop.active_actor
	
	EVENTS.emit_signal("goto_menu_root")
	
	# Update the actions
	if active_actor.is_team_side(ActorTeam.TEAM_TYPE.ALLY):
		var move = can_move()
		var attack = can_attack()
		var skill = can_use_skill()
		var item = can_use_item()
		var wait = can_wait()
		
		EVENTS.emit_signal("update_unabled_actions", move, attack, item, skill, wait)



#### LOGIC ####

# Check if the actor can move
func can_move() -> bool:
	return true

# Check if the actor can attack (ie if a target is reachable)
func can_attack() -> bool:
	return owner.map_node.has_target_reachable(owner.active_actor)


func can_use_item() -> bool:
	return !owner.active_actor.get_team().get_inventory().empty()


func can_use_skill() -> bool:
	return owner.active_actor.get_skills().size() != 0

# Check if the active actor can move
func can_wait() -> bool:
	return true


#### SIGNAL RESPONSES ####

# Adapt the cursor color
func _on_cursor_changed_cell(cursor: Cursor, _cell: Vector3):
	if get_parent().get_state() != self:
		return
	
	cursor.change_color(Color.white)
