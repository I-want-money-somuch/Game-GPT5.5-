extends SceneTree

const OUTLINE := Color8(22, 20, 24)
const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_make_dirs()
	_save("res://assets/sprites/characters/player_vanguard.png", _sprite(32, _draw_player))
	_save("res://assets/sprites/enemies/ashling.png", _sprite(32, _draw_ashling))
	_save("res://assets/sprites/enemies/glassmite.png", _sprite(32, _draw_glassmite))
	_save("res://assets/sprites/enemies/iron_husk.png", _sprite(32, _draw_iron_husk))
	_save("res://assets/sprites/enemies/cinder_bulwark.png", _sprite(48, _draw_cinder_bulwark))
	_save("res://assets/sprites/enemies/depths_warden.png", _sprite(64, _draw_depths_warden))
	_save("res://assets/sprites/items/pickup_weapon.png", _sprite(32, _draw_weapon_pickup))
	_save("res://assets/sprites/items/pickup_equipment.png", _sprite(32, _draw_equipment_pickup))
	_save("res://assets/sprites/effects/player_projectile.png", _sprite(32, _draw_player_projectile))
	_save("res://assets/sprites/effects/boss_projectile.png", _sprite(32, _draw_boss_projectile))
	_save("res://assets/sprites/interactables/chest_body.png", _sprite(32, _draw_chest_body))
	_save("res://assets/sprites/interactables/chest_lid.png", _sprite(32, _draw_chest_lid))
	_save("res://assets/sprites/interactables/forge_station.png", _sprite(32, _draw_forge_station))
	_save("res://assets/sprites/interactables/forge_core.png", _sprite(32, _draw_forge_core))
	_save("res://assets/sprites/interactables/event_station.png", _sprite(32, _draw_event_station))
	_save("res://assets/sprites/interactables/event_core.png", _sprite(32, _draw_event_core))
	_save("res://assets/sprites/interactables/exit_portal.png", _sprite(32, _draw_exit_portal))
	_save("res://assets/sprites/environment/dungeon_floor_tile.png", _floor_tile())
	_save("res://assets/sprites/environment/dungeon_wall_tile.png", _wall_tile())
	_save("res://assets/sprites/environment/dungeon_floor_panel.png", _floor_panel())
	_save("res://assets/sprites/environment/dungeon_wall_horizontal.png", _wall_strip(true))
	_save("res://assets/sprites/environment/dungeon_wall_vertical.png", _wall_strip(false))
	print("PIXEL_ART_GENERATED")
	quit()

func _make_dirs() -> void:
	for path in [
		"res://assets/sprites/characters",
		"res://assets/sprites/enemies",
		"res://assets/sprites/items",
		"res://assets/sprites/effects",
		"res://assets/sprites/interactables",
		"res://assets/sprites/environment",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _sprite(size: int, draw: Callable) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	draw.call(image)
	return image

func _save(path: String, image: Image) -> void:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])

func _draw_player(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	_rect(image, 10, 11, 12, 13, OUTLINE)
	_rect(image, 12, 8, 8, 6, OUTLINE)
	_rect(image, 7, 15, 5, 9, OUTLINE)
	_rect(image, 20, 15, 5, 9, OUTLINE)
	_rect(image, 12, 12, 8, 11, Color8(42, 91, 166))
	_rect(image, 13, 9, 6, 4, Color8(43, 58, 92))
	_rect(image, 14, 10, 4, 2, Color8(238, 187, 83))
	_rect(image, 9, 16, 4, 7, Color8(37, 63, 111))
	_rect(image, 20, 16, 3, 7, Color8(70, 125, 210))
	_rect(image, 11, 23, 4, 4, Color8(31, 39, 58))
	_rect(image, 17, 23, 4, 4, Color8(31, 39, 58))
	_rect(image, 22, 13, 5, 3, OUTLINE)
	_rect(image, 23, 14, 4, 1, Color8(232, 174, 72))
	_rect(image, 15, 14, 2, 8, Color8(108, 170, 230))

func _draw_ashling(image: Image) -> void:
	_ellipse(image, 6, 27, 20, 4, SHADOW)
	_diamond(image, Vector2i(16, 17), 12, 12, OUTLINE)
	_diamond(image, Vector2i(16, 16), 9, 11, Color8(183, 50, 32))
	_triangle(image, Vector2i(8, 9), Vector2i(15, 3), Vector2i(13, 13), OUTLINE)
	_triangle(image, Vector2i(24, 9), Vector2i(17, 3), Vector2i(19, 13), OUTLINE)
	_triangle(image, Vector2i(10, 10), Vector2i(15, 5), Vector2i(14, 13), Color8(245, 111, 38))
	_triangle(image, Vector2i(22, 10), Vector2i(17, 5), Vector2i(18, 13), Color8(245, 111, 38))
	_rect(image, 12, 14, 8, 8, Color8(232, 80, 31))
	_rect(image, 14, 13, 4, 6, Color8(255, 183, 61))
	_rect(image, 12, 17, 2, 2, OUTLINE)
	_rect(image, 18, 17, 2, 2, OUTLINE)
	_rect(image, 11, 24, 3, 3, OUTLINE)
	_rect(image, 18, 24, 3, 3, OUTLINE)

func _draw_glassmite(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	_diamond(image, Vector2i(16, 16), 12, 14, OUTLINE)
	_diamond(image, Vector2i(16, 16), 9, 12, Color8(68, 192, 212))
	_diamond(image, Vector2i(16, 13), 5, 7, Color8(163, 249, 247))
	_rect(image, 6, 17, 5, 2, OUTLINE)
	_rect(image, 21, 17, 5, 2, OUTLINE)
	_rect(image, 7, 21, 5, 2, OUTLINE)
	_rect(image, 20, 21, 5, 2, OUTLINE)
	_rect(image, 12, 18, 2, 2, Color8(18, 51, 74))
	_rect(image, 18, 18, 2, 2, Color8(18, 51, 74))
	_rect(image, 15, 5, 3, 5, Color8(128, 236, 240))
	_rect(image, 16, 22, 2, 4, Color8(31, 132, 166))

func _draw_iron_husk(image: Image) -> void:
	_ellipse(image, 4, 27, 24, 4, SHADOW)
	_rect(image, 8, 10, 16, 15, OUTLINE)
	_rect(image, 10, 8, 12, 7, OUTLINE)
	_rect(image, 10, 12, 12, 12, Color8(91, 98, 104))
	_rect(image, 12, 9, 8, 5, Color8(125, 133, 137))
	_rect(image, 13, 15, 6, 2, Color8(238, 105, 43))
	_rect(image, 6, 15, 4, 9, OUTLINE)
	_rect(image, 22, 15, 4, 9, OUTLINE)
	_rect(image, 8, 16, 2, 7, Color8(76, 82, 88))
	_rect(image, 22, 16, 2, 7, Color8(76, 82, 88))
	_rect(image, 11, 24, 4, 3, OUTLINE)
	_rect(image, 17, 24, 4, 3, OUTLINE)
	_rect(image, 13, 19, 6, 2, Color8(66, 70, 76))

func _draw_cinder_bulwark(image: Image) -> void:
	_ellipse(image, 8, 42, 32, 5, SHADOW)
	_rect(image, 10, 12, 28, 25, OUTLINE)
	_rect(image, 13, 10, 22, 9, OUTLINE)
	_rect(image, 13, 15, 22, 21, Color8(113, 42, 31))
	_rect(image, 16, 12, 16, 7, Color8(182, 66, 34))
	_rect(image, 18, 22, 12, 8, Color8(246, 116, 35))
	_rect(image, 21, 23, 6, 6, Color8(255, 203, 73))
	_rect(image, 6, 20, 6, 13, OUTLINE)
	_rect(image, 36, 20, 6, 13, OUTLINE)
	_rect(image, 8, 22, 4, 9, Color8(84, 38, 34))
	_rect(image, 36, 22, 4, 9, Color8(84, 38, 34))
	_rect(image, 16, 36, 6, 5, OUTLINE)
	_rect(image, 26, 36, 6, 5, OUTLINE)
	_line(image, Vector2i(14, 19), Vector2i(34, 35), Color8(226, 83, 32))
	_line(image, Vector2i(34, 19), Vector2i(14, 35), Color8(226, 83, 32))

func _draw_depths_warden(image: Image) -> void:
	_ellipse(image, 10, 56, 44, 6, SHADOW)
	_rect(image, 18, 18, 28, 31, OUTLINE)
	_rect(image, 22, 13, 20, 12, OUTLINE)
	_rect(image, 21, 20, 22, 28, Color8(49, 34, 87))
	_rect(image, 24, 15, 16, 9, Color8(77, 45, 126))
	_rect(image, 26, 27, 12, 13, Color8(38, 132, 168))
	_rect(image, 29, 29, 6, 9, Color8(112, 229, 232))
	_rect(image, 25, 18, 4, 3, Color8(178, 245, 255))
	_rect(image, 35, 18, 4, 3, Color8(178, 245, 255))
	_rect(image, 10, 25, 9, 19, OUTLINE)
	_rect(image, 45, 25, 9, 19, OUTLINE)
	_rect(image, 12, 27, 7, 15, Color8(40, 28, 72))
	_rect(image, 45, 27, 7, 15, Color8(40, 28, 72))
	_rect(image, 24, 49, 6, 7, OUTLINE)
	_rect(image, 34, 49, 6, 7, OUTLINE)
	_line(image, Vector2i(16, 10), Vector2i(25, 18), Color8(92, 67, 158))
	_line(image, Vector2i(48, 10), Vector2i(39, 18), Color8(92, 67, 158))
	_line(image, Vector2i(18, 44), Vector2i(8, 52), Color8(39, 137, 178))
	_line(image, Vector2i(46, 44), Vector2i(56, 52), Color8(39, 137, 178))

func _draw_weapon_pickup(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	_diamond(image, Vector2i(16, 16), 12, 12, OUTLINE)
	_diamond(image, Vector2i(16, 16), 9, 9, Color8(92, 54, 32))
	_line(image, Vector2i(8, 22), Vector2i(23, 7), Color8(247, 193, 77))
	_line(image, Vector2i(9, 23), Vector2i(24, 8), OUTLINE)
	_rect(image, 20, 7, 5, 4, Color8(229, 108, 41))

func _draw_equipment_pickup(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	_diamond(image, Vector2i(16, 16), 12, 12, OUTLINE)
	_diamond(image, Vector2i(16, 16), 9, 9, Color8(35, 76, 112))
	_rect(image, 11, 10, 10, 12, OUTLINE)
	_rect(image, 13, 12, 6, 9, Color8(95, 175, 219))
	_rect(image, 12, 13, 8, 2, Color8(186, 238, 247))

func _draw_player_projectile(image: Image) -> void:
	_line(image, Vector2i(8, 16), Vector2i(24, 16), OUTLINE)
	_line(image, Vector2i(9, 15), Vector2i(24, 15), Color8(255, 212, 91))
	_line(image, Vector2i(9, 17), Vector2i(24, 17), Color8(238, 118, 43))
	_rect(image, 21, 13, 4, 6, Color8(255, 239, 142))

func _draw_boss_projectile(image: Image) -> void:
	_line(image, Vector2i(7, 16), Vector2i(25, 16), OUTLINE)
	_line(image, Vector2i(9, 14), Vector2i(24, 14), Color8(102, 53, 205))
	_line(image, Vector2i(9, 18), Vector2i(24, 18), Color8(48, 186, 219))
	_rect(image, 21, 12, 4, 8, Color8(178, 245, 255))

func _draw_chest_body(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	_rect(image, 5, 13, 22, 12, OUTLINE)
	_rect(image, 7, 14, 18, 10, Color8(126, 73, 36))
	_rect(image, 8, 14, 16, 3, Color8(211, 143, 52))
	_rect(image, 15, 16, 3, 5, Color8(246, 203, 92))
	_rect(image, 7, 23, 18, 2, Color8(70, 41, 29))

func _draw_chest_lid(image: Image) -> void:
	_rect(image, 4, 11, 24, 8, OUTLINE)
	_rect(image, 6, 12, 20, 6, Color8(222, 153, 55))
	_rect(image, 9, 12, 14, 2, Color8(255, 208, 88))
	_rect(image, 15, 14, 3, 4, Color8(126, 73, 36))

func _draw_forge_station(image: Image) -> void:
	_ellipse(image, 4, 27, 24, 4, SHADOW)
	_diamond(image, Vector2i(16, 17), 13, 12, OUTLINE)
	_diamond(image, Vector2i(16, 17), 10, 9, Color8(70, 76, 83))
	_rect(image, 9, 20, 14, 4, Color8(44, 48, 55))
	_rect(image, 12, 12, 8, 3, Color8(121, 132, 142))

func _draw_forge_core(image: Image) -> void:
	_diamond(image, Vector2i(16, 16), 7, 7, Color8(21, 24, 30))
	_diamond(image, Vector2i(16, 16), 5, 5, Color8(105, 180, 224))
	_rect(image, 15, 13, 2, 6, Color8(226, 244, 255))

func _draw_event_station(image: Image) -> void:
	_ellipse(image, 4, 27, 24, 4, SHADOW)
	_diamond(image, Vector2i(16, 17), 13, 12, OUTLINE)
	_diamond(image, Vector2i(16, 17), 10, 9, Color8(83, 35, 41))
	_rect(image, 9, 21, 14, 3, Color8(45, 23, 32))

func _draw_event_core(image: Image) -> void:
	_diamond(image, Vector2i(16, 15), 7, 9, Color8(25, 20, 32))
	_diamond(image, Vector2i(16, 15), 5, 7, Color8(245, 113, 53))
	_rect(image, 14, 14, 4, 4, Color8(255, 220, 105))

func _draw_exit_portal(image: Image) -> void:
	_ellipse(image, 5, 27, 22, 4, SHADOW)
	for radius in [13, 10, 7]:
		_circle_outline(image, Vector2i(16, 15), radius, Color8(43, 214, 205) if radius != 10 else Color8(75, 92, 224))
	_line(image, Vector2i(10, 17), Vector2i(22, 10), Color8(178, 255, 247))
	_line(image, Vector2i(12, 20), Vector2i(24, 14), Color8(67, 170, 240))
	_rect(image, 15, 14, 3, 3, Color8(235, 255, 255))

func _floor_tile() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color8(31, 35, 39))
	_rect(image, 0, 0, 16, 1, Color8(47, 52, 57))
	_rect(image, 0, 0, 1, 16, Color8(45, 50, 55))
	_rect(image, 0, 15, 16, 1, Color8(20, 23, 27))
	_rect(image, 15, 0, 1, 16, Color8(19, 22, 25))
	_rect(image, 4, 5, 3, 1, Color8(56, 61, 66))
	_rect(image, 10, 11, 4, 1, Color8(22, 26, 30))
	_put_pixel(image, 12, 4, Color8(61, 67, 72))
	_put_pixel(image, 3, 12, Color8(24, 27, 31))
	return image

func _wall_tile() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color8(43, 48, 55))
	_rect(image, 0, 0, 16, 2, Color8(69, 76, 84))
	_rect(image, 0, 14, 16, 2, Color8(22, 25, 31))
	_rect(image, 0, 0, 2, 16, Color8(58, 64, 72))
	_rect(image, 14, 0, 2, 16, Color8(27, 31, 38))
	_rect(image, 4, 5, 8, 1, Color8(73, 80, 89))
	_rect(image, 5, 10, 6, 1, Color8(28, 32, 39))
	return image

func _floor_panel() -> Image:
	var image := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	image.fill(Color8(26, 29, 34))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5502
	for y in range(0, 540, 16):
		for x in range(0, 960, 16):
			var base := Color8(31 + rng.randi_range(-3, 5), 35 + rng.randi_range(-3, 5), 39 + rng.randi_range(-2, 6))
			_rect(image, x, y, 16, 16, base)
			_rect(image, x, y, 16, 1, base.lightened(0.24))
			_rect(image, x, y, 1, 16, base.lightened(0.17))
			_rect(image, x, y + 15, 16, 1, base.darkened(0.28))
			_rect(image, x + 15, y, 1, 16, base.darkened(0.22))
			if rng.randf() < 0.16:
				_rect(image, x + rng.randi_range(3, 11), y + rng.randi_range(4, 12), rng.randi_range(2, 5), 1, base.lightened(0.32))
			if rng.randf() < 0.12:
				_put_pixel(image, x + rng.randi_range(2, 13), y + rng.randi_range(2, 13), base.darkened(0.35))
	return image

func _wall_strip(horizontal: bool) -> Image:
	var width := 960 if horizontal else 32
	var height := 32 if horizontal else 540
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color8(43, 48, 55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9711 if horizontal else 9712
	for y in range(0, height, 16):
		for x in range(0, width, 16):
			var base := Color8(43 + rng.randi_range(-2, 5), 48 + rng.randi_range(-2, 5), 55 + rng.randi_range(-1, 6))
			_rect(image, x, y, 16, 16, base)
			_rect(image, x, y, 16, 2, base.lightened(0.32))
			_rect(image, x, y + 14, 16, 2, base.darkened(0.32))
			_rect(image, x, y, 2, 16, base.lightened(0.18))
			_rect(image, x + 14, y, 2, 16, base.darkened(0.2))
	return image

func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + height, image.get_height())):
		for xx in range(maxi(x, 0), mini(x + width, image.get_width())):
			image.set_pixel(xx, yy, color)

func _ellipse(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var center := Vector2(x + width * 0.5, y + height * 0.5)
	var radius := Vector2(maxf(width * 0.5, 0.1), maxf(height * 0.5, 0.1))
	for yy in range(maxi(y, 0), mini(y + height, image.get_height())):
		for xx in range(maxi(x, 0), mini(x + width, image.get_width())):
			var normalized := Vector2((xx + 0.5 - center.x) / radius.x, (yy + 0.5 - center.y) / radius.y)
			if normalized.length_squared() <= 1.0:
				image.set_pixel(xx, yy, color)

func _diamond(image: Image, center: Vector2i, half_width: int, half_height: int, color: Color) -> void:
	for yy in range(center.y - half_height, center.y + half_height + 1):
		for xx in range(center.x - half_width, center.x + half_width + 1):
			if xx < 0 or yy < 0 or xx >= image.get_width() or yy >= image.get_height():
				continue
			var dx := absf(float(xx - center.x)) / maxf(float(half_width), 1.0)
			var dy := absf(float(yy - center.y)) / maxf(float(half_height), 1.0)
			if dx + dy <= 1.0:
				image.set_pixel(xx, yy, color)

func _triangle(image: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color) -> void:
	var min_x := maxi(mini(a.x, mini(b.x, c.x)), 0)
	var max_x := mini(maxi(a.x, maxi(b.x, c.x)), image.get_width() - 1)
	var min_y := maxi(mini(a.y, mini(b.y, c.y)), 0)
	var max_y := mini(maxi(a.y, maxi(b.y, c.y)), image.get_height() - 1)
	var area := _edge(a, b, c)
	for yy in range(min_y, max_y + 1):
		for xx in range(min_x, max_x + 1):
			var p := Vector2i(xx, yy)
			var w0 := _edge(b, c, p)
			var w1 := _edge(c, a, p)
			var w2 := _edge(a, b, p)
			if (w0 >= 0 and w1 >= 0 and w2 >= 0 and area >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0 and area <= 0):
				image.set_pixel(xx, yy, color)

func _edge(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)

func _line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_put_pixel(image, x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

func _circle_outline(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for yy in range(center.y - radius, center.y + radius + 1):
		for xx in range(center.x - radius, center.x + radius + 1):
			var distance := Vector2(xx - center.x, yy - center.y).length()
			if distance >= radius - 0.8 and distance <= radius + 0.8:
				_put_pixel(image, xx, yy, color)

func _put_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)
