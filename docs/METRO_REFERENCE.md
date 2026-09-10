# Barangaroo and Martin Place metro entrances

Reviewed 10 September 2026. This module creates original exterior geometry, stationary walkable escalators and a lower landing hall at each location. It does **not** implement running metro trains, the full underground platforms, paid-area operations or a complete station interior.

## Position and source evidence

The horizontal coordinate system is the existing game projection: origin −33.86, 151.2105; +X east and +Z south. Horizontal entrance points, building outline and escalator run endpoints come from `source/map-data/city.json` (OpenStreetMap snapshot base timestamp 10 September 2026, 10:26:34 UTC). Curated endpoints are retained in `source/map-data/metro_entrance_geometry.json`. Map-derived data is © OpenStreetMap contributors, ODbL, and is covered by the game's map attribution.

| Location | Mapped evidence | Vertical model |
| --- | --- | --- |
| Barangaroo / Hickson Road | entrance node 11445399049; escalator ways 1246220574, 1246220575, 1246220576 | game street datum 4.5m, landing −4.5m; **9m descent is estimated**, not a surveyed level |
| Martin Place / Hunter Street | entrance nodes 11553917358 and 11553917357; 1 Elizabeth footprint way 1241501338; northern escalator ways 1251022021–2024, 1251022035–2036, 1251022045–2046 | game street datum 4.5m, landing −7.5m; **12m descent is estimated**; upper generic building begins above a 40m atrium |

The northern Barangaroo escalator run is approximately 17.48m horizontally. The Martin Place runs are approximately 24m horizontally. OSM's level tags distinguish several real station levels; this first playable reconstruction brings the mapped northern runs to a common lower landing. It does not claim to reproduce the full vertical circulation scheme. The real Hunter Street sides are at different levels; the game's flat city datum simplifies that slope.

## References actually inspected

- [Sydney Metro: Barangaroo waterfront precinct, July 2024](https://www.sydneymetro.info/article/first-look-barangaroos-newest-waterfront-precinct).
- [Actual Barangaroo entrance photograph](https://www.sydneymetro.info/sites/default/files/styles/accelerator_social_media/public/2024-10/240711_%20Barangaroo%20Entrance_050.1.jpg.webp?itok=GwlA7lnP): viewed directly in the browser. Rounded silver roof edge, warm timber-look soffit, glazed sides, grey piers, station name panel and three escalators informed the model. The canopy footprint and height are photo-based estimates.
- [Barangaroo Interchange Access Plan](https://www.sydneymetro.info/sites/default/files/2022-09/Barangaroo-Station-IAP.pdf): northern entry and precinct access context. This 2022 plan predates opening; the 2024 actual photograph was used for the visible finished form.
- [Sydney Metro: Martin Place northern atrium](https://www.sydneymetro.info/article/martin-place-northern-atrium-and-escalators-make-progress): documents the 40m atrium and eight escalators in the northern precinct.
- [Sydney Metro: Martin Place Design and Precinct Plan](https://www.sydneymetro.info/media/document/37151): north-west and north-east Hunter Street entrances, integrated building and planted entrance hall.
- [WheelEasy: Ilumina](https://wheeleasy.org/explore/ilumina), [actual completed corner entrance photograph](https://files.wheeleasy.org/media/places/3827f53a-0cc7-4e9f-b2e3-6c3851648a71/Nn2IvcTiPKwM3GSuftKCTInPZRcGabmh.webp): viewed directly in the browser. Large white round columns, glass canopy/ribs, metal railings and station identification informed the street entrance details.

No reference photograph, texture or third-party model is copied into the distribution. These are reconstructions, not architectural as-built documents. The 1 Elizabeth upper building remains an ordinary mapped city model; this module is not a full detailed model of Macquarie's headquarters.

## Physical integration

`source/map-data/metro_excavations.json` is the source of the two terrain holes. The module's `excavation_polygons()` returns the matching XZ polygons. The map importer subtracts them from terrain and intersecting surface road/park/beach polygons. Underground mapped ways are not painted as surface roads. Martin Place's local floor has a matching triangulated opening; its generic building starts above the 40m atrium so it does not seal either street entrance.

`water_exclusion_rects()` returns two conservative water-shader clip rectangles. `contains_dry_volume(point)` prevents the player's underwater movement logic, and boat buoyancy, from treating these underground spaces as open water. The source and module rectangles are kept together; moving an entrance requires regenerating the map before release.

Each escalator uses an uninterrupted inclined collision support with individual horizontal tread geometry, yellow nosings, tread grooves, glazed balustrades, metal skirts and handrails. The inclined support avoids the small-box seam catches found on the bridge. The treads are stationary and can be walked in both directions. Lower halls have supporting floors, retaining walls, lighting and a clearly visible return route.

## Validation

```sh
# Isolated geometry plus real player movement, without loading the full city:
./tools/runtime/godot --headless --path game --script ../source/metro_entrance_test.gd
# Native visual review:
./tools/runtime/godot --path game --script ../source/metro_entrance_test.gd -- --capture
# Final production-world integration:
./tools/runtime/godot --headless --path game --script ../source/metro_entrance_test.gd -- --full-world
```

Tests query actual collision support and human capsule clearance along all eleven mapped escalator runs, check both Hunter Street approach paths and verify that a ground slab does not cap the opening. The actual production player walks down to each landing, jumps underground without becoming a swimmer, and walks back to the street using normal movement inputs. Native images are written under `reports/metro-refinement/`. Local geometry checks are not a substitute for the final production-world integration run after map regeneration.

The final regenerated production world passed all **16 assertions** on 10 September 2026 (`reports/metro-refinement/full-world.log`). All 869 sampled positions across the eleven escalator runs had collision support and clear human headroom; both mapped Hunter Street approaches were unobstructed. With normal movement inputs, the production player reached the Barangaroo landing at Y −4.509 and Martin Place landing at Y −7.509, jumped without entering swimming mode, and returned to street level at Y 4.491. The two excavation records in the compiled city map were checked against the final source polygons before this run. Native screenshots distinguish the isolated model in `local/` from the actual surrounding city in `full-world/`.
