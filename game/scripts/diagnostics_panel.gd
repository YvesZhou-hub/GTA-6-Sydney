extends Control
## F3 is dispatched by main. This panel never changes global pause/input ownership.
signal toggled(opened: bool)
var _diagnostics: Node
var _game_ref: WeakRef
var _content: VBoxContainer
var _stats: Label
var _flags: Label
var _status: Label
var _sliders: Dictionary={}
var _numbers: Dictionary={}
var _refresh_time:=0.0
var _built:=false

func setup(game: Node, singleton: Node) -> void:
	_game_ref=weakref(game) if is_instance_valid(game) else null
	_diagnostics=singleton
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not _built: _build()
	if not singleton.tuning_changed.is_connected(_tuning_changed): singleton.tuning_changed.connect(_tuning_changed)
	visible=false
	set_process(false)
	_refresh()

func _build() -> void:
	_built=true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.color=Color(0.01,.025,.04,.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	var panel:=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left=-565;panel.offset_right=-18;panel.offset_top=18;panel.offset_bottom=-18
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.065,.085,.98)
	style.set_corner_radius_all(12);style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content=VBoxContainer.new();_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",10);scroll.add_child(_content)
	var top:=HBoxContainer.new();_content.add_child(top)
	var title:=_label("运行诊断 · F3",23);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
	var closing:=Button.new();closing.name="DiagnosticsClose";closing.text="关闭";closing.pressed.connect(close);top.add_child(closing)
	_stats=_label("读取运行状态…",15);_content.add_child(_stats)
	_flags=_label("",14);_flags.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_content.add_child(_flags)
	var separator:=HSeparator.new();_content.add_child(separator)
	_content.add_child(_label("实时画面参数",19))
	var note:=_label("即时改变数值；未启用的效果保持关闭。\n关闭面板继续驾驶，F3 可再次打开。",14)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_content.add_child(note)
	for key: String in _diagnostics.limits():
		var spec: Dictionary=_diagnostics.limits()[key]
		var row:=HBoxContainer.new();_content.add_child(row)
		var caption:=_label(str(spec.label),15);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption)
		var number:=_label("",15);row.add_child(number);_numbers[key]=number
		var slider:=HSlider.new();slider.min_value=spec.min;slider.max_value=spec.max;slider.step=spec.step
		slider.name="DiagnosticsSlider_"+key
		slider.custom_minimum_size=Vector2(420,24)
		slider.value_changed.connect(_change.bind(key));_content.add_child(slider);_sliders[key]=slider
	var reset:=Button.new();reset.name="DiagnosticsReset";reset.text="恢复默认画面参数（保留当前时刻）";reset.pressed.connect(_reset);_content.add_child(reset)
	_status=_label("仅本机诊断 · 无网络服务",13);_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_content.add_child(_status)

func _label(text: String, font_size: int) -> Label:
	var node:=Label.new();node.text=text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("e0ebef"))
	return node

func toggle() -> void:
	if visible: close();return
	visible=true;set_process(true);_refresh_time=0.0
	_refresh();toggled.emit(true)

func close() -> void:
	if not visible: return
	visible=false;set_process(false)
	var focus: Control=get_viewport().gui_get_focus_owner()
	if focus!=null and is_ancestor_of(focus): focus.release_focus()
	toggled.emit(false)

func _gui_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close();accept_event()

func _process(delta: float) -> void:
	_refresh_time-=delta
	if _refresh_time<=0:
		_refresh_time=.5
		_refresh()

func _format(value: Variant, suffix: String="") -> String:
	return "—" if value==null else str(value)+suffix

func _memory(value: Variant, available: bool) -> String:
	return "不可用" if not available or value==null else "%.1f MiB"%(float(value)/1048576.0)

func _refresh() -> void:
	if not is_instance_valid(_diagnostics) or not _built: return
	var s: Dictionary=_diagnostics.snapshot()
	var p: Dictionary=s.performance
	var world: Dictionary=s.world
	var position: Variant=s.player_position
	var lines: Array[String]=[]
	lines.append("%s · %s / %s"%[s.engine,s.render.method,s.render.driver])
	if s.city_clock is Dictionary:
		var clock: Dictionary=s.city_clock.state
		var solar: Dictionary=s.city_clock.solar_state
		var minutes: int=int(float(clock.hour)*60)%1440
		lines.append("悉尼夏季 %02d:%02d · %.0f 倍速 · %s\n太阳高度 %.1f° · 夜间权重 %.2f"%[minutes/60,minutes%60,float(clock.speed),"循环中" if clock.running else "已定格",float(solar.elevation_deg),float(solar.night_factor)])
	if s.tree_paused: lines.append("角色与物理已暂停 · 画面继续渲染")
	lines.append("FPS %.0f   帧处理 %.2f ms   物理 %.2f ms"%[p.fps,p.process_seconds*1000,p.physics_seconds*1000])
	lines.append("渲染物体 %.0f   Draw calls %.0f\nPrimitives %.0f（含各次绘制）"%[p.render_objects,p.draw_calls,p.render_primitives])
	lines.append("显存 %s   静态内存 %s"%[_memory(p.video_memory_bytes,s.availability.render_counters),_memory(p.static_memory_bytes,s.availability.static_memory)])
	lines.append("活跃刚体 %.0f   碰撞对 %.0f   节点 %.0f"%[p.active_physics_bodies,p.physics_collision_pairs,p.nodes])
	lines.append("结构 %s   已破坏 %s\n建筑网格批次 %s   单元 %s   驻留瓦片 %s"%[_format(world.structures),_format(world.destroyed_registered),_format(world.architecture_mesh_batches),_format(world.structure_cells),_format(world.resident_tiles)])
	if world.streaming is Dictionary:
		lines.append("立面流式 %s / %s   等待 %s\n最近 CPU构建 %s ms / 上传 %s ms"%[_format(world.streaming.get("resident")),_format(world.streaming.get("limit")),_format(world.streaming.get("wanted")),_format(world.streaming.get("last_worker_ms")),_format(world.streaming.get("last_upload_ms"))])
	if world.material_roles is Dictionary: lines.append("统一材质：%s 个资源"%_format(world.material_roles.get("resources")))
	lines.append("载具 %s · %s"%[_format(s.vehicles),str(s.vehicle_kind) if s.vehicle_kind!=null else "步行"])
	if position is Array: lines.append("玩家 X %.1f   Y %.1f   Z %.1f"%[position[0],position[1],position[2]])
	if s.weapons is Dictionary:
		var effects: Dictionary=s.weapons.get("effects",{})
		lines.append("弹药池 %s / %s   爆炸池 %s / %s"%[_format(s.weapons.get("active_projectiles")),_format(s.weapons.get("projectile_capacity")),_format(effects.get("active")),_format(effects.get("capacity"))])
	lines.append("管线编译 Draw %.0f / Surface %.0f / Mesh %.0f\n后台优化 %.0f · 引擎累计计数"%[p.pipeline_draw,p.pipeline_surface,p.pipeline_mesh,p.pipeline_specialization])
	if s.last_spawn_profile is Dictionary:
		var spawn: Dictionary=s.last_spawn_profile
		lines.append("最近生成 %s：%s ms\n模型 %s / 占用缓存 %s / 净空 %s ms"%[_format(spawn.get("kind")),_format(spawn.get("total_ms")),_format(spawn.get("model_ms")),_format(spawn.get("occupancy_cache_ms")),_format(spawn.get("placement_ms"))])
	if s.render.headless: lines.append("Headless：渲染统计不可用于评价画面帧率")
	_stats.text="\n".join(lines)
	var enabled: Dictionary=s.render.enabled_flags
	var status: Array[String]=[]
	for name_pair: Array in [["SSAO","ssao_enabled"],["SSR","ssr_enabled"],["辉光","glow_enabled"],["雾","fog_enabled"],["体积雾","volumetric_fog_enabled"]]:
		status.append(name_pair[0]+" "+("开" if enabled.get(name_pair[1],false) else "关"))
	_flags.text=" · ".join(status)+"\n部分计数最多延迟 1 秒；不代表 GPU 耗时。"
	_tuning_changed(s.tuning)
	for key: String in _sliders:
		var spec: Dictionary=_diagnostics.limits()[key]
		var effect_enabled: bool=enabled.get(spec.get("feature",""),true)
		var zero_cycle: bool=s.cycle.base.has(key) and float(s.cycle.base[key])<0.000000001
		_sliders[key].editable=s.tuning.has(key) and effect_enabled and not zero_cycle
		_sliders[key].tooltip_text="当前时刻此项基础亮度为零；数值跟随昼夜变化" if zero_cycle else "此效果当前关闭；本面板不改变渲染功能开关" if not effect_enabled else "按各材质原值显示；拖动后统一调整这一玻璃参数" if s.tuning.get(key)==null and s.tuning.has(key) else ""

func _tuning_changed(current: Dictionary) -> void:
	for key: String in _sliders:
		if not current.has(key): continue
		if current[key]==null:
			_numbers[key].text="按各材质"
			continue
		_sliders[key].set_value_no_signal(current[key])
		_numbers[key].text=("%.6f" if key=="fog_density" else "%.2f")%float(current[key])

func _change(value: float, key: String) -> void:
	if not is_instance_valid(_diagnostics): return
	var result: Dictionary=_diagnostics.tune({key:value})
	_status.text="已实时应用 · 可随时恢复" if result.ok else "未应用："+JSON.stringify(result.rejected)

func _reset() -> void:
	var result: Dictionary=_diagnostics.reset_tuning()
	_status.text="已恢复本次环境的原始数值" if result.ok else "当前没有可恢复的环境"
	_refresh()
