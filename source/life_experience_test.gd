extends SceneTree
## Small local fixture. Writes one uniquely named temporary JSON round-trip only;
## never opens, overwrites or deletes user world saves.
const Life = preload("res://scripts/harbor_life.gd")
const ICC = preload("res://scripts/icc_landmarks.gd")
const Shops = preload("res://scripts/darling_square_frontages.gd")
const Manly = preload("res://scripts/manly_landmarks.gd")
var checks := 0
var failures := 0
var deliveries := 0
var notices: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value: print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)

func world_anchors() -> Dictionary:
	var result := {}
	for venue: Dictionary in ICC.metadata(): result[venue.id] = venue.get("arrival",venue.center)
	for shop: Dictionary in Shops.metadata():
		result["shop_" + str(shop.id)] = Vector3(shop.front[0],4.5,shop.front[1]) + Vector3(shop.normal[0],0,shop.normal[1])*1.72
	for shop:Dictionary in preload("res://scripts/darling_square_detail.gd").metadata():result[shop.id]=shop.arrival
	for shop:Dictionary in preload("res://scripts/circular_quay_detail.gd").metadata():result[shop.id]=shop.arrival
	result["manly_beach"] = Manly.geo(-33.7970494,151.2883603)
	return result

func round_trip(state: Dictionary) -> Dictionary:
	var directory := OS.get_cache_dir().path_join("harbourlife-life-experience-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	check(not DirAccess.dir_exists_absolute(directory), "save fixture uses a fresh isolated temporary directory")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("experience-state.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run() -> void:
	var life := Life.new()
	root.add_child(life)
	life.service_completed.connect(func(_result: Dictionary): deliveries += 1)
	life.notification.connect(func(message: String): notices.append(message))
	var anchors := world_anchors()
	life.setup(anchors,false)
	check(life.money == 50000 and not life.sandbox, "life mode begins with $50,000")
	check(life.get_state().economy_version == 1 and life.welcome_grant == 0, "new economy is already versioned without a migration grant")
	life.money = 0
	var free := true
	for kind: String in Life.FREE_VEHICLES:
		free = free and life.purchase(kind,999999) and life.money == 0 and life.owned_assets.has(kind)
	check(free and Life.FREE_VEHICLES.size() == 9 and "hoverboard" in Life.FREE_VEHICLES, "all nine vehicle types including hoverboard remain free at zero balance")
	check(not life.purchase("repair",120) and life.money == 0, "optional paid repairs cannot overdraw the balance")
	check(not life.spend(-10) and not life.purchase("invalid",-10) and life.money == 0, "negative general transactions cannot mint currency")
	life.setup(anchors,true)
	check(life.money == 50000 and life.sandbox, "sandbox starts with the same generous spending money")
	life.setup(anchors,false)
	var legacy := {"version":2,"money":1200,"lifetime_earnings":7654,"completed_jobs":{"photo":9},"owned_assets":{"workshop":true,"special_keepsake":true},"active_job":{"id":"photo","title":"Old photo job","reward":240,"elapsed":20.0,"stage":1,"dwell":0.0},"jobs_started":12}
	life.apply_state(legacy)
	check(life.money == 50000 and life.welcome_grant == 48800, "legacy low balance receives only the difference to $50,000")
	check(life.lifetime_earnings == 7654 and life.completed_jobs.photo == 9 and life.owned_assets.special_keepsake, "welcome grant preserves earned income, completions and owned assets")
	check(life.active_job.stage == 1 and life.active_job.reward == 1500 and life._jobs_started == 12, "in-progress legacy job keeps progress and receives the new base reward")
	life.cancel_job()
	var catalog := life.service_catalog()
	check(catalog.size() == 22, "ICC venues, fifteen Darling Square shops three Circular Quay restaurants and Manly provide twenty-two experiences")
	var valid_catalog := true
	var ids := {}
	for service: Dictionary in catalog:
		valid_catalog = valid_catalog and service.position == anchors[service.anchor] and service.cost > 0 and service.cost <= 120 and service.notice == Life.SERVICE_NOTICE
		ids[service.id] = true
	check(valid_catalog and ids.size() == catalog.size(), "service IDs are unique and positions/prices/source boundary are explicit")
	var coffee: Dictionary = catalog[3]
	var balance := life.money
	check(not life.use_service(coffee.id,coffee.position+Vector3(100,0,0)).ok and life.money == balance and deliveries == 0, "remote purchase neither charges nor delivers")
	check(not life.use_service(coffee.id,coffee.position+Vector3(0,100,0)).ok, "flying above a venue is not considered arrival")
	check(not life.use_service("unknown",coffee.position).ok and life.money == balance, "missing service does not charge")
	life.tick_context(coffee.position,"car",8.0,0.1)
	check(not life.use_service(coffee.id,coffee.position,false).ok and life.money == balance, "moving vehicle must stop before ordering")
	life.tick_context(coffee.position,"car",0.0,0.1)
	var receipt := life.use_service(coffee.id,coffee.position,false)
	check(receipt.ok and life.money == balance-int(coffee.cost) and deliveries == 1 and receipt.effects.stamina_restore == 35, "stopped vehicle can buy once without exiting; one delivery signal carries stamina effect")
	check(life._experience_label.visible and life.experience_visits[coffee.id] == 1 and life.experience_spending == coffee.cost, "purchase displays a world-space stamp and persists visit/spending ledger")
	var second := life.use_service(coffee.id,coffee.position,false)
	check(second.ok and deliveries == 2 and life.experience_visits[coffee.id] == 2, "another deliberate purchase is immediately available without artificial cooldown")
	check(life.nearest_service(coffee.position).id == coffee.id and life.interact(coffee.position) == "OPEN_SERVICES" and "游戏体验" in life.available_actions(coffee.position), "nearby hints and interaction open the service menu")
	var before_reload := life.money
	var saved := round_trip(life.get_state())
	var signal_count := deliveries
	life.setup(anchors,false)
	life.apply_state(saved)
	check(life.money == before_reload and life.welcome_grant == 48800, "JSON save reload preserves spent balance and never repeats welcome top-up")
	check(deliveries == signal_count and life._experience_remaining == 0.0, "loading never repeats a purchase, stamina award or visual delivery")
	check(life.experience_visits[coffee.id] == 2 and life.experience_spending == int(coffee.cost)*2 and life.last_experience.id == coffee.id, "travel passport and last receipt survive actual temporary JSON round-trip")
	var detached := life.get_state()
	detached.experience_visits[coffee.id] = 999
	check(life.experience_visits[coffee.id] == 2, "save snapshot cannot mutate the live journal by alias")
	life.apply_state({"version":2,"money":185321,"lifetime_earnings":120000})
	check(life.money == 185321 and life.welcome_grant == 0 and life.lifetime_earnings == 120000, "wealthy legacy save is never reduced or granted unnecessary money")
	life.apply_state({"version":3,"economy_version":1,"money":0})
	check(life.money == 0, "current-version empty wallet remains empty on reload")
	check(not life.use_service(coffee.id,coffee.position).ok and life.experience_spending == 0 and deliveries == signal_count, "insufficient funds returns a recoverable error without side effects")
	life.setup({},false)
	check(life.service_catalog().is_empty(), "missing world anchors never create experiences at invented fallback locations")
	life.anchors = {"shop_edition":"bad coordinate","shop_matcha":[1,2]}
	check(life.service_catalog().is_empty(), "invalid anchor coordinates are omitted")
	life.setup(anchors,true)
	var sum_cost := 0
	var all_delivered := true
	for service: Dictionary in life.service_catalog():
		var outcome := life.use_service(service.id,service.position)
		all_delivered = all_delivered and outcome.ok
		sum_cost += int(service.cost)
	check(all_delivered and life.experience_visits.size() == 22 and life.money == 50000-sum_cost, "all twenty-two experiences work and use game money in sandbox too")
	check(life.experience_spending == sum_cost and life.get_children().filter(func(child): return child.name == "Life_Travel_Stamp").size() == 1, "repeat activities reuse one feedback label and account every cost")
	life.tick_context(Vector3.ZERO,"",0,5.1)
	check(not life._experience_label.visible, "brief stamp feedback ends without delaying movement or the next purchase")
	life.setup(anchors,false)
	var job_income := 0
	for definition: Dictionary in life.job_catalog():
		var id := str(definition.id)
		life.start_job(id)
		var old_money := life.money
		if id == "salvage":
			var crate = life._find_cargo(life.active_job.cargo_id)
			life.tick_context(crate.global_position,"",0,0.1)
			life.toggle_carry(crate.global_position)
			life.tick_context(life._delivery(),"yacht",0,0.1)
			life.interact(life._delivery())
		else:
			for waypoint: Vector3 in life._job_route(id):
				match id:
					"photo":
						life.tick_context(waypoint,"",0,0.1)
						life.interact(waypoint)
					"harbor": life.tick_context(waypoint,"yacht",1,2.1)
					"air": life.tick_context(waypoint,"helicopter",16,0.2)
					"race": life.tick_context(waypoint,"motorcycle",10,0.1)
		var earned := life.money-old_money
		job_income += earned
		check(life.active_job.is_empty() and earned >= 1500 and int(life.completed_jobs.get(id,0)) == 1, "%s spatial activity completes with generous earned reward" % id)
	check(life.money == 50000+job_income and life.lifetime_earnings == job_income, "job earnings balance exactly; welcome money is not counted as earned income")
	var final_state := round_trip(life.get_state())
	life.setup(anchors,false)
	life.apply_state(final_state)
	check(life.money == 50000+job_income and life.lifetime_earnings == job_income and life.completed_jobs.size() == 5, "earned money and all job records persist unchanged")
	life.free()
	print("LIFE EXPERIENCE COMPLETE checks=",checks," failures=",failures)
	quit(failures)
