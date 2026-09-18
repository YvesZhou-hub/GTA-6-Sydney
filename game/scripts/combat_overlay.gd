extends Control
## Draws the two combat readouts that belong on the screen edge rather than in a
## panel: arcs pointing at whoever just hit you, and a red rim when you are low.

var feel: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5


func _draw() -> void:
	if not is_instance_valid(feel) or not is_instance_valid(feel.game) or not feel.game.active: return
	var ratio: float = feel.health_ratio()
	if ratio < feel.VIGNETTE_AT and ratio > 0.0: _draw_rim(1.0 - ratio / feel.VIGNETTE_AT)
	var facing: float = float(feel.game.yaw)
	for hit: Dictionary in feel.hits():
		_draw_arc_marker(float(hit.heading) - facing, clampf(float(hit.time) / feel.HIT_SECONDS, 0.0, 1.0))


## Bands of translucent red along the edges; cheaper than a full-screen shader
## and it never tints what the player is aiming at.
func _draw_rim(strength: float) -> void:
	var depth := minf(size.x, size.y) * 0.16
	var bands := 6
	for i in bands:
		var t := float(i) / float(bands)
		var alpha := strength * 0.20 * (1.0 - t)
		var colour := Color(0.72, 0.12, 0.12, alpha)
		var inset := depth * t
		var thickness := depth / float(bands) + 1.0
		draw_rect(Rect2(0, inset, size.x, thickness), colour)
		draw_rect(Rect2(0, size.y - inset - thickness, size.x, thickness), colour)
		draw_rect(Rect2(inset, 0, thickness, size.y), colour)
		draw_rect(Rect2(size.x - inset - thickness, 0, thickness, size.y), colour)


## One arc at the screen angle the damage came from, fading as it ages.
func _draw_arc_marker(relative: float, life: float) -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.21
	var colour := Color(0.95, 0.35, 0.3, clampf(life, 0.0, 1.0) * 0.85)
	var points := PackedVector2Array()
	var span := 0.42
	for i in 13:
		var angle := relative - span * 0.5 + span * float(i) / 12.0
		points.append(centre + Vector2(sin(angle), -cos(angle)) * radius)
	draw_polyline(points, colour, 5.0, true)
