extends CombatStateBase

#### COMBAT MOVE STATE ####

onready var combat_states_node = get_parent()

var combat_loop_node : Node

var path := PoolVector3Array()

var is_moving : bool = false

#### BUILT-IN FUNCTIONS ####

func _ready():
	yield(owner, "ready")
	
	combat_loop_node = owner
	
	var _err = EVENTS.connect("cursor_cell_changed", self, "_on_cursor_cell_changed")

func _process(delta: float):
	if is_moving:
		move_actor(delta)


#### VIRTUAL FUNCTIONS ####

# When the state is entered define the actor postiton, 
# empty the path and path array, and set a path
func enter_state():
	initialize_path_value()
	owner.HUD_node.set_every_action_disabled()
	
	if owner.active_actor != null:
		owner.map_node.draw_movement_area()
		owner.cursor_node.hide_target_counter(false)


# Empty the path variable when the state is exited and 
func exit_state():
	initialize_path_value() # Empty the path
	owner.map_node.clear_movement_arrow()
	owner.area_node.clear()
	owner.cursor_node.hide_target_counter(true)


#### LOGIC ####

# Ask the IsoMap for a path between current actor's cell and the cursor's cell
func set_path(cursor_cell : Vector3, actor_cell : Vector3) -> void:
	owner.map_node.clear_movement_arrow()
	path = combat_loop.pathfinder.find_path(actor_cell, cursor_cell)
	
	var is_path_valid = check_path(path)
	if is_path_valid:
		owner.map_node.generate_movement_arrow(path)
		owner.cursor_node.change_color(Color.white)
	else:
		owner.map_node.clear_movement_arrow()
		owner.cursor_node.change_color(Color.red)


# Check if the path is valid, return true if it is or false if not
func check_path(path_to_check : PoolVector3Array) -> bool:
	if owner.active_actor == null or path.size() <= 1:
		return false
	
	var movements = owner.active_actor.get_current_movements()
	return len(path_to_check) > 0 and len(path_to_check) - 1 <= movements


# Move the active_actor along the path
func move_actor(delta: float):
	var active_actor = combat_loop.active_actor
	
	if len(path) > 0:
		var target_point_world = owner.map_node.cell_to_world(path[0])
		var arrived_to_next_point = active_actor.move_to(delta, target_point_world)
		
		# If the actor is arrived to the next point, 
		# remove this point from the path and take the next for destination
		if arrived_to_next_point == true:
			if path.size() > 1:
				active_actor.set_current_cell(path[1])
			path.remove(0)
	
	if len(path) == 0:
		is_moving = false
		active_actor.set_state("Idle")
		combat_loop.map_node.update_view_field(active_actor)
		owner.emit_signal("actor_action_finished", active_actor)



# Empty the path and potential path arrays
func initialize_path_value():
	path = []


#### SIGNAL REPONSES ####

# On click, give the active actor its destination
# Triggers the player movement
func _unhandled_input(event):
	if event is InputEventMouseButton && combat_states_node.get_state() == self:
		if event.get_button_index() == BUTTON_LEFT && event.pressed:
			if check_path(path):
				is_moving = true
				owner.active_actor.decrement_current_action()
				owner.area_node.clear() # Clear every cells in the area tilemap


# When the cursor has moved, 
# call the function that calculate a new path
func _on_cursor_cell_changed(cursor: Cursor, cell: Vector3):
	if combat_states_node.get_state() == self:
		if owner.active_actor.get_state_name() == "Idle":
			set_path(cell, owner.active_actor.get_current_cell())
			var targets = owner.map_node.count_reachable_enemies(cell)
			cursor.set_targets(targets)
