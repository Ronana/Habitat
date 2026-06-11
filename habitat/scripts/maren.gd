extends Node3D

var shop_items = [
	{"name": "Berry Seeds",     "cost": 10.0, "min_level": 1, "description": "Plant a berry bush. Roamers will seek it out when hungry."},
	{"name": "Roamer Treat",    "cost": 8.0,  "min_level": 1, "description": "A tasty snack. Select a Roamer then use from inventory to feed them."},
	{"name": "Oak Sapling",     "cost": 25.0, "min_level": 1, "description": "Plant a tree. Woodland Roamers love to shelter beneath them."},
	{"name": "Basic Shelter",   "cost": 30.0, "min_level": 1, "description": "A cosy home for a Roamer. Place it to help Roamers become Residents."},
	{"name": "Wildgrass Seeds", "cost": 15.0, "min_level": 2, "description": "Plant wild grass. Increases the space felt by nearby Roamers."},
	{"name": "Cosy Burrow",     "cost": 55.0, "min_level": 3, "description": "A snug underground den. Provides stronger safety than a Basic Shelter."},
]

var is_shop_open = false

var selection_ring: MeshInstance3D = null
var _ring_pulse_timer: float = 0.0

func _ready():
	$InteractionArea.body_entered.connect(_on_body_entered)
	_create_selection_ring()

func _create_selection_ring():
	selection_ring = MeshInstance3D.new()
	selection_ring.position = Vector3(0.0, 0.05, 0.0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var inner_r := 0.6
	var outer_r := 0.9
	var segments := 48
	for i in range(segments):
		var a1 = (float(i)     / segments) * TAU
		var a2 = (float(i + 1) / segments) * TAU
		var p1i = Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var p1o = Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var p2i = Vector3(cos(a2) * inner_r, 0.0, sin(a2) * inner_r)
		var p2o = Vector3(cos(a2) * outer_r, 0.0, sin(a2) * outer_r)
		st.add_vertex(p1o); st.add_vertex(p2o); st.add_vertex(p1i)
		st.add_vertex(p2o); st.add_vertex(p2i); st.add_vertex(p1i)
	selection_ring.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.shading_mode           = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test          = true
	mat.emission_enabled       = true
	mat.albedo_color           = Color(1.0, 0.9, 0.5, 0.5)
	mat.emission               = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 1.1
	selection_ring.set_surface_override_material(0, mat)
	selection_ring.visible = false
	add_child(selection_ring)

func _process(delta):
	if selection_ring and selection_ring.visible:
		_ring_pulse_timer += delta
		var pulse = 1.0 + 0.05 * sin(_ring_pulse_timer * 3.2)
		selection_ring.scale = Vector3(pulse, 1.0, pulse)

func show_selection_ring():
	if selection_ring:
		selection_ring.visible = true
		_ring_pulse_timer = 0.0

func hide_selection_ring():
	if selection_ring:
		selection_ring.visible = false

func _on_body_entered(body):
	print("Someone entered Maren's area: ", body.name)

func open_shop():
	is_shop_open = true
	print("Maren's shop is open!")
	print("--- Maren's Wares ---")
	for i in range(shop_items.size()):
		var item = shop_items[i]
		print(i, ". ", item["name"], " — ", item["cost"], " Dewdrops — ", item["description"])
	print("Current Dewdrops: ", CurrencyManager.dewdrops)

func buy_item(index: int):
	if index >= shop_items.size():
		print("Invalid item")
		return
	var item = shop_items[index]
	if CurrencyManager.spend_dewdrops(item["cost"]):
		print("Purchased: ", item["name"])
		apply_purchase(item["name"])
	else:
		print("Not enough Dewdrops!")

func apply_purchase(item_name: String):
	InventoryManager.add_item(item_name)
