extends Node2D

const tile_size = Vector2(32, 32)
const cell_size = Vector2(32, 16)

var layers_array : Array = [] setget set_layers_array
var objects_array : Array = [] setget set_objects_array
var ground_cells_array : Array = []

var focus_array : Array = [] setget set_focus_array, get_focus_array

func set_focus_array(array: Array):
	focus_array = array

func get_focus_array() -> Array:
	return focus_array

func set_layers_array(array: Array):
	layers_array = array
	for i in range(1, layers_array.size()):
		for cell in layers_array[i].get_node("Ground").get_used_cells():
			ground_cells_array.append(Vector3(cell.x, cell.y, i))

func set_objects_array(array: Array):
	objects_array = array


func _process(_delta):
	update()


func _draw():
	var sorting_array = ground_cells_array + objects_array
	
	sorting_array.sort_custom(self, "xyz_sum_compare")
	for thing in sorting_array:
		if thing is Vector3:
			draw_cellv(thing)
		else:
			draw_object(thing)


# Draw a single given cell
func draw_cellv(cell3D: Vector3):
	var ground = layers_array[cell3D.z].get_node("Ground")
	var tileset = ground.get_tileset()
	var cell = Vector2(cell3D.x, cell3D.y)
	
	draw_tile(ground, tileset, cell, int(cell3D.z))


# Draw the given tile from the given tilemap
func draw_tile(ground: TileMap, tileset: TileSet, cell: Vector2, height: int):
	if !(cell in ground.get_used_cells()):
		return
	
	var is_centered : int = ground.get_tile_origin()
	var modul : Color = ground.get_modulate()
	
	# Handle the tile transparancy
	for object in focus_array:
		var focus_cell = object.get_grid_position()
		
		# Set the color to transparent if the tile is right below the focus cell
		if cell.x >= focus_cell.x + (height - focus_cell.z) - 1 && cell.x <= focus_cell.x + (height - focus_cell.z):
			if cell.y >= focus_cell.y + (height - focus_cell.z) - 1 && cell.y == focus_cell.y + (height - focus_cell.z):
				if height >= focus_cell.z + 1:
					modul.a = 0.65
	
	# Get the tile id and the position of the cell in the autotile
	var tile_id = ground.get_cellv(cell)
	var autotile_pos = ground.get_cell_autotile_coord(int(cell.x), int(cell.y))
	
	# Get the texture
	var stream_texture = tileset.tile_get_texture(tile_id)
	var atlas_texture = AtlasTexture.new()
	atlas_texture.set_atlas(stream_texture)
	atlas_texture.set_region(Rect2(autotile_pos * tile_size, tile_size))
	
	# Set the texture to the right position
	var world_height = Vector2(0, -16 * height)
	var centered_offset = (cell_size / 2 * is_centered)
	var pos = ground.map_to_world(cell) + world_height - centered_offset
	
	# Draw the texture
	draw_texture(atlas_texture, pos, modul)


# Draw the given object
func draw_object(object: IsoObject):
	var modul = object.get_modulate()
	var sprite = object.get_node("Sprite")
	var texture = sprite.get_texture()
	var sprite_centered = sprite.is_centered()
	var sprite_pos = sprite.get_global_position()
	var pos = sprite_pos - (texture.get_size() / 2) * int(sprite_centered)
	draw_texture(texture, pos, modul)


# Draw the whole layer of the given height
func draw_ground_layer(layer_height: int):
	var ground = layers_array[layer_height].get_node("Ground")
	var tileset = ground.get_tileset()
	
	for cell in ground.get_used_cells():
		draw_tile(ground, tileset, cell, layer_height)


# Compare two positions, return true if a must be renderer before b
func xyz_sum_compare(a, b) -> bool:
	var grid_pos_a
	var height_a
	if a is Vector3:
		grid_pos_a = a
		height_a = 1
	else:
		grid_pos_a = a.get_grid_position()
		height_a = a.get_grid_height()
	
	var grid_pos_b
	var height_b
	if b is Vector3:
		grid_pos_b = b
		height_b = 1
	else:
		grid_pos_b = b.get_grid_position()
		height_b = b.get_grid_height()
	
	var sum_a = grid_pos_a.x + grid_pos_a.y + grid_pos_a.z + height_a
	var sum_b = grid_pos_b.x + grid_pos_b.y + grid_pos_b.z + height_b
	
	if sum_a == sum_b:
		if grid_pos_a.y < grid_pos_b.y:
			return true
		else:
			if (a is Vector3) && !(b is Vector3):
				return true
			elif !(a is Actor) && (b is Actor):
				return true
			else:
				return false
	else:
		return sum_a < sum_b