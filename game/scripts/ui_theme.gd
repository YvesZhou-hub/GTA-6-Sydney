extends RefCounted
## One place for the menu and HUD look: colours, button states, focus outlines
## and the panel shapes. Type variations keep call sites readable, for example
## a primary action is a Button with theme_type_variation "PrimaryButton".

const Fonts = preload("res://scripts/ui_fonts.gd")

const INK := Color("f1efdc")
const INK_SOFT := Color("bcc9c6")
const ACCENT := Color("8ed1c1")
const GOLD := Color("e3c46e")
const SURFACE := Color(0.06, 0.13, 0.15, 0.94)
const SURFACE_DEEP := Color(0.03, 0.08, 0.1, 0.96)
const RAISED := Color(0.10, 0.21, 0.23, 0.96)
const RAISED_HOVER := Color(0.15, 0.32, 0.34, 0.98)
const RAISED_PRESSED := Color(0.08, 0.17, 0.19, 0.98)


static func box(color: Color, radius: int, margin_x := 18, margin_y := 13) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


static func build(size: int = 18) -> Theme:
	var theme := Fonts.make_theme(size)
	theme.set_color("font_color", "Label", INK)
	_buttons(theme)
	_inputs(theme)
	_panels(theme)
	return theme


## Every button state is visible: hover lifts, pressed sinks, focus draws the
## outline controller players rely on, disabled reads as unavailable.
static func _buttons(theme: Theme) -> void:
	var normal := box(RAISED, 9)
	# A quiet accent edge on the left makes a list of actions readable at a glance.
	normal.border_color = Color(ACCENT, 0.32)
	normal.border_width_left = 3
	theme.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate()
	hover.bg_color = RAISED_HOVER
	hover.border_color = ACCENT
	theme.set_stylebox("hover", "Button", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = RAISED_PRESSED
	pressed.border_color = ACCENT
	theme.set_stylebox("pressed", "Button", pressed)
	var focus := normal.duplicate()
	focus.bg_color = Color(RAISED_HOVER, 0.6)
	focus.set_border_width_all(2)
	focus.border_width_left = 3
	focus.border_color = ACCENT
	theme.set_stylebox("focus", "Button", focus)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.09, 0.14, 0.15, 0.7)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.66, 0.65, 0.7))

	# The two starting choices and other main actions carry the warm fill.
	theme.add_type("PrimaryButton")
	theme.set_type_variation("PrimaryButton", "Button")
	var primary := box(GOLD, 9)
	primary.border_width_left = 3
	primary.border_color = Color("f3dfa4")
	theme.set_stylebox("normal", "PrimaryButton", primary)
	var primary_hover := primary.duplicate()
	primary_hover.bg_color = Color("f0d68a")
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	var primary_pressed := primary.duplicate()
	primary_pressed.bg_color = Color("caa94f")
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	var primary_focus := primary.duplicate()
	primary_focus.set_border_width_all(2)
	primary_focus.border_width_left = 3
	primary_focus.border_color = Color("ffffff")
	theme.set_stylebox("focus", "PrimaryButton", primary_focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(state, "PrimaryButton", Color("15302f"))
	theme.set_font_size("font_size", "PrimaryButton", 19)

	# Quiet actions (back, cancel) stay outlines so they do not compete.
	theme.add_type("GhostButton")
	theme.set_type_variation("GhostButton", "Button")
	var ghost := box(Color(1, 1, 1, 0.04), 9)
	ghost.set_border_width_all(1)
	ghost.border_color = Color(1, 1, 1, 0.16)
	theme.set_stylebox("normal", "GhostButton", ghost)
	var ghost_hover := ghost.duplicate()
	ghost_hover.bg_color = Color(1, 1, 1, 0.10)
	ghost_hover.border_color = ACCENT
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", ghost_hover)
	var ghost_focus := ghost.duplicate()
	ghost_focus.set_border_width_all(2)
	ghost_focus.border_color = ACCENT
	theme.set_stylebox("focus", "GhostButton", ghost_focus)
	theme.set_color("font_color", "GhostButton", INK_SOFT)
	theme.set_color("font_hover_color", "GhostButton", INK)


static func _inputs(theme: Theme) -> void:
	var field := box(Color(0.04, 0.1, 0.12, 0.95), 8, 14, 11)
	field.set_border_width_all(1)
	field.border_color = Color(1, 1, 1, 0.14)
	theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate()
	field_focus.border_color = ACCENT
	field_focus.set_border_width_all(2)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.68, 0.74, 0.73, 0.7))
	theme.set_color("caret_color", "LineEdit", ACCENT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var option := box(Color(0.07, 0.16, 0.18, 0.96), 8, 14, 9)
		option.set_border_width_all(1)
		option.border_color = ACCENT if state in ["hover", "focus"] else Color(1, 1, 1, 0.12)
		theme.set_stylebox(state, "OptionButton", option)
	theme.set_color("font_color", "OptionButton", INK)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(1, 1, 1, 0.12)
	slider.set_corner_radius_all(3)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider)
	var grabber_area := slider.duplicate()
	grabber_area.bg_color = ACCENT
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)


static func _panels(theme: Theme) -> void:
	theme.add_type("CardPanel")
	theme.set_type_variation("CardPanel", "PanelContainer")
	var card := box(SURFACE, 14, 24, 20)
	card.border_color = Color(1, 1, 1, 0.07)
	card.set_border_width_all(1)
	theme.set_stylebox("panel", "CardPanel", card)
	theme.add_type("ModalPanel")
	theme.set_type_variation("ModalPanel", "PanelContainer")
	var modal := box(SURFACE_DEEP, 18, 30, 26)
	modal.border_color = Color(1, 1, 1, 0.08)
	modal.set_border_width_all(1)
	modal.shadow_color = Color(0, 0, 0, 0.45)
	modal.shadow_size = 18
	theme.set_stylebox("panel", "ModalPanel", modal)
	theme.add_type("SectionLabel")
	theme.set_type_variation("SectionLabel", "Label")
	theme.set_color("font_color", "SectionLabel", ACCENT)
	theme.set_font_size("font_size", "SectionLabel", 15)
	theme.add_type("TitleLabel")
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("font_color", "TitleLabel", INK)
	theme.set_font_size("font_size", "TitleLabel", 38)
	theme.add_type("QuietLabel")
	theme.set_type_variation("QuietLabel", "Label")
	theme.set_color("font_color", "QuietLabel", INK_SOFT)
	theme.set_font_size("font_size", "QuietLabel", 15)
