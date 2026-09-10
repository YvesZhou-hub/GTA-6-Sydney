# Geographic alignment audit — 11 September 2026

The named building base footprints largely occupied the correct Sydney locations. This audit fixes two different issues: displaced bridge/Opera geometry, and navigation points that conflated the building itself with a public arrival. It does not certify a complete 1:1 city, measured terrain, lane-accurate roads or suitability as a real driving/navigation aid.

## Reproducible source and coordinate contract

The game and map retain one common projection: `x=(lon−151.2105)×92400`, `z=(−33.86−lat)×111320`; +X east, +Z south. Y=4.5m is the common game ground datum, not surveyed AHD. This constant metres-per-degree conversion is an approximation; it is not an ellipsoidal distance-preserving map projection. Retaining it for all layers avoids a new mismatch between existing roads, buildings and saved positions.

Raw source geometry is in `source/map-data/city.json`, `north.json`, `manly.json`, `building_relations.json`, `manly_landmark_detail.json` and `metro_entrance_geometry.json`, acquired for the September 2026 city build. © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL. An OSM outline can itself be incomplete, estimated or outdated. Submillimetre agreement below measures conversion consistency between the same source and the model; it says nothing about the real-world survey error.

The runtime [coordinate catalogue](../game/assets/landmark_geography.json) records 22 canonical destinations and the `the_corso` alias. `harbor_world._register_landmark_geography()` exposes them through `world.get_meta("landmark_geography")`, keyed by canonical/alias ID. The three position fields become `Vector3`:

- `map_position`: building footprint centroid, landmark centre, or explicitly identified entrance/linear-precinct point. A building marker belongs here.
- `arrival`: public ground approach with physical clearance; `world.anchors[id]` uses this. Navigation must not silently replace it with the building centroid.
- `model_reference`: local modelling origin. This may differ from the centroid without shifting the geometry, because footprint vertices are expressed relative to that origin.

`map_position_kind`, `arrival_kind`, `osm_ids`, `source`, `lat_lon` and `map_to_arrival_m` state the provenance and interpretation. Street-side arrivals for nine closed exterior-only buildings are derived from the mapped outline and the named public street, with 3m facade clearance. They are usable game approach points, **not surveyed door coordinates**. No public access to private office interiors is implied. Existing ICC, Cyber, Manly and Metro public approaches are retained.

## Verified corrections

**Sydney Harbour Bridge.** Four raw pylon outlines (ways 142518160–163) give two pairs about 41m apart transversely; the earlier model placed them 72m apart. Their pair centres are 566.8496m apart along the bridge. The new 503m arch is centred between them at `(16.14312, −858.62737)`, and its southern springing is `(-99.61797, −635.35260)`. The former arch centre was about 31.5m too far north along the harbour crossing; the former southern pylon line was about 63m north of the mapped line. All four upper pylons now sit at the mapped centroids instead of an artificial wide spacing.

| Pylon / OSM way | Corrected X / Z (m) |
| --- | --- |
| South west / 142518161 | −132.28018 / −616.66483 |
| South east / 142518160 | −96.34462 / −597.35649 |
| North west / 142518163 | 128.28656 / −1119.98807 |
| North east / 142518162 | 164.91071 / −1100.50008 |

The upper stone masses follow the mapped approximately 10.3×25.3m envelopes, with mapped height/min-height 89/59m. These OSM vertical fields are not an independently surveyed elevation profile. Original lower-abutment geometry has an actual open passage below the upper mass, preserving all eight modelled road lanes and both outer footways; lower supports and the portal are reconstruction decisions. Official structural/photographic references remain in [BRIDGE_REFERENCE](BRIDGE_REFERENCE.md), including the [Transport for NSW conservation plan](https://www.transport.nsw.gov.au/system/files/media/documents/2023/sydney-harbour-bridge-conservation-management-plan_0.pdf).

**Bradfield Highway north approach.** The earlier straight ramp ended at `(350.92043, −1504.33072)`, substantially east of the actual highway. It is now replaced by a 538.72m curved route derived from twelve connected mapped one-way Bradfield Highway ways. [The source/calculation asset](../game/assets/bridge_north_approach.json) retains both way-ID chains and 46 plan vertices: at each source Z station, X is the mean of the opposing carriageway centre-lines. The first vertex moves only 0.083m to connect to the pylon-derived span axis; remaining centreline points are not displaced. The new ground endpoint is `(138.35244, −1600.0)`, connecting onward at `(133.18241, −1615.0)`. All bridge reservations now follow this actual curve, allowing ordinary mapped buildings in the former incorrectly reserved eastern corridor to return.

Only the vertical grade is estimated: `Y=54−49.5×(f+f²−f³)`, where `f` is cumulative mapped horizontal distance divided by route length. This joins the existing deck to the game's flat 4.5m ground and eases to zero slope at the northern ground connection; it is not an AHD profile. The 49m bridge-width envelope, lane/rail allocation and footways continue through the turn as a gameplay reconstruction, not individually surveyed lane boundaries. Cross-section headings are averaged over approximately 11m while centreline points remain fixed, preventing wide surfaces from folding at discrete map knots. The southern ground approach, full highway interchange, real track divergence and Cumberland Street access stairs remain simplified or absent.

**Sydney Opera House.** OSM relation 9596872's outer members form a single mapped footprint with centroid `(427.29477, −321.45441)` and a minimum-area rectangle long-axis bearing 13.23286° east of north. The authored reconstruction now uses that centre and Godot yaw −13.23286°, replacing `(421, −326)` / −12°. The old reference origin was 7.76m from this mapped centre. The podium outline, exact shell positions and detailing remain photographic reconstruction, not a digitised building survey. Its arrival is on the southern forecourt before the monumental stairs, separate from the building marker. The former `(414, −151)` forecourt destination was not evidence of the entire building being in the wrong place. [The Opera House's official precinct/access-map page](https://www.sydneyoperahouse.com/visit/getting-here/map-of-the-sydney-opera-house) supports the forecourt and stair-side approach.

**ICC / TikTok Entertainment Centre.** The three model footprints were already correctly positioned. Their `metadata().center` fields incorrectly contained public arrival coordinates; they now contain the model reference, with an explicit unchanged `arrival`. The Convention marker uses the union of its two mapped masses, rather than the northern mass origin or its door. The official [current ICC navigational map](https://iccsydney.com.au/wp-content/uploads/2025/11/251114-ICCS-Navigational-Map.pdf) and [getting-here page](https://iccsydney.com.au/visitors/getting-here/) identify the convention, exhibition and theatre venues at 14 Darling Drive, their public concourse and distinct approaches. [TikTok's official visitor page](https://tiktokentcent.com/visit/) identifies this theatre beside ICC; it is not a TikTok office model.

**Other named models.** HSBC's host Tower One, Bank of China, W/The Ribbon, The Exchange, Westpac, CBA North/South, Quay Quarter/Salesforce, CyberCX/Cloudflare, Manly Wharf and Hotel Steyne retain their correctly projected mapped base vertices. They are not moved merely because a modelling origin differs from an overall footprint centre. Thirty-four base/part outlines across six modules match the independent raw-OSM projection with maximum boundary disagreement 0.000691m. The W upper curved silhouette and other photo-derived crowns, facade details and interior grids are separate approximations; this base-outline result does not verify every upper surface.

Hotel Steyne's geographic centre accounts for its actual courtyard hole. The Corso and Manly Beach are public linear/coastal areas, so their labelled points are explicitly not building centroids. CyberCX remains the Sydney office at Level 23, 2 Market Street, not its Melbourne headquarters, per the [current official contact page](https://cybercx.com.au/contact-us/); Cloudflare remains at 388 George Street per its [official office directory](https://www.cloudflare.com/en-gb/about-overview/?r=1). Address/photo evidence for the other models remains in [CITY_REFERENCE](CITY_REFERENCE.md), [BANK_REFERENCE](BANK_REFERENCE.md), [QUAY_REFERENCE](QUAY_REFERENCE.md), [CYBER_REFERENCE](CYBER_REFERENCE.md), [MANLY_REFERENCE](MANLY_REFERENCE.md) and [METRO_REFERENCE](METRO_REFERENCE.md).

## Map positions and public arrival separation

Coordinates below are rounded for readability. The runtime JSON retains calculation precision, not a claim of measurement accuracy.

| ID | Map X / Z (m) | Arrival X / Z (m) | Separation (m) |
| --- | --- | --- | --- |
| `westpac` | -608.80 / 674.13 | -584.37 / 622.11 | 57.5 |
| `cba_south` | -693.50 / 1705.14 | -672.87 / 1663.59 | 46.4 |
| `cba_north` | -758.72 / 1622.03 | -700.79 / 1626.65 | 58.1 |
| `tower_one` | -775.00 / 427.87 | -824.62 / 435.12 | 50.1 |
| `boc` | -610.64 / 1027.06 | -627.11 / 1004.01 | 28.3 |
| `ribbon` | -811.47 / 1507.25 | -765.50 / 1453.74 | 70.5 |
| `exchange_haidilao` | -768.50 / 1993.50 | -757.08 / 1974.38 | 22.3 |
| `cybercx_sydney` | -571.78 / 1180.10 | -579.00 / 1214.00 | 34.7 |
| `cloudflare_sydney` | -287.70 / 933.90 | -316.50 / 924.00 | 30.5 |
| `icc_convention` | -1038.92 / 1542.24 | -980.13 / 1492.30 | 77.1 |
| `icc_exhibition` | -982.25 / 1724.13 | -927.06 / 1636.02 | 104.0 |
| `tiktok_entertainment` | -905.81 / 1881.02 | -881.95 / 1823.95 | 61.9 |
| `manly_wharf` | 6827.12 / -6676.83 | 6809.88 / -6753.78 | 78.9 |
| `hotel_steyne` | 7127.77 / -7016.64 | 7157.30 / -6999.80 | 34.0 |
| `quay_quarter` | 92.73 / 313.38 | 98.30 / 366.43 | 53.4 |
| `salesforce` | -171.89 / 264.08 | -208.81 / 268.52 | 37.2 |
| `opera` | 427.29 / -321.45 | 403.95 / -222.16 | 102.0 |
| `bridge` | 16.14 / -858.63 | -316.20 / -162.40 | 771.5 |
| `barangaroo_metro` | -751.18 / -94.19 | -751.18 / -97.00 | 2.8 |
| `martin_place_metro` | -33.22 / 712.21 | -33.22 / 707.50 | 4.7 |
| `manly_corso` | 7070.38 / -6927.15 | 7070.38 / -6927.15 | 0.0 |
| `manly_beach` | 7194.29 / -7007.66 | 7194.29 / -7007.66 | 0.0 |

## Validation and scope

`source/landmark_alignment_test.gd` reads the raw OSM coordinates independently of model constants, compares every mapped base boundary, recomputes pylon and Opera placement, checks the runtime map/arrival contract and loads the complete production world. It requires `HARBOR_WORLD_READY` before physical checks. All 22 arrivals have ground support and a clear 0.84m-wide, 1.85m-high human capsule. ICC's three public service coordinates remain unchanged. This is an endpoint-clearance test, not verification of a complete walk or drive from every possible location.

The final production project uses Godot 4.7.2 stable with **Jolt Physics**. The geographic suite passes **69 assertions** covering 34 mapped base/part footprints and all 22 arrivals; see the [full log](evidence/final-geographic-v012.txt) and [machine-readable point/boundary evidence](evidence/geographic-alignment-v012.json). The final `source/bridge_landmark_test.gd` run passes **29 assertions / 11,345 shape probes** along the revised curve: all eight lanes at 2.4m vehicle width/5.5m height, both raised paths, dense ramp joins, public ground exits, genuine deck/ramp damage holes and repair. Both production runs contain `HARBOR_WORLD_READY` and zero script errors. [Bridge geometry log](evidence/final-bridge-v012.txt). The final Jolt `source/opera_landmark_test.gd` local-model run also passes its 17 checks, including all 48 stair-support samples, actual outer/inner shell collision and destruction/restoration, with zero script errors; [Opera geometry log](evidence/opera-v012.txt). This local model test does not substitute for a complete-world native visual review.

The final production Jolt scene repeats the isolated comparison result: ordinary throttle/steering/brake inputs complete south→north in **85.8167s** and north→south in **85.5333s**, retaining **100 health both ways with zero impacts**. Maximum lateral route error is 0.4054m / 0.3399m. The controlled initial vehicle pose is the only placement; traversal uses the actual physics vehicle and unmodified damage formula. The full run contains `HARBOR_WORLD_READY` and zero script errors. See the [machine-readable driving result](evidence/bridge-drive-v012.json), [full log](evidence/final-bridge-drive-v012.txt) and [physics explanation](BRIDGE_REFERENCE.md). The same first outward drive starts the real `race` job and naturally triggers all eight production checkpoints on the corrected route, reaching the last gate at an actual job elapsed time of 84.85s. The completion counter increases once; money and lifetime earnings each receive **$2,232 ($2,000 base plus the full $232 timing bonus)**. The test reads the completed job dictionary, verifies zero race incidents, and independently compares the credited bonus against `int((240−completion_elapsed)×1.5)` (a $1 rounding tolerance is allowed; this run matches exactly). The return drive produces no duplicate reward. No checkpoint teleport or direct task-context/update call is used. Task incident penalties now apply only to impacts from the currently occupied vehicle; other vehicle impacts still affect the world and NPC reactions. Remaining vehicle/flight compatibility and exported-app native visual review are separate validation steps. No release/deployment status is implied by these source and headless checks. Flat ground, estimated heights/roof slopes, simplified road widths/lanes/traffic, omitted interchange and terrain detail, and incomplete interiors remain material limits for learning real-world driving familiarity.
