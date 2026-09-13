extends RefCounted
## stop() schedules playback deletion in the audio mixer. Fast process frames
## alone do not prove its reference has been released by the main-thread GC.

static func _remaining(playbacks: Array[WeakRef]) -> int:
	var count := 0
	for playback in playbacks:
		if playback.get_ref() != null: count += 1
	return count

static func stop_and_drain(branch: Node, timeout_ms: int = 1000) -> Dictionary:
	var started := Time.get_ticks_msec()
	var playbacks: Array[WeakRef] = []
	var pending: Array[Node] = [branch]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			if node.has_stream_playback():
				# Never keep a strong playback reference across the await below.
				playbacks.append(weakref(node.get_stream_playback()))
			node.stop()
			node.stream = null
		for child in node.get_children(): pending.append(child)
	var remaining := _remaining(playbacks)
	var deadline := started + clampi(timeout_ms, 0, 1000)
	while remaining > 0 and Time.get_ticks_msec() < deadline:
		await branch.get_tree().process_frame
		remaining = _remaining(playbacks)
	return {"tracked": playbacks.size(), "remaining": remaining,
		"elapsed_ms": Time.get_ticks_msec() - started, "complete": remaining == 0}
