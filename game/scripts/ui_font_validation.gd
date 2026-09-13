extends Node
## Final-App font checks against actual menus and map, after world construction.
## Direct UI handlers are intentional; this validates fonts, not hardware input.
const Fonts = preload("res://scripts/ui_fonts.gd")
const OUTPUT := "user://ui-font-qa"
var game: Node
var checks: Array = []
var screenshots: Array = []
var native := false
var _started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":okay,"detail":detail})
	print("UI_FONT_QA ","PASS " if okay else "FAIL ",title)

func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame

func missing_glyphs(value: String, font: Font) -> Array:
	var line := TextLine.new()
	line.add_string(value,font,24)
	var missing: Array = []
	for glyph: Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()):
		if not glyph.font_rid.is_valid() or glyph.index == 0:
			missing.append({"start":glyph.start,"end":glyph.end,"index":glyph.index})
	return missing

func button_named(title: String) -> Button:
	for child: Node in game.modal_content.get_children():
		if child is Button and child.text == title: return child
	return null

func capture(name: String) -> void:
	if not native: return
	await frames()
	await RenderingServer.frame_post_draw
	var picture := get_tree().root.get_texture().get_image()
	var filename := name + ".png"
	var error := picture.save_png(OUTPUT + "/" + filename)
	screenshots.append({"file":filename,"saved":error == OK,"sha256":FileAccess.get_sha256(OUTPUT + "/" + filename) if error == OK else "","resolution":[picture.get_width(),picture.get_height()]})

func check_tree_fonts(node: Node, mismatches: Array) -> int:
	var count := 0
	if node is Label or node is Button or node is LineEdit:
		count += 1
		if node.get_theme_font("font") != Fonts.regular(): mismatches.append(str(node.get_path()))
	for child: Node in node.get_children(): count += check_tree_fonts(child,mismatches)
	return count

func run(owner_game: Node) -> void:
	if _started: return
	_started = true
	game = owner_game
	# Never open slots/settings or invoke new_world, which can save an active slot.
	if not game.qa_running or game.active:
		push_error("UI font QA requires qa_running before main setup and no active world")
		return
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	check("Production world finished before UI font validation",is_instance_valid(game.world) and game.world._ready_complete)
	check("QA does not activate a player slot",not game.active and game.world_id.is_empty())
	check("ThemeDB defaults and actual main theme share bundled font",ThemeDB.get_default_theme().default_font == Fonts.regular() and ThemeDB.fallback_font == Fonts.regular() and game.font == Fonts.regular())
	var faces: Array[Font] = [Fonts.REGULAR.base_font]
	faces.append_array(Fonts.REGULAR.fallbacks)
	check("All four UI faces are bundled FontFiles without system fallback",faces.size() == 4 and faces.all(func(face): return face is FontFile and not face.allow_system_fallback and face.fallbacks.is_empty()))
	check("Bundled primary CJK font contains enemy glyph",Fonts.REGULAR.base_font.has_char("敌".unicode_at(0)))
	for sample: String in ["无敌坦克","无敌战斗机","悉尼歌剧院 · 中国银行 · 维多利亚女王大厦","Kürtősh · ŋ · کابول · 𝕲𝖗𝖆𝖓𝖉","✓ → ↗ ↔ ⇅ ╋ × · …"]:
		var missing := missing_glyphs(sample,game.font)
		check("Actual TextServer glyphs: " + sample,missing.is_empty(),{"missing":missing})
	check("Missing-glyph negative control remains detectable",not missing_glyphs(String.chr(0x10ffff),game.font).is_empty())
	game.main_menu()
	await frames()
	check("Actual title menu and name editor use bundled font",game.active_panel == "main" and game.name_edit.get_theme_font("font") == Fonts.regular() and missing_glyphs(game.name_edit.text,game.font).is_empty())
	await capture("01-title-menu")
	game.vehicles_menu()
	await frames()
	var mismatches: Array = []
	var control_count := check_tree_fonts(game.canvas,mismatches)
	check("Production menu, HUD and auxiliary Controls inherit bundled font",control_count > 20 and mismatches.is_empty(),{"controls":control_count,"mismatches":mismatches})
	for kind: String in game.VEHICLE_NAMES:
		var title: String = game.VEHICLE_NAMES[kind] + " · 耐久 100%"
		var button := button_named(title)
		if not is_instance_valid(button):
			check("Vehicle label exists: " + kind,false)
			continue
		var font: Font = button.get_theme_font("font")
		var size: int = button.get_theme_font_size("font_size")
		var style: StyleBox = button.get_theme_stylebox("normal")
		var width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		check("Complete shaped vehicle label fits: " + kind,missing_glyphs(title,font).is_empty() and width + style.get_minimum_size().x <= button.size.x + .5,{"text":title,"text_width":width,"button_width":button.size.x})
	var tank := button_named("Harbour Bastion · 重装坦克 · 耐久 100%")
	var fighter := button_named("Aster F-27 · 战斗机 · 耐久 100%")
	check("Current tank and fighter names with durability remain exact",is_instance_valid(tank) and is_instance_valid(fighter))
	if is_instance_valid(tank) and is_instance_valid(fighter):
		var scroll: ScrollContainer = game.modal_content.get_parent()
		scroll.ensure_control_visible(fighter)
		await frames()
		var clip := scroll.get_global_rect().grow(.5)
		check("Both enemy labels are fully visible in the real scroll viewport",clip.encloses(tank.get_global_rect()) and clip.encloses(fighter.get_global_rect()))
	await capture("02-tank-fighter-menu")
	game.map_menu()
	await frames()
	check("Actual map and search entry use bundled font",game.map_panel.visible and game.map_panel.data_loaded and game.map_panel.get_theme_default_font() == Fonts.regular() and game.map_search.get_theme_font("font") == Fonts.regular())
	check("Actual minimap and navigation drawing inherit bundled font",game.minimap.get_theme_default_font() == Fonts.regular() and game.navigation_hud.get_theme_default_font() == Fonts.regular())
	await capture("03-map-fonts")
	check("UI font QA preserved inactive slot and empty fleet",not game.active and game.world_id.is_empty() and game.vehicles.is_empty())
	if native: check("All three actual-App screenshots saved",screenshots.size() == 3 and screenshots.all(func(item): return item.saved))
	var passed := checks.all(func(item): return item.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"native":native,"screenshots":screenshots,"font_family":Fonts.REGULAR.base_font.get_font_name(),"font_resource":Fonts.FONT_PATH,"scope":"Actual production title/vehicle/map UI after full-world construction. Direct handlers and scroll visibility request; no physical input or startup-screenshot claim. Runtime resource/shaping assertions work in compiled PCK without source reads.","user_saves_touched":false,"settings_files_written":false}
	FileAccess.open(OUTPUT + "/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI_FONT_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active = false
	get_tree().paused = false
	game.finish_quit(0 if passed else 1)
