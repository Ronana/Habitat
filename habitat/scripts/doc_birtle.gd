## doc_birtle.gd — Doc Birtle the Roamer Physician.
## A portly, spectacled travelling apothecary who visits occasionally and sells
## remedies that the player applies to their roamers from the inventory.
## roamer_ui.gd detects has_method("buy_item") — same path as Sam.
extends Node3D

# ── Shop catalogue ─────────────────────────────────────────────────────────────
var shop_items := [
	{
		"name":        "Calm Draught",
		"cost":        20.0,
		"min_level":   1,
		"description": "Soothe an agitated roamer instantly. Select the roamer, then use from inventory.",
	},
	{
		"name":        "Nourishing Paste",
		"cost":        30.0,
		"min_level":   1,
		"description": "Fills a roamer's food need to full. Works even in bad weather.",
	},
	{
		"name":        "Tonic of Vigour",
		"cost":        60.0,
		"min_level":   2,
		"description": "Raises all three needs to at least 80%. Select a roamer, then apply from inventory.",
	},
	{
		"name":        "Burden Cure",
		"cost":        80.0,
		"min_level":   1,
		"description": "Immediately lifts the burden from a struggling roamer and sends the Grimshroud away.",
	},
]

# ── Dialogue pools ─────────────────────────────────────────────────────────────
const GREETINGS_MORNING: Array = [
	"Ah, an early start. Sensible. Most ailments worsen by midday.",
	"Morning. I've been walking since first light. Your roamers look... passable.",
	"Up early? Good. Let's see what your garden needs before it gets worse.",
	"Morning rounds. I always start with the garden cases — fresh air improves my diagnosis.",
]
const GREETINGS_AFTERNOON: Array = [
	"Afternoon. I've just come from the eastern valleys. Long walk, but duty calls.",
	"Good afternoon. I trust your roamers are in reasonable health? Let me know if not.",
	"Ah, there you are. I was beginning to wonder if anyone tended this garden.",
	"Afternoon. I carry a full kit. Whatever ails your roamers, I've likely seen it.",
]
const GREETINGS_EVENING: Array = [
	"Evening. I don't normally make calls this late, but the road brought me here.",
	"Ah, still at it. A dedicated warden. Your roamers are lucky, probably.",
	"Evening rounds. My knees aren't what they were, but here I am.",
	"Getting late. I'll be brief — do any of yours need attention?",
]
const GREETINGS_NIGHT: Array = [
	"Middle of the night. Unusual hours. Still — a patient's a patient.",
	"You're up late. I respect that. Some of the most serious cases come at night.",
	"Night calls are an occupational hazard. What can I do for you?",
	"Couldn't sleep either? Let's make the most of it.",
]

const PURCHASE_LINES: Array = [
	"Good. Keep it in your bag until you need it.",
	"Use it promptly. These things lose potency if you sit on them.",
	"Right. That's my best work. Don't waste it.",
	"Wise investment. I don't make house calls for free.",
	"There you go. Follow the instructions — or don't, and call me again.",
]
const BROKE_LINES: Array = [
	"Not enough dewdrops, I'm afraid. My remedies aren't charity.",
	"The materials alone cost more than that. Come back better funded.",
	"Short on funds? Let the roamers earn a bit more first.",
	"Can't help if you can't pay. That's just economics.",
]
const FAREWELL_LINES: Array = [
	"Right, I'm off. Keep an eye on that food supply — I mean it.",
	"Time to move on. Call me when something's actually wrong.",
	"I'll be back when the route brings me round. Try not to need me.",
	"Off I go. The road's long and my bag's heavy. Good luck.",
	"Take care of them. I won't always be nearby.",
]

var is_shop_open := false

# ── Node refs ──────────────────────────────────────────────────────────────────
var _character_built  : bool           = false
var _head_node        : Node3D         = null
var _selection_ring   : MeshInstance3D = null
var _ring_pulse_timer : float          = 0.0
var _time             : float          = 0.0
var _breathe_phase    : float          = 0.0
var _base_y           : float          = 0.0
var _bag_node         : Node3D         = null
var _bag_phase        : float          = 0.0

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	add_to_group("doc_birtle")
	_breathe_phase = randf() * TAU
	_bag_phase     = randf() * TAU
	_base_y        = position.y
	_build_character()
	_create_selection_ring()
	if has_node("InteractionArea"):
		$InteractionArea.body_entered.connect(_on_body_entered)

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.75 + _breathe_phase) * 0.007
	# Bag gentle sway
	if _bag_node:
		_bag_node.rotation.z = 0.08 * sin(_time * 1.1 + _bag_phase)
	# Head tracking
	if _head_node:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var to_cam := camera.global_position - _head_node.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.5:
				_head_node.rotation.y = lerp_angle(
					_head_node.rotation.y, atan2(to_cam.x, to_cam.z), delta * 1.0)
	if _selection_ring and _selection_ring.visible:
		_ring_pulse_timer += delta
		var p := 1.0 + 0.05 * sin(_ring_pulse_timer * 3.0)
		_selection_ring.scale = Vector3(p, 1.0, p)

# ── Character mesh ─────────────────────────────────────────────────────────────
func _build_character() -> void:
	if _character_built:
		return
	_character_built = true

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.80, 0.64, 0.52)
	skin_mat.roughness = 0.82

	var coat_mat := StandardMaterial3D.new()
	coat_mat.albedo_color = Color(0.92, 0.90, 0.84)   # cream apothecary coat
	coat_mat.roughness = 0.86

	var trouser_mat := StandardMaterial3D.new()
	trouser_mat.albedo_color = Color(0.28, 0.24, 0.20)  # dark charcoal
	trouser_mat.roughness = 0.90

	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.18, 0.12, 0.08)
	boot_mat.roughness = 0.92

	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.42, 0.28, 0.14)   # worn tan leather
	bag_mat.roughness = 0.88

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color   = Color(0.60, 0.80, 0.90, 0.4)
	glass_mat.roughness      = 0.10
	glass_mat.metallic       = 0.2
	glass_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.55, 0.42, 0.20)  # brass frames
	frame_mat.metallic     = 0.8
	frame_mat.roughness    = 0.3

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.80, 0.78, 0.74)  # silver-white
	hair_mat.roughness = 0.95

	var clasp_mat := StandardMaterial3D.new()
	clasp_mat.albedo_color = Color(0.60, 0.48, 0.22)
	clasp_mat.metallic = 0.7
	clasp_mat.roughness = 0.35

	# Body — portly build
	_add_box(Vector3(0, 0.88, 0), Vector3(0.64, 0.76, 0.38), coat_mat)   # torso (wide)
	# Coat lapels
	_add_box(Vector3(-0.18, 1.02, -0.19), Vector3(0.10, 0.28, 0.06), coat_mat)
	_add_box(Vector3( 0.18, 1.02, -0.19), Vector3(0.10, 0.28, 0.06), coat_mat)
	# Coat clasp buttons (centre line)
	_add_box(Vector3(0, 0.96, -0.19), Vector3(0.05, 0.05, 0.05), clasp_mat)
	_add_box(Vector3(0, 0.82, -0.19), Vector3(0.05, 0.05, 0.05), clasp_mat)
	_add_box(Vector3(0, 0.68, -0.19), Vector3(0.05, 0.05, 0.05), clasp_mat)
	# Legs
	_add_box(Vector3(-0.16, 0.32, 0), Vector3(0.26, 0.60, 0.28), trouser_mat)
	_add_box(Vector3( 0.16, 0.32, 0), Vector3(0.26, 0.60, 0.28), trouser_mat)
	# Boots
	_add_box(Vector3(-0.16, 0.07, 0.03), Vector3(0.27, 0.14, 0.35), boot_mat)
	_add_box(Vector3( 0.16, 0.07, 0.03), Vector3(0.27, 0.14, 0.35), boot_mat)
	# Arms — coat sleeves, short-rolled
	_add_box(Vector3(-0.42, 0.90, 0), Vector3(0.20, 0.50, 0.22), coat_mat)
	_add_box(Vector3( 0.42, 0.90, 0), Vector3(0.20, 0.50, 0.22), coat_mat)
	# Forearms — skin showing (rolled sleeves)
	_add_box(Vector3(-0.42, 0.60, 0), Vector3(0.17, 0.26, 0.18), skin_mat)
	_add_box(Vector3( 0.42, 0.60, 0), Vector3(0.17, 0.26, 0.18), skin_mat)
	# Hands
	_add_box(Vector3(-0.42, 0.43, 0), Vector3(0.16, 0.13, 0.17), skin_mat)
	_add_box(Vector3( 0.42, 0.43, 0), Vector3(0.16, 0.13, 0.17), skin_mat)
	# Neck
	_add_box(Vector3(0, 1.30, 0), Vector3(0.22, 0.14, 0.22), skin_mat)
	# Head — round, jowly
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.46, 0.44, 0.42)
	head.mesh = hm
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.62, 0)
	head.name = "Head"
	add_child(head)
	_head_node = head
	# White hair sides + back
	_add_box(Vector3(-0.22, 1.65, 0), Vector3(0.06, 0.36, 0.40), hair_mat)
	_add_box(Vector3( 0.22, 1.65, 0), Vector3(0.06, 0.36, 0.40), hair_mat)
	_add_box(Vector3(0, 1.65, 0.20), Vector3(0.40, 0.30, 0.06), hair_mat)
	# White moustache
	_add_box(Vector3(0, 1.50, -0.21), Vector3(0.28, 0.06, 0.05), hair_mat)
	# Spectacles — two glass ovals + brass bridge
	_add_box(Vector3(-0.12, 1.60, -0.21), Vector3(0.14, 0.10, 0.04), glass_mat)
	_add_box(Vector3( 0.12, 1.60, -0.21), Vector3(0.14, 0.10, 0.04), glass_mat)
	_add_box(Vector3(0,    1.60, -0.21), Vector3(0.06, 0.03, 0.03), frame_mat)  # bridge
	_add_box(Vector3(-0.22, 1.60, -0.16), Vector3(0.03, 0.03, 0.14), frame_mat) # arm L
	_add_box(Vector3( 0.22, 1.60, -0.16), Vector3(0.03, 0.03, 0.14), frame_mat) # arm R

	# ── Leather satchel — hanging at left hip ─────────────────────────────────
	var bag := Node3D.new()
	bag.name = "Bag"
	bag.position = Vector3(-0.44, 0.72, 0.10)
	add_child(bag)
	_bag_node = bag
	# Body
	var bag_body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.26, 0.14)
	bag_body.mesh = bm
	bag_body.set_surface_override_material(0, bag_mat)
	bag.add_child(bag_body)
	# Flap
	var bag_flap := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.22, 0.08, 0.02)
	bag_flap.mesh = fm
	bag_flap.position = Vector3(0, 0.10, -0.08)
	bag_flap.set_surface_override_material(0, bag_mat)
	bag.add_child(bag_flap)
	# Clasp
	var bag_clasp := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.06, 0.04, 0.04)
	bag_clasp.mesh = cm
	bag_clasp.position = Vector3(0, 0.06, -0.09)
	bag_clasp.set_surface_override_material(0, clasp_mat)
	bag.add_child(bag_clasp)
	# Strap up to shoulder
	_add_box(Vector3(-0.32, 0.98, 0.04), Vector3(0.05, 0.55, 0.05), bag_mat)

func _add_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	add_child(mi)

# ── Selection ring ─────────────────────────────────────────────────────────────
func _create_selection_ring() -> void:
	_selection_ring = MeshInstance3D.new()
	_selection_ring.position = Vector3(0, 0.05, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var inner_r := 0.65
	var outer_r := 0.95
	var segs := 48
	for i in range(segs):
		var a1 := (float(i)     / segs) * TAU
		var a2 := (float(i + 1) / segs) * TAU
		var p1i := Vector3(cos(a1) * inner_r, 0, sin(a1) * inner_r)
		var p1o := Vector3(cos(a1) * outer_r, 0, sin(a1) * outer_r)
		var p2i := Vector3(cos(a2) * inner_r, 0, sin(a2) * inner_r)
		var p2o := Vector3(cos(a2) * outer_r, 0, sin(a2) * outer_r)
		st.add_vertex(p1o); st.add_vertex(p2o); st.add_vertex(p1i)
		st.add_vertex(p2o); st.add_vertex(p2i); st.add_vertex(p1i)
	_selection_ring.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test              = true
	mat.emission_enabled           = true
	mat.albedo_color               = Color(0.55, 0.88, 0.72, 0.50)   # soft green
	mat.emission                   = Color(0.40, 0.80, 0.55)
	mat.emission_energy_multiplier = 1.0
	_selection_ring.set_surface_override_material(0, mat)
	_selection_ring.visible = false
	add_child(_selection_ring)

func show_selection_ring() -> void:
	if _selection_ring:
		_selection_ring.visible = true
		_ring_pulse_timer = 0.0

func hide_selection_ring() -> void:
	if _selection_ring:
		_selection_ring.visible = false

# ── Dialogue helpers ───────────────────────────────────────────────────────────
func get_greeting() -> String:
	var t: float = DayNightManager.current_time
	var pool: Array
	if   t >= 5.0  and t < 12.0: pool = GREETINGS_MORNING
	elif t >= 12.0 and t < 18.0: pool = GREETINGS_AFTERNOON
	elif t >= 18.0 and t < 21.0: pool = GREETINGS_EVENING
	else:                          pool = GREETINGS_NIGHT
	return pool[randi() % pool.size()]

func get_purchase_line() -> String:
	return PURCHASE_LINES[randi() % PURCHASE_LINES.size()]

func get_broke_line() -> String:
	return BROKE_LINES[randi() % BROKE_LINES.size()]

func get_farewell_line() -> String:
	return FAREWELL_LINES[randi() % FAREWELL_LINES.size()]

# ── Shop API ───────────────────────────────────────────────────────────────────
## Charges dewdrops and adds the item to inventory.
## roamer_ui checks affordability before calling this.
func buy_item(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	var item: Dictionary = shop_items[index]
	CurrencyManager.spend_dewdrops(item["cost"])
	InventoryManager.add_item(item["name"])
	WardenManager.gain_xp("item_purchased")

# ── Interaction ────────────────────────────────────────────────────────────────
func _on_body_entered(_body: Node3D) -> void:
	pass
