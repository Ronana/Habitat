## maren.gd — Sam the Seedkeeper NPC.
## Handles the shop, idle animations (breathing bob, head tracking),
## a procedural fabric shader on the robe, floating seed particles,
## and a pulsing crystal glow.
extends Node3D

# ── Shop data ─────────────────────────────────────────────────────────────────
# sell_price is what Sam pays YOU when selling back. 0 = not sellable.
var shop_items := [
	# Essentials
	{"name": "Berry Seeds",      "cost": 10.0, "sell_price": 4.0,  "min_level": 1,
		"description": "Plant a berry bush. Roamers will seek it out when hungry."},
	{"name": "Roamer Treat",     "cost": 8.0,  "sell_price": 3.0,  "min_level": 1,
		"description": "A tasty snack. Select a Roamer then use from inventory to feed them."},
	{"name": "Oak Sapling",      "cost": 25.0, "sell_price": 10.0, "min_level": 1,
		"description": "Plant a tree. Woodland Roamers love to shelter beneath them."},
	{"name": "GlowFox Den",      "cost": 40.0, "sell_price": 18.0, "min_level": 1,
		"description": "A glowing den for GlowFoxes. Place it to help GlowFoxes settle as Residents."},
	{"name": "MossDeer Hollow",  "cost": 45.0, "sell_price": 20.0, "min_level": 1,
		"description": "A mossy woodland hollow for MossDeer. Large enough for a small herd."},
	{"name": "Stoneback Cave",   "cost": 40.0, "sell_price": 18.0, "min_level": 1,
		"description": "A sturdy stone cave for Stonebacks. Built to last like the creatures inside."},
	{"name": "Thornmouse Burrow", "cost": 35.0, "sell_price": 15.0, "min_level": 2,
		"description": "A cosy underground burrow for Thornmice. Lined with dry grass and hidden from predators."},
	{"name": "Emberowl Roost",  "cost": 50.0, "sell_price": 22.0, "min_level": 3,
		"description": "A hollowed-out tree stump with an ember-warm interior. Emberowls love to sleep inside by day."},
	{"name": "Crystalback Grotto", "cost": 60.0, "sell_price": 26.0, "min_level": 4,
		"description": "A crystal-studded rock grotto that pulses with soft blue light. Draws Crystalbacks who find it irresistible."},
	{"name": "Wildgrass Seeds",  "cost": 15.0, "sell_price": 6.0,  "min_level": 2,
		"description": "Plant wild grass. Increases the space felt by nearby Roamers."},
	# Decoratives
	{"name": "Flower Patch",     "cost": 12.0, "sell_price": 5.0,  "min_level": 1,
		"description": "A cluster of colourful wildflowers. Brightens up any corner of the garden."},
	{"name": "Mossy Rock",       "cost": 18.0, "sell_price": 8.0,  "min_level": 1,
		"description": "A mossy boulder. Roamers like to sit near large rocks."},
	{"name": "Mushroom Cluster", "cost": 14.0, "sell_price": 6.0,  "min_level": 2,
		"description": "Earthy toadstools in autumnal shades. A favourite of Stonebacks."},
	{"name": "Fallen Log",       "cost": 22.0, "sell_price": 9.0,  "min_level": 2,
		"description": "A mossy log. Adds a woodland feel and gives critters a place to rest beside."},
	# Lighting
	{"name": "Garden Lantern",   "cost": 40.0, "sell_price": 16.0, "min_level": 2,
		"description": "A warm lantern that lights up at dusk. Keeps the garden cosy through the night."},
	{"name": "Glowing Mushroom", "cost": 35.0, "sell_price": 14.0, "min_level": 3,
		"description": "A bioluminescent mushroom that pulses with soft blue-green light."},
	{"name": "Firefly Jar",      "cost": 30.0, "sell_price": 12.0, "min_level": 3,
		"description": "A sealed jar full of fireflies. Flickers gently and releases sparkles."},
	{"name": "Moss Torch",       "cost": 45.0, "sell_price": 18.0, "min_level": 4,
		"description": "A stone torch draped in moss. Casts a warm, flickering glow over a wide area."},
	# Fencing
	{"name": "Fence Panel",      "cost": 8.0,  "sell_price": 3.0,  "min_level": 1,
		"description": "A sturdy wooden fence segment. Right-click to place; keep clicking to build a run. Press R to rotate, Esc to finish."},
	# Care items
	{"name": "Restorative Berry", "cost": 25.0, "sell_price": 0.0, "min_level": 3,
		"description": "A glowing berry infused with elderwood magic. Clears a struggling Roamer's burden and restores their strength. Gift it to a selected Roamer."},
]

# ── Dialogue pools ─────────────────────────────────────────────────────────────
const GREETINGS_MORNING: Array = [
	"Morning! The seeds are practically jumping out of my satchel today.",
	"Early start? The garden thanks you. So do I — got fresh stock in.",
	"Good morning! Best time of day to plant something new, if you ask me.",
	"Ah, you're up with the dew! Wonderful. Let's see what takes your fancy.",
	"Morning light, fresh seeds. You've got good timing.",
]
const GREETINGS_AFTERNOON: Array = [
	"Afternoon! How's the garden coming along? Anything need restocking?",
	"Perfect timing — I just sorted out the shelves. Take a look.",
	"Good afternoon! The roamers looking lively today?",
	"Busy day? I've had a few wanderers stop by. You're my favourite though.",
	"Ah, the Warden! Come in, come in. Plenty to choose from.",
]
const GREETINGS_EVENING: Array = [
	"Evening already? Time flies when you're tending a garden.",
	"Still at it? Good. The best gardeners work by moonrise.",
	"The GlowFoxes'll be waking up soon. Good time to stock up on light sources.",
	"Evening! I was about to close up, but I'll stay open for you.",
	"Getting dark — perfect time to pick up a lantern or two.",
]
const GREETINGS_NIGHT: Array = [
	"You're up late! The garden doesn't sleep, and neither do I apparently.",
	"Midnight stock check — you caught me. Browse away.",
	"The roamers are sleeping, so why aren't you? …Why aren't I? Anyway — shopping!",
	"Stars are out. Makes everything feel more magical, don't you think?",
	"Night shift Warden! I respect the dedication. What can I get you?",
]

const PURCHASE_LINES: Array = [
	"Lovely choice. Your garden's going to be thriving.",
	"Excellent taste. The roamers will appreciate that.",
	"Good pick! That one always sells well.",
	"There you go. Come back whenever you need more.",
	"A fine investment. I always say — spend on the garden, earn it back tenfold.",
	"Done and dusted. Your dewdrops are well spent.",
]
const BROKE_LINES: Array = [
	"Hmm — dewdrops running a bit low, are they? Come back when you've topped up.",
	"I'd love to help, but dewdrops don't lie! Not enough there, I'm afraid.",
	"The roamers will earn you more if you keep them happy. Short a few drops right now.",
	"Can't quite stretch to that one yet. Patience — the dewdrops will flow.",
	"Not quite enough, I'm afraid! Give the garden a bit of time.",
]
const SELL_LINES: Array = [
	"I can always use stock. Fair deal.",
	"Good condition too. I'll take it.",
	"Done. Always happy to buy back from a well-kept garden.",
	"Sold! Dewdrops straight to your pocket.",
	"Pleasure doing business with you.",
]

var is_shop_open := false

# ── Node references ────────────────────────────────────────────────────────────
var _head_node       : Node3D         = null
var _crystal_light   : OmniLight3D    = null
var _crystal_mesh    : MeshInstance3D = null

# ── Animation state ────────────────────────────────────────────────────────────
var _time            : float = 0.0
var _breathe_phase   : float = 0.0   # random offset so multiple Marens differ
var _base_y          : float = 0.0

# ── Selection ring ────────────────────────────────────────────────────────────
var selection_ring   : MeshInstance3D = null
var _ring_pulse_timer: float = 0.0

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	_breathe_phase = randf() * TAU
	_base_y        = position.y

	_head_node     = get_node_or_null("Head")     as Node3D
	_crystal_light = get_node_or_null("CrystalGlow") as OmniLight3D
	_crystal_mesh  = get_node_or_null("StaffCrystal") as MeshInstance3D

	$InteractionArea.body_entered.connect(_on_body_entered)

	_apply_robe_shader()
	_create_selection_ring()
	_spawn_seed_particles()

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta

	# ── Gentle idle breathing bob (whole character) ──────────────────────────
	var breathe := sin(_time * 0.95 + _breathe_phase) * 0.012
	position.y = _base_y + breathe

	# ── Slow head tracking toward camera ─────────────────────────────────────
	if _head_node:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var to_cam := camera.global_position - _head_node.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.5:
				var target_angle := atan2(to_cam.x, to_cam.z)
				_head_node.rotation.y = lerp_angle(
					_head_node.rotation.y, target_angle, delta * 1.4)

	# ── Crystal pulse ─────────────────────────────────────────────────────────
	if _crystal_light:
		var pulse := 1.0 + 0.18 * sin(_time * 2.1)
		_crystal_light.light_energy = 1.20 * pulse

	# ── Selection ring pulse ──────────────────────────────────────────────────
	if selection_ring and selection_ring.visible:
		_ring_pulse_timer += delta
		var ring_pulse := 1.0 + 0.05 * sin(_ring_pulse_timer * 3.2)
		selection_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)

# ── Robe fabric shader ─────────────────────────────────────────────────────────
func _apply_robe_shader() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform vec4 robe_base   : source_color = vec4(0.13, 0.29, 0.15, 1.0);
uniform vec4 robe_shadow : source_color = vec4(0.07, 0.18, 0.09, 1.0);
uniform vec4 robe_sheen  : source_color = vec4(0.20, 0.40, 0.22, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * vec2(7.0, 11.0);

	// Woven fabric: cross-hatch of sin waves at 90 degrees
	float weave_h = sin(uv.x * 3.14159) * 0.5 + 0.5;
	float weave_v = sin(uv.y * 3.14159) * 0.5 + 0.5;
	float weave   = mix(weave_h, weave_v, 0.5);

	// Noise for fabric variation and fold hints
	float n_fold  = vnoise(UV * vec2(2.5, 4.0));  // Large fold shadows
	float n_fine  = vnoise(UV * vec2(10.0, 8.0)); // Fine cloth texture

	float cloth = weave * 0.28 + n_fold * 0.44 + n_fine * 0.28;

	// Bottom of robe slightly darker (hem shadow)
	float hem_dark = smoothstep(0.15, 0.0, UV.y) * 0.35;
	cloth -= hem_dark;
	cloth  = clamp(cloth, 0.0, 1.0);

	vec3 col = mix(robe_shadow.rgb, robe_base.rgb, cloth);

	// Very subtle sheen at top (catches light at shoulder area)
	float sheen = smoothstep(0.7, 1.0, UV.y) * 0.18;
	col = mix(col, robe_sheen.rgb, sheen);

	// Fresnel: fabric catches light at grazing angles
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, robe_sheen.rgb, fresnel * 0.12);

	ALBEDO    = col;
	ROUGHNESS = 0.88;
	METALLIC  = 0.0;
}
"""
	var robe_mat := ShaderMaterial.new()
	robe_mat.shader = shader

	for node_name: String in ["Robe", "RobeHem", "Collar"]:
		var node: MeshInstance3D = get_node_or_null(node_name) as MeshInstance3D
		if node:
			node.set_surface_override_material(0, robe_mat)

# ── Ambient seed particles ─────────────────────────────────────────────────────
func _spawn_seed_particles() -> void:
	var p := GPUParticles3D.new()
	p.name            = "SeedParticles"
	p.emitting        = true
	p.one_shot        = false
	p.amount          = 14
	p.lifetime        = 4.5
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.55
	mat.direction              = Vector3(0.0, 1.0, 0.0)
	mat.spread                 = 60.0
	mat.initial_velocity_min   = 0.12
	mat.initial_velocity_max   = 0.55
	mat.gravity                = Vector3(0.0, 0.06, 0.0)
	mat.scale_min              = 0.022
	mat.scale_max              = 0.052
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.50, 0.90, 0.42, 0.0))
	grad.add_point(0.25, Color(0.55, 0.95, 0.46, 0.85))
	grad.add_point(0.75, Color(0.40, 0.80, 0.78, 0.60))
	grad.add_point(1.0, Color(0.40, 0.78, 0.72, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color               = Color(0.50, 0.92, 0.46, 0.9)
	draw_mat.emission_enabled           = true
	draw_mat.emission                   = Color(0.34, 0.82, 0.40)
	draw_mat.emission_energy_multiplier = 0.9
	draw_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	p.draw_pass_1 = mesh

	add_child(p)
	p.position = Vector3(0.0, 1.1, 0.0)

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
	mat.albedo_color               = Color(1.0, 0.9, 0.5, 0.5)
	mat.emission                   = Color(1.0, 0.85, 0.4)
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

func get_purchase_line() -> String:
	return PURCHASE_LINES[randi() % PURCHASE_LINES.size()]

func get_broke_line() -> String:
	return BROKE_LINES[randi() % BROKE_LINES.size()]

func get_sell_line() -> String:
	return SELL_LINES[randi() % SELL_LINES.size()]

## Returns the sell price for an inventory item name, or 0 if Sam won't buy it.
func get_sell_price(item_name: String) -> float:
	for item in shop_items:
		if item["name"] == item_name:
			return item.get("sell_price", 0.0)
	return 0.0

# ── Interaction ────────────────────────────────────────────────────────────────
func _on_body_entered(_body: Node3D) -> void:
	pass

func apply_purchase(item_name: String) -> void:
	InventoryManager.add_item(item_name)

func buy_item(index: int) -> void:
	if index < 0 or index >= shop_items.size():
		return
	var item: Dictionary = shop_items[index]
	if CurrencyManager.spend_dewdrops(item["cost"]):
		apply_purchase(item["name"])
		WardenManager.gain_xp("item_purchased")

func sell_item(item_name: String) -> bool:
	var price: float = get_sell_price(item_name)
	if price <= 0.0:
		return false
	if not InventoryManager.remove_item(item_name):
		return false
	CurrencyManager.add_dewdrops(price)
	return true
