## dev_console.gd — in-game developer console.
## Toggle with tilde (~) key.
## Commands: devmode | enable freecam | disable freecam | disable hud | enable hud | help | clear
extends CanvasLayer

var _open    : bool      = false
var _devmode : bool      = false
var _freecam : Camera3D  = null
var _hud_hidden: bool    = false

@onready var _panel  : PanelContainer = $Panel
@onready var _output : RichTextLabel  = $Panel/VBox/Output
@onready var _input_field  : LineEdit       = $Panel/VBox/Input

func _ready() -> void:
	_panel.visible = false
	_input_field.text_submitted.connect(_on_submitted)

func _input(event: InputEvent) -> void:
	# Tilde / grave accent — toggle console regardless of focus
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_QUOTELEFT:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_input_field.grab_focus()
		_input_field.clear()
	else:
		_input_field.release_focus()
		if is_instance_valid(_freecam):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_submitted(text: String) -> void:
	var cmd := text.strip_edges()
	_log("[color=cyan]> " + cmd + "[/color]")
	_input_field.clear()
	_parse(cmd.to_lower())

# ── Parser ────────────────────────────────────────────────────────────────────

func _parse(cmd: String) -> void:
	var parts : PackedStringArray = cmd.split(" ", false)
	var argc  : int               = parts.size()
	var base  : String            = parts[0] if argc > 0 else ""
	var arg1  : String            = parts[1] if argc > 1 else ""
	var arg2  : String            = parts[2] if argc > 2 else ""

	# ── Simple exact-match commands ───────────────────────────────────────────
	match cmd:
		"devmode":
			_devmode = not _devmode
			if _devmode:
				_log("[color=lime]Developer mode [b]ON[/b][/color]")
			else:
				_log("[color=yellow]Developer mode [b]OFF[/b][/color]")
				if is_instance_valid(_freecam):
					_disable_freecam()
			return

		"enable freecam":
			if not _devmode:
				_log("[color=red]Error:[/color] devmode must be enabled first.")
				return
			_enable_freecam()
			return

		"disable freecam":
			_disable_freecam()
			return

		"disable hud":
			_set_hud_visible(false)
			return

		"enable hud":
			_set_hud_visible(true)
			return

		"toggle hud":
			_set_hud_visible(_hud_hidden)
			return

		# ── NPC spawning (no devmode required) ───────────────────────────────
		"spawn torvald":
			TorvaldManager.force_visit()
			_log("[color=lime]Torvald visit forced.[/color]")
			return

		"spawn gus":
			GusManager.force_visit()
			_log("[color=lime]Gus visit forced.[/color]")
			return

		"spawn doc":
			DocBirtleManager.force_visit()
			_log("[color=lime]Doc Birtle visit forced.[/color]")
			return

		"spawn all":
			TorvaldManager.force_visit()
			GusManager.force_visit()
			DocBirtleManager.force_visit()
			_log("[color=lime]All NPC visits forced.[/color]")
			return

		"spawn thornmouse":
			_spawn_wild_creature("res://creatures/thornmouse.tscn", "Thornmouse")
			return
		"spawn emberowl":
			_spawn_wild_creature("res://creatures/emberowl.tscn", "Emberowl")
			return
		"spawn crystalback":
			_spawn_wild_creature("res://creatures/crystalback.tscn", "Crystalback")
			return
		"spawn glowfox":
			_spawn_wild_creature("res://creatures/glowfox.tscn", "GlowFox")
			return
		"spawn mossdeer":
			_spawn_wild_creature("res://creatures/mossdeer.tscn", "Mossdeer")
			return
		"spawn stoneback":
			_spawn_wild_creature("res://creatures/stoneback.tscn", "Stoneback")
			return

		# ── Time / day ────────────────────────────────────────────────────────
		"skip day":
			if not _devmode: _need_devmode(); return
			SeasonManager.advance_day()
			_log("[color=lime]Day advanced → Day " + str(SeasonManager.current_day) + ", " + SeasonManager.get_season_name() + "[/color]")
			return

		"next season":
			if not _devmode: _need_devmode(); return
			SeasonManager.advance_season()
			_log("[color=lime]Season → [b]" + SeasonManager.get_season_name() + "[/b][/color]")
			return

		# ── Zone unlock ───────────────────────────────────────────────────────
		"unlock zone":
			if not _devmode: _need_devmode(); return
			_unlock_zone_free()
			return

		"unlock all zones":
			if not _devmode: _need_devmode(); return
			while not ZoneManager.is_max_zone():
				_unlock_zone_free()
			return

		# ── Roamer helpers ────────────────────────────────────────────────────
		"fill needs":
			if not _devmode: _need_devmode(); return
			var r := _get_selected_roamer()
			if not r: return
			_fill_roamer_needs(r)
			_log("[color=lime]" + r.roamer_name + "'s needs filled.[/color]")
			return

		"fill all needs":
			if not _devmode: _need_devmode(); return
			for roamer in get_tree().get_nodes_in_group("roamers"):
				_fill_roamer_needs(roamer)
			_log("[color=lime]All roamer needs filled.[/color]")
			return

		"cure burden":
			if not _devmode: _need_devmode(); return
			var r := _get_selected_roamer()
			if not r: return
			if r.burden_state == r.BurdenState.HEALTHY:
				_log("[color=yellow]" + r.roamer_name + " is already healthy.[/color]")
				return
			r.recover_from_burden()
			_log("[color=lime]Burden cleared on " + r.roamer_name + ".[/color]")
			return

		"cure all burdens":
			if not _devmode: _need_devmode(); return
			var count := 0
			for roamer in get_tree().get_nodes_in_group("roamers"):
				if roamer.burden_state != roamer.BurdenState.HEALTHY:
					roamer.recover_from_burden()
					count += 1
			_log("[color=lime]Cured " + str(count) + " burdened roamer(s).[/color]")
			return

		"agitate roamer":
			if not _devmode: _need_devmode(); return
			var r := _get_selected_roamer()
			if not r: return
			r.state = r.State.AGITATED
			_log("[color=yellow]" + r.roamer_name + " agitated.[/color]")
			return

		"burden roamer":
			if not _devmode: _need_devmode(); return
			var r := _get_selected_roamer()
			if not r: return
			for need in r.needs:
				r.needs[need] = 0.05
			_log("[color=yellow]" + r.roamer_name + "'s needs set to 5%% — burden incoming.[/color]")
			return

		"list roamers":
			_list_roamers()
			return

		# ── God mode ──────────────────────────────────────────────────────────
		"god":
			if not _devmode: _need_devmode(); return
			CurrencyManager.add_dewdrops(99999.0)
			WardenManager.current_xp += 99999.0
			WardenManager.check_level_up()
			for roamer in get_tree().get_nodes_in_group("roamers"):
				_fill_roamer_needs(roamer)
			while not ZoneManager.is_max_zone():
				_unlock_zone_free()
			_log("[color=gold][b]⚡ GOD MODE — max currency, max XP, all zones, all needs filled.[/b][/color]")
			return

		"clear":
			_output.clear()
			return

		"help":
			_print_help()
			return

	# ── Argument-based commands (base + args) ─────────────────────────────────

	match base:

		# give dewdrops/eldermoss/xp/item <value>
		"give":
			if not _devmode: _need_devmode(); return
			match arg1:
				"dewdrops", "gold", "coins", "dp":
					var n := arg2.to_float()
					if n <= 0.0: _log("[color=red]Usage: give dewdrops <amount>[/color]"); return
					CurrencyManager.add_dewdrops(n)
					_log("[color=lime]+" + str(n) + " 💧  (total: " + str(snappedf(CurrencyManager.dewdrops, 0.1)) + ")[/color]")
				"eldermoss", "em":
					var n := arg2.to_int()
					if n <= 0: _log("[color=red]Usage: give eldermoss <amount>[/color]"); return
					CurrencyManager.add_eldermoss(n)
					_log("[color=lime]+" + str(n) + " Eldermoss[/color]")
				"xp":
					var n := arg2.to_float()
					if n <= 0.0: _log("[color=red]Usage: give xp <amount>[/color]"); return
					WardenManager.current_xp += n
					WardenManager.check_level_up()
					_log("[color=lime]+" + str(n) + " XP → Level " + str(WardenManager.current_level) + "[/color]")
				"item":
					# give item <name> — everything after "item"
					var item_name : String = _title_case(" ".join(parts.slice(2)))
					if item_name.is_empty(): _log("[color=red]Usage: give item <item name>[/color]"); return
					InventoryManager.add_item(item_name)
					_log("[color=lime]Added \"" + item_name + "\" to inventory.[/color]")
				_:
					_log("[color=red]Unknown: give " + arg1 + "  (try: dewdrops | eldermoss | xp | item <name>)[/color]")

		# set dewdrops/level/time/season/weather/happiness <value>
		"set":
			if not _devmode: _need_devmode(); return
			match arg1:
				"dewdrops", "gold", "coins", "dp":
					var n := arg2.to_float()
					CurrencyManager.dewdrops = maxf(0.0, n)
					CurrencyManager.dewdrops_changed.emit(CurrencyManager.dewdrops)
					_log("[color=lime]Dewdrops set to " + str(CurrencyManager.dewdrops) + "[/color]")
				"level":
					var target := arg2.to_int()
					if target < 1: _log("[color=red]Usage: set level <n>[/color]"); return
					_set_warden_level(target)
					_log("[color=lime]Warden level → " + str(WardenManager.current_level) + "[/color]")
				"time":
					var h := arg2.to_float()
					if h < 0.0 or h > 24.0: _log("[color=red]Usage: set time <0–24>[/color]"); return
					DayNightManager.current_time = h
					DayNightManager.update_lighting()
					_log("[color=lime]Time → " + DayNightManager.get_time_string() + "[/color]")
				"season":
					match arg2:
						"spring":          _set_season(SeasonManager.Season.SPRING)
						"summer":          _set_season(SeasonManager.Season.SUMMER)
						"autumn", "fall":  _set_season(SeasonManager.Season.AUTUMN)
						"winter":          _set_season(SeasonManager.Season.WINTER)
						_: _log("[color=red]Usage: set season spring|summer|autumn|winter[/color]")
				"weather":
					match arg2:
						"sunny", "sun":   _set_weather(WeatherManager.Weather.SUNNY)
						"rain", "rainy":  _set_weather(WeatherManager.Weather.RAIN)
						"fog", "foggy":   _set_weather(WeatherManager.Weather.FOG)
						"wind", "windy":  _set_weather(WeatherManager.Weather.WIND)
						_: _log("[color=red]Usage: set weather sunny|rain|fog|wind[/color]")
				"happiness":
					var r := _get_selected_roamer()
					if not r: return
					var n := arg2.to_float()
					r.happiness = clamp(n, 0.0, 1.0)
					_log("[color=lime]" + r.roamer_name + " happiness → " + str(snappedf(r.happiness, 0.01)) + "[/color]")
				_:
					_log("[color=red]Unknown: set " + arg1 + "  (try: dewdrops | level | time | season | weather | happiness)[/color]")

		_:
			_log("[color=red]Unknown command:[/color] " + cmd + "  (type [b]help[/b] for list)")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _need_devmode() -> void:
	_log("[color=red]Error:[/color] type [b]devmode[/b] to enable dev mode first.")

func _spawn_wild_creature(scene_path: String, species: String) -> void:
	var scene := load(scene_path) as PackedScene
	if not scene:
		_log("[color=red]Error:[/color] Could not load " + scene_path)
		return
	var garden := get_tree().current_scene
	var roamer  := scene.instantiate()
	var half    := ZoneManager.get_garden_half()
	var pos     := Vector3(randf_range(-half * 0.5, half * 0.5), 2.0,
						   randf_range(-half * 0.5, half * 0.5))
	garden.add_child(roamer)
	roamer.global_position = pos
	_log("[color=lime]Spawned " + species + " at " + str(pos.x) + ", " + str(pos.z) + "[/color]")

func _get_selected_roamer() -> Node:
	# Walk the scene to find PlayerCursor (it's a child of the Garden scene root)
	var scene := get_tree().current_scene
	var cursor : Node = null
	for child in scene.get_children():
		if child.get("selected_roamer") != null:
			cursor = child
			break
	if cursor and is_instance_valid(cursor.selected_roamer):
		return cursor.selected_roamer
	_log("[color=yellow]No roamer selected — click a roamer first.[/color]")
	return null

func _fill_roamer_needs(roamer: Node) -> void:
	for need in roamer.needs:
		roamer.needs[need] = 1.0
	roamer.happiness = 1.0

func _unlock_zone_free() -> void:
	if ZoneManager.is_max_zone():
		_log("[color=yellow]Already at max zone.[/color]")
		return
	var next : Dictionary = ZoneManager.get_next_zone()
	var cost : float      = float(next.get("cost", 0))
	# Top up currency so unlock_next() can spend it, then the leftover remains
	if CurrencyManager.dewdrops < cost:
		CurrencyManager.add_dewdrops(cost - CurrencyManager.dewdrops)
	ZoneManager.unlock_next()
	_log("[color=lime]Zone unlocked → [b]" + next.get("name", "?") + "[/b][/color]")

func _set_season(season: int) -> void:
	SeasonManager.current_season = season as SeasonManager.Season
	SeasonManager.apply_season()
	SeasonManager.season_changed.emit(SeasonManager.current_season)
	_log("[color=lime]Season → [b]" + SeasonManager.get_season_name() + "[/b][/color]")

func _set_weather(weather: int) -> void:
	WeatherManager.set_weather(weather)
	_log("[color=lime]Weather → [b]" + WeatherManager.get_weather_name() + "[/b][/color]")

func _set_warden_level(target: int) -> void:
	WardenManager.current_level = target
	WardenManager.current_xp    = 0.0
	# xp_to_next_level starts at 100 and × xp_multiplier each level
	var threshold : float = 100.0
	for _i in range(target - 1):
		threshold = round(threshold * WardenManager.xp_multiplier)
	WardenManager.xp_to_next_level = threshold
	WardenManager.level_up.emit(target)

func _list_roamers() -> void:
	var roamers := get_tree().get_nodes_in_group("roamers")
	if roamers.is_empty():
		_log("[color=yellow]No roamers in garden.[/color]")
		return
	_log("[color=yellow]── Roamers (" + str(roamers.size()) + ") ──[/color]")
	for r in roamers:
		var need_avg := 0.0
		for v in r.needs.values():
			need_avg += float(v)
		need_avg /= max(r.needs.size(), 1)
		var burden_str := ""
		if   r.burden_state == r.BurdenState.BURDENED:  burden_str = " [color=orange]BURDENED[/color]"
		elif r.burden_state == r.BurdenState.DEPARTING:  burden_str = " [color=red]DEPARTING[/color]"
		var state_name : String = r.State.keys()[r.state]
		_log("  [b]" + r.roamer_name + "[/b] (" + r.species_id + ")  " +
			 state_name + "  needs " + str(snappedf(need_avg * 100.0, 1.0)) + "%%  " +
			 "happy " + str(snappedf(r.happiness * 100.0, 1.0)) + "%%" + burden_str)

func _title_case(s: String) -> String:
	var words := s.split(" ")
	var out : PackedStringArray = []
	for w in words:
		if w.is_empty(): continue
		out.append(w[0].to_upper() + w.substr(1))
	return " ".join(out)

# ── Help ──────────────────────────────────────────────────────────────────────

func _print_help() -> void:
	_log("[color=yellow]── General ──────────────────────────────────────[/color]")
	_log("  [b]devmode[/b]                  toggle dev mode (required for cheat commands)")
	_log("  [b]enable/disable freecam[/b]   fly camera — WASD, mouse, Q/E up/down, Shift=fast")
	_log("  [b]disable/enable/toggle hud[/b] screenshot mode")
	_log("  [b]clear[/b]                    clear console output")
	_log("[color=yellow]── NPC Spawning ──────────────────────────────────[/color]")
	_log("  [b]spawn torvald/gus/doc[/b]    force that NPC to visit now")
	_log("  [b]spawn all[/b]               force all three NPCs to visit")
	_log("  [b]spawn thornmouse/emberowl/crystalback[/b]  spawn new species")
	_log("  [b]spawn glowfox/mossdeer/stoneback[/b]       spawn original species")
	_log("[color=yellow]── Currency  [devmode] ───────────────────────────[/color]")
	_log("  [b]give dewdrops <n>[/b]        add N dewdrops")
	_log("  [b]give eldermoss <n>[/b]       add N eldermoss")
	_log("  [b]set dewdrops <n>[/b]         set exact dewdrop total")
	_log("[color=yellow]── XP / Level  [devmode] ────────────────────────[/color]")
	_log("  [b]give xp <n>[/b]             add N raw XP (triggers level-ups)")
	_log("  [b]set level <n>[/b]           jump directly to warden level N")
	_log("[color=yellow]── Time / Season / Weather  [devmode] ───────────[/color]")
	_log("  [b]set time <0–24>[/b]          set hour of day")
	_log("  [b]skip day[/b]                 advance one game day")
	_log("  [b]set season spring|summer|autumn|winter[/b]")
	_log("  [b]next season[/b]              advance to the next season")
	_log("  [b]set weather sunny|rain|fog|wind[/b]")
	_log("[color=yellow]── Zones  [devmode] ─────────────────────────────[/color]")
	_log("  [b]unlock zone[/b]              unlock next zone (free, no cost deducted)")
	_log("  [b]unlock all zones[/b]         unlock every zone at once")
	_log("[color=yellow]── Inventory  [devmode] ─────────────────────────[/color]")
	_log("  [b]give item <name>[/b]         e.g.  give item Burden Cure")
	_log("[color=yellow]── Roamers  [devmode] (select one first) ────────[/color]")
	_log("  [b]fill needs[/b]               fill selected roamer to 100%%")
	_log("  [b]fill all needs[/b]           fill every roamer to 100%%")
	_log("  [b]set happiness <0–1>[/b]      set selected roamer happiness")
	_log("  [b]cure burden[/b]              cure selected roamer's burden")
	_log("  [b]cure all burdens[/b]         cure every burdened roamer")
	_log("  [b]agitate roamer[/b]           force AGITATED state")
	_log("  [b]burden roamer[/b]            drop all needs to 5%% (triggers burden)")
	_log("  [b]list roamers[/b]             print all roamers + state + stats")
	_log("[color=yellow]── God Mode  [devmode] ──────────────────────────[/color]")
	_log("  [b]god[/b]                      max currency, XP, zones, fill all needs")

# ── Freecam ───────────────────────────────────────────────────────────────────

func _enable_freecam() -> void:
	if is_instance_valid(_freecam):
		_log("[color=yellow]Freecam is already active.[/color]")
		return
	var script := load("res://scripts/freecam.gd")
	_freecam = Camera3D.new()
	_freecam.set_script(script)
	_freecam.name = "DevFreecam"
	get_tree().current_scene.add_child(_freecam)
	_freecam.console = self
	_log("[color=lime]Freecam enabled.[/color] Close console to fly.")
	_log("  WASD = move  |  Mouse = look  |  Q/E = up/down  |  Shift = fast")
	_toggle()

func _disable_freecam() -> void:
	if not is_instance_valid(_freecam):
		_log("[color=yellow]Freecam is not active.[/color]")
		return
	_freecam.queue_free()
	_freecam = null
	_log("[color=lime]Freecam disabled.[/color] Normal camera restored.")

# ── HUD toggle ────────────────────────────────────────────────────────────────

func _set_hud_visible(hud_visible: bool) -> void:
	_hud_hidden = not hud_visible
	var scene := get_tree().current_scene

	for node in get_tree().get_nodes_in_group("hud"):
		node.visible = hud_visible
	var hud_names := ["HUD", "UILayer", "HudLayer", "CanvasLayer", "UI",
					  "InventoryPanel", "RoamerPanel", "ToastLayer", "ToolWheel"]
	for child in scene.get_children():
		if child == self:
			continue
		if child is CanvasLayer and child.name != "DevConsole":
			child.visible = hud_visible
		elif child.name in hud_names:
			child.visible = hud_visible

	for roamer in get_tree().get_nodes_in_group("roamers"):
		var name_lbl := roamer.get_node_or_null("NameLabel")
		if name_lbl:
			name_lbl.visible = hud_visible
		var needs := roamer.get_node_or_null("NeedIndicators")
		if needs:
			needs.visible = hud_visible
	for z_label in get_tree().get_nodes_in_group("sleep_z"):
		z_label.visible = hud_visible
	for ring in get_tree().get_nodes_in_group("selection_ring"):
		ring.visible = hud_visible

	if hud_visible:
		_log("[color=lime]HUD restored.[/color]")
		_toggle()
	else:
		_log("[color=yellow]HUD hidden.[/color] Type [b]enable hud[/b] to restore.")
		_toggle()

func _log(msg: String) -> void:
	_output.append_text(msg + "\n")
