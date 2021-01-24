extends Node

# warnings-disable

#### MAP EVENTS ####

signal appear_transition()
signal disappear_transition()

signal cursor_world_pos_changed(cursor)
signal cursor_cell_changed(cursor, cell)
signal visible_cells_changed()
signal iso_object_cell_changed(iso_object)

signal iso_object_added(iso_object)
signal iso_object_removed(iso_object)

signal actor_moved(actor, from_cell, to_cell)

signal tiles_shake(origin, magnitude)

#### COMBAT EVENTS ####

signal combat_new_turn_started(actor)
signal active_actor_stats_changed(actor)

signal timeline_movement_finished()
