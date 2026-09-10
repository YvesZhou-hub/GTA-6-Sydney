# Sydney Harbour Bridge refinement

Reference review: 10 September 2026. Geometry is original procedural work. The linked photographs were inspected as visual references; no third-party photograph, texture or downloaded 3D model is included in the game.

## References actually inspected

- [Transport for NSW: Sydney Harbour Bridge Conservation Management Plan](https://www.transport.nsw.gov.au/system/files/media/documents/2023/sydney-harbour-bridge-conservation-management-plan_0.pdf): structural dimensions, deck arrangement, granite pylons, hangers and approach trusses.
- [Australian Heritage Database: Sydney Harbour Bridge](https://www.agriculture.gov.au/sites/default/files/documents/sydney-harbour-bridge.pdf): independent official description of the twin 28-panel trusses, 30m separation and 89m pylons.
- [NFSA: constructing the arch](https://www.nfsa.gov.au/collection/item/construction-sydney-harbour-bridge-constructing-arch-0): 28-panel arch and construction views.
- [Full-span photograph, 16 October 2025](https://commons.wikimedia.org/wiki/File:Sydney_Harbour_Bridge-16_October_2025.jpg): inspected at full browser viewport for the changing truss depth, broad flat pylon crowns, end bearings and lower horizontal deck ribbon.
- [Road-level photograph from a car](https://commons.wikimedia.org/wiki/File:View_from_car_sydney_harbour_bridge.JPG): inspected at full browser viewport for the overhead bracing, vertical hangers, western railway and clear carriageway.
- [Destination NSW: Pylon Museum and Lookout](https://www.sydney.com/in/destinations/sydney/sydney-city/the-rocks/attractions/sydney-harbour-bridge-pylon-museum-and-lookout): its portrait photograph was inspected for grey granite, tapered sides, a principal round-headed opening, balcony, slender slit windows, dressed corner strips and restrained flat crown. [Reference photograph](https://assets.atdw-online.com.au/images/0aa6010614ba7445e7ef01fdd8a82241.jpeg).
- [City of Sydney: Percy James Bryant photographs](https://news.cityofsydney.nsw.gov.au/articles/donated-photographs-give-a-unique-view-of-sydney-in-the-1930s-and-40s): historical roadway reference and collection context. The article loaded but its inline images did not load during this review, so the directly viewed road-level photograph above supplied the visual confirmation.

## Model decisions

| Element | Implemented geometry |
| --- | --- |
| Main span and datum | Existing geographic axis retained; 503m arch span, 49m deck, deck top 54m above game water |
| Arch planes | Two 28-panel trusses, 30m between their centre planes |
| Arch section | 57m deep beside the pylons, 18m at the crown; top steel surface approximately 134m |
| Structural detail | Upper and lower chords, alternating diagonals, vertical members, hangers, flange strips, splice plates and rivet heads |
| Traffic | Six lanes between the arches and two eastern lanes, western double railway, outer walking/cycle paths |
| Pylons | Four tapered grey granite-faced masses terminating near 89m, with arched recesses, balconies, slit windows, stone trim and flat lookout parapets |
| Approaches | Continuous 49m wide ramps, low approach trusses, piers, matched span tangents and continuous raised footways |

This is a playable reference-based reconstruction, not a survey-grade model. The arch curves are analytic approximations constrained by the official major dimensions. Exact rivet positions, every stone course, railway operations, signage and the complete real approach road network are simplified. The outer walking/cycle surfaces are 2.2m wide in this model. The original airport-to-harbour geography and surveyed arch endpoints are unchanged. The simplified south ground entry was moved 0.8m and the north ground entry 15.2m onto the arch extension axis so the whole carriageway, including its outer lanes, meets without a turn-shaped gap. These approach connections are explicitly gameplay simplifications.

The former steel across the roadway came from interpolating lateral X-braces through the deck elevation near both arch ends. Cross-bracing now has an explicit minimum-clearance guard. Other structural members stay in their side planes or below the deck. The old maintenance steps across the walking line were removed. Raised paths now have matching physical colliders.

The old 35m approaches did not align with the 49m span. Both approaches now match the full width, and the three support regions share one horizontal axis. This removes the north-end wedge-shaped collision cracks found by dense testing. The southern ground connector first follows the ramp's outward direction, then joins the street without cutting through a divider. World generation separately reserves the complete bridge and approach corridor against buildings and ground clutter.

## Integration and validation

`game/scripts/bridge_landmark.gd` exposes `build(world)`, `pos(station, height, across)`, `ramp_position(label, fraction)`, `ramp_basis(label, fraction)`, `ROAD_LANES` and `WALK_X`. Deck and existing principal structural IDs remain compatible with the damage save system. Each intact approach/span has one continuous BoxShape road support and two continuous footway supports. This replaces the exposed inner faces of the former small collision boxes. Actual wheel tests also found ghost edge contacts on welded concave triangles and convex-hull end faces; those support geometries are not used. Damaged components split the long supports into shorter intact runs, preserving actual collision holes. The world queues a support refresh after damage, save loading and repair. Decorative parts attach to their removable component and are merged by the existing spatial structure batching system.

Run from the repository root:

```sh
./tools/runtime/godot --headless --path game --script ../source/bridge_landmark_test.gd
./tools/runtime/godot --path game --script ../source/bridge_landmark_test.gd -- --capture
```

The test checks actual physics colliders throughout all eight road lanes and both outer paths on the main span and both approaches. It probes a 2.4m wide, 5.5m high vehicle clearance volume and a walking/camera volume, samples both span joins every 5cm, and checks all ground exit legs. Captures use the native Metal Forward+ renderer and are written under `reports/bridge-refinement/`. The suite also destroys a deck, reloads saved deck/approach damage and repairs the bridge, checking actual collision holes and restored supports. It currently contains 29 assertions and 11,111 shape probes. Passing these geometric checks does not replace a real driving test; vehicle traversal is tested separately by the full-scene integration suite.

The actual inputs-only driving run recorded in `reports/bridge-refinement/drive-thin-top.log` completed both directions in 82.43 / 82.45 seconds. South to north retained 100 health; north to south retained **99.887542** health after one small physics edge contact at the north ramp/main-span crest. This residual 0.112458 loss is recorded honestly; it is not a both-directions-100 result. The former internal deck seams caused repeated large pitch impulses and damage; the continuous supports removed those. Vehicle impact thresholds were not raised to hide geometry contacts.
