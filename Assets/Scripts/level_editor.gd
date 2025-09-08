extends Control

@onready var tile_selector: OptionButton = %TileSelector
@onready var pickup_selector: OptionButton = %PickupSelector
@onready var entity_selector: OptionButton = %EntitySelector
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var current_screen_label: Label = $%CurrentScreenCoords

var current_screen := Vector2i(0, 0)
const SCREEN_SIZE = Vector2i(20, 10)
const MAP_SCREENS := Vector2i(6, 4)  # 6 across, 4 down

var level_data = {
	"screens": {},
	"pickups": {}
}

var brush_mode: String = "floor"
var current_tile_id: int = 1
var is_painting := false
var occuppied_cells = {}


enum PickupType {HEALTH, AMMO, KEY}
var pickup_scenes = {
	PickupType.AMMO: preload("res://Assets/Scenes/Pickups/PickupAmmo.tscn"),
	PickupType.HEALTH: preload("res://Assets/Scenes/Pickups/PickupHealth.tscn"),
	PickupType.KEY: preload("res://Assets/Scenes/Pickups/PickupKey.tscn")
}
var current_pickup_type: PickupType = PickupType.HEALTH

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
	pickup_selector.clear()
	pickup_selector.add_separator("Pickups")
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/health_pickup.png"), "Health", 0)
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/ammo_pickup.png"), "Ammo", 1)
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/pickups/key_pickup.png"), "Key", 2)
	pickup_selector.add_item("Empty", 9)
	
	# Initialize EntitySelector dropdown control
	pickup_selector.add_separator("Entities")
	#pickup_selector.clear()
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/start_tile.png"), "Player Start", 20)
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/tiles/end_tile.png"), "Level End", 21)
	pickup_selector.add_icon_item(
		preload("res://Assets/Sprites/player.png"), "Enemy", 22)
	
	current_tile_id = tile_selector.get_item_id(1)
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
		
func _place_pickup(pos: Vector2) -> void:
	#var local_pos: Vector2 = tilemap.to_local(pos)
	var cell: Vector2i = tilemap.local_to_map(pos)
	var cell_origin: Vector2 = tilemap.map_to_local(cell)  # top-left of the cell in local space
	
	var tile_size_v2: Vector2 = Vector2(tilemap.tile_set.tile_size)  # cast Vector2i -> Vector2
	var half_tile: Vector2 = tile_size_v2 * 0.5
	var pickup_pos := cell_origin + half_tile
	
	if occuppied_cells.has(cell):
		var existing_pickup = occuppied_cells[cell]
		# If same type, do nothing
		if existing_pickup.pickup_type == pickup_type_to_name(
			current_pickup_type):
			return
		# Otherwise, replace it
		existing_pickup.queue_free()
		occuppied_cells.erase(cell)
	
	if pickup_scenes.has(current_pickup_type):
		var scene: PackedScene = pickup_scenes[current_pickup_type]
		var pickup = scene.instantiate()
		var tile_size = tilemap.tile_set.tile_size
		pickup.position = cell_origin    # center of the cell
		tilemap.add_sibling(pickup)
		occuppied_cells[cell] = pickup

func _on_tile_selected(index: int) -> void:
	# store which tile the user picked
	current_tile_id = tile_selector.get_item_id(index)
	is_painting = false
	
func _on_pickup_selected(index: int) -> void:
	var pickup_map = {
		0: "health",
		1: "ammo",
		2: "key"
	}
	current_pickup_type = index# pickup_map[index]
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
	
func load_current_screen():
	var key = _get_current_screen_key()
	tilemap.clear()
	if key in level_data["screens"]:
		var data = level_data["screens"][key]
		for y in range(data.size()):
			for x in range(data[y].size()):
				var tile_id = data[y][x]
				#if tile_id >= 0 && tile_id <10:
				tilemap.set_cell(Vector2i(x,y), tile_id, Vector2i(0,0))
				
