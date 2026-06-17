## gus.gd — Gus the Groundskeeper NPC.
## A gruff, no-nonsense ex-groundskeeper who sells permanent garden upgrades.
## One-time purchases — once bought, always active. No sell system.
## roamer_ui.gd detects upgrade_item() via has_method() to show the upgrade panel.
extends Node3D

# ── Upgrade catalogue ──────────────────────────────────────────────────────────
# id: matches GusManager constant. cost: dewdrops. One-time purchase.
var upgrade_items := [
	{
		"id":          GusManager.UPGRADE_DEEP_POCKETS,
		"name":        "Deep Pockets",
		"cost":        50.0,
		"min_level":   1,
		"description": "Gain 50 bonus dewdrops whenever you unlock a new garden zone. Compounds nicely.",
	},
	{
		"id":          GusManager.UPGRADE_WIDE_BERTH,
		"name":        "Wide Berth",
		"cost":        75.0,
		"min_level":   1,
		"description": "Reduces the clearance needed between placed items by 20%. Pack the garden tighter.",
	},
	{
		"id":          GusManager.UPGRADE_SEASONED_SHOVEL,
		"name":        "Seasoned Shovel",
		"cost":        80.0,
		"min_level":   2,
		"description": "Your shovel digs and raises in a 40% wider radius. Sculpt the terrain faster.",
	},
	{
		"id":          GusManager.UPGRADE_HARDY_STOCK,
		"name":        "Hardy Stock",
		"cost":        90.0,
		"min_level":   2,
		"description": "Berry bushes take 30% longer to deplete. Less running around, more watching roamers.",
	},
	{
		"id":          GusManager.UPGRADE_GENEROUS_WELLS,
		"name":        "Generous Wells",
		"cost":        100.0,
		"min_level":   3,
		"description": "Bonded roamers produce 25% more dewdrops. The garden pays for itself eventually.",
	},
	{
		"id":          GusManager.UPGRADE_WARM_WELCOME,
		"name":        "Warm Welcome",
		"cost":        120.0,
		"min_level":   4,
		"description": "Wild roamers visit the garden 30% more frequently. Word gets around.",
	},
]

# ── Dialogue pools ─────────────────────────────────────────────────────────────
const GREETINGS_MORNING: Array = [
	"Up early. Good. Gardens don't tend themselves — believe me, I've checked.",
	"Morning. I was having a look at your setup. Not bad. Could be better.",
	"Right on time. I've got a list of improvements and not all day to go through them.",
	"Early start. That's the right instinct. The garden rewards it.",
	"Morning. You've done more than most. Let's see if we can make it even better.",
]
const GREETINGS_AFTERNOON: Array = [
	"Afternoon. Bit late in the day, but I'll take it.",
	"Good. I was starting to think I'd wasted the trip.",
	"Afternoon. Your roamers look settled enough. Let's talk improvements.",
	"I've been walking the boundary. There's work to be done, as always.",
	"Right. You've got my attention. What are you investing in?",
]
const GREETINGS_EVENING: Array = [
	"Evening. I don't usually work this late, but here we are.",
	"Still light enough to see what needs doing. What'll it be?",
	"Evening. I'll be straight with you — I'm heading off soon. Make it count.",
	"Late for business, but I'm not one to turn away a serious gardener.",
	"The light's going. Good time to talk upgrades, bad time to plant anything.",
]
const GREETINGS_NIGHT: Array = [
	"Night shift? Fair enough. I've seen worse dedication.",
	"Most people are asleep. You're here. That says something.",
	"Right. Middle of the night. Let's make it worth both our while.",
	"Garden's quiet at night. Good time to plan improvements.",
	"Late, but I've got nothing else on. What do you need?",
]

const PURCHASE_LINES: Array = [
	"Good investment. You'll feel that one.",
	"Sensible choice. Should've done it sooner, but no matter.",
	"Done. Don't thank me — just use it properly.",
	"Right. That's in. You'll notice the difference.",
	"Money well spent, for once.",
]
const BROKE_LINES: Array = [
	"Not enough. Come back when the garden's earned it.",
	"Dewdrops short. The upgrade'll keep. So should you.",
	"That one costs what it costs. No negotiating.",
	"Short a few drops. Let the roamers earn their keep.",
	"Not yet. Keep at it.",
]
const ALREADY_PURCHASED_LINES: Array = [
	"You've already got that one. Pay attention.",
	"Done already. Move on.",
	"That's in. Look at the rest of the list.",
	"Already purchased. Eyes on what you haven't got yet.",
]
const FAREWELL_LINES: Array = [
	"Right. I'm off. Garden looks better than when I arrived — that's something.",
	"Time to move on. I'll be back when the route brings me round again.",
	"Keep at it. There's always more to do.",
	"I'll be back. Don't let it go to seed in the meantime.",
	"Off I go. Don't make me regret leaving this place in your hands.",
]

var is_shop_open := false

# ── Node refs ──────────────────────────────────────────────────────────────────
var _character_built : bool           = false
var _head_node       : Node3D         = null
var _selection_ring  : MeshInstance3D = null
var _ring_pulse_timer: float          = 0.0
var _time            : float          = 0.0
var _breathe_phase   : float          = 0.0
var _base_y          : float          = 0.0

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	add_to_group("gus")
	_breathe_phase = randf() * TAU
	_base_y        = position.y
	_build_character()
	_create_selection_ring()
	if has_node("InteractionArea"):
		$InteractionArea.body_entered.connect(_on_body_entered)

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.82 + _breathe_phase) * 0.009
	if _head_node:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var to_cam := camera.global_position - _head_node.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.5:
				_head_node.rotation.y = lerp_angle(
					_head_node.rotation.y, atan2(to_cam.x, to_cam.z), delta * 1.1)
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
	skin_mat.albedo_color = Color(0.72, 0.54, 0.40)
	skin_mat.roughness = 0.82

	var shirt_mat := StandardMaterial3D.new()
	shirt_mat.albedo_color = Color(0.42, 0.38, 0.30)  # dusty olive work shirt
	shirt_mat.roughness = 0.88

	var trouser_mat := StandardMaterial3D.new()
	trouser_mat.albedo_color = Color(0.24, 0.22, 0.18)  # dark charcoal
	trouser_mat.roughness = 0.90

	var boot_mat := StandardMaterial3D.new()
	boot_mat.albedo_color = Color(0.20, 0.15, 0.10)
	boot_mat.roughness = 0.92

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.28, 0.24, 0.18)  # dark flat cap
	cap_mat.roughness = 0.90

	var belt_mat := StandardMaterial3D.new()
	belt_mat.albedo_color = Color(0.35, 0.22, 0.10)
	belt_mat.roughness = 0.85

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.55, 0.50, 0.45)  # greying
	hair_mat.roughness = 0.95

	# Body — stocky build
	_add_box(Vector3(0, 0.84, 0), Vector3(0.58, 0.72, 0.34), shirt_mat)   # torso
	# Legs
	_add_box(Vector3(-0.15, 0.32, 0), Vector3(0.24, 0.60, 0.28), trouser_mat)
	_add_box(Vector3( 0.15, 0.32, 0), Vector3(0.24, 0.60, 0.28), trouser_mat)
	# Boots — heavy
	_add_box(Vector3(-0.15, 0.07, 0.03), Vector3(0.26, 0.14, 0.36), boot_mat)
	_add_box(Vector3( 0.15, 0.07, 0.03), Vector3(0.26, 0.14, 0.36), boot_mat)
	# Arms — rolled sleeves
	_add_box(Vector3(-0.38, 0.88, 0), Vector3(0.18, 0.52, 0.22), shirt_mat)
	_add_box(Vector3( 0.38, 0.88, 0), Vector3(0.18, 0.52, 0.22), shirt_mat)
	_add_box(Vector3(-0.38, 0.58, 0), Vector3(0.16, 0.30, 0.18), skin_mat)
	_add_box(Vector3( 0.38, 0.58, 0), Vector3(0.16, 0.30, 0.18), skin_mat)
	# Hands
	_add_box(Vector3(-0.38, 0.40, 0), Vector3(0.15, 0.14, 0.16), skin_mat)
	_add_box(Vector3( 0.38, 0.40, 0), Vector3(0.15, 0.14, 0.16), skin_mat)
	# Tool belt
	_add_box(Vector3(0, 0.58, 0.18), Vector3(0.58, 0.07, 0.06), belt_mat)
	# Neck
	_add_box(Vector3(0, 1.24, 0), Vector3(0.20, 0.14, 0.20), skin_mat)
	# Head — broad face
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.42, 0.40, 0.38)
	head.mesh = hm
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.55, 0)
	head.name = "Head"
	add_child(head)
	_head_node = head
	# Stubble / grey beard
	_add_box(Vector3(0, 1.38, -0.19), Vector3(0.36, 0.18, 0.06), hair_mat)
	# Flat cap — brim + top
	_add_box(Vector3(0, 1.79, 0),    Vector3(0.46, 0.10, 0.42), cap_mat)  # top
	_add_box(Vector3(0.12, 1.73, -0.22), Vector3(0.36, 0.06, 0.08), cap_mat)  # brim front

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
	mat.albedo_color               = Color(0.70, 0.55, 0.25, 0.50)
	mat.emission                   = Color(0.70, 0.50, 0.18)
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
	if t >= 5.0 and t < 12.0:   pool = GREETINGS_MORNING
	elif t >= 12.0 and t < 18.0: pool = GREETINGS_AFTERNOON
	elif t >= 18.0 and t < 21.0: pool = GREETINGS_EVENING
	else:                         pool = GREETINGS_NIGHT
	return pool[randi() % pool.size()]

func get_purchase_line() -> String:
	return PURCHASE_LINES[randi() % PURCHASE_LINES.size()]

func get_broke_line() -> String:
	return BROKE_LINES[randi() % BROKE_LINES.size()]

func get_already_purchased_line() -> String:
	return ALREADY_PURCHASED_LINES[randi() % ALREADY_PURCHASED_LINES.size()]

func get_farewell_line() -> String:
	return FAREWELL_LINES[randi() % FAREWELL_LINES.size()]

# ── Upgrade system ─────────────────────────────────────────────────────────────
## Returns true on success, false if not enough dewdrops or already owned.
func upgrade_item(index: int) -> bool:
	if index < 0 or index >= upgrade_items.size():
		return false
	var item: Dictionary = upgrade_items[index]
	var id: String = item["id"]
	if GusManager.has_upgrade(id):
		return false  # caller should show already_purchased line
	if not CurrencyManager.spend_dewdrops(item["cost"]):
		return false
	GusManager.buy_upgrade(id)
	WardenManager.gain_xp("item_purchased")
	return true

func is_purchased(index: int) -> bool:
	if index < 0 or index >= upgrade_items.size():
		return false
	return GusManager.has_upgrade(upgrade_items[index]["id"])

# ── Interaction ────────────────────────────────────────────────────────────────
func _on_body_entered(_body: Node3D) -> void:
	pass
