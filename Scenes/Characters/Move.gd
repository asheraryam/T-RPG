extends StateBase

var character_node : Node

var path : PoolVector2Array = []
var target_point_world : Vector2
var speed = 5.0

# Signal used to notifiy the combat move state that the movement is finished
# Connected from combat move state
signal movement_finished

# Move the actor, until it's arrived to the next point
func update(_delta):
	if len(path) > 0:
		target_point_world = path[0]
		var arrived_to_next_point = move_to(target_point_world)
		
		# If the actor is arrived to the next point, remove this point from the path and take the next for destination
		if arrived_to_next_point == true:
			path.remove(0)
	
	# If the path is empty, change the state to move
	if len(path) == 0:
		emit_signal("movement_finished")
		return "Idle"


# Handle the movement to the next point on the path, return true if the character is arrived
func move_to(world_position):
	var velocity = (world_position - character_node.global_position).normalized() * speed
	if character_node.global_position.distance_to(world_position) <= speed:
		character_node.global_position = world_position
	else:
		character_node.global_position += velocity
	
	return world_position == character_node.global_position

