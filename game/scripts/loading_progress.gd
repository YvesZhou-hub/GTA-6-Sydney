extends RefCounted
## The city builds on the main thread for several seconds. Between build stages
## this redraws the loading screen and handles window events, so the OS does not
## mark the game as not responding and players can see how far loading has got.
## Without a listener (tests, tools) every report is a no-op.

static var _listener := Callable()
static var _last_draw := 0
static var quit_requested := false


static func listen(callback: Callable) -> void:
	_listener = callback
	_last_draw = 0
	quit_requested = false


static func stop() -> void:
	_listener = Callable()


static func active() -> bool:
	return _listener.is_valid()


static func report(fraction: float, stage: String) -> void:
	if not _listener.is_valid(): return
	# One redraw costs a few milliseconds, so long loops can report every item.
	var now := Time.get_ticks_msec()
	if now - _last_draw < 60: return
	_last_draw = now
	_listener.call(clampf(fraction, 0.0, 1.0), stage)
	if DisplayServer.get_name() == "headless": return
	DisplayServer.process_events()
	# Swap buffers: drawing without presenting leaves the window showing 0%.
	RenderingServer.force_draw(true)
