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
	"entities": []
}

var brush_mode: String = "floor"
var current_tile_id: int = 1
var current_marker_id: int = 0
var is_painting_tiles := false
var is_painting_entity := false
var occuppied_cells = {}

enum EntityType {
	# Pickups
	AMMO_PICKUP, HEALTH_PICKUP, KEY_PICKUP, 
	# Entities
	PLAYER_START = 20, END_OF_LEVEL = 21, ENEMY = 22,
	
	EMPTY = 40
}

var current_entity_type = EntityType.EMPTY

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
	entity_selector.add_item("Empty", EntityType.EMPTY)
	entity_selector.add_separator("Pickups")
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/ammo_pickup.png"), "Ammo", EntityType.AMMO_PICKUP)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/health_pickup.png"), "Health", EntityType.HEALTH_PICKUP)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/key_pickup.png"), "Key", EntityType.KEY_PICKUP)
	
	
	# Initialize EntitySelector dropdown control
	entity_selector.add_separator("Entities")
	#entity_selector.clear()
	entity_selector.add_icon_item(
		preload("res://Assets/sprites/entities/start_tile.png"), "Player Start", EntityType.PLAYER_START)
	entity_selector.add_icon_item(
		preload("res://Assets/sprites/entities/end_tile.png"), "Level End", EntityType.END_OF_LEVEL)
	entity_selector.add_icon_item(
		preload("res://Assets/Sprites/player.png"), "Enemy", EntityType.ENEMY)
	
	current_tile_id = tile_selector.get_item_id(2)
	# Connect dropdown changes
	#tile_selector.item_selected.connect(_on_tile_selected)
	
	LevelLoader.load_level_for_editor("res://testlevel.json", tilemap, markers_layer)

func _input(event: InputEvent):
	if event.is_action_pressed("quit"):
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting_tiles = event.pressed
			if event.pressed:
				_paint_tile(event.position)
				print(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_painting_entity = event.pressed
			if event.pressed:
				_place_pickup(event.position)
				
	# Keep painting while moving mouse
	if event is InputEventMouseMotion and is_painting_tiles:
		_paint_tile(event.position)
	if event is InputEventMouseMotion and is_painting_entity:
		_place_pickup(event.position)

func _paint_tile(mouse_pos: Vector2):
	var local_pos = tilemap.to_local(mouse_pos)
	var cell = tilemap.local_to_map(local_pos)
	
	# Paint the selected tile
	if current_tile_id >= 0:
		tilemap.set_cell(cell, current_tile_id, Vector2i(0,0))
		
#func _place_pickup(pos: Vector2) -> void:
func _place_pickup(mouse_pos: Vector2i):
	var local_pos: Vector2 = tilemap.to_local(mouse_pos)
	var cell: Vector2i = markers_layer.local_to_map(local_pos)
	# Remove old pickup if one exists at this cell
	for i in range(level_data["entities"].size()):
		var pickup = level_data["entities"][i]
		if pickup["screen"] == current_screen and pickup["cell"] == cell:
			level_data["entities"].remove_at(i)
			break
	
	# Add new pickup
	markers_layer.set_cell(cell)
	
	if current_entity_type != EntityType.EMPTY:
		var new_pickup = {
			"screen": current_screen,
			"cell": cell,
			"type": str(current_entity_type) # e.g. "HEALTH", "AMMO", "KEY"
		}
		level_data["entities"].append(new_pickup)
		markers_layer.set_cell(cell, current_entity_type, Vector2i(0,0))	
		print("Placed pickup: ", new_pickup)

func _on_tile_selected(index: int) -> void:
	# store which tile the user picked
	current_tile_id = tile_selector.get_item_id(index)
	is_painting_tiles = false
	
func _on_pickup_selected(index: int) -> void:
	current_entity_type = entity_selector.get_item_id(index)
	$CanvasLayer/ColorRect/Label.text = str(current_entity_type)
	is_painting_tiles = false

func pickup_type_to_name(t: EntityType) -> String:
	match t:
		EntityType.HEALTH_PICKUP: return "health"
		EntityType.AMMO_PICKUP: return "ammo"
		EntityType.KEY_PICKUP: return "key"
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
	LevelLoader.save_level("res://testlevel.json", tilemap, markers_layer)
	#save_level()
