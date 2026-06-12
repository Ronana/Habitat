## SplatMapManager — runtime splat map for terrain texture blending.
##
## The splat map is an RGBA Image where each channel controls one terrain layer:
##   R = Grass   G = Dirt   B = Mud/Sand   A = Snow
##
## Weights per pixel always sum to 1. paint_circle() raises a target layer and
## proportionally reduces the others so the invariant is maintained.
##
## Usage from any script:
##   SplatMapManager.paint_circle(world_pos, SplatMapManager.LAYER_DIRT, radius, strength)
##   SplatMapManager.get_texture()  →  ImageTexture (assign to shader parameter)

extends Node

# ── Layer index constants ──────────────────────────────────────────────────────
const LAYER_GRASS := 0   # R channel
const LAYER_DIRT  := 1   # G channel
const LAYER_MUD   := 2   # B channel
const LAYER_SNOW  := 3   # A channel

# ── World bounds (must match shader uniforms in terrain_splat.gdshader) ────────
const WORLD_ORIGIN := Vector2(-75.0, -75.0)
const WORLD_SIZE   := Vector2(150.0, 150.0)

# ── Map resolution ────────────────────────────────────────────────────────────
const MAP_SIZE := 512

# ── Water surface Y — must match tool_manager.gd WATER_LEVEL ─────────────────
const WATER_LEVEL := -0.65

var _image   : Image
var _texture : ImageTexture
var _dirty   := false

# ── Water mask (separate R8 image — 1.0 = water, 0.0 = dry) ──────────────────
var _water_image   : Image
var _water_texture : ImageTexture
var _water_dirty   := false

# ── Initialise ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_image = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	_image.fill(Color(1.0, 0.0, 0.0, 0.0))   # start as 100 % grass
	_texture = ImageTexture.create_from_image(_image)

	_water_image = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_R8)
	_water_image.fill(Color(0.0, 0.0, 0.0, 1.0))   # no water to start
	_water_texture = ImageTexture.create_from_image(_water_image)

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the ImageTexture to assign to the terrain shader's splat_map uniform.
func get_texture() -> ImageTexture:
	return _texture

## Returns the water mask texture to assign to the water plane shader.
func get_water_texture() -> ImageTexture:
	return _water_texture

## Paint a filled circle of water onto the water mask.
func paint_water_circle(world_pos: Vector3, radius: float) -> void:
	var px_per_unit := float(MAP_SIZE) / WORLD_SIZE.x
	var px_r        := radius * px_per_unit
	var cx := (world_pos.x - WORLD_ORIGIN.x) / WORLD_SIZE.x * float(MAP_SIZE)
	var cz := (world_pos.z - WORLD_ORIGIN.y) / WORLD_SIZE.y * float(MAP_SIZE)
	var x0 := clampi(int(cx - px_r) - 1, 0, MAP_SIZE - 1)
	var x1 := clampi(int(cx + px_r) + 1, 0, MAP_SIZE - 1)
	var z0 := clampi(int(cz - px_r) - 1, 0, MAP_SIZE - 1)
	var z1 := clampi(int(cz + px_r) + 1, 0, MAP_SIZE - 1)
	for pz in range(z0, z1 + 1):
		for px in range(x0, x1 + 1):
			var dx := (float(px) - cx) / px_r
			var dz := (float(pz) - cz) / px_r
			if dx * dx + dz * dz <= 1.0:
				_water_image.set_pixel(px, pz, Color(1.0, 0.0, 0.0, 1.0))
	_water_dirty = true

## Erase a circle of water from the water mask (terrain raised back up).
func clear_water_circle(world_pos: Vector3, radius: float) -> void:
	var px_per_unit := float(MAP_SIZE) / WORLD_SIZE.x
	var px_r        := radius * px_per_unit
	var cx := (world_pos.x - WORLD_ORIGIN.x) / WORLD_SIZE.x * float(MAP_SIZE)
	var cz := (world_pos.z - WORLD_ORIGIN.y) / WORLD_SIZE.y * float(MAP_SIZE)
	var x0 := clampi(int(cx - px_r) - 1, 0, MAP_SIZE - 1)
	var x1 := clampi(int(cx + px_r) + 1, 0, MAP_SIZE - 1)
	var z0 := clampi(int(cz - px_r) - 1, 0, MAP_SIZE - 1)
	var z1 := clampi(int(cz + px_r) + 1, 0, MAP_SIZE - 1)
	for pz in range(z0, z1 + 1):
		for px in range(x0, x1 + 1):
			var dx := (float(px) - cx) / px_r
			var dz := (float(pz) - cz) / px_r
			if dx * dx + dz * dz <= 1.0:
				_water_image.set_pixel(px, pz, Color(0.0, 0.0, 0.0, 1.0))
	_water_dirty = true

## Returns true if the given world position is over a water cell.
func is_water_at(world_pos: Vector3) -> bool:
	var ux := (world_pos.x - WORLD_ORIGIN.x) / WORLD_SIZE.x
	var uz := (world_pos.z - WORLD_ORIGIN.y) / WORLD_SIZE.y
	if ux < 0.0 or ux > 1.0 or uz < 0.0 or uz > 1.0:
		return false
	var px := clampi(int(ux * float(MAP_SIZE)), 0, MAP_SIZE - 1)
	var pz := clampi(int(uz * float(MAP_SIZE)), 0, MAP_SIZE - 1)
	return _water_image.get_pixel(px, pz).r > 0.5

## Returns the fraction of garden cells currently marked as water (0.0–1.0).
func get_water_percentage() -> float:
	var count := 0
	for pz in range(MAP_SIZE):
		for px in range(MAP_SIZE):
			if _water_image.get_pixel(px, pz).r > 0.5:
				count += 1
	return float(count) / float(MAP_SIZE * MAP_SIZE)

## Paint a circular area on the splat map.
## world_pos  : 3D world position of the brush centre (Y is ignored).
## layer      : LAYER_GRASS / LAYER_DIRT / LAYER_MUD / LAYER_SNOW.
## radius     : World-unit radius of the brush.
## strength   : 0-1 — how strongly to paint per pixel at the centre.
func paint_circle(world_pos: Vector3, layer: int, radius: float, strength: float) -> void:
	var px_per_unit := float(MAP_SIZE) / WORLD_SIZE.x
	var px_r        := radius * px_per_unit

	var cx := (world_pos.x - WORLD_ORIGIN.x) / WORLD_SIZE.x * float(MAP_SIZE)
	var cz := (world_pos.z - WORLD_ORIGIN.y) / WORLD_SIZE.y * float(MAP_SIZE)

	var x0 := clampi(int(cx - px_r) - 1, 0, MAP_SIZE - 1)
	var x1 := clampi(int(cx + px_r) + 1, 0, MAP_SIZE - 1)
	var z0 := clampi(int(cz - px_r) - 1, 0, MAP_SIZE - 1)
	var z1 := clampi(int(cz + px_r) + 1, 0, MAP_SIZE - 1)

	for pz in range(z0, z1 + 1):
		for px in range(x0, x1 + 1):
			var dx   := (float(px) - cx) / px_r
			var dz   := (float(pz) - cz) / px_r
			var dist := dx * dx + dz * dz
			if dist > 1.0:
				continue

			# Smooth circular falloff
			var influence := (1.0 - dist) * (1.0 - dist) * strength
			influence = clampf(influence, 0.0, 1.0)

			var col   := _image.get_pixel(px, pz)
			var ch    := [col.r, col.g, col.b, col.a]

			var old_v: float = ch[layer]
			var new_v: float = clampf(old_v + influence, 0.0, 1.0)
			var delta: float = new_v - old_v
			ch[layer]  = new_v

			# Reduce other channels proportionally to keep sum = 1
			var other_sum := 0.0
			for i in range(4):
				if i != layer:
					other_sum += ch[i] as float
			if other_sum > 0.0001:
				var scale: float = (other_sum - delta) / other_sum
				for i in range(4):
					if i != layer:
						ch[i] = maxf(0.0, (ch[i] as float) * scale)

			_image.set_pixel(px, pz, Color(ch[0], ch[1], ch[2], ch[3]))

	_dirty = true

## Paint snow across the entire map — used by SeasonManager.
## amount 0-1: 0 = clear all snow, 1 = full coverage.
func set_global_snow(amount: float) -> void:
	for pz in range(MAP_SIZE):
		for px in range(MAP_SIZE):
			var col   := _image.get_pixel(px, pz)
			var ch    := [col.r, col.g, col.b, col.a]
			var cur: float   = ch[LAYER_SNOW]
			var delta: float = clampf(amount - cur, -1.0, 1.0)
			ch[LAYER_SNOW] = clampf(amount, 0.0, 1.0)
			# Reduce non-snow channels proportionally
			var other_sum: float = (ch[0] as float) + (ch[1] as float) + (ch[2] as float)
			if other_sum > 0.0001 and delta > 0.0:
				var sc: float = (other_sum - delta) / other_sum
				ch[0] = maxf(0.0, ch[0] * sc)
				ch[1] = maxf(0.0, ch[1] * sc)
				ch[2] = maxf(0.0, ch[2] * sc)
			elif delta < 0.0:
				# Snow melting: redistribute back to grass
				ch[LAYER_GRASS] = clampf(ch[LAYER_GRASS] + (-delta), 0.0, 1.0)
			_image.set_pixel(px, pz, Color(ch[0], ch[1], ch[2], ch[3]))
	_dirty = true

# ── Save / load (for future persistence) ─────────────────────────────────────
func save_to(path: String) -> void:
	_image.save_png(path)

func load_from(path: String) -> void:
	var img := Image.load_from_file(path)
	if img:
		_image = img
		_texture.update(_image)
		_dirty = false

# ── Upload to GPU each frame if changed ───────────────────────────────────────
func _process(_delta: float) -> void:
	if _dirty:
		_texture.update(_image)
		_dirty = false
	if _water_dirty:
		_water_texture.update(_water_image)
		_water_dirty = false
