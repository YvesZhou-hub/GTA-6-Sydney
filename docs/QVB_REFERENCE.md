# QVB public Grand Walk reconstruction

This is a bounded reconstruction of the Queen Victoria Building's exterior and public ground-floor arcade. It is not a claim of a complete 1:1 QVB survey or a reproduction of current tenants.

## Sources actually inspected

- [QVB official architecture/history](https://www.qvb.com.au/about), accessed 12 September 2026: the central copper outer dome and separate glass inner dome, Romanesque arches and restored floor/rail details.
- [QVB official refurbishment account](https://www.qvb.com.au/centre-info/queen-victorias-makeover), accessed 12 September 2026: 2009-era white arches, coloured interior, shopfront and entrance alterations.
- [City of Sydney, Celebrating 120 years of the QVB](https://news.cityofsydney.nsw.gov.au/articles/celebrating-120-years-of-the-queen-victoria-building), published 24 July 2018, updated 11 July 2023: nominal 58 m cupola and approximately 19 m exterior dome diameter.
- [City archival longitudinal section, 1892](https://images.ctfassets.net/kcmyw5u53voi/5K8mkfjyEgaoeoKKWUU8wE/53754d59ae1f8ed1138aefac81082c51/QVB_2.jpg), linked by that official article: the actual 1604 × 949 image was viewed with `view_image`. Intermediate levels and separate inner/outer dome widths were read from the drawing, cross-checked against the 2018 photographs and CMP structural description. The ignored `reports/qvb-height-review/vertical-calibration-review.json` records the original image hash and pixel trace points.
- [City development assessment, 4 December 2006, PDF p14](https://meetings.cityofsydney.nsw.gov.au/Data/Planning%20Development%20and%20Transport%20Committee/20061204/Agenda/061204_pdtc_item07.pdf): existing dome nominal 58 m, RL79.
- [Urbis planning report, 2019, PDF pp7/29](https://www.cityofsydney.nsw.gov.au/-/media/corporate/files/2020-07-migrated/files_p/planning-report.pdf?download=true): spire RL80.45. This absolute level is **not** used as a local building height; the attached survey section is only a cover, not the actual survey.
- [City of Sydney / Urbis Conservation Management Plan, final issue 8 August 2019](https://meetings.cityofsydney.nsw.gov.au/documents/s40891/Attachment%20C1%20-%20Conservation%20Management%20Plan%20-%20Queen%20Victoria%20Building%20-%20prepared%20by%20Urbis.pdf). The reference photographs used are explicitly credited **Urbis, 2018**, not contemporary 2026 photography.

The downloaded PDF was rendered with `pdftoppm`; the actual rendered images were opened with `view_image`, not judged from text extraction alone:

| PDF page | Printed section page | Viewed evidence | Implemented features |
| --- | --- | --- | --- |
| 21 | 9 | George Street elevation | Paired tall round-headed windows, sandstone mouldings, continuous awning, roof drum and lantern |
| 25 | 13 | York and Market street entrances | Dark entrance columns, wheel window, coloured shopfront highlights |
| 30 | 18 | Central George/York entries | Cross-building public passage, contrasting tiled floor and pendant lights |
| 31 | 19 | Ground-floor arcade | White column arches, galleries/railings, glazed roof and long axial views |
| 34 | 22 | Upper arcade and inner dome | Roof framing and separate coloured glass inner dome |

The photographs/PDF remain in ignored `reports/qvb-reference/` for research only. No third-party picture, texture, font or PDF is packaged into the game. All delivered surfaces are original procedural geometry/materials.

## Position, scale and limits

The 25 OSM **records/parts** form one QVB building; they are not 25 separate buildings. Source `way/40717424` remains centred at world `(-352.277, 4.5, 1309.448)`. Its actual 12-point boundary is retained for the floor and clipping the main shop wings. The building axis is approximately 0.0431 radians east of map south; the model spans approximately 188 by 30 metres. All 20 minor dome centres and the main dome/lantern centres retain their OSM positions. The exact 25 source identifiers are available from `excluded_way_ids()`.

The former levels-derived 34.65 m lantern envelope was demonstrably too low and has been replaced. The height configuration is explicit in `HEIGHT`; it separates retail floors, glass roofing, the central masonry transition, windowed drum, copper shell and lantern. No whole-building scale operation was applied.

| Feature | Nominal local height above ground / span | Basis |
| --- | --- | --- |
| First / second retail gallery floor | 5.7 / 10.9 m | 1892 section ratio |
| Long arcade low eaves / glass lower edge | 15.8 / 17.0 m | 1892 section ratio |
| Upper sloping glass / raised clerestory ridge | 21.4 / 23.0 m | 1892 section ratio; transverse shape from 2018 photographs |
| Square masonry transition | 21.5–26.5 m | Approximately 5 m spacer in CMP, section level |
| Inner coloured-glass dome | 26.5–32.4 m; diameter 11.3 m | Separate inner dome measured in the historical drawing |
| Windowed outer drum | 26.5–35.4 m | 1892 section ratio |
| Main copper shell | 35.4–47.9 m; exterior diameter 19 m | Official diameter and historical section levels |
| Lantern, cap and finial | 47.9–58 m | Official nominal cupola height, historical proportions |
| End turret eaves / end small dome tips | 23.9 / 31 m | 1892 section ratio, current-photo comparison |
| Intermediate small dome tips | 28 m | 1892 section ratio, current-photo comparison |

Intermediate dimensions carry approximately **±1 m or greater uncertainty** from historical/as-built differences, paper distortion and drawing interpretation. They are not modern surveyed FFLs. The nominal 58 m height and approximately 19 m exterior span are official published quantities; the 2019 RL80.45 endpoint is recorded separately and is not mixed into the game's flat terrain datum. The approximately 11.3 m inner glass span is distinct from the 19 m outer copper dome. The current model preserves all OSM centres while correcting roof geometry based on these sources.

The 6 m arcade rhythm, 12.6 m central aisle width, transverse clerestory slopes, moulding relief, window/glass subdivisions and lantern details remain photographic approximations. The minor copper domes now rise on separate masonry turrets instead of remaining embedded as shallow bumps in the main roof. The short Market/Druitt elevations use paired long windows under two arches, as described by the CMP; wheel windows are restricted to the George/York central entries.

The ground substrate remains at the existing 4.5 m datum. The authored tile slab occupies local -0.18 to +0.04 m, creating a four-centimetre threshold, eliminating coplanar rendering and ambiguous duplicate terrain/floor physics. This does not change the city terrain. The CMP explicitly documents up to approximately 1.5 m of actual transverse ground-floor variation; that elevation is **not** reproduced here because the surrounding street model has no verified matching elevations.

The model opens the north–south arcade and central George–York crossing. Shop interiors remain closed; there are no invented tenant names or private rooms. Existing basement light wells, basement shopping, vertical circulation/escalators, exact historic stairs, clocks, statues and sculptural carving are not reproduced. In particular, the current continuous tiled slab simplifies the real ground-floor void layout. Upper galleries and the inner glass dome provide the observed architectural view; no upper-floor public route is advertised. These limits preclude a complete 1:1 claim.

## Integration and save compatibility

`game/scripts/qvb_public.gd` provides `build`, `metadata`, `footprints`, `excluded_way_ids`, `legacy_damage_ids`, `capture_views` and `walk_routes`. It depends only on the existing `city_landmarks.gd` geometry helpers and does not preload `city_map.gd`.

All **39 existing OSM storey-group damage IDs** are preserved. The former full-height extrusions become shop wings, roof drums and dome skins, leaving the public passages genuinely empty. The `city/qvb/public_floor` ID owns the tile slab. Three additional independently destructible components own the continuous glass roof (`city/qvb/roof_glazing`), square-to-round dome roof connection (`city/qvb/roof_transition`), and the physically arched George/York entrance walls (`city/qvb/entry_shell`). Copper ribs belong to the upper dome damage component. The shared integration reserves all 25 records and classifies their retained IDs as custom physical shells for migration; no generic solid OSM prism should be generated over this arcade.

Metadata places the navigation arrival at the tested Market Street approach, separate from the map label at the building centre. Four authored capture cameras cover George Street/dome, Market entry, Grand Walk and inner dome. Two routes run north–south and George–York; the local test walks each route in both directions.

## Verification

Run from the repository root:

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/qvb_public_test.gd
```

The fixture builds QVB and clipped **real OSM land** only. It also traces actual final mesh triangles to verify that exterior relief, arched windows, interior arches and the coloured glass inner dome survive rendering, checks 18 overhead glass-roof collision samples and six dome connection samples, tests the Market doorway curved shoulder opening, and destroys/restores the two closed roof skins. It checks the 39 legacy IDs independently against the original snapshot's base/wall-height/parent-part policy, actual collision/render equality, triangle winding/degeneracy, generic-building exclusions, 93 standing-capsule/support stations, four continuous production `HarborPlayer` walks, five actually settled migration poses and their 6 cm buried counterexamples, and dome destruction/restoration. It also records current model/test/migration/integration hashes, component and triangle counts in `reports/qvb-public/checks.json`.

This agent does not run GPU/native capture. The main application must still verify these four views with the real adjacent city, final lighting and shared production batches.


## Exported visual failure and geometry correction

The first exported v0.1.7 candidate passed traversal checks but failed actual visual review: the long arcade showed outdoor sky where the roof should be, the central dome had unclosed sky gaps, and the street and interior arches were absent/hidden. Its unmodified screenshots remain in ignored `reports/release-v017-candidate-unenclosed-qvb/precinct-screenshots/` and the local `reports/qvb-public/visual-v1/` comparison directory.

The primary rendering defect was a mixture of indexed BoxMesh/CylinderMesh primitives and unindexed procedural triangle faces in the same SurfaceTool. Once an index array existed, later unindexed arch/window/glass vertices were not drawn. QVB now expands every source primitive to one consistent unindexed triangle stream locally, including its normals and UVs. This repairs the actual final render geometry; collision-only success is not used as visual evidence.

The correction also moves the relief to the real OSM-derived facade edge, gives Market/Druitt doors a closed curved spandrel above an open doorway, and moves the interior white arches ahead of the closed private shop mass. The roof uses closed physical panes over segmented slopes and a raised central clerestory. Trusses, ties and pane frames are below the glass so they remain visible from the public arcade. A high square-to-round masonry transition with a tapering inner opening leads to the separate, narrower coloured-glass dome; it replaces the initial low flat red annulus. The closed connection prevents outdoor sky around the dome without an opaque ceiling over that glass. The new roof skins and their ribs share damage ownership, so a destroyed roof cannot leave floating intact framing.

For a coordinated **local** native preview (the root agent owns GPU scheduling), run the same fixture without `--headless`, adding `-- --capture`. It saves four images under `reports/qvb-public/v4-preview/` after applying the production structure batching. A local preview still cannot establish final-city visibility, real adjoining building occlusion or measured architectural proportions.


The v4 local headless run passes **63 checks** with **43 components**, **39 legacy IDs**, and **321,332 triangles**. The larger geometry count includes exposed roof trusses, the re-proportioned windowed outer drum and 20 independently positioned minor turret/dome assemblies. The fixture now checks every vertex is used by its final mesh, confirms the actual 58 m geometry and distinct inner/outer dome extents, and verifies the two retail gallery elevations independently. Its exact current model/test/migration hashes and nine visual geometry probe records are in `reports/qvb-public/checks.json`; `reports/qvb-public/headless-height-v4.log` records the zero-warning headless result. Native/full-city visual acceptance remains a separate root-agent step and is not implied by this count.

A faster coordinated native capture is available after the complete headless run: `tools/runtime/godot --path game --script ../source/qvb_public_test.gd -- --capture-only`. This mode explicitly runs **no checks**; it builds the same QVB fixture and production batches and writes a capture manifest with model/fixture hashes, camera positions and image hashes. It avoids repeating thousands of traversal physics frames while checking the rendering.


The actual v3 native inspection caught a second placement defect: minor-turret collar rings were correctly owned by their respective legacy IDs but their origin-based helper geometry lacked the individual turret-centre translation. They overlapped under the main glass dome as a thick pale ring. Pixel-to-mesh rays from the captured camera identified `way/568422316` and `way/568422317` as the wrongly placed first-visible surfaces; the ignored `reports/qvb-public/ring-probe.log` records the counterexample. Each collar is now translated to its own retained OSM centre. The test checks every minor-dome render mesh remains within that turret's plan radius, and inner-glass visibility is tested against **all 43 components**, so unrelated misplaced geometry cannot escape the check. The spacer's outer stone surface and inner red lining are also checked from opposite directions.
