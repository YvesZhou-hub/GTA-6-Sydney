extends RefCounted
## One bundled font chain for startup, Controls, custom map drawing and Label3D.
## Install on the main thread before creating the loading screen or world labels.
## Keeping project gui/theme/custom_font empty also permits a clean first import:
## Godot 4.7.2 may otherwise notify ThemeDB from a font import worker.
const FONT_PATH := "res://assets/fonts/harbour_ui_font.tres"
const REGULAR: Font = preload("res://assets/fonts/harbour_ui_font.tres")

static func regular() -> Font:
	return REGULAR

static func install_defaults() -> void:
	var default_theme := ThemeDB.get_default_theme()
	if default_theme.default_font != REGULAR:
		default_theme.default_font = REGULAR
	if ThemeDB.fallback_font != REGULAR:
		ThemeDB.fallback_font = REGULAR

static func make_theme(size: int = 18) -> Theme:
	install_defaults()
	var result := Theme.new()
	result.default_font = REGULAR
	result.default_font_size = size
	return result
