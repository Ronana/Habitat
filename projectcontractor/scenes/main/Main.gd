extends Node2D
## Gameplay redesign: MINE screen as default, MENU+SHOP navigation.
##
## Screen layout (720×1280 portrait):
##   [   0 – 110 ] HUD + XP bar        (CanvasLayer 10)
##   [ 110 – 190 ] Location bar        (Node2D — always visible)
##   [ 190 – 1180] Mine area           (Node2D — always visible)
##   [1180 – 1280] Bottom bar          (CanvasLayer 50 — always on top)
##
## Overlay panels  (CanvasLayer 20):  Build, Craft, Crew, Skyline, Shop
## Wall panel      (CanvasLayer 25)
## Menu modal      (CanvasLayer 30)
## Splash          (CanvasLayer 40)

# ── Constants ──────────────────────────────────────────────────────────────
const SCREEN_W     := 720
const SCREEN_H     := 1280
const HUD_H        := 110
const BOTTOM_BAR_H := 100
const LOC_BAR_H    := 76
const MINE_Y       := HUD_H + LOC_BAR_H   # 186
const MINE_H       := SCREEN_H - MINE_Y - BOTTOM_BAR_H  # 994

const _HOUSE_SHEET_PATH := "res://assets/imported/ModernHouseA.png"
const _CELL_W           := 281
const _CELL_H           := 384
const _LOGO_W           := 200

# ── Colour palette ─────────────────────────────────────────────────────────
const C_BG       := Color(0.06, 0.07, 0.10)
const C_PANEL    := Color(0.09, 0.10, 0.15, 0.98)
const C_CARD     := Color(0.13, 0.14, 0.20)
const C_BORDER   := Color(0.20, 0.22, 0.32)
const C_GOLD     := Color(1.00, 0.78, 0.20)
const C_GEM      := Color(0.40, 0.85, 1.00)
const C_TIMBER   := Color(0.82, 0.57, 0.25)
const C_STONE    := Color(0.70, 0.70, 0.76)
const C_LUMBER   := Color(0.95, 0.72, 0.30)
const C_CONCRETE := Color(0.55, 0.55, 0.62)
const C_GREEN    := Color(0.25, 0.80, 0.42)
const C_RED      := Color(0.85, 0.28, 0.28)
const C_ACCENT   := Color(0.28, 0.62, 1.00)
const C_TEXT     := Color(0.92, 0.92, 0.96)
const C_DIM      := Color(0.50, 0.52, 0.60)
const C_XP       := Color(0.70, 0.35, 1.00)

# ── HUD refs ───────────────────────────────────────────────────────────────
var _lbl_cash:    Label
var _lbl_gems:    Label
var _lbl_level:   Label
var _xp_bar_fill: ColorRect

# ── Mine screen refs ───────────────────────────────────────────────────────
var _loc_btns:         Array[Button]    = []
var _loc_indicators:   Array[ColorRect] = []
var _node_rect:        ColorRect   # inner fill
var _node_border:      ColorRect   # outer border
var _node_accent_bar:  ColorRect   # top colour strip
var _lbl_node_symbol:  Label       # big letter "T" / "S"
var _lbl_node_name:    Label       # "Sapling", "Pebble", etc.
var _lbl_hp_left:      Label       # "HP" label (left)
var _lbl_hp_right:     Label       # "8.0 / 10" (right)
var _hp_bar_bg:        ColorRect
var _hp_bar_fill:      ColorRect
var _lbl_mat_count:    Label
var _lbl_mine_rate:    Label
var _lbl_feedback:     Label
var _feedback_tween:   Tween

# ── Build panel refs ───────────────────────────────────────────────────────
var _build_panel:       CanvasLayer
var _building_sprite:   Sprite2D
var _house_sheet_tex:   Texture2D
var _lbl_build_stage:   Label
var _build_reqs_box:    VBoxContainer
var _build_prog_bg:     ColorRect
var _build_prog_fill:   ColorRect
var _lbl_build_pct:     Label
var _btn_start_stage:   Button
var _lbl_cant_start:    Label
var _btn_tap_build:     Button
var _lbl_build_bp:      Label
var _lbl_build_feedback:Label

# ── Menu overlay refs ──────────────────────────────────────────────────────
var _menu_overlay: CanvasLayer

# ── Crew panel refs ────────────────────────────────────────────────────────
var _crew_panel:          CanvasLayer
var _lbl_crew_bp:         Label
var _crew_hire_btns:      Array[Button]    = []
var _crew_levelup_btns:   Array[Button]    = []
var _crew_level_labels:   Array[Label]     = []
var _crew_rate_labels:    Array[Label]     = []
var _crew_progress_fills: Array[ColorRect] = []

# ── Craft panel refs ───────────────────────────────────────────────────────
var _craft_panel:      CanvasLayer
var _craft_inv_lbls:   Array[Label]  = []
var _craft_yield_lbls: Array[Label]  = []
var _craft1_btns:      Array[Button] = []
var _craftall_btns:    Array[Button] = []

# ── Wall panel refs ────────────────────────────────────────────────────────
var _wall_panel:      CanvasLayer
var _lbl_wall_title:  Label
var _lbl_wall_detail: Label

# ── Skyline panel refs ─────────────────────────────────────────────────────
var _skyline_panel:    CanvasLayer
var _skyline_list_box: VBoxContainer

# ── Upgrades panel refs ────────────────────────────────────────────────────
var _upgrades_panel:     CanvasLayer
var _upgrade_cards:      Array[Dictionary] = []  # {bg, bar, name_lbl, desc_lbl, level_lbl, cost_lbl, btn}

# ── Sell panel refs ────────────────────────────────────────────────────────
var _sell_panel:       CanvasLayer
var _sell_inv_lbls:    Array[Label]  = []   # current qty per material
var _sell_earn_lbls:   Array[Label]  = []   # "= X cash" preview

# ── Shop panel refs ────────────────────────────────────────────────────────
var _shop_panel:     CanvasLayer
var _lbl_shop_gems:  Label
var _btn_stage_skip: Button

# ── Runtime accumulators ───────────────────────────────────────────────────
# Per-location worker HP-damage accumulator (smooth sub-integer ticking)
var _worker_dmg_accum: Dictionary = {}

# ══════════════════════════════════════════════════════════════════════════
# Lifecycle
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_splash()
	_build_hud()
	_build_location_bar()
	_build_mine_area()
	_build_bottom_bar()
	_build_menu_overlay()
	_build_build_panel()
	_build_crew_panel()
	_build_craft_panel()
	_build_wall_panel()
	_build_skyline_panel()
	_build_upgrades_panel()
	_build_sell_panel()
	_build_shop_panel()
	_update_display()
	_check_offline_summary()

func _process(delta: float) -> void:
	_tick_workers(delta)

# ══════════════════════════════════════════════════════════════════════════
# Scene construction
# ══════════════════════════════════════════════════════════════════════════

# ── Splash ─────────────────────────────────────────────────────────────────
func _build_splash() -> void:
	var cl      := CanvasLayer.new()
	cl.name      = "Splash"
	cl.layer     = 40
	add_child(cl)

	var bg      := ColorRect.new()
	bg.color     = Color(0.04, 0.06, 0.14)
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H)
	cl.add_child(bg)

	var logo_tex := load("res://assets/imported/MainLogoWText.png") as Texture2D
	if logo_tex:
		var logo         := TextureRect.new()
		logo.texture      = logo_tex
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.position     = Vector2(40, SCREEN_H / 2.0 - 100)
		logo.size         = Vector2(640, 200)
		cl.add_child(logo)

	var skip_btn     := Button.new()
	skip_btn.flat     = true
	skip_btn.position = Vector2.ZERO
	skip_btn.size     = Vector2(SCREEN_W, SCREEN_H)
	skip_btn.pressed.connect(cl.queue_free)
	cl.add_child(skip_btn)

	var timer          := Timer.new()
	timer.wait_time     = 2.5
	timer.one_shot      = true
	timer.autostart     = true
	timer.timeout.connect(cl.queue_free)
	cl.add_child(timer)

# ── HUD ────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var cl  := CanvasLayer.new()
	cl.name  = "HUD"
	cl.layer = 10
	add_child(cl)

	var bg      := ColorRect.new()
	bg.color     = Color(0.07, 0.08, 0.12)
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, HUD_H)
	cl.add_child(bg)

	var sep      := ColorRect.new()
	sep.color     = C_BORDER
	sep.position  = Vector2(0, HUD_H - 2)
	sep.size      = Vector2(SCREEN_W, 2)
	cl.add_child(sep)

	# Banner logo (left side)
	var banner_tex := load("res://assets/imported/BannerLogo.png") as Texture2D
	if banner_tex:
		var logo         := TextureRect.new()
		logo.texture      = banner_tex
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.position     = Vector2(8, 0)
		logo.size         = Vector2(_LOGO_W, HUD_H - 26)
		cl.add_child(logo)

	# Stat chips: Cash | Gems | Level  (right of logo)
	var chip_w := float(SCREEN_W - _LOGO_W) / 3.0
	_lbl_cash  = _hud_chip(cl, "$ 0",  C_GOLD,   _LOGO_W + chip_w * 0, chip_w)
	_lbl_gems  = _hud_chip(cl, "◆ 0",  C_GEM,    _LOGO_W + chip_w * 1, chip_w)
	_lbl_level = _hud_chip(cl, "Lv.1", C_ACCENT, _LOGO_W + chip_w * 2, chip_w)

	# XP bar strip along the bottom of the HUD
	var xp_bg      := ColorRect.new()
	xp_bg.color     = Color(0.10, 0.06, 0.18)
	xp_bg.position  = Vector2(0, HUD_H - 22)
	xp_bg.size      = Vector2(SCREEN_W, 20)
	cl.add_child(xp_bg)

	_xp_bar_fill         = ColorRect.new()
	_xp_bar_fill.color   = C_XP
	_xp_bar_fill.position = Vector2(0, HUD_H - 22)
	_xp_bar_fill.size     = Vector2(0, 20)
	cl.add_child(_xp_bar_fill)

	var xp_lbl      := Label.new()
	xp_lbl.name      = "XpLabel"
	xp_lbl.text      = "XP"
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	xp_lbl.position  = Vector2(0, HUD_H - 22)
	xp_lbl.size      = Vector2(SCREEN_W, 20)
	xp_lbl.add_theme_font_size_override("font_size", 11)
	xp_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	cl.add_child(xp_lbl)

func _hud_chip(parent: CanvasLayer, text: String, color: Color, x: float, w: float) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.position             = Vector2(x, 0)
	lbl.size                 = Vector2(w, HUD_H - 26)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

# ── Location selector bar ───────────────────────────────────────────────────
func _build_location_bar() -> void:
	var bg      := ColorRect.new()
	bg.color     = Color(0.07, 0.08, 0.13)
	bg.position  = Vector2(0, HUD_H)
	bg.size      = Vector2(SCREEN_W, LOC_BAR_H)
	add_child(bg)

	var sep      := ColorRect.new()
	sep.color     = C_BORDER
	sep.position  = Vector2(0, HUD_H + LOC_BAR_H - 2)
	sep.size      = Vector2(SCREEN_W, 2)
	add_child(sep)

	var locs  := BuildDatabase.LOCATION_ORDER
	var btn_w := float(SCREEN_W) / float(locs.size())

	for i in locs.size():
		var loc_id: String   = locs[i]
		var loc_data         := BuildDatabase.get_location(loc_id)
		var dname: String    = loc_data.get("display_name", loc_id)
		var mat: String      = loc_data.get("material", "timber")
		var accent           := _mat_color(mat)

		var btn      := Button.new()
		btn.flat      = true
		btn.text      = dname
		btn.position  = Vector2(i * btn_w, HUD_H)
		btn.size      = Vector2(btn_w, LOC_BAR_H - 2)
		btn.pressed.connect(_on_location_btn.bind(loc_id))
		btn.add_theme_color_override("font_color", C_DIM)
		add_child(btn)
		_loc_btns.append(btn)

		# Active-tab underline indicator
		var ind      := ColorRect.new()
		ind.color     = accent
		ind.position  = Vector2(i * btn_w + 20, HUD_H + LOC_BAR_H - 6)
		ind.size      = Vector2(btn_w - 40, 4)
		ind.visible   = false
		add_child(ind)
		_loc_indicators.append(ind)

# ── Mine area ───────────────────────────────────────────────────────────────
func _build_mine_area() -> void:
	# Dark background fill
	var bg      := ColorRect.new()
	bg.color     = C_BG
	bg.position  = Vector2(0, MINE_Y)
	bg.size      = Vector2(SCREEN_W, MINE_H)
	add_child(bg)

	# ── Node visual (centered card) ─────────────────────────────────────────
	# Card: x=210, y=MINE_Y+90, size=300×280
	var card_x := 210
	var card_y := MINE_Y + 90

	_node_border         = ColorRect.new()
	_node_border.color   = C_BORDER
	_node_border.position = Vector2(card_x, card_y)
	_node_border.size     = Vector2(300, 280)
	add_child(_node_border)

	_node_rect           = ColorRect.new()
	_node_rect.color     = Color(0.12, 0.09, 0.06)
	_node_rect.position  = Vector2(card_x + 4, card_y + 4)
	_node_rect.size      = Vector2(292, 272)
	add_child(_node_rect)

	_node_accent_bar         = ColorRect.new()
	_node_accent_bar.color   = C_TIMBER
	_node_accent_bar.position = Vector2(card_x, card_y)
	_node_accent_bar.size     = Vector2(300, 6)
	add_child(_node_accent_bar)

	_lbl_node_symbol                      = Label.new()
	_lbl_node_symbol.text                 = "T"
	_lbl_node_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_node_symbol.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_lbl_node_symbol.position             = Vector2(card_x, card_y + 20)
	_lbl_node_symbol.size                 = Vector2(300, 180)
	_lbl_node_symbol.add_theme_font_size_override("font_size", 80)
	_lbl_node_symbol.add_theme_color_override("font_color", C_TIMBER)
	add_child(_lbl_node_symbol)

	_lbl_node_name                      = Label.new()
	_lbl_node_name.text                 = "Sapling"
	_lbl_node_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_node_name.position             = Vector2(card_x, card_y + 200)
	_lbl_node_name.size                 = Vector2(300, 34)
	_lbl_node_name.add_theme_font_size_override("font_size", 16)
	_lbl_node_name.add_theme_color_override("font_color", C_DIM)
	add_child(_lbl_node_name)

	# ── HP bar (below node card) ────────────────────────────────────────────
	var hp_y := card_y + 300

	_lbl_hp_left                      = Label.new()
	_lbl_hp_left.text                 = "HP"
	_lbl_hp_left.position             = Vector2(50, hp_y - 30)
	_lbl_hp_left.size                 = Vector2(200, 26)
	_lbl_hp_left.add_theme_color_override("font_color", C_DIM)
	add_child(_lbl_hp_left)

	_lbl_hp_right                      = Label.new()
	_lbl_hp_right.text                 = "10 / 10"
	_lbl_hp_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_hp_right.position             = Vector2(470, hp_y - 30)
	_lbl_hp_right.size                 = Vector2(200, 26)
	_lbl_hp_right.add_theme_color_override("font_color", C_DIM)
	add_child(_lbl_hp_right)

	_hp_bar_bg         = ColorRect.new()
	_hp_bar_bg.color   = Color(0.12, 0.12, 0.18)
	_hp_bar_bg.position = Vector2(50, hp_y)
	_hp_bar_bg.size     = Vector2(620, 18)
	add_child(_hp_bar_bg)

	_hp_bar_fill         = ColorRect.new()
	_hp_bar_fill.color   = C_GREEN
	_hp_bar_fill.position = Vector2(50, hp_y)
	_hp_bar_fill.size     = Vector2(620, 18)
	add_child(_hp_bar_fill)

	# ── Info labels below HP bar ────────────────────────────────────────────
	_lbl_mat_count                      = Label.new()
	_lbl_mat_count.text                 = "Timber: 0"
	_lbl_mat_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_mat_count.position             = Vector2(0, hp_y + 28)
	_lbl_mat_count.size                 = Vector2(SCREEN_W, 34)
	_lbl_mat_count.add_theme_font_size_override("font_size", 18)
	_lbl_mat_count.add_theme_color_override("font_color", C_TIMBER)
	add_child(_lbl_mat_count)

	_lbl_mine_rate                      = Label.new()
	_lbl_mine_rate.text                 = "Mine Power: 2  ·  Workers: 0 HP/s"
	_lbl_mine_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_mine_rate.position             = Vector2(0, hp_y + 68)
	_lbl_mine_rate.size                 = Vector2(SCREEN_W, 30)
	_lbl_mine_rate.add_theme_font_size_override("font_size", 13)
	_lbl_mine_rate.add_theme_color_override("font_color", C_DIM)
	add_child(_lbl_mine_rate)

	# ── Floating feedback label (damage / XP numbers) ───────────────────────
	_lbl_feedback                      = Label.new()
	_lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_feedback.position             = Vector2(0, MINE_Y + 30)
	_lbl_feedback.size                 = Vector2(SCREEN_W, 44)
	_lbl_feedback.modulate.a           = 0.0
	_lbl_feedback.add_theme_font_size_override("font_size", 16)
	_lbl_feedback.add_theme_color_override("font_color", C_GOLD)
	add_child(_lbl_feedback)

	# ── Full-area invisible tap button ──────────────────────────────────────
	var tap_btn      := Button.new()
	tap_btn.flat      = true
	tap_btn.position  = Vector2(0, MINE_Y)
	tap_btn.size      = Vector2(SCREEN_W, MINE_H)
	tap_btn.pressed.connect(_on_tap_node)
	add_child(tap_btn)

# ── Bottom bar (MENU + SHOP) ────────────────────────────────────────────────
func _build_bottom_bar() -> void:
	var cl  := CanvasLayer.new()
	cl.name  = "BottomBar"
	cl.layer = 50
	add_child(cl)

	var bg      := ColorRect.new()
	bg.color     = Color(0.07, 0.08, 0.12)
	bg.position  = Vector2(0, SCREEN_H - BOTTOM_BAR_H)
	bg.size      = Vector2(SCREEN_W, BOTTOM_BAR_H)
	cl.add_child(bg)

	var sep      := ColorRect.new()
	sep.color     = C_BORDER
	sep.position  = Vector2(0, SCREEN_H - BOTTOM_BAR_H)
	sep.size      = Vector2(SCREEN_W, 2)
	cl.add_child(sep)

	# MENU button (left)
	var menu_bg      := ColorRect.new()
	menu_bg.color     = Color(0.10, 0.11, 0.17)
	menu_bg.position  = Vector2(12, SCREEN_H - BOTTOM_BAR_H + 10)
	menu_bg.size      = Vector2(310, BOTTOM_BAR_H - 20)
	cl.add_child(menu_bg)

	var menu_btn      := Button.new()
	menu_btn.flat      = true
	menu_btn.text      = "☰  MENU"
	menu_btn.position  = Vector2(12, SCREEN_H - BOTTOM_BAR_H + 10)
	menu_btn.size      = Vector2(310, BOTTOM_BAR_H - 20)
	menu_btn.pressed.connect(_on_menu_btn_pressed)
	menu_btn.add_theme_color_override("font_color", C_TEXT)
	menu_btn.add_theme_font_size_override("font_size", 18)
	cl.add_child(menu_btn)

	# SHOP button (right)
	var shop_bg      := ColorRect.new()
	shop_bg.color     = C_GEM.darkened(0.75)
	shop_bg.position  = Vector2(398, SCREEN_H - BOTTOM_BAR_H + 10)
	shop_bg.size      = Vector2(310, BOTTOM_BAR_H - 20)
	cl.add_child(shop_bg)

	var shop_top      := ColorRect.new()
	shop_top.color     = C_GEM
	shop_top.position  = Vector2(398, SCREEN_H - BOTTOM_BAR_H + 10)
	shop_top.size      = Vector2(310, 3)
	cl.add_child(shop_top)

	var shop_btn      := Button.new()
	shop_btn.flat      = true
	shop_btn.text      = "◆  SHOP"
	shop_btn.position  = Vector2(398, SCREEN_H - BOTTOM_BAR_H + 10)
	shop_btn.size      = Vector2(310, BOTTOM_BAR_H - 20)
	shop_btn.pressed.connect(_on_shop_btn_pressed)
	shop_btn.add_theme_color_override("font_color", C_GEM)
	shop_btn.add_theme_font_size_override("font_size", 18)
	cl.add_child(shop_btn)

# ── Menu modal overlay ──────────────────────────────────────────────────────
func _build_menu_overlay() -> void:
	_menu_overlay         = CanvasLayer.new()
	_menu_overlay.name    = "MenuOverlay"
	_menu_overlay.layer   = 30
	_menu_overlay.visible = false
	add_child(_menu_overlay)

	# Dim background (tap to close)
	var dim      := ColorRect.new()
	dim.color     = Color(0, 0, 0, 0.72)
	dim.position  = Vector2.ZERO
	dim.size      = Vector2(SCREEN_W, SCREEN_H)
	_menu_overlay.add_child(dim)

	var dim_btn      := Button.new()
	dim_btn.flat      = true
	dim_btn.position  = Vector2.ZERO
	dim_btn.size      = Vector2(SCREEN_W, SCREEN_H)
	dim_btn.pressed.connect(_on_menu_close)
	_menu_overlay.add_child(dim_btn)

	# Card
	var card_w := 680
	var card_h := 640
	var card_x := (SCREEN_W - card_w) / 2
	var card_y := (SCREEN_H - card_h) / 2

	var card      := ColorRect.new()
	card.color     = C_PANEL
	card.position  = Vector2(card_x, card_y)
	card.size      = Vector2(card_w, card_h)
	_menu_overlay.add_child(card)

	var card_top      := ColorRect.new()
	card_top.color     = C_ACCENT
	card_top.position  = Vector2(card_x, card_y)
	card_top.size      = Vector2(card_w, 4)
	_menu_overlay.add_child(card_top)

	# Menu items: 2 columns × 4 rows
	var items: Array = [
		["MINE",     C_TIMBER,   _on_menu_mine],
		["BUILD",    C_ACCENT,   _on_menu_build],
		["CRAFT",    C_LUMBER,   _on_menu_craft],
		["SELL",     C_GOLD,     _on_menu_sell],
		["CREW",     C_GREEN,    _on_menu_crew],
		["SKYLINE",  C_STONE,    _on_menu_skyline],
		["UPGRADES", C_XP,       _on_menu_upgrades],
	]
	var cols       := 2
	var rows       := 4
	var pad        := 16
	var item_w     := (card_w - pad * (cols + 1)) / cols
	var item_h     := (card_h - 60 - pad * (rows + 1)) / rows

	for i in items.size():
		var col     := i % cols
		var row     := i / cols
		var item_x  := card_x + pad + col * (item_w + pad)
		var item_y  := card_y + 50 + pad + row * (item_h + pad)
		var label:  String   = items[i][0]
		var accent: Color    = items[i][1]
		var cb:     Callable = items[i][2]

		var ibg      := ColorRect.new()
		ibg.color     = C_CARD
		ibg.position  = Vector2(item_x, item_y)
		ibg.size      = Vector2(item_w, item_h)
		_menu_overlay.add_child(ibg)

		var ibar      := ColorRect.new()
		ibar.color     = accent
		ibar.position  = Vector2(item_x, item_y)
		ibar.size      = Vector2(item_w, 4)
		_menu_overlay.add_child(ibar)

		var ibtn      := Button.new()
		ibtn.flat      = true
		ibtn.text      = label
		ibtn.position  = Vector2(item_x, item_y)
		ibtn.size      = Vector2(item_w, item_h)
		ibtn.pressed.connect(cb)
		ibtn.add_theme_color_override("font_color", accent)
		ibtn.add_theme_font_size_override("font_size", 17)
		_menu_overlay.add_child(ibtn)

# ── Build panel ─────────────────────────────────────────────────────────────
func _build_build_panel() -> void:
	_build_panel         = CanvasLayer.new()
	_build_panel.name    = "BuildPanel"
	_build_panel.layer   = 20
	_build_panel.visible = false
	add_child(_build_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_build_panel.add_child(bg)

	# Header
	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_build_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_ACCENT
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_build_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "BUILD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_build_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_build_close)
	_build_panel.add_child(close_btn)

	# Stage name label
	_lbl_build_stage                      = Label.new()
	_lbl_build_stage.text                 = ""
	_lbl_build_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_build_stage.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_lbl_build_stage.position             = Vector2(16, 84)
	_lbl_build_stage.size                 = Vector2(SCREEN_W - 32, 56)
	_lbl_build_stage.add_theme_color_override("font_color", C_TEXT)
	_build_panel.add_child(_lbl_build_stage)

	# Building sprite (stage art)
	_building_sprite          = Sprite2D.new()
	_building_sprite.name     = "BuildingSprite"
	_building_sprite.centered = true
	_building_sprite.position = Vector2(360, 240)
	_building_sprite.scale    = Vector2(1.0, 1.0)
	_building_sprite.visible  = false
	_build_panel.add_child(_building_sprite)

	# Build power display
	_lbl_build_bp                      = Label.new()
	_lbl_build_bp.text                 = "Build Power: 0"
	_lbl_build_bp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_build_bp.position             = Vector2(0, 382)
	_lbl_build_bp.size                 = Vector2(SCREEN_W, 32)
	_lbl_build_bp.add_theme_color_override("font_color", C_ACCENT)
	_build_panel.add_child(_lbl_build_bp)

	var divider      := ColorRect.new()
	divider.color     = C_BORDER
	divider.position  = Vector2(20, 420)
	divider.size      = Vector2(SCREEN_W - 40, 2)
	_build_panel.add_child(divider)

	# ── Requirements section (stage NOT started) ────────────────────────────
	var req_title     := Label.new()
	req_title.text     = "Required Materials"
	req_title.position = Vector2(24, 432)
	req_title.size     = Vector2(400, 30)
	req_title.add_theme_color_override("font_color", C_DIM)
	_build_panel.add_child(req_title)

	_build_reqs_box          = VBoxContainer.new()
	_build_reqs_box.position = Vector2(20, 468)
	_build_reqs_box.size     = Vector2(SCREEN_W - 40, 300)
	_build_panel.add_child(_build_reqs_box)

	_btn_start_stage          = Button.new()
	_btn_start_stage.text     = "Start Stage  (consumes materials)"
	_btn_start_stage.position = Vector2(20, 780)
	_btn_start_stage.size     = Vector2(SCREEN_W - 40, 66)
	_btn_start_stage.pressed.connect(_on_start_stage_pressed)
	_btn_start_stage.add_theme_color_override("font_color", C_GREEN)
	_build_panel.add_child(_btn_start_stage)

	_lbl_cant_start                      = Label.new()
	_lbl_cant_start.text                 = "Not enough materials."
	_lbl_cant_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cant_start.position             = Vector2(20, 858)
	_lbl_cant_start.size                 = Vector2(SCREEN_W - 40, 32)
	_lbl_cant_start.add_theme_color_override("font_color", C_RED)
	_lbl_cant_start.visible              = false
	_build_panel.add_child(_lbl_cant_start)

	# ── Progress section (stage IS started) ────────────────────────────────
	_build_prog_bg         = ColorRect.new()
	_build_prog_bg.color   = Color(0.10, 0.12, 0.18)
	_build_prog_bg.position = Vector2(20, 432)
	_build_prog_bg.size     = Vector2(SCREEN_W - 40, 26)
	_build_prog_bg.visible  = false
	_build_panel.add_child(_build_prog_bg)

	_build_prog_fill         = ColorRect.new()
	_build_prog_fill.color   = C_ACCENT
	_build_prog_fill.position = Vector2(20, 432)
	_build_prog_fill.size     = Vector2(0, 26)
	_build_prog_fill.visible  = false
	_build_panel.add_child(_build_prog_fill)

	_lbl_build_pct                      = Label.new()
	_lbl_build_pct.text                 = "0%"
	_lbl_build_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_build_pct.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_lbl_build_pct.position             = Vector2(20, 432)
	_lbl_build_pct.size                 = Vector2(SCREEN_W - 40, 26)
	_lbl_build_pct.add_theme_font_size_override("font_size", 13)
	_lbl_build_pct.add_theme_color_override("font_color", C_TEXT)
	_lbl_build_pct.visible              = false
	_build_panel.add_child(_lbl_build_pct)

	# Big "TAP TO BUILD" area
	var tap_bg      := ColorRect.new()
	tap_bg.color     = C_ACCENT.darkened(0.72)
	tap_bg.name      = "TapBuildBg"
	tap_bg.position  = Vector2(20, 474)
	tap_bg.size      = Vector2(SCREEN_W - 40, 500)
	tap_bg.visible   = false
	_build_panel.add_child(tap_bg)

	var tap_bar      := ColorRect.new()
	tap_bar.color     = C_ACCENT
	tap_bar.name      = "TapBuildBar"
	tap_bar.position  = Vector2(20, 474)
	tap_bar.size      = Vector2(SCREEN_W - 40, 4)
	tap_bar.visible   = false
	_build_panel.add_child(tap_bar)

	_btn_tap_build          = Button.new()
	_btn_tap_build.flat      = true
	_btn_tap_build.text      = "TAP TO BUILD"
	_btn_tap_build.position  = Vector2(20, 474)
	_btn_tap_build.size      = Vector2(SCREEN_W - 40, 500)
	_btn_tap_build.pressed.connect(_on_tap_build)
	_btn_tap_build.add_theme_color_override("font_color", C_ACCENT)
	_btn_tap_build.add_theme_font_size_override("font_size", 28)
	_btn_tap_build.visible   = false
	_build_panel.add_child(_btn_tap_build)

	_lbl_build_feedback                      = Label.new()
	_lbl_build_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_build_feedback.position             = Vector2(20, 588)
	_lbl_build_feedback.size                 = Vector2(SCREEN_W - 40, 40)
	_lbl_build_feedback.modulate.a           = 0.0
	_lbl_build_feedback.add_theme_color_override("font_color", C_ACCENT)
	_build_panel.add_child(_lbl_build_feedback)

# ── Crew overlay panel ──────────────────────────────────────────────────────
func _build_crew_panel() -> void:
	_crew_panel         = CanvasLayer.new()
	_crew_panel.name    = "CrewPanel"
	_crew_panel.layer   = 20
	_crew_panel.visible = false
	add_child(_crew_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_crew_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_crew_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_ACCENT
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_crew_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "CREW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_crew_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_crew_close)
	_crew_panel.add_child(close_btn)

	_lbl_crew_bp                      = Label.new()
	_lbl_crew_bp.text                  = "Build Power: 0"
	_lbl_crew_bp.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_crew_bp.position              = Vector2(0, 88)
	_lbl_crew_bp.size                  = Vector2(SCREEN_W, 36)
	_lbl_crew_bp.add_theme_color_override("font_color", C_ACCENT)
	_crew_panel.add_child(_lbl_crew_bp)

	var templates := BuildDatabase.get_hireable_crew()
	for i in templates.size():
		_build_crew_card(templates[i], i)

func _build_crew_card(template: CrewMemberResource, idx: int) -> void:
	var card_y    := 135 + idx * 210
	var card_h    := 192
	var mat_color := _mat_color(template.material_type)

	var bg      := ColorRect.new()
	bg.color     = C_CARD
	bg.position  = Vector2(14, card_y)
	bg.size      = Vector2(SCREEN_W - 28, card_h)
	_crew_panel.add_child(bg)

	var left_bar      := ColorRect.new()
	left_bar.color     = mat_color
	left_bar.position  = Vector2(14, card_y)
	left_bar.size      = Vector2(5, card_h)
	_crew_panel.add_child(left_bar)

	# Avatar
	var av_bg      := ColorRect.new()
	av_bg.color     = mat_color.darkened(0.55)
	av_bg.position  = Vector2(28, card_y + 14)
	av_bg.size      = Vector2(58, 58)
	_crew_panel.add_child(av_bg)

	var av_lbl     := Label.new()
	av_lbl.text     = template.display_name.left(1)
	av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	av_lbl.position = Vector2(28, card_y + 14)
	av_lbl.size     = Vector2(58, 58)
	av_lbl.add_theme_font_size_override("font_size", 26)
	av_lbl.add_theme_color_override("font_color", mat_color)
	_crew_panel.add_child(av_lbl)

	# Name
	var name_lbl     := Label.new()
	name_lbl.text     = template.display_name
	name_lbl.position = Vector2(100, card_y + 12)
	name_lbl.size     = Vector2(300, 32)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	_crew_panel.add_child(name_lbl)

	# Location badge (top-right)
	var loc_data := BuildDatabase.get_location(template.location_id)
	var loc_name: String = loc_data.get("display_name", template.location_id)
	var loc_lbl     := Label.new()
	loc_lbl.text     = loc_name
	loc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loc_lbl.position = Vector2(420, card_y + 14)
	loc_lbl.size     = Vector2(258, 26)
	loc_lbl.add_theme_font_size_override("font_size", 12)
	loc_lbl.add_theme_color_override("font_color", mat_color)
	_crew_panel.add_child(loc_lbl)

	# Rate label
	var rate_lbl     := Label.new()
	rate_lbl.text     = "%.1f %s/s at Lv.1" \
		% [template.base_speed_bonus, template.material_type.capitalize()]
	rate_lbl.position = Vector2(100, card_y + 50)
	rate_lbl.size     = Vector2(578, 28)
	rate_lbl.add_theme_color_override("font_color", C_DIM)
	_crew_panel.add_child(rate_lbl)
	_crew_rate_labels.append(rate_lbl)

	# Level label
	var lvl_lbl     := Label.new()
	lvl_lbl.text     = "Not hired"
	lvl_lbl.position = Vector2(100, card_y + 90)
	lvl_lbl.size     = Vector2(220, 34)
	lvl_lbl.add_theme_color_override("font_color", C_DIM)
	_crew_panel.add_child(lvl_lbl)
	_crew_level_labels.append(lvl_lbl)

	# Hire button
	var hire_btn     := Button.new()
	hire_btn.text     = "Hire  (%d cash)" % template.hire_cost
	hire_btn.position = Vector2(326, card_y + 88)
	hire_btn.size     = Vector2(350, 50)
	hire_btn.pressed.connect(_on_hire_pressed.bind(template.id))
	hire_btn.add_theme_color_override("font_color", C_GREEN)
	_crew_panel.add_child(hire_btn)
	_crew_hire_btns.append(hire_btn)

	# Level-up button
	var lvlup_btn     := Button.new()
	lvlup_btn.text     = "Upgrade"
	lvlup_btn.position = Vector2(326, card_y + 88)
	lvlup_btn.size     = Vector2(350, 50)
	lvlup_btn.visible  = false
	lvlup_btn.pressed.connect(_on_levelup_pressed.bind(template.id))
	lvlup_btn.add_theme_color_override("font_color", C_GOLD)
	_crew_panel.add_child(lvlup_btn)
	_crew_levelup_btns.append(lvlup_btn)

	# Progress bar
	var pbg     := ColorRect.new()
	pbg.color    = Color(0.10, 0.10, 0.16)
	pbg.position = Vector2(14, card_y + card_h - 14)
	pbg.size     = Vector2(SCREEN_W - 28, 10)
	_crew_panel.add_child(pbg)

	var pfill     := ColorRect.new()
	pfill.color    = mat_color.darkened(0.2)
	pfill.position = Vector2(14, card_y + card_h - 14)
	pfill.size     = Vector2(0, 10)
	_crew_panel.add_child(pfill)
	_crew_progress_fills.append(pfill)

# ── Craft overlay panel ─────────────────────────────────────────────────────
func _build_craft_panel() -> void:
	_craft_panel         = CanvasLayer.new()
	_craft_panel.name    = "CraftPanel"
	_craft_panel.layer   = 20
	_craft_panel.visible = false
	add_child(_craft_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_craft_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_craft_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_LUMBER
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_craft_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "WORKSHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_craft_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_craft_close)
	_craft_panel.add_child(close_btn)

	# Inventory summary
	var inv_bg      := ColorRect.new()
	inv_bg.color     = C_CARD
	inv_bg.position  = Vector2(14, 88)
	inv_bg.size      = Vector2(SCREEN_W - 28, 68)
	_craft_panel.add_child(inv_bg)

	var inv_title     := Label.new()
	inv_title.text     = "Inventory"
	inv_title.position = Vector2(28, 92)
	inv_title.size     = Vector2(200, 26)
	inv_title.add_theme_color_override("font_color", C_DIM)
	_craft_panel.add_child(inv_title)

	var inv_defs: Array = [
		["Timber",   C_TIMBER  ],
		["Stone",    C_STONE   ],
		["Lumber",   C_LUMBER  ],
		["Concrete", C_CONCRETE],
	]
	var inv_cell_w := float(SCREEN_W - 28) / 4.0
	for i in inv_defs.size():
		var lbl     := Label.new()
		lbl.text     = "%s\n0" % inv_defs[i][0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(14 + i * inv_cell_w, 96)
		lbl.size     = Vector2(inv_cell_w, 56)
		lbl.add_theme_color_override("font_color", inv_defs[i][1] as Color)
		_craft_panel.add_child(lbl)
		_craft_inv_lbls.append(lbl)

	# Recipe cards
	var recipes: Array = [
		["timber", "lumber",   3, C_LUMBER,   "Lumber",   "Timber"],
		["stone",  "concrete", 3, C_CONCRETE, "Concrete", "Stone"],
	]
	for ri in recipes.size():
		var r: Array   = recipes[ri]
		var raw_id:    String = r[0]
		var ref_id:    String = r[1]
		var cost:      int    = r[2]
		var accent:    Color  = r[3]
		var ref_name:  String = r[4]
		var raw_name:  String = r[5]
		var card_y     := 172 + ri * 230

		var card      := ColorRect.new()
		card.color     = C_CARD
		card.position  = Vector2(14, card_y)
		card.size      = Vector2(SCREEN_W - 28, 212)
		_craft_panel.add_child(card)

		var left_bar      := ColorRect.new()
		left_bar.color     = accent
		left_bar.position  = Vector2(14, card_y)
		left_bar.size      = Vector2(5, 212)
		_craft_panel.add_child(left_bar)

		var ref_lbl     := Label.new()
		ref_lbl.text     = ref_name
		ref_lbl.position = Vector2(28, card_y + 12)
		ref_lbl.size     = Vector2(400, 36)
		ref_lbl.add_theme_font_size_override("font_size", 20)
		ref_lbl.add_theme_color_override("font_color", accent)
		_craft_panel.add_child(ref_lbl)

		var recipe_lbl     := Label.new()
		recipe_lbl.text     = "%d %s  →  1 %s" % [cost, raw_name, ref_name]
		recipe_lbl.position = Vector2(28, card_y + 54)
		recipe_lbl.size     = Vector2(SCREEN_W - 56, 28)
		recipe_lbl.add_theme_color_override("font_color", C_DIM)
		_craft_panel.add_child(recipe_lbl)

		var yield_lbl     := Label.new()
		yield_lbl.text     = "Will make: 0"
		yield_lbl.position = Vector2(28, card_y + 90)
		yield_lbl.size     = Vector2(SCREEN_W - 56, 28)
		yield_lbl.add_theme_color_override("font_color", C_TEXT)
		_craft_panel.add_child(yield_lbl)
		_craft_yield_lbls.append(yield_lbl)

		var btn1     := Button.new()
		btn1.text     = "Craft 1"
		btn1.position = Vector2(28, card_y + 130)
		btn1.size     = Vector2(200, 62)
		btn1.pressed.connect(_on_craft_one.bind(raw_id, ref_id, cost))
		btn1.add_theme_color_override("font_color", accent)
		_craft_panel.add_child(btn1)
		_craft1_btns.append(btn1)

		var btn_all     := Button.new()
		btn_all.text     = "Craft All"
		btn_all.position = Vector2(248, card_y + 130)
		btn_all.size     = Vector2(448, 62)
		btn_all.pressed.connect(_on_craft_all.bind(raw_id, ref_id, cost))
		btn_all.add_theme_color_override("font_color", C_GREEN)
		_craft_panel.add_child(btn_all)
		_craftall_btns.append(btn_all)

# ── Wall panel ──────────────────────────────────────────────────────────────
func _build_wall_panel() -> void:
	_wall_panel         = CanvasLayer.new()
	_wall_panel.name    = "WallPanel"
	_wall_panel.layer   = 25
	_wall_panel.visible = false
	add_child(_wall_panel)

	var bg      := ColorRect.new()
	bg.color     = Color(0.05, 0.04, 0.07, 0.98)
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_wall_panel.add_child(bg)

	var card      := ColorRect.new()
	card.color     = C_CARD
	card.position  = Vector2(36, 260)
	card.size      = Vector2(648, 480)
	_wall_panel.add_child(card)

	var top_bar      := ColorRect.new()
	top_bar.color     = C_RED
	top_bar.position  = Vector2(36, 260)
	top_bar.size      = Vector2(648, 5)
	_wall_panel.add_child(top_bar)

	_lbl_wall_title                      = Label.new()
	_lbl_wall_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_wall_title.position             = Vector2(56, 282)
	_lbl_wall_title.size                 = Vector2(608, 58)
	_lbl_wall_title.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_lbl_wall_title.add_theme_font_size_override("font_size", 22)
	_lbl_wall_title.add_theme_color_override("font_color", C_RED)
	_wall_panel.add_child(_lbl_wall_title)

	_lbl_wall_detail                      = Label.new()
	_lbl_wall_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_wall_detail.position             = Vector2(56, 360)
	_lbl_wall_detail.size                 = Vector2(608, 240)
	_lbl_wall_detail.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_lbl_wall_detail.add_theme_color_override("font_color", C_TEXT)
	_wall_panel.add_child(_lbl_wall_detail)

	var keep_btn     := Button.new()
	keep_btn.text     = "Keep Building"
	keep_btn.position = Vector2(56, 660)
	keep_btn.size     = Vector2(280, 60)
	keep_btn.pressed.connect(_on_wall_keep_pressed)
	_wall_panel.add_child(keep_btn)

	var crew_btn     := Button.new()
	crew_btn.text     = "Open Crew ->"
	crew_btn.position = Vector2(384, 660)
	crew_btn.size     = Vector2(280, 60)
	crew_btn.add_theme_color_override("font_color", C_GREEN)
	crew_btn.pressed.connect(_on_wall_crew_pressed)
	_wall_panel.add_child(crew_btn)

# ── Skyline overlay panel ───────────────────────────────────────────────────
func _build_skyline_panel() -> void:
	_skyline_panel         = CanvasLayer.new()
	_skyline_panel.name    = "SkylinePanel"
	_skyline_panel.layer   = 20
	_skyline_panel.visible = false
	add_child(_skyline_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_skyline_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_skyline_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_GOLD
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_skyline_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "SKYLINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_skyline_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_skyline_close)
	_skyline_panel.add_child(close_btn)

	var sub      := Label.new()
	sub.text      = "All completed buildings:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position  = Vector2(0, 86)
	sub.size      = Vector2(SCREEN_W, 34)
	sub.add_theme_color_override("font_color", C_DIM)
	_skyline_panel.add_child(sub)

	var scroll      := ScrollContainer.new()
	scroll.position  = Vector2(0, 128)
	scroll.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H - 128)
	_skyline_panel.add_child(scroll)

	_skyline_list_box          = VBoxContainer.new()
	_skyline_list_box.position = Vector2.ZERO
	_skyline_list_box.size     = Vector2(SCREEN_W, 0)
	scroll.add_child(_skyline_list_box)

# ── Sell overlay panel ─────────────────────────────────────────────────────
## Sell prices (cash per unit)
const SELL_PRICES: Dictionary = {
	"timber":   1,
	"stone":    1,
	"lumber":   4,
	"concrete": 4,
}

func _build_sell_panel() -> void:
	_sell_panel         = CanvasLayer.new()
	_sell_panel.name    = "SellPanel"
	_sell_panel.layer   = 20
	_sell_panel.visible = false
	add_child(_sell_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_sell_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_sell_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_GOLD
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_sell_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "SELL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_sell_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_sell_close)
	_sell_panel.add_child(close_btn)

	var sub      := Label.new()
	sub.text      = "Raw materials sell for less than refined — craft first for more cash."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	sub.position  = Vector2(20, 84)
	sub.size      = Vector2(SCREEN_W - 40, 40)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_DIM)
	_sell_panel.add_child(sub)

	# One card per sellable material
	var mat_defs: Array = [
		["timber",   "Timber",   C_TIMBER  ],
		["stone",    "Stone",    C_STONE   ],
		["lumber",   "Lumber",   C_LUMBER  ],
		["concrete", "Concrete", C_CONCRETE],
	]

	for i in mat_defs.size():
		var mid: String   = mat_defs[i][0]
		var mname: String = mat_defs[i][1]
		var accent: Color = mat_defs[i][2]
		var price: int    = int(SELL_PRICES.get(mid, 1))
		var card_y        := 136 + i * 220

		var card      := ColorRect.new()
		card.color     = C_CARD
		card.position  = Vector2(14, card_y)
		card.size      = Vector2(SCREEN_W - 28, 204)
		_sell_panel.add_child(card)

		var left_bar      := ColorRect.new()
		left_bar.color     = accent
		left_bar.position  = Vector2(14, card_y)
		left_bar.size      = Vector2(5, 204)
		_sell_panel.add_child(left_bar)

		# Material name + price badge
		var name_lbl     := Label.new()
		name_lbl.text     = mname
		name_lbl.position = Vector2(28, card_y + 12)
		name_lbl.size     = Vector2(360, 36)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", accent)
		_sell_panel.add_child(name_lbl)

		var price_lbl     := Label.new()
		price_lbl.text     = "$ %d / unit" % price
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.position = Vector2(400, card_y + 16)
		price_lbl.size     = Vector2(292, 28)
		price_lbl.add_theme_color_override("font_color", C_GOLD)
		_sell_panel.add_child(price_lbl)

		# Stock + earnings preview
		var inv_lbl     := Label.new()
		inv_lbl.text     = "Have: 0"
		inv_lbl.position = Vector2(28, card_y + 54)
		inv_lbl.size     = Vector2(300, 28)
		inv_lbl.add_theme_color_override("font_color", C_DIM)
		_sell_panel.add_child(inv_lbl)
		_sell_inv_lbls.append(inv_lbl)

		var earn_lbl     := Label.new()
		earn_lbl.text     = "= $ 0"
		earn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		earn_lbl.position = Vector2(400, card_y + 54)
		earn_lbl.size     = Vector2(292, 28)
		earn_lbl.add_theme_color_override("font_color", C_GOLD)
		_sell_panel.add_child(earn_lbl)
		_sell_earn_lbls.append(earn_lbl)

		# Sell buttons
		var btn_defs: Array = [["Sell 1", 1], ["Sell 10", 10], ["Sell All", -1]]
		for bi in btn_defs.size():
			var btn_label: String = btn_defs[bi][0]
			var qty: int          = int(btn_defs[bi][1])
			var btn      := Button.new()
			btn.text      = btn_label
			btn.position  = Vector2(14 + bi * 232, card_y + 98)
			btn.size      = Vector2(220, 88)
			btn.pressed.connect(_on_sell_pressed.bind(mid, qty))
			btn.add_theme_color_override("font_color", C_GOLD)
			_sell_panel.add_child(btn)

# ── Upgrades overlay panel ─────────────────────────────────────────────────
func _build_upgrades_panel() -> void:
	_upgrades_panel         = CanvasLayer.new()
	_upgrades_panel.name    = "UpgradesPanel"
	_upgrades_panel.layer   = 20
	_upgrades_panel.visible = false
	add_child(_upgrades_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_upgrades_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_upgrades_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_XP
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_upgrades_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_upgrades_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_upgrades_close)
	_upgrades_panel.add_child(close_btn)

	var sub      := Label.new()
	sub.text      = "Unlocked by player level  ·  costs multiply ×2 per level"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position  = Vector2(0, 84)
	sub.size      = Vector2(SCREEN_W, 28)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_DIM)
	_upgrades_panel.add_child(sub)

	# Scrollable area for cards
	var scroll      := ScrollContainer.new()
	scroll.position  = Vector2(0, 116)
	scroll.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H - 116)
	_upgrades_panel.add_child(scroll)

	var list      := VBoxContainer.new()
	list.name      = "UpgradeList"
	list.position  = Vector2.ZERO
	list.size      = Vector2(SCREEN_W, 0)
	scroll.add_child(list)

	# Build one card per upgrade definition
	var all_upgrades := UpgradeDatabase.get_all()
	for i in all_upgrades.size():
		var u: Dictionary = all_upgrades[i]
		var card := _build_upgrade_card(list, u)
		_upgrade_cards.append(card)

func _build_upgrade_card(parent: VBoxContainer, u: Dictionary) -> Dictionary:
	var accent := C_XP

	var outer      := ColorRect.new()
	outer.color     = C_CARD
	outer.custom_minimum_size = Vector2(SCREEN_W, 130)
	parent.add_child(outer)

	var left_bar      := ColorRect.new()
	left_bar.color     = accent
	left_bar.position  = Vector2(0, 0)
	left_bar.size      = Vector2(5, 130)
	outer.add_child(left_bar)

	var lock_stripe      := ColorRect.new()
	lock_stripe.name      = "LockStripe"
	lock_stripe.color     = Color(0, 0, 0, 0.50)
	lock_stripe.position  = Vector2(0, 0)
	lock_stripe.size      = Vector2(SCREEN_W, 130)
	lock_stripe.visible   = false
	outer.add_child(lock_stripe)

	var name_lbl     := Label.new()
	name_lbl.text     = u["name"]
	name_lbl.position = Vector2(18, 10)
	name_lbl.size     = Vector2(460, 34)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", accent)
	outer.add_child(name_lbl)

	var unlock_lbl     := Label.new()
	unlock_lbl.text     = "Lv.%d" % int(u["unlock_level"])
	unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unlock_lbl.position = Vector2(488, 10)
	unlock_lbl.size     = Vector2(220, 28)
	unlock_lbl.add_theme_font_size_override("font_size", 13)
	unlock_lbl.add_theme_color_override("font_color", C_DIM)
	outer.add_child(unlock_lbl)

	var desc_lbl     := Label.new()
	desc_lbl.text     = u["description"]
	desc_lbl.position = Vector2(18, 46)
	desc_lbl.size     = Vector2(SCREEN_W - 36, 28)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", C_DIM)
	outer.add_child(desc_lbl)

	var level_lbl     := Label.new()
	level_lbl.text     = "Level 0 / %d" % int(u["max_level"])
	level_lbl.position = Vector2(18, 76)
	level_lbl.size     = Vector2(300, 28)
	level_lbl.add_theme_color_override("font_color", C_TEXT)
	outer.add_child(level_lbl)

	var cost_lbl     := Label.new()
	cost_lbl.text     = ""
	cost_lbl.position = Vector2(18, 100)
	cost_lbl.size     = Vector2(440, 26)
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", C_GOLD)
	outer.add_child(cost_lbl)

	var btn     := Button.new()
	btn.text     = "Buy"
	btn.position = Vector2(530, 70)
	btn.size     = Vector2(168, 52)
	btn.add_theme_color_override("font_color", accent)
	btn.pressed.connect(_on_upgrade_buy.bind(u["id"]))
	outer.add_child(btn)

	# Spacer line between cards
	var sep      := ColorRect.new()
	sep.color     = C_BORDER
	sep.custom_minimum_size = Vector2(SCREEN_W, 2)
	parent.add_child(sep)

	return {
		"id":         u["id"],
		"outer":      outer,
		"lock":       lock_stripe,
		"name_lbl":   name_lbl,
		"level_lbl":  level_lbl,
		"cost_lbl":   cost_lbl,
		"btn":        btn,
	}

# ── Shop overlay panel ─────────────────────────────────────────────────────
func _build_shop_panel() -> void:
	_shop_panel         = CanvasLayer.new()
	_shop_panel.name    = "ShopPanel"
	_shop_panel.layer   = 20
	_shop_panel.visible = false
	add_child(_shop_panel)

	var bg      := ColorRect.new()
	bg.color     = C_PANEL
	bg.position  = Vector2.ZERO
	bg.size      = Vector2(SCREEN_W, SCREEN_H - BOTTOM_BAR_H)
	_shop_panel.add_child(bg)

	var header      := ColorRect.new()
	header.color     = Color(0.10, 0.11, 0.17)
	header.position  = Vector2.ZERO
	header.size      = Vector2(SCREEN_W, 78)
	_shop_panel.add_child(header)

	var h_border      := ColorRect.new()
	h_border.color     = C_GEM
	h_border.position  = Vector2(0, 76)
	h_border.size      = Vector2(SCREEN_W, 3)
	_shop_panel.add_child(h_border)

	var title      := Label.new()
	title.text      = "SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.position  = Vector2(60, 0)
	title.size      = Vector2(SCREEN_W - 120, 78)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_TEXT)
	_shop_panel.add_child(title)

	var close_btn     := Button.new()
	close_btn.flat     = true
	close_btn.text     = "X"
	close_btn.position = Vector2(SCREEN_W - 70, 14)
	close_btn.size     = Vector2(52, 52)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.pressed.connect(_on_shop_close)
	_shop_panel.add_child(close_btn)

	_lbl_shop_gems                      = Label.new()
	_lbl_shop_gems.text                  = "◆ 0  Gems"
	_lbl_shop_gems.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_shop_gems.position              = Vector2(0, 88)
	_lbl_shop_gems.size                  = Vector2(SCREEN_W, 40)
	_lbl_shop_gems.add_theme_color_override("font_color", C_GEM)
	_shop_panel.add_child(_lbl_shop_gems)

	var policy      := Label.new()
	policy.text      = "Gems are earned through play.\nEvery item here is optional and never required to progress."
	policy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	policy.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	policy.position  = Vector2(40, 138)
	policy.size      = Vector2(SCREEN_W - 80, 60)
	policy.add_theme_color_override("font_color", C_DIM)
	_shop_panel.add_child(policy)

	var card      := ColorRect.new()
	card.color     = C_CARD
	card.position  = Vector2(20, 218)
	card.size      = Vector2(SCREEN_W - 40, 200)
	_shop_panel.add_child(card)

	var card_top      := ColorRect.new()
	card_top.color     = C_GEM
	card_top.position  = Vector2(20, 218)
	card_top.size      = Vector2(SCREEN_W - 40, 4)
	_shop_panel.add_child(card_top)

	var item_name     := Label.new()
	item_name.text     = "Instant Stage Skip"
	item_name.position = Vector2(36, 230)
	item_name.size     = Vector2(SCREEN_W - 72, 38)
	item_name.add_theme_font_size_override("font_size", 18)
	item_name.add_theme_color_override("font_color", C_TEXT)
	_shop_panel.add_child(item_name)

	var item_desc     := Label.new()
	item_desc.text     = "Complete the current build stage instantly.\nMaterials are not consumed."
	item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_desc.position = Vector2(36, 274)
	item_desc.size     = Vector2(SCREEN_W - 72, 60)
	item_desc.add_theme_color_override("font_color", C_DIM)
	_shop_panel.add_child(item_desc)

	_btn_stage_skip          = Button.new()
	_btn_stage_skip.text     = "Buy  (10 Gems)"
	_btn_stage_skip.position = Vector2(36, 346)
	_btn_stage_skip.size     = Vector2(300, 58)
	_btn_stage_skip.pressed.connect(_on_stage_skip_pressed)
	_btn_stage_skip.add_theme_color_override("font_color", C_GEM)
	_shop_panel.add_child(_btn_stage_skip)

	var ad_card      := ColorRect.new()
	ad_card.color     = Color(0.09, 0.12, 0.10)
	ad_card.position  = Vector2(20, 440)
	ad_card.size      = Vector2(SCREEN_W - 40, 120)
	_shop_panel.add_child(ad_card)

	var ad_lbl      := Label.new()
	ad_lbl.text      = "Watch an optional ad for bonus Gems\n(Coming soon — always player-initiated, never forced)"
	ad_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	ad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_lbl.position  = Vector2(36, 452)
	ad_lbl.size      = Vector2(SCREEN_W - 72, 100)
	ad_lbl.add_theme_color_override("font_color", C_DIM)
	_shop_panel.add_child(ad_lbl)

# ══════════════════════════════════════════════════════════════════════════
# Panel open / close
# ══════════════════════════════════════════════════════════════════════════

func _close_all_panels() -> void:
	_build_panel.visible    = false
	_crew_panel.visible     = false
	_craft_panel.visible    = false
	_sell_panel.visible     = false
	_wall_panel.visible     = false
	_skyline_panel.visible  = false
	_upgrades_panel.visible = false
	_shop_panel.visible     = false
	_menu_overlay.visible   = false

func _on_menu_btn_pressed() -> void:
	var opening := not _menu_overlay.visible
	_close_all_panels()
	_menu_overlay.visible = opening

func _on_menu_close() -> void:
	_menu_overlay.visible = false

func _on_menu_mine() -> void:
	_close_all_panels()

func _on_menu_build() -> void:
	_close_all_panels()
	_build_panel.visible = true
	_update_build_panel()

func _on_menu_craft() -> void:
	_close_all_panels()
	_craft_panel.visible = true
	_update_craft_panel()

func _on_menu_crew() -> void:
	_close_all_panels()
	_crew_panel.visible = true
	_update_crew_panel()

func _on_menu_skyline() -> void:
	_close_all_panels()
	_skyline_panel.visible = true
	_update_skyline_panel()

func _on_menu_sell() -> void:
	_close_all_panels()
	_sell_panel.visible = true
	_update_sell_panel()

func _on_sell_close() -> void:
	_sell_panel.visible = false

func _on_sell_pressed(mat_id: String, qty: int) -> void:
	var have: int  = GameState.materials.get(mat_id, 0)
	if have <= 0:
		return
	var sell_qty: int = have if qty == -1 else mini(qty, have)
	var price: int    = int(SELL_PRICES.get(mat_id, 1))
	var earned: int   = sell_qty * price
	GameState.materials[mat_id] = have - sell_qty
	GameState.cash              += earned
	_update_sell_panel()
	_update_hud()
	_flash_feedback("Sold %d %s  +$ %d" % [sell_qty, mat_id.capitalize(), earned])

func _update_sell_panel() -> void:
	var mats: Array[String] = ["timber", "stone", "lumber", "concrete"]
	for i in mats.size():
		var have: int  = GameState.materials.get(mats[i], 0)
		var price: int = int(SELL_PRICES.get(mats[i], 1))
		_sell_inv_lbls[i].text  = "Have: %d" % have
		_sell_earn_lbls[i].text = "= $ %d" % (have * price)

func _on_menu_upgrades() -> void:
	_close_all_panels()
	_upgrades_panel.visible = true
	_update_upgrades_panel()

func _on_upgrades_close() -> void:
	_upgrades_panel.visible = false

func _on_upgrade_buy(upgrade_id: String) -> void:
	var u := UpgradeDatabase.get_upgrade(upgrade_id)
	if u.is_empty():
		return
	var cur_level: int = int(GameState.upgrades.get(upgrade_id, 0))
	if cur_level >= int(u["max_level"]):
		return
	if int(u["unlock_level"]) > GameState.player_level:
		return
	var cost := UpgradeDatabase.get_cost(upgrade_id, cur_level)
	# Check and deduct — cash handled separately from materials
	for mat: String in cost:
		var needed: int = int(cost[mat])
		if mat == "cash":
			if GameState.cash < needed:
				return
		else:
			if GameState.materials.get(mat, 0) < needed:
				return
	for mat: String in cost:
		var needed: int = int(cost[mat])
		if mat == "cash":
			GameState.cash -= needed
		else:
			GameState.materials[mat] = GameState.materials.get(mat, 0) - needed
	GameState.upgrades[upgrade_id] = cur_level + 1
	_update_upgrades_panel()
	_update_hud()
	_flash_feedback("%s  Lv.%d!" % [u["name"], cur_level + 1])

func _update_upgrades_panel() -> void:
	var all_upgrades := UpgradeDatabase.get_all()
	for i in _upgrade_cards.size():
		if i >= all_upgrades.size():
			break
		var u: Dictionary      = all_upgrades[i]
		var card: Dictionary   = _upgrade_cards[i]
		var uid: String        = u["id"]
		var cur_level: int     = int(GameState.upgrades.get(uid, 0))
		var max_level: int     = int(u["max_level"])
		var unlock_level: int  = int(u["unlock_level"])
		var locked: bool       = GameState.player_level < unlock_level
		var maxed: bool        = cur_level >= max_level

		(card["lock"] as ColorRect).visible = locked
		(card["level_lbl"] as Label).text   = "Level %d / %d" % [cur_level, max_level]

		if maxed:
			(card["cost_lbl"] as Label).text    = "MAXED"
			(card["cost_lbl"] as Label).add_theme_color_override("font_color", C_GREEN)
			(card["btn"] as Button).disabled    = true
			(card["btn"] as Button).text        = "Max"
		elif locked:
			(card["cost_lbl"] as Label).text    = "Unlock at player level %d" % unlock_level
			(card["cost_lbl"] as Label).add_theme_color_override("font_color", C_DIM)
			(card["btn"] as Button).disabled    = true
			(card["btn"] as Button).text        = "Locked"
		else:
			var cost := UpgradeDatabase.get_cost(uid, cur_level)
			var parts := PackedStringArray()
			var can_afford := true
			for mat: String in cost:
				var needed: int = int(cost[mat])
				var have: int
				if mat == "cash":
					have = GameState.cash
				else:
					have = GameState.materials.get(mat, 0)
				if have < needed:
					can_afford = false
				parts.append("%d %s" % [needed, mat.capitalize()])
			(card["cost_lbl"] as Label).text = "Cost: " + "  ·  ".join(parts)
			(card["cost_lbl"] as Label).add_theme_color_override(
				"font_color", C_GOLD if can_afford else C_RED)
			(card["btn"] as Button).disabled = not can_afford
			(card["btn"] as Button).text     = "Buy"

func _on_shop_btn_pressed() -> void:
	var opening := not _shop_panel.visible
	_close_all_panels()
	if opening:
		_shop_panel.visible = true
		_update_shop_panel()

func _on_build_close() -> void:
	_build_panel.visible = false

func _on_crew_close() -> void:
	_crew_panel.visible = false

func _on_craft_close() -> void:
	_craft_panel.visible = false

func _on_skyline_close() -> void:
	_skyline_panel.visible = false

func _on_shop_close() -> void:
	_shop_panel.visible = false

# ══════════════════════════════════════════════════════════════════════════
# Mine screen logic
# ══════════════════════════════════════════════════════════════════════════

func _on_location_btn(loc_id: String) -> void:
	if GameState.active_location_id == loc_id:
		return
	GameState.active_location_id = loc_id
	_update_mine_screen()

func _on_tap_node() -> void:
	var mp := GameState.get_mine_power()
	_apply_node_damage(GameState.active_location_id, float(mp))

func _apply_node_damage(loc_id: String, dmg: float) -> void:
	var node_state: Dictionary = GameState.location_nodes.get(loc_id, {})
	if node_state.is_empty():
		return
	var hp: float = float(node_state.get("hp", 0.0)) - dmg
	if hp <= 0.0:
		_break_node(loc_id)
	else:
		node_state["hp"] = hp
		if loc_id == GameState.active_location_id:
			_update_mine_screen()

func _break_node(loc_id: String) -> void:
	var node_state: Dictionary = GameState.location_nodes.get(loc_id, {})
	var node_id: String = node_state.get("node_id", "")
	var node_data  := BuildDatabase.get_node_data(node_id)
	var loc_data   := BuildDatabase.get_location(loc_id)
	var mat: String = loc_data.get("material", "timber")

	var drop_qty: int = int(node_data.get("drop_qty", 1)) if not node_data.is_empty() else 1
	var xp: float     = float(node_data.get("xp", 2))    if not node_data.is_empty() else 2.0

	# Apply Bonus Drop upgrade
	var total_drop: int = drop_qty + GameState.get_drop_bonus()
	# Apply XP Rush upgrade
	var total_xp: float = xp * GameState.get_xp_mult()

	GameState.materials[mat] = GameState.materials.get(mat, 0) + total_drop
	_gain_xp(total_xp)

	if loc_id == GameState.active_location_id:
		_flash_feedback("+%d %s   +%.0f XP" % [total_drop, mat.capitalize(), total_xp])

	# Spawn next node (best unlocked for current level)
	var best_node := BuildDatabase.get_active_node(loc_id, GameState.player_level)
	if not best_node.is_empty():
		GameState.location_nodes[loc_id] = {
			"node_id": best_node.get("id", ""),
			"hp":      float(best_node.get("hp", 10))
		}
	if loc_id == GameState.active_location_id:
		_update_mine_screen()
	_update_hud()

func _gain_xp(amount: float) -> void:
	GameState.player_xp += amount
	var needed := BuildDatabase.get_xp_needed(GameState.player_level)
	while GameState.player_xp >= needed:
		GameState.player_xp -= needed
		GameState.player_level += 1
		needed = BuildDatabase.get_xp_needed(GameState.player_level)
		_on_level_up()
	_update_xp_bar()

func _on_level_up() -> void:
	# Upgrade any locations that now have a better node available
	for loc_id: String in GameState.location_nodes.keys():
		var best := BuildDatabase.get_active_node(loc_id, GameState.player_level)
		if best.is_empty():
			continue
		var cur_id: String = GameState.location_nodes[loc_id].get("node_id", "")
		if best.get("id", "") != cur_id:
			GameState.location_nodes[loc_id] = {
				"node_id": best.get("id", ""),
				"hp":      float(best.get("hp", 10))
			}
	_flash_feedback("LEVEL UP!   Lv. %d" % GameState.player_level)
	_update_mine_screen()
	_update_hud()

# ══════════════════════════════════════════════════════════════════════════
# Worker tick
# ══════════════════════════════════════════════════════════════════════════

func _tick_workers(delta: float) -> void:
	if GameState.crew.is_empty():
		return
	for loc_id: String in BuildDatabase.LOCATION_ORDER:
		var rate := _worker_damage_rate(loc_id)
		if rate <= 0.0:
			continue
		_worker_dmg_accum[loc_id] = _worker_dmg_accum.get(loc_id, 0.0) + rate * delta
		if _worker_dmg_accum[loc_id] >= 1.0:
			var dmg := int(_worker_dmg_accum[loc_id])
			_worker_dmg_accum[loc_id] -= float(dmg)
			_apply_node_damage(loc_id, float(dmg))

func _worker_damage_rate(loc_id: String) -> float:
	var rate := 0.0
	for member: Dictionary in GameState.crew:
		if member.get("location_id", "") == loc_id:
			rate += float(member.get("base_speed_bonus", 0.1)) \
				* float(member.get("level", 1)) * 4.0
	# Apply Quick Crew upgrade multiplier
	return rate * GameState.get_worker_rate_mult()

# ══════════════════════════════════════════════════════════════════════════
# Build panel logic
# ══════════════════════════════════════════════════════════════════════════

func _on_start_stage_pressed() -> void:
	var stage := BuildDatabase.get_current_stage()
	if not stage:
		return
	# Check we have all required materials
	for mat: String in stage.required_materials:
		var need: int = int(stage.required_materials[mat])
		if GameState.materials.get(mat, 0) < need:
			return
	# Consume materials upfront
	for mat: String in stage.required_materials:
		var need: int = int(stage.required_materials[mat])
		GameState.materials[mat] = GameState.materials.get(mat, 0) - need
	# Start the stage
	GameState.current_building["stage_started"]  = true
	GameState.current_building["stage_progress"] = 0.0
	_update_build_panel()

func _on_tap_build() -> void:
	if not GameState.current_building.get("stage_started", false):
		return
	var stage := BuildDatabase.get_current_stage()
	if not stage:
		return

	# Build effort = sum of required quantities; each tap contributes build_power / effort
	var effort := 0
	for v in stage.required_materials.values():
		effort += int(v)
	effort = max(effort, 1)
	var bp: int = max(GameState.get_build_power(), 1)
	var inc := (float(bp) / float(effort)) * GameState.get_build_progress_mult()

	var progress: float = float(GameState.current_building.get("stage_progress", 0.0)) + inc
	GameState.current_building["stage_progress"] = minf(progress, 1.0)

	_flash_build_feedback("+%d BP" % bp)

	if progress >= 1.0:
		_complete_stage()
	else:
		_update_build_panel()

func _on_build_panel_opened() -> void:
	_update_build_panel()

# ══════════════════════════════════════════════════════════════════════════
# Stage / building logic
# ══════════════════════════════════════════════════════════════════════════

func _complete_stage() -> void:
	var stage := BuildDatabase.get_current_stage()
	if not stage:
		return

	var reward: int = int(float(25 + stage.stage_order * 10) * GameState.get_stage_cash_mult())
	GameState.cash += reward
	GameState.gems += 1

	var new_idx: int = int(GameState.current_building.get("stage_index", 0)) + 1
	GameState.current_building["stage_index"]   = new_idx
	GameState.current_building["stage_started"]  = false
	GameState.current_building["stage_progress"] = 0.0

	var tier := BuildDatabase.get_tier(GameState.current_building.get("tier_id", "shed"))
	if tier and new_idx >= tier.stages.size():
		_complete_building()
	else:
		_flash_feedback("Stage done!  +%d cash" % reward)
		_update_build_panel()
		_update_hud()

func _complete_building() -> void:
	var tier_id: String = GameState.current_building.get("tier_id", "shed")
	GameState.skyline.append(tier_id)
	GameState.cash += 100
	GameState.gems += 5

	var next_id := BuildDatabase.get_next_tier_id(tier_id)

	if next_id == "":
		# Max tier — loop on current
		GameState.current_building = {
			"tier_id": tier_id, "stage_index": 0,
			"stage_progress": 0.0, "stage_started": false
		}
		_flash_feedback("Building complete!  +100 cash\nSkyline: %d" % GameState.skyline.size())
		_update_build_panel()
		_update_hud()
		return

	var next_tier := BuildDatabase.get_tier(next_id)
	var bp        := GameState.get_build_power()

	if next_tier and bp >= next_tier.build_power_required:
		GameState.current_building = {
			"tier_id": next_id, "stage_index": 0,
			"stage_progress": 0.0, "stage_started": false
		}
		_flash_feedback("Building complete!  +100 cash\nNow: %s" % next_tier.display_name)
		_update_build_panel()
		_update_hud()
	else:
		GameState.current_building = {
			"tier_id": tier_id, "stage_index": 0,
			"stage_progress": 0.0, "stage_started": false
		}
		_flash_feedback("Building complete!  +100 cash")
		_update_build_panel()
		_update_hud()
		_show_wall_panel(next_id)

# ══════════════════════════════════════════════════════════════════════════
# Crew panel interaction
# ══════════════════════════════════════════════════════════════════════════

func _on_hire_pressed(id: String) -> void:
	var template := _crew_template(id)
	if not template or _is_hired(id) or GameState.cash < template.hire_cost:
		return
	GameState.cash -= template.hire_cost
	GameState.crew.append({
		"id":               id,
		"display_name":     template.display_name,
		"level":            1,
		"material_type":    template.material_type,
		"base_speed_bonus": template.base_speed_bonus,
		"location_id":      template.location_id,
	})
	_update_crew_panel()
	_update_hud()

func _on_levelup_pressed(id: String) -> void:
	var member   := _crew_member_dict(id)
	var template := _crew_template(id)
	if member.is_empty() or not template:
		return
	var level: int = int(member.get("level", 1))
	var cost: int  = template.hire_cost * level
	if GameState.cash < cost:
		return
	GameState.cash -= cost
	member["level"] = level + 1
	_update_crew_panel()
	_update_hud()

func _update_crew_panel() -> void:
	_lbl_crew_bp.text = "Build Power: %d" % GameState.get_build_power()
	var templates := BuildDatabase.get_hireable_crew()
	var fill_w    := float(SCREEN_W - 28)
	const MAX_LVL  := 10
	for i in templates.size():
		var tmpl   := templates[i]
		var hired  := _is_hired(tmpl.id)
		var member := _crew_member_dict(tmpl.id)
		var level: int = int(member.get("level", 1)) if hired else 1

		var rate: float = tmpl.base_speed_bonus * float(level)
		_crew_rate_labels[i].text = ("%.2f %s/s  (Lv.%d)" \
			% [rate, tmpl.material_type.capitalize(), level]) if hired else \
			("%.1f %s/s at Lv.1" % [tmpl.base_speed_bonus, tmpl.material_type.capitalize()])

		_crew_level_labels[i].text = ("Level %d" % level) if hired else "Not hired"
		_crew_level_labels[i].add_theme_color_override(
			"font_color", C_TEXT if hired else C_DIM)

		_crew_hire_btns[i].visible   = not hired
		_crew_hire_btns[i].disabled  = GameState.cash < tmpl.hire_cost

		var lvlup_cost: int           = tmpl.hire_cost * level
		_crew_levelup_btns[i].visible  = hired
		_crew_levelup_btns[i].text     = "Upgrade  (%d cash)" % lvlup_cost
		_crew_levelup_btns[i].disabled = GameState.cash < lvlup_cost

		_crew_progress_fills[i].size.x = fill_w * minf(float(level) / float(MAX_LVL), 1.0)

# ── Wall panel interaction ──────────────────────────────────────────────────
func _on_wall_keep_pressed() -> void:
	_wall_panel.visible = false

func _on_wall_crew_pressed() -> void:
	_wall_panel.visible = false
	_crew_panel.visible = true
	_update_crew_panel()

func _show_wall_panel(blocked_tier_id: String) -> void:
	var tier := BuildDatabase.get_tier(blocked_tier_id)
	if not tier:
		return
	var bp       := GameState.get_build_power()
	var required := tier.build_power_required
	_lbl_wall_title.text  = "BUILD POWER TOO LOW"
	_lbl_wall_detail.text = (
		"%s requires Build Power %d\n\nYour current Build Power: %d\n\n" \
		+ "Hire or level up your Crew to break through!"
	) % [tier.display_name, required, bp]
	_wall_panel.visible = true

# ── Skyline panel interaction ───────────────────────────────────────────────
func _update_skyline_panel() -> void:
	for child in _skyline_list_box.get_children():
		child.queue_free()

	if GameState.skyline.is_empty():
		var empty_lbl     := Label.new()
		empty_lbl.text     = "Nothing built yet.\nComplete a building to see it here."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.custom_minimum_size  = Vector2(SCREEN_W, 80)
		empty_lbl.add_theme_color_override("font_color", C_DIM)
		_skyline_list_box.add_child(empty_lbl)
		return

	for entry: String in GameState.skyline:
		var tier := BuildDatabase.get_tier(entry)
		var row  := HBoxContainer.new()
		row.custom_minimum_size = Vector2(SCREEN_W, 72)
		_skyline_list_box.add_child(row)

		var swatch      := ColorRect.new()
		swatch.color     = _tier_colour(entry)
		swatch.custom_minimum_size = Vector2(56, 56)
		row.add_child(swatch)

		var spacer      := Control.new()
		spacer.custom_minimum_size = Vector2(12, 0)
		row.add_child(spacer)

		var lbl      := Label.new()
		lbl.text      = tier.display_name if tier else entry
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size  = Vector2(580, 56)
		lbl.add_theme_color_override("font_color", C_TEXT)
		row.add_child(lbl)

# ── Craft panel interaction ─────────────────────────────────────────────────
func _on_craft_one(raw_id: String, ref_id: String, cost: int) -> void:
	if GameState.materials.get(raw_id, 0) < cost:
		return
	GameState.materials[raw_id] = GameState.materials.get(raw_id, 0) - cost
	# Double Craft chance
	var yield_qty := 2 if randf() < GameState.get_double_craft_chance() else 1
	GameState.materials[ref_id] = GameState.materials.get(ref_id, 0) + yield_qty
	_update_craft_panel()

func _on_craft_all(raw_id: String, ref_id: String, cost: int) -> void:
	var have: int = GameState.materials.get(raw_id, 0)
	var made: int = have / cost
	if made <= 0:
		return
	GameState.materials[raw_id] = have - made * cost
	# Apply Double Craft chance per craft (approximated as average for bulk)
	var double_chance := GameState.get_double_craft_chance()
	var bonus_yield: int = 0
	for _i in made:
		if randf() < double_chance:
			bonus_yield += 1
	made += bonus_yield
	GameState.materials[ref_id] = GameState.materials.get(ref_id, 0) + made
	_update_craft_panel()

func _update_craft_panel() -> void:
	var inv_mats:  Array[String] = ["timber", "stone", "lumber", "concrete"]
	var inv_names: Array[String] = ["Timber", "Stone", "Lumber", "Concrete"]
	for i in inv_mats.size():
		_craft_inv_lbls[i].text = "%s\n%d" % [inv_names[i], GameState.materials.get(inv_mats[i], 0)]

	var raw_ids:   Array[String] = ["timber", "stone"]
	var ref_ids:   Array[String] = ["lumber", "concrete"]
	var costs:     Array[int]    = [3, 3]
	for i in 2:
		var have: int     = GameState.materials.get(raw_ids[i], 0)
		var can_make: int = have / costs[i]
		_craft_yield_lbls[i].text  = "Will make: %d" % can_make
		_craft1_btns[i].disabled   = have < costs[i]
		_craftall_btns[i].disabled = have < costs[i]

# ── Shop panel interaction ──────────────────────────────────────────────────
func _update_shop_panel() -> void:
	_lbl_shop_gems.text      = "◆ %d  Gems" % GameState.gems
	_btn_stage_skip.disabled = GameState.gems < 10 or \
		not GameState.current_building.get("stage_started", false) or \
		BuildDatabase.get_current_stage() == null

func _on_stage_skip_pressed() -> void:
	if not GameState.current_building.get("stage_started", false):
		return
	var stage := BuildDatabase.get_current_stage()
	if not stage or GameState.gems < 10:
		return
	GameState.gems -= 10
	GameState.current_building["stage_progress"] = 1.0
	_shop_panel.visible = false
	_complete_stage()

# ══════════════════════════════════════════════════════════════════════════
# Display refresh
# ══════════════════════════════════════════════════════════════════════════

func _update_display() -> void:
	_update_hud()
	_update_mine_screen()
	if _craft_panel and _craft_panel.visible:
		_update_craft_panel()
	if _build_panel and _build_panel.visible:
		_update_build_panel()

func _update_hud() -> void:
	_lbl_cash.text  = "$ %d"   % GameState.cash
	_lbl_gems.text  = "◆ %d"   % GameState.gems
	_lbl_level.text = "Lv. %d" % GameState.player_level
	_update_xp_bar()

func _update_xp_bar() -> void:
	var needed := BuildDatabase.get_xp_needed(GameState.player_level)
	var pct    := minf(GameState.player_xp / needed, 1.0)
	_xp_bar_fill.size.x = float(SCREEN_W) * pct

func _update_mine_screen() -> void:
	var loc_id   := GameState.active_location_id
	var loc_data := BuildDatabase.get_location(loc_id)
	var mat: String = loc_data.get("material", "timber")
	var accent      := _mat_color(mat)

	# Location bar indicators
	var locs := BuildDatabase.LOCATION_ORDER
	for i in _loc_btns.size():
		var lid: String = locs[i]
		var is_active   := lid == loc_id
		_loc_btns[i].add_theme_color_override("font_color", accent if is_active else C_DIM)
		_loc_indicators[i].visible = is_active

	# Node visual
	var node_state: Dictionary = GameState.location_nodes.get(loc_id, {})
	var node_id: String = node_state.get("node_id", "")
	var cur_hp: float   = float(node_state.get("hp", 10.0))
	var node_data  := BuildDatabase.get_node_data(node_id)
	var max_hp: float   = float(node_data.get("hp", 10)) if not node_data.is_empty() else 10.0
	var node_name: String = node_data.get("name", node_id) if not node_data.is_empty() else node_id

	_node_border.color      = accent.darkened(0.4)
	_node_rect.color        = accent.darkened(0.78)
	_node_accent_bar.color  = accent
	_lbl_node_symbol.text   = mat.left(1).to_upper()
	_lbl_node_symbol.add_theme_color_override("font_color", accent)
	_lbl_node_name.text     = node_name

	# HP bar
	var hp_pct := minf(cur_hp / max_hp, 1.0)
	_hp_bar_fill.size.x  = 620.0 * hp_pct
	_hp_bar_fill.color   = C_GREEN if hp_pct > 0.6 else (C_GOLD if hp_pct > 0.3 else C_RED)
	_lbl_hp_left.text    = "HP"
	_lbl_hp_right.text   = "%.0f / %.0f" % [cur_hp, max_hp]

	# Material count chip
	var mat_count: int = GameState.materials.get(mat, 0)
	var mat_name: String = loc_data.get("display_name", "").split(" ")[0]  # "Lumber" from "Lumber Yard"
	_lbl_mat_count.text = "%s: %d" % [mat.capitalize(), mat_count]
	_lbl_mat_count.add_theme_color_override("font_color", accent)

	# Mine rate info
	var mp     := GameState.get_mine_power()
	var wrate  := _worker_damage_rate(loc_id)
	_lbl_mine_rate.text = "Mine Power: %d  ·  Workers: %.1f HP/s" % [mp, wrate]

func _update_build_panel() -> void:
	var tier := BuildDatabase.get_tier(GameState.current_building.get("tier_id", "shed"))
	var idx:  int = int(GameState.current_building.get("stage_index", 0))
	var stage     := BuildDatabase.get_current_stage()
	var started:  bool = GameState.current_building.get("stage_started", false)
	var progress: float = float(GameState.current_building.get("stage_progress", 0.0))

	# Stage header label
	if tier and stage:
		_lbl_build_stage.text = "%s   Stage %d / %d\n%s" \
			% [tier.display_name, idx + 1, tier.stages.size(), stage.display_name]
	elif tier:
		_lbl_build_stage.text = "%s — All stages complete!" % tier.display_name
	else:
		_lbl_build_stage.text = ""

	# Building sprite (atlas for houses, hidden for shed)
	var art := _get_stage_texture(
		GameState.current_building.get("tier_id", "shed"), idx)
	if art:
		_building_sprite.texture = art
		_building_sprite.visible = true
	else:
		_building_sprite.visible = false

	# Build Power stat
	_lbl_build_bp.text = "Build Power: %d" % GameState.get_build_power()

	if started:
		# Progress view
		_build_reqs_box.visible  = false
		_btn_start_stage.visible = false
		_lbl_cant_start.visible  = false
		_build_prog_bg.visible   = true
		_build_prog_fill.visible = true
		_lbl_build_pct.visible   = true
		_btn_tap_build.visible   = true
		# Show the two sibling nodes (tap bg + accent bar) that are children of the panel
		if _build_panel.get_node_or_null("TapBuildBg"):
			_build_panel.get_node("TapBuildBg").visible   = true
		if _build_panel.get_node_or_null("TapBuildBar"):
			_build_panel.get_node("TapBuildBar").visible  = true

		var prog_w := float(SCREEN_W - 40) * progress
		_build_prog_fill.size.x = prog_w
		_lbl_build_pct.text     = "%d%%" % int(progress * 100)
	else:
		# Requirements view
		_build_reqs_box.visible  = true
		_build_prog_bg.visible   = false
		_build_prog_fill.visible = false
		_lbl_build_pct.visible   = false
		_btn_tap_build.visible   = false
		if _build_panel.get_node_or_null("TapBuildBg"):
			_build_panel.get_node("TapBuildBg").visible  = false
		if _build_panel.get_node_or_null("TapBuildBar"):
			_build_panel.get_node("TapBuildBar").visible = false

		# Rebuild requirement rows
		for child in _build_reqs_box.get_children():
			child.queue_free()

		if stage:
			var can_afford := true
			for mat: String in stage.required_materials:
				var need: int = int(stage.required_materials[mat])
				var have: int = GameState.materials.get(mat, 0)
				if have < need:
					can_afford = false
				var accent := _mat_color(mat)

				var row_lbl     := Label.new()
				var tick        := " ✓" if have >= need else ""
				row_lbl.text     = "%s: %d / %d%s" % [mat.capitalize(), have, need, tick]
				row_lbl.custom_minimum_size = Vector2(SCREEN_W - 40, 36)
				row_lbl.add_theme_color_override("font_color", C_GREEN if have >= need else accent)
				_build_reqs_box.add_child(row_lbl)

				var bar_bg     := ColorRect.new()
				bar_bg.color    = Color(0.10, 0.10, 0.16)
				bar_bg.custom_minimum_size = Vector2(SCREEN_W - 40, 12)
				_build_reqs_box.add_child(bar_bg)

				var bar_fill     := ColorRect.new()
				bar_fill.color    = accent.darkened(0.15)
				var pct           := minf(float(have) / float(need), 1.0)
				bar_fill.custom_minimum_size = Vector2((SCREEN_W - 40) * pct, 12)
				_build_reqs_box.add_child(bar_fill)

				# Spacer
				var spacer     := Control.new()
				spacer.custom_minimum_size = Vector2(0, 8)
				_build_reqs_box.add_child(spacer)

			_btn_start_stage.visible  = can_afford
			_lbl_cant_start.visible   = not can_afford

			# Check build power gate
			if can_afford and tier:
				var bp       := GameState.get_build_power()
				var required := tier.build_power_required
				if bp < required:
					_btn_start_stage.visible = false
					_lbl_cant_start.visible  = true
					_lbl_cant_start.text     = ("Build Power too low: need %d, have %d" \
						% [required, bp])
				else:
					_lbl_cant_start.text = "Not enough materials."
		else:
			_btn_start_stage.visible = false
			_lbl_cant_start.visible  = false

# ══════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════

func _mat_color(mat_id: String) -> Color:
	match mat_id:
		"timber":   return C_TIMBER
		"stone":    return C_STONE
		"lumber":   return C_LUMBER
		"concrete": return C_CONCRETE
		_:          return C_TEXT

func _tier_colour(tier_id: String) -> Color:
	match tier_id:
		"shed":            return Color(0.55, 0.45, 0.28)
		"single_house":    return Color(0.35, 0.55, 0.70)
		"two_story_house": return Color(0.50, 0.35, 0.70)
		_:                 return Color(0.50, 0.50, 0.50)

func _get_stage_texture(tier_id: String, stage_idx: int) -> AtlasTexture:
	match tier_id:
		"single_house":    return _atlas_region(stage_idx, 0)
		"two_story_house": return _atlas_region(stage_idx, 1)
	return null

func _atlas_region(col: int, row: int) -> AtlasTexture:
	if not _house_sheet_tex:
		_house_sheet_tex = load(_HOUSE_SHEET_PATH) as Texture2D
	if not _house_sheet_tex:
		return null
	var atlas        := AtlasTexture.new()
	atlas.atlas       = _house_sheet_tex
	atlas.filter_clip = true
	var w := 284 if col == 4 else _CELL_W
	atlas.region = Rect2(col * _CELL_W, row * _CELL_H, w, _CELL_H)
	return atlas

func _is_hired(id: String) -> bool:
	return not _crew_member_dict(id).is_empty()

func _crew_member_dict(id: String) -> Dictionary:
	for m: Dictionary in GameState.crew:
		if m.get("id", "") == id:
			return m
	return {}

func _crew_template(id: String) -> CrewMemberResource:
	for t in BuildDatabase.get_hireable_crew():
		if t.id == id:
			return t
	return null

func _flash_feedback(msg: String) -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	_lbl_feedback.text = msg
	_feedback_tween    = create_tween()
	_feedback_tween.tween_property(_lbl_feedback, "modulate:a", 1.0, 0.06)
	_feedback_tween.tween_interval(1.5)
	_feedback_tween.tween_property(_lbl_feedback, "modulate:a", 0.0, 0.5)

func _flash_build_feedback(msg: String) -> void:
	if not _lbl_build_feedback:
		return
	var tw := create_tween()
	_lbl_build_feedback.text = msg
	tw.tween_property(_lbl_build_feedback, "modulate:a", 1.0, 0.05)
	tw.tween_interval(0.6)
	tw.tween_property(_lbl_build_feedback, "modulate:a", 0.0, 0.3)

# ── Offline gains summary ───────────────────────────────────────────────────
func _check_offline_summary() -> void:
	var summary := OfflineProgressCalculator.get_offline_summary()
	if summary.gains.is_empty():
		return
	var mins  := int(summary.elapsed / 60.0)
	var parts := PackedStringArray()
	for mat: String in summary.gains:
		parts.append("+%d %s" % [int(summary.gains[mat]), mat.capitalize()])
	_flash_feedback("Welcome back!\n%s\n(%d min offline)" % [", ".join(parts), mins])
	OfflineProgressCalculator.clear_offline_summary()
	_update_display()
