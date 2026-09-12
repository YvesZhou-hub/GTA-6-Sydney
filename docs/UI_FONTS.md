# Bundled interface fonts

v0.1.8 fixes the missing “敌” glyph in the original vehicle names `Harbour Bastion · 无敌坦克` and `Aster F-27 · 无敌战斗机`. The names remain unchanged.

The previous `SystemFont` selected Avenir Next and relied on operating-system fallback despite listing PingFang SC and Arial. On the development Mac, an actual TextServer shaping probe returned an invalid font RID at both occurrences of “敌”, reproducing the user screenshot. A family-name list did not guarantee per-character coverage.

`ui_fonts.gd` now shares one bundled FontVariation resource: Noto Sans CJK SC Regular, followed by Noto Sans, Noto Sans Arabic and Noto Sans Math. The additional fonts cover existing names such as Kürtősh, ŋ, Arabic lettering and mathematical Fraktur characters in the map data. All five imported font files, including the separate caption Bold face, disable `allow_system_fallback`; the successful coverage checks therefore cannot silently borrow fonts installed on the test computer. Original binaries, pinned upstream URLs, hashes and SIL OFL 1.1 licenses are documented in [FONTS.md](../licenses/FONTS.md).

`bootstrap.gd` installs the shared font on the main thread before creating any loading labels or the city. `main.gd` uses the same resource for its theme. `ThemeDB`’s default theme and fallback font also supply Controls outside the main theme and unconfigured Label3D nodes. Maps that draw text with `get_theme_default_font()` inherit that resource. Themes may be separate; their Font resource is not duplicated per widget.

The project’s `gui/theme/custom_font` setting stays empty. In Godot 4.7.2, setting it to an as-yet-unimported font chain caused a first-import worker to notify ThemeDB off the main thread and exit 139. Installing the font at bootstrap avoids that import-time dependency. A fresh, isolated font project with no `.godot` directory imported the same font assets successfully, with no ERROR or WARNING. This verifies clean font import, not a full-city render.

## Verification

From the repository root:

```sh
tools/runtime/godot --headless --editor --path game --import --quit
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/ui_font_test.gd
```

The focused fixture instantiates the production `setup_ui()` and vehicle menu with lightweight world/life holders. It does not build the city, open a user save, or spawn a vehicle. Its 42 checks passed with no ERROR or WARNING:

- The full character superset of production `.gd` files: 824 unique characters, including 672 Han characters.
- All selected OSM display names: 5,300 road records and 5,103 place records.
- Other public asset JSON text, including facility and shop directories: 112 unique characters, including 20 Han characters.
- 855 distinct characters across these corpora, with no missing glyphs; these counts overlap and must not be summed.
- Actual TextServer shaping for both vehicle names, accented Latin, Arabic, Fraktur and interface symbols. An unmapped-codepoint negative control confirms the test detects missing glyphs.
- 28 production menu/HUD Controls share the bundled font; map and navigation drawing use it too. All 11 vehicle buttons fit their allocated width.
- Default Label3D layout matches an explicitly assigned bundled font. Original font/license hashes match upstream binaries.

Reports are written to `reports/ui-font/checks.json` and the redirected headless log. Report hashes identify the sources scanned during that run; rerun after changing interface strings or font data.

The root task separately ran the actual renderer with:

```sh
tools/runtime/godot --path game --fixed-fps 60 --script ../source/ui_font_test.gd -- --capture
```

The two focused viewport images were individually inspected: “敌” renders correctly in both production vehicle rows and the larger reference labels; no horizontal text clipping or overlapping rows was visible. The original menu scroll behavior is retained. This native run had 44 checks: the earlier 41-check fixture plus three capture assertions. The later JSON-directory coverage added one headless check without changing any font, layout or capture code; the native result is not relabeled as a 45-check run. `reports/ui-font/visual-review.json` records the exact earlier native fixture hash, later source hash and image hashes.

These checks cover current authored strings and actual selected map names. They do not promise every Unicode character, every possible future player-entered name or an entire game performance benchmark. Future content additions should run the coverage fixture before release.

## Engine references

- [Godot FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html): `allow_system_fallback` controls platform fallback.
- [Godot dynamic font importer](https://docs.godotengine.org/en/stable/classes/class_resourceimporterdynamicfont.html): bundled OTF/TTF input, fallback resources and import flags.
- [Godot ThemeDB](https://docs.godotengine.org/en/stable/classes/class_themedb.html): shared default theme and fallback font.
- [Godot Label3D implementation](https://github.com/godotengine/godot/blob/master/scene/3d/label_3d.cpp): default-font lookup through the global theme context; also verified by the fixture’s runtime layout comparison.

## Final exported-App hook

`game/scripts/ui_font_validation.gd` exposes `run(main)` for the root task’s `--ui-font-qa` dispatch. The flag must set `qa_running` before normal main initialization, and dispatch after production world/UI construction. The validator refuses an active player slot, never calls `new_world`, and never reads source scripts from the compiled PCK. It checks live font resources, shapes the real strings, opens actual title/vehicle/map menus and reveals both tank/fighter rows inside the scroll viewport.

The report is `user://ui-font-qa/report.json` with `passed`, dynamic `count`, `checks`, `native`, `screenshots`, `user_saves_touched` and `settings_files_written`. A native run requests `01-title-menu.png`, `02-tank-fighter-menu.png` and `03-map-fonts.png` in that directory and prints `UI_FONT_QA_COMPLETE`. The new validator’s 29 headless checks passed using production UI methods with lightweight holders; this is interface validation, not an exported full-world result. The final App run remains a separate root-owned gate. The fixture does not claim that directly invoking a menu handler tests physical keyboard/mouse input.
