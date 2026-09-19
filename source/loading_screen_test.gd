extends SceneTree
## The loading screen is painted while the main thread is busy building the
## city, so it has to push each frame to the window itself. v0.5.0 drew those
## frames without presenting them and players saw 0% until the city appeared.
## Checked by real screen capture during a native start; this test guards the
## two things that made it work: reports reach the screen code with their
## intermediate values, and every forced draw presents the frame.
const Loading = preload("res://scripts/loading_progress.gd")

var checks: Array = []

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("LOADING_SCREEN ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))

func run() -> void:
	var seen: Array = []
	Loading.listen(func(fraction: float, stage: String): seen.append([snappedf(fraction, 0.01), stage]))
	var stages := ["读取城市地图", "铺设街道", "建造悉尼歌剧院", "生成城市建筑", "准备界面"]
	for i in stages.size():
		Loading.report(float(i + 1) / float(stages.size()), stages[i])
		# Reports closer together than one redraw are dropped on purpose.
		OS.delay_msec(70)
	Loading.stop()
	var values: Array = seen.map(func(row: Array): return float(row[0]))
	check("every stage reaches the loading screen", seen.size() == stages.size(), {"seen":seen})
	check("the bar moves through intermediate values", values.any(func(v): return v > 0.05 and v < 0.95), {"values":values})
	var forward := true
	for i in range(1, values.size()): forward = forward and float(values[i]) >= float(values[i - 1])
	check("the bar only moves forward", forward, {"values":values})
	Loading.report(0.5, "no listener")
	check("without a listener reports do nothing", not Loading.active() and seen.size() == stages.size())
	for path in ["res://scripts/loading_progress.gd", "res://scripts/bootstrap.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check("%s presents every forced frame" % path.get_file(), source.contains("force_draw(true)") and not source.contains("force_draw(false)"))
	var passed: bool = checks.all(func(c): return c.passed)
	print("LOADING_SCREEN_COMPLETE ", checks.size(), " passed=", passed)
	quit(0 if passed else 1)
