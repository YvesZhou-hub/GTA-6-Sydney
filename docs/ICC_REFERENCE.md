# ICC Sydney and TikTok Entertainment Centre reconstruction

Reference review: 10 September 2026. `icc_landmarks.gd` models three separate venues at their mapped Darling Harbour locations. **TikTok Entertainment Centre is the entertainment theatre formerly called ICC Sydney Theatre, not TikTok's office.** The game is a public-space architectural reconstruction, not a complete or measured BIM and not a live event seat-booking plan.

## Evidence actually reviewed

- [ICC public floor-plan directory](https://iccsydney.com.au/organisers/organiser-toolkit/floor-plans/) and its independently public [Ground Level PDF](https://iccsydney.com.au/wp-content/uploads/2023/05/icc-sydney_ground-level_floor-plan_1.pdf) and [Level One PDF](https://iccsydney.com.au/wp-content/uploads/2023/05/icc-sydney_floor-plans_level-one.pdf). Both pages were rendered and visually inspected. These establish the northern Convention / central Exhibition / southern Theatre arrangement, public entrances, the ground-floor car park below the exhibition halls, Level 1 hall sequence and eastern public foyer. The full venue bundle on the directory is password protected and was not accessed.
- [Official entrance and venue-level information](https://iccsydney.com.au/about/venue-information/entrance-and-venue-levels/) and [accessible entrances](https://iccsydney.com.au/about/venue-information/accessibility-and-inclusion-for-visitors/location-and-access/). The Convention entry faces Cockle Bay; Exhibition entries face the public boulevard near the Convention and Moriarty Walk; the Theatre's ground entry is on Moriarty Walk near Tumbalong Boulevard. Public entry wording varies with event and access mode, so the game retains both Theatre-facing openings rather than claiming one universal event queue.
- [Official venue capacity summary, June 2026](https://iccsydney.com.au/ICC-Sydney-Fact-Sheet-Venue-Capacity): four lower halls on Level 1, total 19,043 m², 10.5 m clear height; three upper halls on Level 4; theatre capacity 8,000 seated or 9,000 general admission. **The modeled hall areas and seat count are simplified and are not advertised as those exact capacities.**
- [Populous completed ICC project](https://populous.com/showcases/international-convention-centre-sydney) and [Hassell project description](https://www.hassellstudio.com/project/icc-darling-harbour-sydney). Browser-inspected photographs: `N78` crystalline Convention façade and angular pale crown; `N40` black-edged projecting Exhibition meeting pods with timber interiors and white terraces; `N303` Hall 1 timber registration counter and slatted foyer ceiling; `N59` public interior with wood, pale floors, exposed concrete columns, glazing and stairs; `N567` black folded Theatre envelope, tall foyer glazing and red reveals. Exterior proportions, glazing rhythms and timber details are reconstructed from these photographs; no architectural façade shop drawings were available.
- [Sydney Symphony's venue page](https://www.sydneysymphony.com/venues/tiktok-entertainment-centre) and its [auditorium photograph](https://images.baskercdn.com/sydneysymphony/media/venue-icc-sydney-theatre.jpg), visually inspected: fan-shaped, three principal red/grey seating tiers, dark acoustic walls, side aisles and exposed lighting trusses. The [public Theatre seating PDF](https://iccsydney.com.au/Theatre-Seating-Plan) was read for tier/door relationships. The stage configuration on the Ground PDF gives 18.3 × 12.2 m at 1.524 m; that public configuration informs the modeled platform, not a claim that every event uses it.

No reference photographs, PDF pages, event branding, people, or other third-party raster pixels are included in the game. The façade materials, chairs, trusses, typography and interior details are authored procedural geometry. Public source links remain in this document so the evidence can be reviewed.

## Mapped geometry and approximation boundary

`game/assets/icc_geometry.json` retains the project OpenStreetMap snapshot's local outlines and projection, with no OSM contributor usernames, changesets or edit history. Coordinates use the project's origin (-33.86, 151.2105); X is east and Z is south in metres. OSM is mapped data, **not independently surveyed or cadastral geometry**.

| Venue part | OSM way | Use |
| --- | --- | --- |
| Convention north | 488447518 | Hollow public ground foyer and façade |
| Convention south | 488447519 | Conference/theatre wing exterior, closed rooms |
| Exhibition lower | 23646745 | Hollow Level 1 halls and public entry strip |
| Exhibition upper | 1116329939 | Set-back upper envelope, closed |
| Entertainment theatre | 487371417 | Hollow auditorium and foyer |
| Theatre rear parking | 1098953175 | Separate mapped rear volume |
| Whole ICC parent | 501890909 | Suppressed to avoid a duplicate enclosing building |

The OSM 10.5–18.9 m height tags on several parts do not describe the full photographed buildings and were not used as whole-venue heights. The game uses approximate overall envelopes of 44 m (Convention crown), 36 m (Exhibition) and 38 m (Theatre). Floor elevations, wall thicknesses, podium details, staircase dimensions, individual meeting-pod positions and exact seating rake are estimates. The Convention ground foyer's 5.5 m clear height and Exhibition halls' 10.5 m clear height come from public official documents. No claim is made to replicate unknown mechanical, backstage, security, plant or staff-only layouts.

## Playable spaces

- Convention: open street entrance, registration desk, pale stone foyer, wood-clad rear wall, concrete columns, timber grand stair and public mezzanine landing. Other meeting rooms are visibly closed.
- Exhibition: open ground entrance, staircase to Level 1, long public foyer and the four lower halls. Ground parking stays behind a closed boundary; the upper hall envelope and terraces are exterior reconstruction. Lower hall partitions leave connecting openings for exploration; this is an empty, simplified exhibition configuration.
- Theatre: Moriarty Walk and boulevard entry openings, ticket foyer, side aisle, flat audience/stage-front floor, raised stage with side steps, three fan seating tiers and overhead trusses. The auditorium now has a separate opaque charcoal acoustic enclosure up to the modeled roof underside; the exterior glass remains around the public foyer. Its north side is outside the modeled widest seats, and the north GA route and eastern foyer route each pass through an explicit 6.0 m wide × 3.6 m high opening. Those opening sizes, wall positions and 37.1 m modeled enclosure height are estimated game geometry, not dimensions taken from an architectural acoustic specification. Seat number and red/grey pattern are representative, not the exact ticketed seat map. Upper tiers and boxes are scenery unless reached through an explicitly modeled public route. Seats do not provide a sitting interaction.

The primary massing follows the mapped parts; small façade fins and folded cladding relief are approximate. The existing gap at Moriarty Walk remains open. The module does not alter roads, shops, Darling Square circulation, or player movement rules. Stairs use continuous inclined collision support with visible treads to avoid introducing the repeated-contact vibration previously found on bridge road seams.

## Reproducible checks

`source/icc_landmark_test.gd` creates an isolated local fixture and never reads or writes a real user save. It checks replacement IDs, independent metadata, idempotent build, capsule clearance, continuous support, and the actual `HarborPlayer` walking from the street to each interior, onto the raised theatre stage, and back using normal movement input. Additional enclosure checks cast 28 rays above and behind the audience from the stage-front viewpoint, require the first hit to be an opaque internal acoustic wall, test both public door openings across their width, and walk the real player through the glazed foyer connection. Native captures cover the group, each exterior, foyer, stairs, hall, auditorium and stage. The final complete-world fixture passed all 27 checks, including actual player ascent onto the raised Theatre stage and return to the street. This final route was executed headlessly; native illustrations are a separate visual check.

```sh
./tools/runtime/godot --headless --fixed-fps 60 --path game --script ../source/icc_landmark_test.gd
./tools/runtime/godot --path game --fixed-fps 60 --script ../source/icc_landmark_test.gd -- --capture
```

Verified final acoustic-enclosure revision: **27/27 local headless assertions and 27/27 production-world headless assertions passed**, including all three original return routes, the raised stage, the separate glazed-foyer connection, 28/28 sightline rays and both public door clearances. The final native visual pass passed **15/15 geometry checks**, saved the auditorium and foyer views, and both were visually inspected: no city/glazing is visible behind the seating, while the public foyer retains its transparent exterior. Actual player traversal and native illustrations remain separate verification scopes. The final local fixture has 277 independent structure records, 36 visible meshes, 2,400 representative seats, and 138,034 visible triangles including the fixture ground. Captures are original game renders, not reference-photo assets. Earlier ten-view captures document the other unchanged venue exteriors and interiors. [Complete-world route evidence](evidence/icc-interiors.txt).
