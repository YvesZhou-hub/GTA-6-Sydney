extends SceneTree
## Control hints name the player's current keys, including after rebinding.
const GameSettings = preload("res://scripts/game_settings.gd")
var failures := 0

func check(title: String, okay: bool, detail: Variant = null) -> void:
	if not okay: failures += 1
	print("KEY_HINT ", "PASS " if okay else "FAIL ", title, "" if detail == null else " " + str(detail))

func bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _initialize() -> void:
	for row: Array in [["forward", [KEY_W, KEY_UP]], ["back", [KEY_S, KEY_DOWN]], ["left", [KEY_A, KEY_LEFT]], ["right", [KEY_D, KEY_RIGHT]], ["jump", [KEY_SPACE]], ["brake", [KEY_SPACE]], ["interact", [KEY_E]], ["map", [KEY_M]], ["sprint", [KEY_SHIFT]], ["boost", [KEY_SHIFT]]]:
		bind(row[0], row[1])
	GameSettings.apply_bindings({})
	var walk := GameSettings.keys("{move} 行走   {sprint} 奔跑")
	check("default walking keys read as WASD", walk == "WASD 行走   Shift 奔跑", walk)
	check("space is shown in Chinese", GameSettings.keys("{brake} 急刹") == "空格 急刹", GameSettings.keys("{brake} 急刹"))
	check("text without placeholders is unchanged", GameSettings.keys("常速 420 km/h") == "常速 420 km/h")
	check("unbound actions say so", GameSettings.keys("{nonexistent_action} 测试") == "未绑定 测试")
	check("repeated calls return the cached hint", GameSettings.keys("{interact} 进入 ") == "E 进入 ")
	GameSettings.apply_bindings({"interact": [KEY_F], "forward": [KEY_UP], "jump": [KEY_J]})
	check("rebinding refreshes a cached hint", GameSettings.keys("{interact} 进入 ") == "F 进入 ", GameSettings.keys("{interact} 进入 "))
	var arrows := GameSettings.keys("{move} 行走")
	check("multi-letter keys are separated", arrows == "Up/A/S/D 行走", arrows)
	check("paired jump and brake share the rebound key", GameSettings.keys("{jump}/{brake}") == "J/J", GameSettings.keys("{jump}/{brake}"))
	GameSettings.apply_bindings({})
	check("clearing bindings restores default hints", GameSettings.keys("{move} 行走") == "WASD 行走" and GameSettings.keys("{interact} 进入 ") == "E 进入 ")
	print("KEY_HINT COMPLETE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
