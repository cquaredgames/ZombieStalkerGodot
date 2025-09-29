extends Node

const TILE_SIZE = 16

enum EntityType {
	# Pickups
	AMMO_PICKUP,
	HEALTH_PICKUP,
	KEY_PICKUP,
	# Entities
	PLAYER_START = 20,
	END_OF_LEVEL = 21,
	ENEMY = 22
}

var entity_scenes := {
	EntityType.HEALTH_PICKUP: preload("res://Assets/scenes/pickups/health.tscn"),
	EntityType.AMMO_PICKUP: preload("res://Assets/scenes/pickups/ammo.tscn"),
	EntityType.KEY_PICKUP: preload("res://Assets/scenes/pickups/key.tscn"),
	EntityType.PLAYER_START: preload("res://Assets/scenes/player.tscn"),
	EntityType.END_OF_LEVEL: preload("res://Assets/scenes/level_end_portal.tscn"),
	EntityType.ENEMY: preload("res://Assets/scenes/enemies/zombie.tscn")
}

# -----------------------
# Utility helpers
# -----------------------
func vec2i_to_str(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]

func str_to_vec2i(s: String) -> Vector2i:
	var parts = s.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

# -----------------------
# Saving (used by editor)
# -----------------------
# LevelLoader.gd (autoload)

var current_level_data: Dictionary = {}

func save_level(path: String, level_data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(level_data, "\t")) # with tabs
		file.close()

#func save_level( path: String, ground_layer: TileMapLayer, marker_layer: TileMapLayer) -> void:
	#var level_data: Dictionary = {}
#
	## Save ground tiles
	#var ground_tiles: Array = []
	#for cell in ground_layer.get_used_cells():
		#var tile_id = ground_layer.get_cell_source_id(cell)
		#ground_tiles.append({
			#"pos": Vector2i(cell),
			#"id": tile_id
		#})
	#level_data["tiles"] = ground_tiles
#
	## Save markers/entities
	#var markers: Array = []
	#for cell in marker_layer.get_used_cells():
		#var tile_id = marker_layer.get_cell_source_id(cell)
		#markers.append({
			#"pos": Vector2i(cell),
			#"id": tile_id
		#})
	#level_data["entities"] = markers
#
	## Write JSON file
	#var file := FileAccess.open(path, FileAccess.WRITE)
	#file.store_string(JSON.stringify(level_data, "\t"))  # pretty print
	#file.close()

func _load_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open level file: %s" % file_path)
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		push_error("Failed to parse JSON")
		return

	return json.get_data()

# -----------------------
# Loading (used by editor)
# -----------------------
func load_level_for_editor(file_path: String, tilemap: TileMapLayer, markers_layer: TileMapLayer) -> void:
	var data = _load_file(file_path)
	
	# Clear old
	tilemap.clear()
	markers_layer.clear()
	
	for tile_entry in data.get("tiles", []):
		var pos = str_to_vec2i(tile_entry["pos"])
		var id = tile_entry["id"]
		tilemap.set_cell(pos, id, Vector2i(0, 0))
		
	for marker in data.get("entities", []):
		var pos = str_to_vec2i(marker["pos"])
		var id = marker["id"]
		markers_layer.set_cell(pos, id, Vector2i(0, 0))
	

# -----------------------
# Loading (used by game)
# -----------------------
func load_level(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Level file not found: %s" % path)
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var result = JSON. parse_string(content)
	if typeof(result) == TYPE_DICTIONARY:
		return result
	else:
		push_error("Failed to parse JSON: %s" % path)
		return {}
	
#func load_level(file_path: String, tilemap: TileMapLayer, parent: Node) -> void:
	#var data = _load_file(file_path)
#
	## Load tiles
	#for tile_entry in data.get("tiles", []):
		#var pos = str_to_vec2i(tile_entry["pos"])
		#var id = tile_entry["id"]
		#tilemap.set_cell(pos, id, Vector2i(0,0))
#
	## Load entities
	#for ent_entry in data.get("entities", []):
		#var pos = str_to_vec2i(ent_entry["pos"])
		#var ent_type = int(ent_entry["id"])
#
		#if entity_scenes.has(ent_type):
			#var scene = entity_scenes[ent_type].instantiate()
			#scene.position = pos * TILE_SIZE
			#parent.add_child(scene)
