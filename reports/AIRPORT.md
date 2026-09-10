# Sydney Airport implementation and evidence

Implemented 10 September 2026 as a continuous, geographically separated part of the native Godot world. There is no airport scene transition. Coordinates use the same harbour origin, latitude −33.86°, longitude 151.2105°, with X east, Z south, metres.

## Verified geometry and sources

Sydney Airport publishes the airport reference coordinate −33.946111°, 151.177222°; elevation 21 ft; three 45 m wide runways of 3,962 m (16R/34L), 2,438 m (16L/34R), and 2,530 m (07/25). The official page also states a 6 m elevation difference along the main runway, which this build simplifies to a flat 6.4 m airfield.

Source: [Sydney Airport: Aviation enthusiasts](https://www.sydneyairport.com.au/corporate/sustainability/supporting-our-people-and-communities/aviation-enthusiasts), accessed 10 September 2026. Official factual dimensions inform original geometry; no airport photographs or web imagery are embedded.

Runway axis endpoints are from [OurAirports runways.csv](https://davidmegginson.github.io/ourairports-data/runways.csv), retrieved 10 September 2026 and retained as `source/airport-runways.json`. [OurAirports data terms](https://ourairports.com/data/) release this dataset to the public domain without an accuracy guarantee. This is an independently maintained geographic dataset, not a survey or an operational navigation source.

Each runway preserves the source endpoint midpoint and direction, then uses the official runway length exactly. The source endpoint distances were approximately 3,972.9 m, 2,456.7 m and 2,500.6 m; the simulation therefore adjusts the endpoints symmetrically by approximately 5.4 m, 9.3 m and 14.7 m respectively. The 34L takeoff spawn is 115 m inside the southern end, pointing approximately 348° true. In local coordinates the airfield extends roughly 7.7–12.7 km south of the harbour origin.

## Original playable construction

- Three collision-supported full-size runway pairs, shoulders, centreline/threshold/aiming-point markings, direction numbers, threshold lights, approach lights and runway edge lights. These are gameplay markings and do not certify operational aviation accuracy.
- Connected parallel taxiways, exits, hold markings and blue taxiway lights, international/domestic aprons, gate markings and an aircraft service apron.
- Original modular international and domestic halls with usable central entrance gaps, floors, roofs, interior seating and columns. Original gate piers and boarding bridges, control tower and an open service hangar with an 82 m clear entrance.
- Airport land and separate runway peninsulas leave open Botany Bay water between and beyond the runways. Shoreline polygons are hand-authored approximations, not surveyed coastline.
- An explicitly labelled, empty terrain corridor and simplified road connect the harbour to the airport. This does not claim to recreate the intervening Sydney suburbs or actual motorway alignment.
- Terminal/hangar wall sections support local damage with removed rendering/collision and limited rigid debris. Stable section IDs save and restore visible gaps and passability; up to 45 important debris bodies also retain their transforms and momentum. Large roof slabs remain static; this is local modular damage, not engineering-grade structural collapse.

All models, markings and materials in `game/scripts/airport_world.gd` are newly authored procedural geometry. No real airline liveries, branded aircraft, airport aerial photographs, Google assets or streamed city models are distributed. This source provenance does not constitute commercial approval for airport names, depictions, or promotional uses; any applicable landmark/branding rights require separate review before commercial release.

## Executed subsystem checks

Godot 4.7.2 stable, native macOS executable, headless subsystem execution. Test source: `source/airport_test.gd`.

Passed: three runways generated; each published length within 0.1 m; 34L spawn at the southern end and northwest heading; terminal/hangar anchors; downward ray collision at the runway spawn; downward rays at the simplified land corridor and runway peninsula; physical section damage; resetting intact airport geometry for a new world; restoring section damage and important debris from a JSON round trip. All 24 checks passed with zero failures. A clockwise winding error discovered by the terrain ray test was corrected before delivery. An integrated aircraft takeoff later revealed a 7 cm raised taxiway collider at a runway crossing; all 27 taxiway/exit colliders, three aprons and hangar/terminal floors now share the runway surface datum of 6.46 m. Collision rays along three wheel lanes sampled every 10 m inside all runway thresholds found a maximum surface error below 0.002 m; the reported impact location was explicitly retested. Start/end anchors now also use the physical surface datum. Paint and lights remain visual-only raised details.

These checks establish geometry/collision/state behavior. They do not constitute aircraft taxi, takeoff, landing or visual performance certification. Refer to the parent project's delivered-build test results for actual integrated play and recordings.

Reproduce from the project root with the included Godot runtime or a compatible Godot 4.7.2 binary:

```sh
Godot --headless --path game --script "$PWD/source/airport_test.gd"
```
