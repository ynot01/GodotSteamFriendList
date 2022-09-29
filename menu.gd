extends Control

var thread: Thread

const friendState = {
	0:"Offline",
	1:"Online",
	2:"Busy",
	3:"Away",
	4:"Snooze",
	5:"Looking For Trade",
	6:"Looking for Play",
}
const friendStateColor = {
	0:Color("CADET_BLUE"),
	1:Color("CHARTREUSE"),
	2:Color("DARK_GOLDENROD"),
	3:Color("DARK_GREEN"),
	4:Color("DARK_CYAN"),
	5:Color("CHOCOLATE"),
	6:Color("CORAL"),
}

var boxes = {}
var available = []
func _ready() -> void:
	var steam = await _init_steam()
	
	# Make sure steam is active!
	if steam["verbal"] != "Steamworks active.":
		push_warning("Steam init failed! "+steam["verbal"])
		get_tree().quit()
	
	Steam.avatar_loaded.connect(_loaded_Avatar.bind("avatar_id", "width", "data"))
	generate_friends()

enum AvatarSizes {
	SMALL=1,
	MEDIUM=2,
	LARGE=3,
}
# 1 = Small, 32x32
# 2 = Medium, 64x64
# 3 = Large, 184x184 (documentation says 128x128???)
# On a 1920x1080 monitor fullscreened, max columns/rows that will fit:
# 1 - 60x32
# 2 - 30x16
# 3 - 10x5
@export var AvatarSize = AvatarSizes.MEDIUM
@export var widthx : int = 30
@export var heighty : int = 16
func generate_friends():
	AvatarSize = clamp(AvatarSize, 1, 3)
	
	for n in get_children():
		if n is Button: continue
		remove_child(n)
		n.queue_free()
	
	for n in Steam.getFriendCount():
		available.push_back(n)
	
	for y in heighty:
		for x in widthx:
			if available.size() == 0: return
			var fr_pos = randi_range(0, available.size()-1)
			var sid = Steam.getFriendByIndex(available[fr_pos], 4)
			available.pop_at(fr_pos)
			var texrect = TextureRect.new()
			var dimensions = 32
			var fontsize = 8
			var ImageInt : int
			match AvatarSize:
				1: # 32x32
					dimensions = 32
					fontsize = 8
					ImageInt = Steam.getSmallFriendAvatar(sid)
				2: # 64x64
					dimensions = 64
					fontsize = 11
					ImageInt = Steam.getMediumFriendAvatar(sid)
				3: # 184x184
					dimensions = 184
					fontsize = 14
					ImageInt = Steam.getLargeFriendAvatar(sid)
			texrect.size = Vector2(dimensions,dimensions)
			texrect.position = Vector2(x * dimensions, y * dimensions)
			var state = Steam.getFriendPersonaState(sid)
			var lbl = Label.new()
			lbl.size = texrect.size
			lbl.autowrap_mode = 1
			lbl.text = str(Steam.getFriendPersonaName(sid))
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.add_theme_font_size_override("font_size", fontsize)
			lbl.add_theme_color_override("font_outline_color", Color("BLACK"))
			lbl.add_theme_color_override("font_color", friendStateColor[state])
			texrect.add_child(lbl)
			boxes[ImageInt] = texrect
			var ImageSize : Dictionary = Steam.getImageSize(ImageInt)
			var ImageRGBA : Dictionary = Steam.getImageRGBA(ImageInt)
			if ImageSize["success"] and ImageRGBA["success"]:
				_loaded_Avatar(0, ImageSize["width"], ImageRGBA["buffer"], texrect)
			else:
				print(Steam.getFriendPersonaName(sid))

func _loaded_Avatar(id: int, ImgSize: int, buffer: PackedByteArray, texrect = 0):
	if texrect is int:
		print("J")
		texrect = boxes[id]
	# Create the image and texture for loading
	var AVATAR = Image.new()
	var AVATAR_TEXTURE: ImageTexture
	AVATAR.create_from_data(ImgSize, ImgSize, false, Image.FORMAT_RGBA8, buffer)
	# Apply it to the texture
	AVATAR_TEXTURE = ImageTexture.create_from_image(AVATAR)
	texrect.texture = AVATAR_TEXTURE
	add_child(texrect)

func _init_steam() -> Dictionary:
	thread = Thread.new()
	thread.start(_init_steam_thread)
	
	while thread.is_alive():
		await get_tree().process_frame
	
	var init_return = thread.wait_to_finish()
	thread = null
	return init_return

func _init_steam_thread() -> Dictionary:
	var INIT: Dictionary = Steam.steamInit(true)
	return INIT


func _on_button_pressed():
	generate_friends()

const grey = Color("101010")
const white = Color("WHITE")
func _on_line_edit_text_changed(new_text : String):
	for n in get_children():
		if n is Button: continue
		var valid = false
		if new_text.length():
			valid = new_text.to_lower() in n.get_child(0).text.to_lower()
		else:
			valid = true
		
		if valid:
			n.modulate = white
		else:
			n.modulate = grey

func _on_exit_pressed():
	get_tree().quit()
