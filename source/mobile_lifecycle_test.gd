extends SceneTree
## Production notification handler with fake saves: no city or user files.
## tools/runtime/godot --headless --path game --script ../source/mobile_lifecycle_test.gd
const Profile = preload("res://scripts/mobile_profile.gd")

class TouchFixture extends Control:
	var releases := 0
	func release_all() -> void: releases += 1

class GameFixture extends "res://scripts/main.gd":
	var saves := 0
	var pauses := 0
	var save_succeeds := true
	func _ready() -> void: pass
	func save_world() -> bool:
		saves += 1
		return save_succeeds
	func pause_menu() -> void:
		pauses += 1
		paused = true

var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool) -> void:
	checks.append({"name":title,"passed":passed})
	print("MOBILE_LIFECYCLE ", "PASS " if passed else "FAIL ", title)

func run() -> void:
	var previous_profile := Profile._cached_current.duplicate(true)
	var previous_mute := AudioServer.is_bus_mute(0)
	Profile._cached_current = Profile.detect("iOS", PackedStringArray(["mobile", "ios"]), PackedStringArray(), "iPhone")
	var game := GameFixture.new()
	var touch := TouchFixture.new()
	game.mobile_controls = touch
	game.active = true
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss saves immediately, releases input, pauses and mutes", game.saves == 1 and game.pauses == 1 and touch.releases == 1 and AudioServer.is_bus_mute(0))
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus out and pause share one save despite repeated notifications", game.saves == 1 and game.pauses == 1 and touch.releases == 3)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("foreground restores sound while preserving the pause menu", not AudioServer.is_bus_mute(0) and game.paused and game.saves == 1)
	game.paused = false
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("a later background cycle can save once again", game.saves == 2 and game.pauses == 2)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus return alone rearms saving even while a menu stays paused", game.saves == 3 and game.pauses == 2)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("pause without preceding focus loss still saves exactly once", game.saves == 4)
	for guard in ["inactive", "qa", "quitting"]:
		game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game.active = guard != "inactive"
		game.qa_running = guard == "qa"
		game.quitting = guard == "quitting"
		var before := game.saves
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(guard + " never saves on focus loss or pause", game.saves == before)
	game.active = true
	game.qa_running = false
	game.quitting = false
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.save_succeeds = false
	var before_failure := game.saves
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.save_succeeds = true
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("a failed first save may retry without duplicating a successful write", game.saves == before_failure + 2)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	Profile._cached_current = Profile.detect("macOS", PackedStringArray(), PackedStringArray())
	var before_desktop := game.saves
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("ordinary desktop focus loss does not save", game.saves == before_desktop)
	game.free()
	touch.free()
	Profile._cached_current = previous_profile
	AudioServer.set_bus_mute(0, previous_mute)
	var failures := checks.filter(func(row: Dictionary): return not row.passed).size()
	var report := {"passed":failures == 0,"checks":checks,"count":checks.size(),"failures":failures,"user_saves_touched":false,"main_sha256":FileAccess.get_sha256("res://scripts/main.gd")}
	FileAccess.open("res://../reports/mobile-lifecycle.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MOBILE_LIFECYCLE_COMPLETE checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)
