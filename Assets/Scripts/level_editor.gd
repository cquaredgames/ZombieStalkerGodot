extends Control

@onready var tile_selector: OptionButton = %TileSelector
@onready var entity_selector: OptionButton = %EntitySelector
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var markers_layer: TileMapLayer = $MarkersLayer
@onready var current_screen_label: Label = $%CurrentScreenCoords

var current_screen := Vector2i(0, 0)
const SCREEN_SIZE = Vector2i(20, 10)
const MAP_SCREENS := Vector2i(4, 6)  # 6 across, 4 down

var level_data = {
	"screens": {},
	"entities": {}
}

var brush_mode: String = "floor"
var current_tile_id: int = 1
var current_marker_id: int = 0
var is_painting := false
var occuppied_cells = {}

enum PickupType {HEALTH, AMMO, KEY}
enum EntityType {
	# Pickups
	HEALTH_PICKUP, AMMO_PICKUP, KEY_PICKUP, 
	# Entities
	PLAYER_START = 20, END_OF_LEVEL = 21, ENEMY = 22}
var pickup_scenes = {
	PickupType.AMMO: preload("res://Assets/Sprites/pickups/ammo_pickup.png"),
	PickupType.HEALTH: preload("res://Assets/Sprites/pickups/health_pickup.png"),
	PickupType.KEY: preload("res://Assets/Sprites/pickups/key_pickup.png"),
}
var current_entity_type = PickupType.HEALTH

func _ready():
	level_data["screens"]["0,0"] = [
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	]
	
	%CurrentScreenCoords.text = _get_current_screen_key()
	update_screen_buttons()
	
	# Initialize TileSelector dropdown control
	tile_selector.clear()
	tile_selector.add_separator("Barriers")
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/grey_wall.png"), "Grey Wall", 0)
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/blue_wall.png"), "Blue Wall", 1)
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/bush.png"), "Bush", 2)
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/door.png"), "Door", 3)
	
	tile_selector.add_separator("Ground")
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/floor.png"), "Tile Floor", 4)
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/grass.png"), "Grass", 5)
	tile_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/health_regenerator.png"), 
		"Health Reg", 6)
	tile_selector.add_separator("-------")	
	tile_selector.add_item("Blank", 99)

	# Initialize PickupSelector dropdown control
	entity_selector.clear()
	entity_selector.add_item("Empty", 9)
	entity_selector.add_separator("Pickups")
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/health_pickup.png"), "Health", 0)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/ammo_pickup.png"), "Ammo", 1)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/key_pickup.png"), "Key", 2)
	
	
	# Initialize EntitySelector dropdown control
	entity_selector.add_separator("Entities")
	#entity_selector.clear()
	entity_selector.add_icon_item(
		preload("res://Assets/sprites/entities/start_tile.png"), "Player Start", 20)
	entity_selector.add_icon_item(
		preload("res://Assets/sprites/entities/end_tile.png"), "Level End", 21)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/player.png"), "Enemy", 22)
	
	current_tile_id = tile_selector.get_item_id(2)
	# Connect dropdown changes
	#tile_selector.item_selected.connect(_on_tile_selected)

func _input(event: InputEvent):
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if event.pressed:
				_paint_tile(event.position)
				print(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_painting = event.pressed
			if event.pressed:
				_place_pickup(event.position)
				
	# Keep painting while moving mouse
	if event is InputEventMouseMotion and is_painting:
		_paint_tile(event.position)

func _paint_tile(mouse_pos: Vector2):
	var local_pos = tilemap.to_local(mouse_pos)
	var cell = tilemap.local_to_map(local_pos)
	
	# Paint the selected tile
	if current_tile_id >= 0:
		tilemap.set_cell(cell, current_tile_id, Vector2i(0,0))
		level_data.screens[_get_current_screen_key()]["()"]
		
#func _place_pickup(pos: Vector2) -> void:
func _place_pickup(cell: Vector2i):
	# Remove old pickup if one exists at this cell
	for i in range(level_data["pickups"].size()):
		var pickup = level_data["pickups"][i]
		if pickup["screen"] == current_screen and pickup["cell"] == cell:
			level_data["pickups"].remove_at(i)
			break
	
	# Add new pickup
	var new_pickup = {
		"screen": [current_screen.x, current_screen.y],
		"cell": [cell.x, cell.y],
		"type": str(current_entity_type) # e.g. "HEALTH", "AMMO", "KEY"
	}
	level_data["pickups"].append(new_pickup)
	
	print("Placed pickup: ", new_pickup)

	##var local_pos: Vector2 = tilemap.to_local(pos)
	#var cell: Vector2i = markers_layer.local_to_map(pos)
	#var cell_origin: Vector2 = markers_layer.map_to_local(cell)  # top-left of the cell in local space
	#
	#var tile_size_v2: Vector2 = Vector2(markers_layer.tile_set.tile_size)  # cast Vector2i -> Vector2
	#var half_tile: Vector2 = tile_size_v2 * 0.5
	#var pickup_pos := cell_origin + half_tile
	#
	#if current_entity_type >= 0:
		#markers_layer.set_cell(cell, current_entity_type, Vector2i(0,0))
	
	#if occuppied_cells.has(cell):
		#var existing_pickup = occuppied_cells[cell]
		## If same type, do nothing
		#if existing_pickup.pickup_type == pickup_type_to_name(
			#current_entity_type):
			#return
		## Otherwise, replace it
		#existing_pickup.queue_free()
		#occuppied_cells.erase(cell)
	
	#if pickup_scenes.has(current_entity_type):
		##var scene: PackedScene = pickup_scenes[current_enity_type]
		##var pickup = scene.instantiate()
		#var tile_size = tilemap.tile_set.tile_size
		#pickup.position = cell_origin    # center of the cell
		#tilemap.add_sibling(pickup)
		#occuppied_cells[cell] = pickup

func _on_tile_selected(index: int) -> void:
	# store which tile the user picked
	current_tile_id = tile_selector.get_item_id(index)
	is_painting = false
	
func _on_pickup_selected(index: int) -> void:
	current_entity_type = entity_selector.get_item_id(index)
	$CanvasLayer/ColorRect/Label.text = str(current_entity_type)
	is_painting = false

func pickup_type_to_name(t: PickupType) -> String:
	match t:
		PickupType.HEALTH: return "health"
		PickupType.AMMO: return "ammo"
		PickupType.KEY: return "key"
		_: return "unknown"

func _on_fill_screen_button_pressed() -> void:
	if current_tile_id == -1:
		return
	for y in range(SCREEN_SIZE.y):
		for x in range(SCREEN_SIZE.x):
			tilemap.set_cell(Vector2i(x,y), current_tile_id, Vector2i(0,0))

func update_screen_buttons() -> void:
	%LeftButton.disabled = current_screen.x <= 0
	%RightButton.disabled = current_screen.x >= MAP_SCREENS.x - 1
	%UpButton.disabled = current_screen.y <= 0
	%DownButton.disabled = current_screen.y >= MAP_SCREENS.y - 1		
	
func _on_left_pressed() -> void:
	if current_screen.x > 0:
		save_current_screen()
		current_screen.x -= 1
		current_screen_label.text = _get_current_screen_key()
		load_current_screen()
	update_screen_buttons()

func _on_right_pressed() -> void:
	if current_screen.x < SCREEN_SIZE.x - 1:
		save_current_screen()
		current_screen.x += 1
		current_screen_label.text = _get_current_screen_key()
		load_current_screen()
	update_screen_buttons()

func _on_up_pressed() -> void:
	if current_screen.y > 0:
		save_current_screen()
		current_screen.y -= 1
		current_screen_label.text = _get_current_screen_key()
		load_current_screen()
	update_screen_buttons()

func _on_down_pressed() -> void:
	if current_screen.y < MAP_SCREENS.y - 1:
		save_current_screen()
		current_screen.y += 1
		current_screen_label.text = _get_current_screen_key()
		load_current_screen()
	update_screen_buttons()

func _get_current_screen_key():
	return str(current_screen.x) + "," + str(current_screen.y)

func save_current_screen() -> void:
	var key = _get_current_screen_key()
	var data = []
	for y in range(SCREEN_SIZE.y):
		var row = []
		for x in range(SCREEN_SIZE.x):
			row.append(tilemap.get_cell_source_id(Vector2i(x,y)))
		data.append(row)
	level_data["screens"][key] = data
	print("saved screen", key)
	# TODO: save pickups to json file too
	
func load_current_screen() -> void:
	var key = _get_current_screen_key()
	tilemap.clear()
	if key in level_data["screens"]:
		var data = level_data["screens"][key]
		for y in range(data.size()):
			for x in range(data[y].size()):
				var tile_id = data[y][x]
				#if tile_id >= 0 && tile_id <10:
				tilemap.set_cell(Vector2i(x,y), tile_id, Vector2i(0,0))
				
func save_level() -> void:
	var file = FileAccess.open("res://testlevel.json", FileAccess.WRITE)
	if file:
		var json_text := JSON.stringify(level_data, "\t") # pretty-print with tabs
		file.store_string(json_text)
		file.close()
		print("Level saved to user://testlevel.json")
	

func load_level() -> void:
	var file = FileAccess.open("user://testlevel.json", FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_text)
		
		if error == OK:
			level_data = json.data
			print("Level loaded successfully!")
		else:
			print("Failed to parse level file: ", error)


func _on_save_level_pressed() -> void:
	save_level()
