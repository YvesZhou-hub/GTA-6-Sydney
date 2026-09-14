extends SceneTree
## Fail-closed tests for the full-city validator's actual-damage and report gates.
## Gameplay itself is exercised by --arsenal-qa, not reimplemented here.
const Arsenal = preload("res://scripts/arsenal_validation.gd")
var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool) -> void:
	checks.append({"name":title,"passed":passed})
	print("ARSENAL_GATE ","PASS " if passed else "FAIL ",title)

func run() -> void:
	var hits: Array = [{"id":101,"actual":42.25},{"id":202,"actual":9.5}]
	var state := {"actual_damage":51.75,"floating":[{"id":101,"amount":42.25,"kind":"damage"},{"id":202,"amount":9.5,"kind":"damage"},{"id":101,"amount":0,"kind":"reward"}]}
	check("actual fractional per-victim damage and distinct reward pass",Arsenal.damage_feedback_matches(hits,state))
	check("empty hit list cannot pass a damage scenario",not Arsenal.damage_feedback_matches([],state))
	var wrong := state.duplicate(true)
	wrong.floating[0].amount = 10000
	check("requested overkill cannot substitute for actual damage",not Arsenal.damage_feedback_matches(hits,wrong))
	wrong = state.duplicate(true);wrong.floating.remove_at(1)
	check("missing edge victim is rejected even with correct global total",not Arsenal.damage_feedback_matches(hits,wrong))
	wrong = state.duplicate(true);wrong.actual_damage = 100
	check("incorrect global damage sum is rejected",not Arsenal.damage_feedback_matches(hits,wrong))
	wrong = state.duplicate(true);wrong.floating[1].id = 101
	check("same explosion centre cannot attribute both losses to one victim",not Arsenal.damage_feedback_matches(hits,wrong))
	var duplicate: Array = hits.duplicate(true);duplicate[1].id = 101
	check("duplicate victim records cannot inflate a successful blast",not Arsenal.damage_feedback_matches(duplicate,state))
	var invalid: Array = hits.duplicate(true);invalid[0].actual = NAN
	check("nonfinite actual damage fails validation",not Arsenal.damage_feedback_matches(invalid,state))
	wrong = state.duplicate(true);wrong.floating[0].kind = "reward"
	check("coins cannot be interpreted as player damage",not Arsenal.damage_feedback_matches(hits,wrong))
	wrong = state.duplicate(true);wrong.floating[0].amount = 20.0;wrong.floating.append({"id":101,"amount":22.25,"kind":"damage"})
	check("multiple true numbers on a victim may sum to its actual loss",Arsenal.damage_feedback_matches(hits,wrong))
	var required: Array = ["actual shell","actual aerial strike"]
	var rows: Array = [{"name":"actual shell","passed":true},{"name":"actual aerial strike","passed":true}]
	check("complete unique true checks pass",Arsenal.required_checks_pass(rows,required))
	check("an empty successful-looking report fails",not Arsenal.required_checks_pass([],required))
	check("an omitted required scenario fails",not Arsenal.required_checks_pass(rows.slice(0,1),required))
	var failed: Array = rows.duplicate(true);failed[1].passed = false
	check("an explicit failed scenario fails the release gate",not Arsenal.required_checks_pass(failed,required))
	failed = rows.duplicate(true);failed[1].passed = "true"
	check("truthy strings cannot impersonate boolean passes",not Arsenal.required_checks_pass(failed,required))
	failed = rows.duplicate(true);failed.append(rows[0])
	check("duplicate check names cannot fill a report",not Arsenal.required_checks_pass(failed,required))
	var names := {}
	for title: String in Arsenal.REQUIRED: names[title] = true
	check("real full-city contract retains at least fifteen distinct required scenarios",Arsenal.REQUIRED.size()>=15 and Arsenal.REQUIRED.size()==names.size())
	var passed: bool = checks.all(func(row):return row.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"scope":"Negative regression for production full-city QA evidence gates; gameplay requires separate actual --arsenal-qa run","source_sha256":{}}
	for path: String in ["res://scripts/arsenal_validation.gd","res://../source/arsenal_test.gd"]: report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/arsenal-gates.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ARSENAL_GATE_COMPLETE checks=",checks.size()," passed=",passed)
	quit(0 if passed else 1)
