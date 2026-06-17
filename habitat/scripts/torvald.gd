## torvald.gd — Torvald the Wandering Carpenter.
## A visiting master craftsman who commissions bespoke garden pieces.
## He spawns at the garden boundary, stays for one in-game day, then leaves.
## roamer_ui.gd detects commission_item() via has_method() to show the commission panel.
extends Node3D

# ── Commission catalogue ──────────────────────────────────────────────────────
# cost: dewdrops. material_cost: {"ItemName": count, ...} checked from inventory.
# scene_path: what gets added to inventory on commission.
var commission_items := [
	{
		"name":          "Stone Bench",
		"cost":          50.0,
		"material_cost": {},
		"scene_path":    "res://scenes/stone_bench.tscn",
		"min_level":     1,
		"description":   "A carved stone bench with moss creeping over the armrests. Roamers will rest nearby.",
	},
	{
		"name":          "Mossy Fountain",
		"cost":          75.0,
		"material_cost": {},
		"scene_path":    "res://scenes/mossy_fountain.tscn",
		"min_level":     2,
		"description":   "A stone basin where clean water pools. Roamers visit to drink. Glows faintly at night.",
	},
	{
		"name":          "Rune Totem",
		"cost":          90.0,
		"material_cost": {},
		"scene_path":    "res://scenes/rune_totem.tscn",
		"min_level":     2,
		"description":   "An ancient standing stone carved with runes that pulse with soft green light. Said to calm nervous roamers.",
	},
	{
		"name":          "Fire Ring",
		"cost":          70.0,
		"material_cost": {},
		"scene_path":    "res://scenes/fire_ring.tscn",
		"min_level":     3,
		"description":   "A ring of standing stones around a crackling fire pit. Roamers gather here on cold nights.",
	},
	{
		"name":          "Stone Archway",
		"cost":          110.0,
		"material_cost": {},
		"scene_path":    "res://scenes/stone_archway.tscn",
		"min_level":     3,
		"description":   "A grand arched gateway of carved stone. Makes every garden path feel like an event.",
	},
	{
		"name":          "Lantern Arch",
		"cost":          85.0,
		"material_cost": {},
		"scene_path":    "res://scenes/lantern_arch.tscn",
		"min_level":     4,
		"description":   "A wooden arch hung with three glowing iron lanterns. Casts warm light over whatever lies beneath.",
	},
]

# ── Dialogue pools ─────────────────────────────────────────────────────────────
const GREETINGS_MORNING: Array = [
	"Aye, morning! I had a look at your garden at first light. There's real potential here.",
	"Morning! Best time to scout out where a good piece of stonework might sit.",
	"Early start. I like that. Craftsmen and gardeners are cut from the same cloth.",
	"Took me a while to find the gate in this light. Worth it, though — good-looking plot you've got.",
	"Morning. I've been up since before the sun. Had an idea for an archway I want to try.",
]
const GREETINGS_AFTERNOON: Array = [
	"Afternoon! I've been sizing up your paths. Wouldn't say no to a good commission.",
	"Good timing — I just finished sharpening my tools. What are you after?",
	"Afternoon! I don't get to many gardens as lived-in as this. The roamers seem to trust you.",
	"Good afternoon. Any good craftwork I do here, I do right. No rushing.",
	"I'm only here till sundown, mind. So let's not waste daylight.",
]
const GREETINGS_EVENING: Array = [
	"Getting late, but I've still got time for a commission if you're quick.",
	"Evening light's the best light for seeing where shadows fall. A garden needs both.",
	"I'll be off before the stars are too thick. But there's still time.",
	"One last commission, perhaps? I do my best work by firelight anyway.",
	"Not gone yet! I wanted to see the garden in the evening light before I left. Beautiful.",
]
const GREETINGS_NIGHT: Array = [
	"Still here — I got caught admiring that rune totem in the dark. Glad I made it.",
	"Couldn't sleep. Same old problem. Figured I'd see if you were about.",
	"Night-time commission? I respect the dedication. Let's see what we can do.",
	"The roamers are quiet. Good time to talk craft.",
	"You're up late. So am I. Might as well make something of it.",
]

const COMMISSION_LINES: Array = [
	"Right. I'll get to work on that. Come find me when I've finished.",
	"Good choice. That one takes some proper effort — worth every dewdrop.",
	"Consider it done. I'll have it ready before I leave.",
	"Aye. Now that's a piece worth making. I'll do it proud.",
	"Leave it with me. I don't rush, but I don't dawdle either.",
]
const BROKE_LINES: Array = [
	"Dewdrops a bit thin right now? Come back when the garden's paid out a bit more.",
	"I'd love to take the commission, but the dewdrops aren't there yet. No hard feelings.",
	"Not quite enough there, I'm afraid. Let the roamers earn it for you.",
	"Short a few drops. Keep at it — the garden'll pay you back.",
	"Almost. Come back once you've topped up and we'll shake on it.",
]
const FAREWELL_LINES: Array = [
	"Right — I'll be off. Don't be surprised if I turn up again in a few days.",
	"Time to move on. You've got a fine garden here, Warden. Keep at it.",
	"Good work today. I'll find my way back when I've got new designs to try.",
	"Until next time. Leave the gate open — I'll knock, but still.",
	"I'm away. Don't let the place go to seed while I'm gone. Actually — do. Seeds are good.",
]

var is_shop_open := false

# ── Node references ────────────────────────────────────────────────────────────
var _character_built   : bool           = false
var _head_node         : Node3D         = null
var _tool_node         : Node3D         = null  # hammer/chisel mesh group

# ── Animation state ────────────────────────────────────────────────────────────
var _time              : float = 0.0
var _breathe_phase     : float = 0.0
var _base_y            : float = 0.0
var _hammer_phase      : float = 0.0
var _is_working        : bool  = false  # plays hammer swing when building

# ── Selection ring ────────────────────────────────────────────────────────────
var selection_ring     : MeshInstance3D = null
var _ring_pulse_timer  : float = 0.0

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	add_to_group("torvald")
	_breathe_phase = randf() * TAU
	_base_y        = position.y

	_head_node   = get_node_or_null("Head")  as Node3D
	_tool_node   = get_node_or_null("Hammer") as Node3D

	_create_selection_ring()
	_spawn_wood_chip_particles()
	_build_character()

	if has_node("InteractionArea"):
		$InteractionArea.body_entered.connect(_on_body_entered)

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta

	# Breathing bob
	var breathe := sin(_time * 0.88 + _breathe_phase) * 0.010
	position.y = _base_y + breathe

	# Head tracks camera
	if _head_node:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var to_cam := camera.global_position - _head_node.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.5:
				var target_angle := atan2(to_cam.x, to_cam.z)
				_head_node.rotation.y = lerp_angle(
					_head_node.rotation.y, target_angle, delta * 1.2)

	# Hammer swing idle — Torvald taps his chisel rhythmically when nearby
	if _tool_node:
		if _is_working:
			_hammer_phase += delta * 4.2
			_tool_node.rotation.z = -0.3 + 0.3 * sin(_hammer_phase)
		else:
			_tool_node.rotation.z = lerp(_tool_node.rotation.z, 0.0, delta * 2.0)

	# Selection ring pulse
	if selection_ring and selection_ring.visible:
		_ring_pulse_timer += delta
		var ring_pulse := 1.0 + 0.05 * sin(_ring_pulse_timer * 3.0)
		selection_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)

# ── Character mesh (procedural placeholder) ───────────────────────────────────
func _build_character() -> void:
	if _character_built:
		return
	_character_built = true

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.78, 0.60, 0.46)
	skin_mat.roughness = 0.80

	var tunic_mat := StandardMaterial3D.new()
	tunic_mat.albedo_color = Color(0.45, 0.30, 0.16)  # warm leather brown
	tunic_mat.roughness = 0.85

	var apron_mat := StandardMaterial3D.new()
	apron_mat.albedo_color = Color(0.30, 0.22, 0.12)  # dark leather apron
	apron_mat.roughness = 0.90

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.62, 0.42, 0.20)  # warm auburn
	hair_mat.roughness = 0.95

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.50, 0.48, 0.46)
	iron_mat.roughness = 0.55
	iron_mat.metallic = 0.7

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.55, 0.36, 0.18)
	wood_mat.roughness = 0.90

	# Body
	_add_box(Vector3(0, 0.80, 0),  Vector3(0.52, 0.70, 0.32), tunic_mat)  # torso
	_add_box(Vector3(0, 0.75, 0),  Vector3(0.30, 0.72, 0.36), apron_mat)  # apron front

	# Legs
	_add_box(Vector3(-0.14, 0.30, 0), Vector3(0.22, 0.58, 0.28), tunic_mat)
	_add_box(Vector3( 0.14, 0.30, 0), Vector3(0.22, 0.58, 0.28), tunic_mat)

	# Boots
	_add_box(Vector3(-0.14, 0.06, 0.02), Vector3(0.24, 0.12, 0.34), apron_mat)
	_add_box(Vector3( 0.14, 0.06, 0.02), Vector3(0.24, 0.12, 0.34), apron_mat)

	# Arms
	_add_box(Vector3(-0.34, 0.82, 0), Vector3(0.16, 0.56, 0.22), tunic_mat)  # upper left
	_add_box(Vector3( 0.34, 0.82, 0), Vector3(0.16, 0.56, 0.22), tunic_mat)  # upper right
	_add_box(Vector3(-0.34, 0.52, 0), Vector3(0.14, 0.32, 0.18), skin_mat)   # forearm left
	_add_box(Vector3( 0.34, 0.52, 0), Vector3(0.14, 0.32, 0.18), skin_mat)   # forearm right

	# Hands
	_add_box(Vector3(-0.34, 0.36, 0), Vector3(0.13, 0.14, 0.16), skin_mat)
	_add_box(Vector3( 0.34, 0.36, 0), Vector3(0.13, 0.14, 0.16), skin_mat)

	# Neck + Head
	_add_box(Vector3(0, 1.22, 0), Vector3(0.18, 0.14, 0.18), skin_mat)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.38, 0.42, 0.36)
	head.mesh = head_mesh
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.52, 0)
	head.name = "Head"
	add_child(head)
	_head_node = head

	# Hair / beard
	_add_box(Vector3(0, 1.72, 0), Vector3(0.40, 0.12, 0.38), hair_mat)  # top hair
	_add_box(Vector3(0, 1.36, -0.18), Vector3(0.34, 0.24, 0.06), hair_mat)  # beard

	# Tool belt detail
	_add_box(Vector3(0, 0.58, 0.17), Vector3(0.52, 0.06, 0.04), iron_mat)

	# Hammer (right hand — separate so we can animate it)
	var hammer_root := Node3D.new()
	hammer_root.name = "Hammer"
	hammer_root.position = Vector3(0.34, 0.34, 0.12)
	add_child(hammer_root)
	_tool_node = hammer_root

	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.06, 0.38, 0.06)
	handle.mesh = handle_mesh
	handle.set_surface_override_material(0, wood_mat)
	handle.position = Vector3(0, 0, 0)
	hammer_root.add_child(handle)

	var head_iron := MeshInstance3D.new()
	var head_mesh2 := BoxMesh.new()
	head_mesh2.size = Vector3(0.18, 0.12, 0.10)
	head_iron.mesh = head_mesh2
	head_iron.set_surface_override_material(0, iron_mat)
	head_iron.position = Vector3(0, 0.22, 0)
	hammer_root.add_child(head_iron)

# ── Wood chip particles (ambient) ──────────────────────────────────────────────
func _spawn_wood_chip_particles() -> void:
	var p := GPUParticles3D.new()
	p.name = "WoodChips"
	p.emitting = true
	p.one_shot = false
	p.amount = 8
	p.lifetime = 3.0
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 4, 4))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.30
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.22
	mat.gravity = Vector3(0, -1.2, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05

	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.65, 0.42, 0.18, 0.9))
	grad.add_point(1.0, Color(0.55, 0.35, 0.12, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat

	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.04, 0.02, 0.03)
	p.draw_pass_1 = chip_mesh
	p.position = Vector3(0, 0.9, 0)
	add_child(p)

# ── Selection ring ─────────────────────────────────────────────────────────────
func _create_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	selection_ring.position = Vector3(0.0, 0.05, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var inner_r := 0.62
	var outer_r := 0.90
	var segments := 48
	for i in range(segments):
		var a1 := (float(i)     / segments) * TAU
		var a2 := (float(i + 1) / segments) * TAU
		var p1i := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var p1o := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var p2i := Vector3(cos(a2) * inner_r, 0.0, sin(a2) * inner_r)
		var p2o := Vector3(cos(a2) * outer_r, 0.0, sin(a2) * outer_r)
		st.add_vertex(p1o); st.add_vertex(p2o); st.add_vertex(p1i)
		st.add_vertex(p2o); st.add_vertex(p2i); st.add_vertex(p1i)
	selection_ring.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test              = true
	mat.emission_enabled           = true
	mat.albedo_color               = Color(0.85, 0.60, 0.25, 0.50)
	mat.emission                   = Color(0.90, 0.55, 0.15)
	mat.emission_energy_multiplier = 1.1
	selection_ring.set_surface_override_material(0, mat)
	selection_ring.visible = false
	add_child(selection_ring)

func show_selection_ring() -> void:
	if selection_ring:
		selection_ring.visible = true
		_ring_pulse_timer = 0.0

func hide_selection_ring() -> void:
	if selection_ring:
		selection_ring.visible = false

# ── Dialogue helpers ──────────────────────────────────────────────────────────
func get_greeting() -> String:
	var t: float = DayNightManager.current_time
	var pool: Array
	if t >= 5.0 and t < 12.0:
		pool = GREETINGS_MORNING
	elif t >= 12.0 and t < 18.0:
		pool = GREETINGS_AFTERNOON
	elif t >= 18.0 and t < 21.0:
		pool = GREETINGS_EVENING
	else:
		pool = GREETINGS_NIGHT
	return pool[randi() % pool.size()]

func get_commission_line() -> String:
	return COMMISSION_LINES[randi() % COMMISSION_LINES.size()]

func get_broke_line() -> String:
	return BROKE_LINES[randi() % BROKE_LINES.size()]

func get_farewell_line() -> String:
	return FAREWELL_LINES[randi() % FAREWELL_LINES.size()]

# ── Commission system ──────────────────────────────────────────────────────────
## Checks dewdrops and material cost. On success: charges cost, adds item to
## inventory, and plays the working animation briefly.
func commission_item(index: int) -> bool:
	if index < 0 or index >= commission_items.size():
		return false
	var item: Dictionary = commission_items[index]

	# Dewdrop check
	if not CurrencyManager.spend_dewdrops(item["cost"]):
		return false

	# Material check — refund dewdrops if materials missing
	var mat_cost: Dictionary = item.get("material_cost", {})
	for mat_name: String in mat_cost.keys():
		var needed: int = mat_cost[mat_name]
		if InventoryManager.get_item_count(mat_name) < needed:
			CurrencyManager.add_dewdrops(item["cost"])  # refund
			return false

	# Deduct materials
	for mat_name: String in mat_cost.keys():
		InventoryManager.remove_item(mat_name, mat_cost[mat_name])

	# Add commissioned item to inventory
	InventoryManager.add_item(item["name"])
	WardenManager.gain_xp("item_purchased")

	# Play working anim briefly
	_is_working = true
	await get_tree().create_timer(3.0).timeout
	_is_working = false

	return true

# ── Interaction ────────────────────────────────────────────────────────────────
func _on_body_entered(_body: Node3D) -> void:
	pass

# ── Helper ────────────────────────────────────────────────────────────────────
func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)
