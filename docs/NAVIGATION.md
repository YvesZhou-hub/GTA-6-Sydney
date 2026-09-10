# Geographic navigation

The full map and minimap use the same local metre coordinates as the playable world: east is +X, south is +Z and north is upward on the default map. Roads, coastlines and building footprints come from the compiled, attributed city map. Airport paving and the hatched intervening terrain remain simplified game geometry.

Click a landmark symbol or its visible label to select its public arrival point. A landmark may provide `map_position` for the building symbol separately from its `position` arrival point. At street zoom, the visible OpenStreetMap place labels can also be selected. A short click elsewhere sets a free waypoint at that geographic coordinate. Dragging pans; a drag of six pixels or more never sets a pin, including a release displacement without intermediate motion events. The map header and footer cannot place pins. Right-click in the map or use **清除标记** to remove the destination.

The gold flag and dashed line show the selected destination and direct direction. They are not a computed street route and do not certify pedestrian, boat or aircraft access. Selecting a place does not move the player or create a vehicle. Arbitrary pins use the common map ground datum; terrain clearance and accessible public entrances remain separate from map coordinates.

The minimap stays centred on the player. Its green arrow shows heading; the gold destination moves to an edge arrow when it lies outside the current map extent. The displayed distance is horizontal straight-line distance. It defaults to north-up; `north_up=false` rotates the map with the player's Godot yaw. Clicking the minimap requests the full map.

Integration keeps the existing `landmark_selected(key)` signal. The full map adds `waypoint_selected(position, title)` and `navigation_cleared`. The minimap exposes `clicked` and receives its map through `configure(map_panel)`. Populate the full map's `landmarks`, `anchors` and `runway_data` before configuring the minimap. Both controls accept `sync_navigation(snapshot)` with `player_position`, `player_heading`, `target_key`, `target_position` and `target_name`.

Only the first full map reads and converts `city_map.json`. Additional map controls and the minimap share the same mesh resources and packed geometry arrays. The minimap records its terrain drawing commands once; following the player changes the terrain node transform and the small overlay, at most ten times per second when its public variables are assigned directly. It does not build a second 3D scene or reread the geographic database per frame.

The focused fixture is [navigation_map_test.gd](../source/navigation_map_test.gd). Its 22 checks cover projection, zoom anchoring, separate building/entrance markers, free pins, drag suppression, chrome exclusion, place-label selection, clearing, north/east/heading-up bearings, arrival, minimap opening and shared cache reuse. It uses no player saves and does not construct the 3D city.

All 22 checks passed headless and in the native Metal renderer. The native map/minimap image was visually inspected; this component test does not replace the complete-world HUD and input integration checks. Run `./tools/runtime/godot --headless --path game --script ../source/navigation_map_test.gd` from the repository root; omit `--headless` for the native fixture and its screenshot.
