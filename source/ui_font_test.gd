extends SceneTree
## Focused production UI + TextServer coverage test. No world, save access or GPU
## in default mode. Root may run --capture for two actual UI viewport PNGs.
const Fonts = preload("res://scripts/ui_fonts.gd")
const Main = preload("res://scripts/main.gd")
var checks: Array = []
var failures := 0
var hashes: Dictionary = {}
var corpus_counts: Dictionary = {}
var captured: Array = []
var all_characters: Dictionary = {}
var baseline: Dictionary = {}

class FixtureGame extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _unhandled_input(_event): pass

class FixtureWorld extends Node3D:
	var anchors: Dictionary = {"quay":Vector3.ZERO,"home":Vector3.ZERO}

class FixtureLife extends Node3D:
	signal service_completed(result)

func _init(): call_deferred("run")

func check(title: String, passed: bool, evidence: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"evidence":evidence})
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + title + " " + JSON.stringify(evidence))

func remember(path: String) -> void:
	hashes[path.trim_prefix("res://../").replace("res://","game/")] = FileAccess.get_sha256(path)

func shape_missing(value: String, font: Font) -> Array:
	var line := TextLine.new()
	line.add_string(value,font,24)
	var missing: Array = []
	for glyph: Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()):
		if not glyph.font_rid.is_valid() or glyph.index == 0:
			missing.append({"start":glyph.start,"end":glyph.end,"index":glyph.index})
	return missing

func add_characters(value: String, to: Dictionary) -> void:
	for c: String in value:
		var cp := c.unicode_at(0)
		if cp >= 32 and cp != 127 and not cp in [0x202a,0x202c]:
			to[cp] = true
			all_characters[cp] = true

func check_corpus(name: String, characters: Dictionary) -> void:
	var missing: Array = []
	var han := 0
	for cp: int in characters:
		if cp >= 0x3400 and cp <= 0x9fff: han += 1
		if not Fonts.regular().has_char(cp): missing.append({"character":String.chr(cp),"codepoint":cp})
	corpus_counts[name] = {"unique_characters":characters.size(),"han_characters":han,"missing":missing}
	check(name + " has no missing authored/displayed characters",missing.is_empty(),corpus_counts[name])

func source_corpus() -> void:
	# A conservative superset: every non-control character in all production
	# scripts, including strings assembled dynamically and their comments.
	var chars: Dictionary = {}
	var files := DirAccess.get_files_at("res://scripts")
	files.sort()
	for name: String in files:
		if not name.ends_with(".gd"): continue
		var path := "res://scripts/" + name
		remember(path)
		add_characters(FileAccess.get_file_as_string(path),chars)
	check_corpus("Production script character superset",chars)
	remember("res://assets/city_map.json")
	var city: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
	# Match HarborMap.load_map_data and City.build_place_labels name selection.
	# Unused OSM name:xx/description metadata is deliberately outside UI coverage.
	for group: String in ["roads","places"]:
		var names: Dictionary = {}
		var record_count := 0
		for record: Dictionary in city.get(group,[]):
			var tags: Dictionary = record.get("tags",{})
			var name := str(record.get("name",tags.get("name",tags.get("brand","") if group == "places" else "")))
			if name.is_empty(): continue
			record_count += 1
			add_characters(name,names)
		check_corpus("OSM " + group + " display names",names)
		corpus_counts["OSM " + group + " display names"].records = record_count

func asset_corpus(directory: String, chars: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".json") or name == "city_map.json": continue
		var path := directory.path_join(name)
		remember(path)
		add_characters(FileAccess.get_file_as_string(path),chars)
	for folder: String in DirAccess.get_directories_at(directory):
		asset_corpus(directory.path_join(folder),chars)

func verify_controls(node: Node, problems: Array) -> int:
	var count := 0
	if node is Label or node is Button or node is LineEdit:
		count += 1
		var actual: Font = node.get_theme_font("font")
		if actual != Fonts.regular(): problems.append(str(node.get_path()))
	for child: Node in node.get_children(): count += verify_controls(child,problems)
	return count

func capture(name: String) -> void:
	for _i in range(3): await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://../reports/ui-font/" + name + ".png")
	var error := image.save_png(path)
	check("Viewport capture " + name,error == OK,{"width":image.get_width(),"height":image.get_height()})
	if error == OK: captured.append({"path":"reports/ui-font/" + name + ".png","sha256":FileAccess.get_sha256(path)})

func sample_panel(game: Node) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(625,40)
	panel.size = Vector2(755,820)
	panel.add_theme_stylebox_override("panel",game.panel_style(Color("10232b"),14))
	panel.theme = Fonts.make_theme()
	game.canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	panel.add_child(column)
	var samples := ["字体核验 · 随游戏提供的 Noto 字体",Main.VEHICLE_NAMES.tank,Main.VEHICLE_NAMES.fighter,"正在加载悉尼海港\n准备建筑、道路和可破坏场景，请稍候。",game.vehicle_help("tank"),"地图与位置 · 目的地已标记\n悉尼歌剧院 · 中国银行 · 维多利亚女王大厦","菜单符号：✓  →  ↗  ↔  ⇅  ╋  ×  ·  …","实际名称字形：Kürtősh · ŋ · کابول · 𝕲𝖗𝖆𝖓𝖉"]
	for i in range(samples.size()):
		var label := Label.new()
		label.text = samples[i]
		label.add_theme_font_size_override("font_size",26 if i < 3 else 19)
		label.add_theme_color_override("font_color",Color("f1efdf"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 650
		column.add_child(label)

func run() -> void:
	var out := ProjectSettings.globalize_path("res://../reports/ui-font")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440,900)
	var old := SystemFont.new()
	old.font_names = PackedStringArray(["Avenir Next","PingFang SC","Arial"])
	baseline = {"old_primary_font":old.get_font_name(),"old_primary_has_di":old.has_char("敌".unicode_at(0)),"old_system_fallback_enabled":old.allow_system_fallback,"old_shaping_missing":shape_missing("无敌坦克 / 无敌战斗机",old),"note":"Platform observation only; pass does not rely on old system fallback failing on every host."}
	var manifest_path := "res://assets/fonts/font_sources.json"
	remember(manifest_path)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for row: Dictionary in manifest.fonts:
		var path := "res://" + str(row.file).trim_prefix("game/")
		remember(path)
		var resource: FontFile = load(path)
		check("Bundled original " + str(row.file).get_file(),FileAccess.get_sha256(path) == row.sha256 and not resource.allow_system_fallback and resource.fallbacks.is_empty(),{"source_sha256":FileAccess.get_sha256(path),"allow_system_fallback":resource.allow_system_fallback})
		var license_path := "res://../" + str(row.license_file)
		remember(license_path)
		check("OFL accompanies " + str(row.file).get_file(),FileAccess.get_sha256(license_path) == row.license_sha256 and FileAccess.get_file_as_string(license_path).contains("SIL OPEN FONT LICENSE"))
	check("Font resource is shared across independent UI themes",Fonts.make_theme().default_font == Fonts.make_theme(22).default_font and Fonts.regular() == load(Fonts.FONT_PATH))
	check("Default theme and fallback both use bundled chain",ThemeDB.get_default_theme().default_font == Fonts.regular() and ThemeDB.fallback_font == Fonts.regular())
	check("First import has no project-theme font dependency",str(ProjectSettings.get_setting("gui/theme/custom_font","")) == "")
	check("Unmapped Unicode negative control is detected",not Fonts.regular().has_char(0x10ffff) and not shape_missing(String.chr(0x10ffff),Fonts.regular()).is_empty())
	check("Enemy character is physically in bundled CJK font",Fonts.REGULAR.base_font.has_char("敌".unicode_at(0)))
	for value: String in ["无敌坦克","无敌战斗机","Kürtősh","ŋ","کابول","𝕲𝖗𝖆𝖓𝖉","✓ → ↗ ↔ ⇅ ╋ × · …"]:
		check("TextServer shapes " + value,shape_missing(value,Fonts.regular()).is_empty())
	source_corpus()
	var assets: Dictionary = {}
	asset_corpus("res://assets",assets)
	check_corpus("Public asset JSON character superset",assets)
	var bare := Label.new()
	bare.text = "正在加载悉尼海港 · 无敌坦克"
	root.add_child(bare)
	check("Unthemed loading/diagnostic Label resolves bundled font",bare.get_theme_font("font") == Fonts.regular())
	bare.queue_free()
	var world3d := Node3D.new();root.add_child(world3d)
	var inherited := Label3D.new();inherited.text = "无敌坦克 · Kürtősh"
	var explicit := Label3D.new();explicit.text = inherited.text;explicit.font = Fonts.regular()
	world3d.add_child(inherited);world3d.add_child(explicit)
	for _i in range(3): await process_frame
	check("Default Label3D uses same layout as explicit bundled font",inherited.get_aabb().is_equal_approx(explicit.get_aabb()) and inherited.get_aabb().size.x > 0,{"default_bounds":str(inherited.get_aabb()),"explicit_bounds":str(explicit.get_aabb())})
	world3d.queue_free()
	var game := FixtureGame.new()
	game.qa_running = true
	root.add_child(game)
	game.world = FixtureWorld.new();game.add_child(game.world)
	game.life = FixtureLife.new();game.add_child(game.life)
	game.setup_ui()
	game.vehicles_menu()
	for _i in range(3): await process_frame
	var problems: Array = []
	var count := verify_controls(game,problems)
	check("Production menu and HUD Controls inherit same bundled font",problems.is_empty() and count > 20,{"controls":count,"mismatches":problems})
	check("Custom map and navigation drawing use bundled default",game.map_panel.get_theme_default_font() == Fonts.regular() and game.minimap.get_theme_default_font() == Fonts.regular() and game.navigation_hud.get_theme_default_font() == Fonts.regular())
	var buttons: Dictionary = {}
	for child: Node in game.modal_content.get_children():
		if child is Button: buttons[child.text] = child
	for kind: String in Main.VEHICLE_NAMES:
		var title: String = Main.VEHICLE_NAMES[kind] + " · 免费驾驶"
		var button: Button = buttons.get(title)
		var width := Fonts.regular().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		check("Production vehicle button " + kind,is_instance_valid(button) and shape_missing(title,button.get_theme_font("font")).is_empty() and width + 36 <= button.size.x,{"text":title,"text_width":width,"button_width":button.size.x})
	check("Original Chinese vehicle names remain exact",Main.VEHICLE_NAMES.tank == "Harbour Bastion · 无敌坦克" and Main.VEHICLE_NAMES.fighter == "Aster F-27 · 无敌战斗机")
	if "--capture" in OS.get_cmdline_user_args():
		check("Capture mode uses real renderer",DisplayServer.get_name() != "headless")
		if DisplayServer.get_name() != "headless":
			sample_panel(game)
			await capture("vehicle-menu-top")
			var scroll: ScrollContainer = game.modal_content.get_parent()
			scroll.ensure_control_visible(buttons[Main.VEHICLE_NAMES.fighter + " · 免费驾驶"])
			await capture("vehicle-menu-tank-fighter")
	for path: String in ["res://scripts/ui_fonts.gd","res://scripts/bootstrap.gd","res://scripts/main.gd",Fonts.FONT_PATH,"res://project.godot","res://../source/ui_font_test.gd"]: remember(path)
	game.queue_free()
	for _i in range(3): await process_frame
	var report := {"passed":failures == 0,"count":checks.size(),"checks":checks,"hashes":hashes,"coverage":corpus_counts,"total_unique_characters":all_characters.size(),"old_system_font_observation":baseline,"screenshots":captured,"headless":DisplayServer.get_name() == "headless","user_saves_touched":false,"world_built":false,"limitations":"Checks existing production strings and selected OSM display names, not all Unicode or arbitrary future player names. Native captures require --capture and are not implied by headless success."}
	var report_name := "capture-checks.json" if "--capture" in OS.get_cmdline_user_args() else "checks.json"
	FileAccess.open(out + "/" + report_name,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI_FONT_COMPLETE ",checks.size()," passed=",failures == 0)
	quit(0 if failures == 0 else 1)
