# v0.1.0 historical harbour construction notes

**Historical record from the initial preview, retained for provenance only.** The building counts, geometry, coverage and performance samples below describe v0.1.0 and have been superseded. Current coverage and uncertainty are documented in [CITY_DATA](../docs/CITY_DATA.md); current bridge and Opera models in [BRIDGE_REFERENCE](../docs/BRIDGE_REFERENCE.md) and [OPERA_REFERENCE](../docs/OPERA_REFERENCE.md). Use [TESTING](../docs/TESTING.md) for current build-specific validation. The old development log/probe filenames mentioned below are historical, are not public reproduction commands, and are not included in this release.

Last verified: 10 September 2026. This is a playable interpretation, not a surveyed digital twin. The original runtime source is `game/scripts/harbor_world.gd`; shoreline/road coordinates are in `game/assets/world_geography.json`.

## Reference frame and source data

Origin: WGS84 latitude -33.8600, longitude 151.2105. +X east, +Z south, +Y up. The small-area conversion uses 92,400 m per longitude degree and 111,320 m per latitude degree. Mean water is Y=0. This local tangent-plane approximation is adequate for geographic relationships around the harbour; it is not a navigation product.

OpenStreetMap water relation **1252425** (Sydney Harbour) supplies the connected coastal outline. Retained outer member ways reconstruct the south shoreline through Walsh Bay, Dawes Point, Sydney Cove, Bennelong Point and Farm Cove, and the north shoreline through Milsons Point/Kirribilli. Curves are simplified approximately 4 m south/5 m north. Both source extract and transformed data are included under the ODbL. No online map tiles, aerial photographs or streamed city models are shipped.

Named OSM road ways supply George Street, Hickson Road, Cumberland Street, Macquarie Street, Alfred Street, Broughton Street and Olympic Drive. The original Bradfield Highway ways 171978153/388949144 informed the bridge axis. The complete responses, including the exact retrieved geometry and source metadata, are retained in `source/world_osm_reference.json` and `source/world_osm_water.json`.

## Reliable reference facts and their use

| Source | Confirmed fact | Runtime interpretation |
|---|---|---|
| [Transport for NSW, A Short History](https://www.transport.nsw.gov.au/system/files/media/documents/2023/harbour-bridge-history.pdf) | Main span 503 m, deck width 49 m, highest arch point 134 m, shipping clearance 49 m, full length including approaches 1,149 m | 503 m main span, 49 m deck, arch top 134 m, deck underside 49 m. Approaches deliberately extended to meet gameplay grade. |
| [Transport for NSW heritage framework](https://www.transport.nsw.gov.au/sites/default/files/media/documents/rww/projects/01documents/sydney-harbour-bridge/shb-detailed-heritage-framework.pdf) | Paired 28-panel trusses and suspended road/rail deck | Original two 28-panel arch meshes with uprights, diagonal members, hangers and lateral bracing. Rail operations are not simulated. |
| [NSW Planning, Opera House internal escalators assessment](https://majorprojects.planningportal.nsw.gov.au/prweb/PRRestService/mp/01/getContent?AttachRef=MP07_0142%2120190821T023142.022+GMT) | Opera House 183 m long/120 m wide, principal halls and smaller restaurant shell on a podium | Original unequal paired hall/shell groups, podium, southern stairs and broadwalk. The roof is an artistic geometric reconstruction, not a copy of construction drawings. |
| [Sydney Opera House, Jørn Utzon](https://www.sydneyoperahouse.com/our-story/jorn-utzon) | Side-by-side halls and sculptural harbour-facing shells | Orientation, hall hierarchy and visible silhouette informed the mesh design. |
| [Sydney Opera House, Tubowgule](https://www.sydneyoperahouse.com/our-story/tubowgule) | Bennelong Point is a modified headland with significant First Nations history | Real geographic name retained, without inventing historical dialogue or cultural authority. |

The references above were read for factual architectural context. Their photography, prose, technical drawings and PDF layouts have not been imported as distributable art.

## Traversable implementation

Main bridge: arch south endpoint (-83,54,-662), north endpoint (149,54,-1109). The full drivable/walkable approach runs from (-325,4.5,-194) to the south end, crosses the harbour, and continues from the north end to (340,4.5,-1510). Road and separated foot areas share physical geometry, with colliding guardrails and persistent removable deck segments. All eleven sampled main-deck raycasts returned a supporting surface at approximately 54 m.

Key walkable anchors: personal studio (-335,5,-28), Circular Quay (70,5,165), Opera House forecourt (414,5,-151), The Rocks (-210,5,-175), north shore (302,5,-1218), Walsh Bay marina (-545,3,-410), and the fictional local helipad (-410,5,420). The studio is an actual furnished, accessible interior, with adjacent open garage, storage furnishings and roof stair. There are low floating pontoons and sloped gangways on both shores. Coastal retaining walls have collision to stop boats passing beneath solid land.

The detailed harbour content covers approximately X=-900..1100, Z=-1750..750, with lower-detail modeled shore/skyline extensions. Water covers approximately 40 km × 40 km, using denser wave geometry at the harbour and coarser geometric patches outside. The separate airport module owns the southward city corridor and airport; this harbour module adds no land south of Z=1350.

## Explicit gameplay changes and remaining fidelity limits

- Most quays and streets use a common 4.5 m base elevation. Observatory Garden supplies a modeled, physically traversable rise to approximately 23.5 m. This is not an elevation survey; real street grades and the entire Rocks sandstone escarpment are not reproduced.
- Bridge approach geometry and lane allocation are simplified for continuous play. The arch/main deck dimensions are factual references, while approach routes, maintenance access, lane count and damage parameters are game design.
- The Opera House shell model has seven grouped forms, eight removable bands per form, ribs and glazing; its maximum modeled height is around 61 m rather than the real landmark's approximately 67 m. Hall dimensions, shell curvature and steps are an approximation. Its interior auditoria are not reproduced.
- Ordinary buildings, storefront businesses, skyline towers, home, garage, helipad and service streets are original fictional infill. They are not parcel-by-parcel reconstructions or claimed real businesses.
- No complete Manly, Bondi, CBD or outer harbour districts are implied by the distant landscape. The original source geography is available for future expansion, but the modeled outer landscape is deliberately lower detail.

## Damage, persistence and performance architecture

Facade bays, floor/roof slabs, Opera shell/glass bands, bridge deck/truss/pylon pieces and key service buildings have stable component identifiers. Impacts accumulate energy against component strength. Severe local impacts remove the corresponding visible geometry and collision; both `destroyed` and partial damage persist. Up to 96 important debris pieces have collision and saved transforms. Small excess pieces are retired; persistent architectural holes are never retired by visibility changes.

Static architecture is batched by material in 160 m cells. Every damage component keeps its own collider and intact source mesh, while the displayed cell mesh combines those components. Only dirty cells rebuild after impact/repair. Component IDs for generated urban buildings include their grid coordinates, so adding a different grid plot does not renumber neighboring objects. Repair restores each source material, including facade windows, rather than replacing every surface with generic masonry.

The independent development probes in `source/world_physics_probe.gd` and `source/world_visual_probe.gd` verify anchor support, eleven bridge samples, damage/save/repair consistency and rendered geometry. Their PNGs/logs are engineering evidence from the project; they must not be presented as screenshots of the exported application. Final native application evidence belongs to the root delivery tests.

Initial unbatched aerial view reached ~29,222 draw calls and ~34 FPS. After batching, the 113-building development scene measured ~760 draw calls/~102 FPS from the same aerial camera on Apple M4, Metal Forward+, 1440×900. The final denser scene is measured separately in `source/world_visual_probe.log`; these short isolated samples are not a sustained full-game 60 FPS certification.

Final development sample: **339 buildings / 13,437 damage components**. At 1440×900 on Apple M4 / Metal Forward+, the bridge sample reported 98 FPS/329 draw calls, street 107 FPS/860 draw calls, aerial harbour 117 FPS/1,168 draw calls and warmed Opera House 102 FPS/251 draw calls. The initial Opera sample was 39 FPS during first-view startup/warmup. These are single engine FPS snapshots after short camera dwells, not percentile benchmarks and not a substitute for full-game stress testing.

`source/world_damage_probe.log` records ten explicit passing checks: initial wall collision; collision and batched vertices removed by impact; neighboring wall retained; visible and colliding hole preserved after restoration; destroyed IDs round-trip; collision, geometry vertex count and original facade shader recovered after repair. The latest world code was frozen before the final native export tests.
