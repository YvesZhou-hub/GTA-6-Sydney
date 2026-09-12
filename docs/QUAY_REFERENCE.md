# Circular Quay tower exteriors

Research and native-model review: 10 September 2026. `quay_landmarks.gd` contains two distinct procedural exteriors, with explicit source confidence. This is a game reconstruction, not surveyed construction geometry, a complete interior, or a claim that Sydney is reproduced at 1:1 accuracy. No third-party photograph or texture is redistributed in the game.

## Location and height

| Model | Mapped world centre x/z, metres | Height used | Basis and limitations |
| --- | --- | --- | --- |
| Quay Quarter Tower, 50 Bridge Street | 94.871112 / 329.616717 | 206 m | Architect-published height; OSM base and four higher outlines. OSM marks geometry and its old 48/73/106/151 m part heights as estimated. Only the plan outlines are retained; heights are reconstructed to the published total. |
| Salesforce Tower, 180 George Street | -171.890096 / 264.077195 | 263 m | Developer-published height and mapped half-hexagonal outline; individual floor heights, crown setback and brace dimensions are inferred. |

The existing world projection is unchanged: `x=(longitude-151.2105)*92400`, `z=(-33.86-latitude)*111320`, base y=4.5. Footprints come from the existing `source/map-data/city.json` OpenStreetMap extract. Attribution and ODbL obligations remain those of the city dataset. Excluded ways are 312373859, 387782063, 1120046335–1120046338 and 1116329930, preventing generic buildings from occupying the same footprint.

## Quay Quarter Tower

[The architects' project description](https://www.archdaily.com/1003606/quay-quarter-tower-3xn) states 206 metres, 49 storeys and five shifted volumes turning east as they rise. The model preserves a common southern mass and the successively turning mapped northern faces. Its 49 upper floor slices are divided into groups of 9/10/10/10/10 above a 12 m lobby envelope; this distribution is a modelling estimate, not an as-built level schedule.

[BVN's project page](https://www.bvn.com.au/project/quay-quarter/) describes staggered projecting solar frames that alternate direction between volumes, and an open public podium. The model gives these frames real depth, ivory outer faces, bronze undersides, thick block-edge returns, and planted guards on exposed terrace edges. A recessed roof plant enclosure sits behind a separate structural parapet. Lobby and podium grade/columns are simplified; there is no simulated office, market interior or lift service.

Actual photographs inspected in the browser:

- [BVN aerial photograph](https://cdn.sanity.io/images/o5vscjl2/production/923db8a502d07ae969403f8748cb404dad83a2ef-1215x1620.jpg): five-village composition, terrace rotation and rooftop recess.
- [BVN copper-framed facade close-up](https://cdn.sanity.io/images/o5vscjl2/production/caf2c9437afaec8ac19f520ac7435b59e9283b8d-8380x10679.jpg): stagger, projection depth and warm frame undersides.
- [Phil Noller photograph published with the 3XN project](https://newatlas-brightspot.s3.amazonaws.com/16/07/1aa9cf834415baf52f49d791f64b/01-quay-quarter-tower-by-3xn-phil-noller.jpg): ground-view cantilevers and pale outer framing. Context: [New Atlas project article](https://newatlas.com/architecture/quay-quarter-tower-world-building-year-2022/).

Identity is verified independently of the historical AMP Centre name: [AMP's registered address](https://www.amp.com.au/help-and-support/need-to-serve-a-legal-document) lists AMP at Level 29, Quay Quarter Tower, 50 Bridge Street; [Deloitte's Sydney office page](https://www.deloitte.com/au/en/offices/australia-offices/sydney.html) lists its office here. Tenant identity is metadata, not fabricated retail signage.

## Salesforce Tower

[Developer Sydney Place](https://www.sydneyplace.com/workplace/workplace/) confirms 263 metres, 55 storeys, 180 George Street, and the externally expressed white tree structure. [Structural engineer Arup](https://www.arup.com/projects/salesforce-tower/) explains the half-hexagonal plan, rear core, and organic bracing on the northern facade linking to the twin northern columns. [Foster + Partners' project description](https://www.fosterandpartners.com/projects/salesforce-tower-at-sydney-place/) identifies three transparent lift banks book-ended by the southern concrete core. This page was available in the indexed primary-source result; live opening intermittently timed out.

Actual photographs inspected:

- [Arup / Foster + Partners / Brett Boardman, looking up at the northern apex](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-header-credit-foster-partners-brett-boardman-photography.jpg).
- [Same official project gallery, distant full-height view](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-1-credit-foster-partners-brett-boardman-photography.jpg).
- [Same gallery, crown detail](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-3-credit-foster-partners-brett-boardman-photography.jpg).

The architect's [north elevation](https://www.metalocus.es/sites/default/files/metalocus_fosterpartners_salesforce-tower_27.jpg) and [south elevation](https://www.metalocus.es/sites/default/files/metalocus_fosterpartners_salesforce-tower_28.jpg), published with [Foster + Partners' project material](https://www.metalocus.es/en/news/a-new-icon-sydney-skyline-salesforce-tower-foster-partners), were also visually inspected. Six unequal branches per northern face were traced proportionally. Their outer junction heights in the model are 44/72/99/139/191/248 m; these are approximate values read from the elevation, not structural survey points. The northern twin trunks, shaded outer wings, southern concrete piers and three glass lift banks have separate geometry. The raised crown has a recessed roof and a structural parapet. The model uses a 14 m lobby and 54 upper floor slices; no underground or office interior is represented.

## Integration and validation

`build(world)`, `metadata()`, `footprints()` and `excluded_way_ids()` follow the earlier custom landmark API. Structural components use `quay/qqt/` and `quay/salesforce/` IDs. Fine geometry is joined by material per owner; tree branches are clipped at floor boundaries so the damaged floor removes the matching section of brace and its facade details. Rendered structural solids supply the same triangles as the collision shapes.

Run from the repository:

```sh
./tools/runtime/godot --headless --path game --script ../source/quay_landmark_test.gd --quit-after 600
./tools/runtime/godot --path game --script ../source/quay_landmark_test.gd --quit-after 600 -- --visual
```

19 checks passed in native Godot 4.7.2: mapping/exclusions, five QQT plan changes, six branch paths and floor clipping, nondegenerate triangles, outward winding, identical structural render/collision faces, total heights, physical roof rays, and destruction/restoration. Final module: 149 structural components and 98,888 triangles including repeated facade details. Native screenshot review covers `qqt_north.png`, `qqt_street.png`, `qqt_roof.png`, `salesforce_north.png`, `salesforce_south.png`, and `salesforce_roof.png`, written to `/tmp/harbourlife-quay-review/`. These isolated scene checks precede the parent's full-city integration regression.


## v0.1.3: Existing wharves and waterfront shops

[circular_quay_detail.gd](../game/scripts/circular_quay_detail.gd) replaces five equally spaced invented piers with the **existing Wharves 2–6**. It does not depict an unbuilt renewal proposal. [TfNSW's stop guide](https://transportnsw.info/document/4688/circular-quay-stop-guide.pdf) identifies the interchange. [Bermagui Constructions' wharf refurbishment](https://bermaguiconstructions.com.au/projects/commercial/circular-quay-wharf-refresh/) supplies completed-work photographs: the [Wharf 2 entrance](https://bermaguiconstructions.com.au/wp-content/gallery/commercial-circularquay/Andronicus_J20150217_Circular-Quay-20_19.jpg) and [roof/waterfront view](https://bermaguiconstructions.com.au/wp-content/gallery/commercial-circularquay/Andronicus_J20150217_Circular-Quay-4_03.jpg) were both inspected. These photographs document 2015 work; the model does not claim a new survey of every current paint finish.

The existing OSM snapshot provides **14 canopy outlines and 14 kiosk/service footprints**. All polygons are retained, rather than regenerated with uniform widths and rotation. `excluded_way_ids()` lists these 28 replacements plus seven station envelopes, **35 explicit exclusions** in total; the world excludes them from ordinary building extrusion. The platform is an inferred half-metre extension around each pier's mapped roof envelope. Its top is 4.58 m, aligned with the game's flat 4.5 m shore datum, not a hydrographic measurement. Metal roof seams, slender columns, green numbered gate panels, ticket-reader bodies, tactile strips, open boarding edges and benches distinguish the wharves. Wharf 3 receives a taller clerestory. Live ferry services and operational upper-level boarding are not implemented.

**Three** commercial exteriors use identified branch photographs. The fourteen small mapped pier kiosks use restrained generic glazing without unverified current tenant graphics; they are not counted as photographed shop reproductions.

| Venue | Mapped facade centre X, Z (m) | Primary identity and actual exterior source |
| --- | --- | --- |
| Eastbank Café · Bar · Pizzeria | 213.5632, 71.8168 | [Operator address: Ground Level Quay Grand, 61–69 Macquarie Street](https://eastbank.com.au/); [property agent's sale photograph](https://www.colliers.com.au/en-au/news/circular-quay-sale). Tall glass bays, pale stone piers, dark rails, small fascia, round tables and planters. |
| Searock Grill | 218.5538, 21.4607 | [Operator address: Shop 15, 5 Macquarie Street](https://searock.com.au/); [photographed accessible entrance](https://wheeleasy.org/explore/searock-grill). Veined dark stone jambs, narrow glass frames, bottle silhouettes, projecting sign and outdoor tables. |
| City Extra | 68.6112, 143.5034 | [Operator address: E4 East Podium between Wharves 3 and 4](https://cityextra.com.au/); [identified street photograph](https://portplanner.com.au/port/sydney-au/city-extra-restaurant). Red awning supported by diagonal steel arms, upper glazing, red lettering and a low planted dining boundary. |

OSM POIs 4242649492 / 4739109527 / 4422281496 are projected to host building polygons 23717454 / 23717448 / 51065527. Projection distances are approximately 4.07 / 5.45 / 1.33 m; widths 15 / 12 / 21 m and small fittings are photo estimates. Doors are closed collision-backed exteriors, not invented enterable spaces inside solid ordinary OSM buildings. No third-party reference pixels or personal OSM editing metadata are shipped.

Metadata group `circular_quay_detail` contains nine entries: `cq_wharf_2` through `cq_wharf_6`, `cq_station`, `cq_eastbank`, `cq_searock`, `cq_city_extra`. `center`/`map_position` describe the place; `arrival`/`anchors[id]` identify a supported public approach. The original coast and street centre-lines remain authoritative. Foreshore benches/bins and apron bollards are photo-informed approximations, not surveyed fixtures.

### Circular Quay railway station

The [Heritage NSW station record, item 4801109](https://www.hms.heritage.nsw.gov.au/App/Item/ViewItem?itemId=4801109) identifies the 1956 transport structure; its indexed record was accessible, while opening the complete page returned an access error. The actual [September 2023 north-elevation photograph](https://upload.wikimedia.org/wikipedia/commons/2/2b/20230910_Circular_Quay.jpg) was visually inspected. It informed the long granite name band, single steel-framed window strip, open end galleries and lower concourse piers. No photograph is redistributed as a material.

The replacement retains the plan of **way/51065527** and the six separately mapped ground enclosures **ways/408117948–408117953**. All seven are explicit `CUSTOM_IDS` exclusions. The lower enclosures use their original outlines, with a 6.4 m central public passage cut through the collision geometry. Their stone and glazed faces replace the previous generic office-window boxes. City Extra remains attached to its mapped station-side facade. The raised rail floor and Cahill roof retain the main outline; their levels, facade band dimensions, roof fittings and gallery details are photo estimates, not engineering measurements. The accessible ground concourse has a supported arrival at world **(11.93, 4.5, 167.36)**. Train operation, upstairs access and a connected elevated traffic route are outside this model.

### v0.1.3 precinct validation

The [combined precinct test](../source/precinct_detail_test.gd) passes **72/72 headless and 72/72 native checks** on the final geometry: 1.8 m capsule clearance and actual floor support at twelve destinations, 41 continuous route samples on each pier, canopy outlines, station raised floor and public-concourse clearance/support, idempotence, original frontage retention and outward finite geometry. The local integration fixture also rejects old `quay/pier/*` and `quay/transit_hall` IDs. The six final ground enclosures were included in both runs.

`--capture` writes eleven real Godot images to `reports/precinct-detail/`; all eleven were inspected after the final station revision. These are an isolated mapped-precinct fixture with native rendering, not screenshots of the exported complete city. The fixture deliberately omits the main-world water/environment and operating gameplay. Full-world arrival, spawning, runtime and export checks are separate release evidence. No user save is loaded or changed.

```sh
./tools/runtime/godot --headless --path game --script ../source/precinct_detail_test.gd
./tools/runtime/godot --path game --script ../source/precinct_detail_test.gd -- --capture
```

## v0.1.6: Canopy and boarding-edge detail

On 12 September 2026 the two Bermagui Constructions completion photographs linked above were opened and visually inspected again. The entrance photo shows a circular green ferry marker with a pale rim, separated numbered green bands, dark ticket panels, pale soffits and recessed lighting. The water-facing photo shows metal edge trims, thin columns and brackets, closely spaced railing bars, and dark waterside fenders with pale pile caps. The [10 January 2025 photograph of all five wharves](https://commons.wikimedia.org/wiki/File:Circular_Quay_view_from_ferry_2025.jpg) was also opened at original resolution to check the continuing overall low-canopy / raised Wharf 3 composition; it is too distant to establish individual current fittings. The 2014 fare-gate catalogue was inspected as metadata only and is not treated as a current fare-equipment survey.

The model now includes the round F markers, divided entrance signs, reader display housings, pale roof undersides with shallow luminaires, perimeter metal fascia, column capitals and knee braces, railing pickets and water-facing fenders. All 14 original mapped roof polygons and all five platform footprints remain unchanged. Roof fittings are children of their damageable roof, entrance details of their sign, and fender details of the deck, so these details disappear with their damaged owner. Fine brackets, pickets and small fittings are render detail; the existing structural collision owners remain authoritative. Existing navigation arrivals are unchanged, and the revised reader bodies leave a clear central pedestrian route.

This is procedural geometry inferred from real photographs, not a copied image material or an engineering survey. Fitting spacing, trim thickness, reader dimensions and paint values are estimates. No operational ticket gates, live departures, moving ferries, revised shoreline, or proposed future terminal redevelopment is implied. The final release's complete-city captures and continuous walk evidence are recorded in `TESTING.md`; the local 83-check precinct fixture separately verifies all original mapped pieces, five multi-offset entrance clearances, every pier's 41-point route, and geometry winding.

## v0.1.6: Additional two-tower facade detail (12 September 2026)

This section concerns only `quay_landmarks.gd`, not the wharf/station module above. Four primary-source photographs were actually opened and inspected for this pass:

- [BVN close view of QQT's staggered frames](https://cdn.sanity.io/images/o5vscjl2/production/caf2c9437afaec8ac19f520ac7435b59e9283b8d-8380x10679.jpg): warm deep returns and fine recessed glazing seals rather than a single flat rectangular frame section.
- [BVN street view of QQT's podium](https://cdn.sanity.io/images/o5vscjl2/production/ac0af6f0df997c56385a0c70f0b7eedaca195222-1215x1620.jpg): pale coursed stone, continuous dark ventilation bands and projecting floor edges. The photographed artwork is not reproduced.
- [Arup / Foster + Partners / Brett Boardman, Salesforce northern apex](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-header-credit-foster-partners-brett-boardman-photography.jpg): white metal-clad tree members and densely spaced horizontal shading blades.
- [Same official gallery, Salesforce entrance](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-2-credit-foster-partners-brett-boardman-photography.jpg): tall glazing with slender subsidiary vertical framing and restrained cross-members. The photographed digital artwork and indoor foyer are not recreated.

QQT gains folded bronze returns inside its staggered sun frames and narrow dark seals behind them. Its original stone podium has coursing joints and shallow louvred ventilation bands. Salesforce's formerly square white members now have an eight-corner chamfered cross-section; their existing tree paths and floor ownership are unchanged. The outer wings have three slender profiled shade blades per modeled storey, with their inner limits following the existing branching boundary. Additional slim vertical glazing frames and cross-members give the lobby exterior depth.

Frame return depth, 1.5 m stone joint spacing, ventilation-band positions, member chamfer, blade profile and three-blade sampling are photograph-informed modeling estimates. They are not fabrication dimensions or a claim to match every one of the real facade panels. All seven mapped outlines, the 206/263 m published total heights, floor elevations, navigation metadata and 149 original structural damage IDs remain unchanged. No physical floor, door opening, entry bridge, public garden route or office interior is added. Details remain attached to their original owning structure; its destruction removes its finishes together. This pass does not change the separate waterfront module's geometry or sources.

`capture_views()` supplies four dedicated cameras, two per building: `quay-qqt-rebated-frames`, `quay-qqt-stone-podium`, `quay-salesforce-tree-shades`, and `quay-salesforce-glazing`. These are external detail views, not claims that the commercial interiors can be visited.

The isolated headless fixture passes **28/28** checks on this batch: original projection, outlines, heights and floor-brace ownership; matching structural render/collision faces; nondegenerate outward geometry; actual roof collisions and destruction/restoration; repeated-build idempotence; the closed eight-corner member profile; and four camera clearances. Geometry is **138,552 visible triangles and 149 structural components**. Results and exact model/test hashes are in `reports/quay-v016-detail-headless.log` and `reports/quay-v016-detail-report.json`. Native visual acceptance, background-building occlusion and final packaged-app behavior are separate root-task checks; no new native pass is claimed here.
