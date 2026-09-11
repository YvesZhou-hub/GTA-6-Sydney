# Sydney Opera House public interiors

This original procedural reconstruction covers the ticket foyer, southern entrance foyers, Concert Hall, Joan Sutherland Theatre and the two northern harbour foyers. It is a playable interpretation of published plans and photographs, not an architectural survey or complete building information model. The exterior is documented separately in `OPERA_REFERENCE.md`.

## References inspected

| Primary source | Evidence used | Limits |
| --- | --- | --- |
| [Opera House Concert Hall technical specifications, January 2024](https://www.sydneyoperahouse.com/sites/default/files/collaborodam_assets/SOHVenueTechnicalSpecifications_ConcertHall202401.pdf) | Interior photograph, seating plan, stage plan and longitudinal section; 14.50 m stage front, 12.30 m stage depth, stage approximately 0.9 m above front seating floor | Ceiling profile scaled from the public section; individual seat and wall-fold positions are estimates |
| [Opera House Joan Sutherland Theatre technical specifications, April 2024](https://www.sydneyoperahouse.com/sites/default/files/collaborodam_assets/SOHVenueTechnicalSpecifications_JST_2024.04.pdf) | Auditorium photograph, stage plan and section; 14.03 m downstage width, 11.35 m proscenium opening and 7.1 m opening height | No complete backstage or rigging system is reconstructed |
| [Opera House Conservation Management Plan, 2017](https://www.sydneyoperahouse.com/sites/default/files/collaborodam_assets/soh-cmp-interactive-1.pdf) | Level plans and Box Office Foyer photographs on printed pages 132–133: folded concrete ceiling beams, low ticket counters and stairs | Historic photographs are used for enduring architectural features, not a claim about every current fitting |
| [Official Concert Hall venue page](https://www.sydneyoperahouse.com/visit/our-venues/concert-hall) and [Joan Sutherland Theatre venue page](https://www.sydneyoperahouse.com/visit/our-venues/joan-sutherland-theatre) | Room identity, public orientation and auditorium appearance | Seating capacities vary by layout and document revision |
| [Official visitor map](https://www.sydneyoperahouse.com/visit/getting-here/map-of-the-sydney-opera-house) | Covered concourse, Box Office and upper entrance relationship | The game stairs use simplified slopes and landing geometry |
| [Opera House, Renewing an Icon](https://stories.sydneyoperahouse.com/renewing-an-icon/) and [ShapeShift reflector project](https://shapeshift.tech/portfolio/sydney-opera-house/) | The 2022 Concert Hall has 18 magenta acoustic reflectors | All 18 are represented; suspension locations, tilt angles and the 12 small / 4 large / 2 choir arrangement are interpreted from public imagery rather than a rigging survey |

Reference photographs were visually inspected. They are not redistributed as game textures. Timber grain, seating, pipe organ, reflectors, concrete folds, counters and lighting are original geometry or shaders.

## Modelled spaces and dimensions

The interior uses the exterior's mapped site frame. Local floor elevations are 0 m for the covered concourse, 5.4864 m for the ticket foyer, 11.2 m for the upper public floor and 12.1 m for both stages. These coordinate choices align the game modules; they are not independently measured elevations.

The Concert Hall has an independent opaque timber enclosure with the short northern rear corners tapered as shown in the CMP plan, a higher ceiling crown over the stage, a lower rear ceiling, curved seating terraces, side boxes, choir seating, a representative pipe organ and 18 reflectors. The approximate timber crown rises from local 28.9 m at the rear to 37.1 m above the stage region. The technical section's 15 m dimension refers to acoustic equipment, not the highest timber crown; it was not used as the room's uniform roof height.

The Joan Sutherland Theatre has a separate dark enclosure, stage and proscenium, orchestra pit, curved stalls and circle, two levels of side boxes and a pleated stage drape. The orchestra pit is physically lower than the public floor and occupies an actual opening in the exterior podium slab.

Rendered seats are deliberately representative: **2,488 in the Concert Hall and 1,549 in the Joan Sutherland Theatre**. These are actual generated geometry counts, not claims of exact seating capacity or seat-by-seat reproduction. The organ uses 63 visible representative pipes rather than reproducing all working pipes.

Public circulation includes the west covered-concourse entrance, ticket-foyer stairs, upper southern foyers, front seating aisles and northern foyers with broad carpeted stairs. Exterior promenade routes go around shell supports. The exported route interface provides five continuous paths; automated tests use a production player and movement input, starting each route only once and walking both directions.

Backstage rooms, dressing rooms, loading facilities, full fly machinery, every box access passage, technical galleries and current event staging are outside this reconstruction. The game does not simulate live performances or actual ticket sales.

## Destruction and verification

Stair treads and rails are attached to their structural support. Their smooth physics ramp has an explicit `collision_only` visual exclusion. Seat rows and box seating attach to their supporting platforms; organ details attach to the organ wall. Destroyed supporting components therefore remove their attached fittings rather than leaving a complete floating auditorium.

`source/opera_interior_test.gd` checks the complete exterior plus interiors, route capsule clearance, continuous support, actual player entry and return, clear camera positions, opaque acoustic boundaries, raised stages and exterior shell/glass/louvre triangles intruding into either auditorium. Its `--interior-only` option is a diagnostic fixture and must not be described as complete-world acceptance. Saving a screenshot also does not establish visual quality: the eight native views must be inspected separately.

Final local exterior-plus-interior integration: **42/42 checks passed**, using Godot 4.7.2 / Jolt. All five routes were walked forward and back with the production player. The check includes approximately 2.96 million samples from actual exterior shell, glazing and louvre triangles, with no intrusion into either acoustic room; both audience-to-stage sightlines and the two rear stage enclosure rays passed. This fixture includes the complete Opera exterior and interior, plus a small replacement strip for the surrounding promenade ground. It is distinct from the parent task's complete-city validation.

Eight native Metal views were rendered and inspected: ticket foyer, entry stairs, Concert Hall audience and stage, organ, Joan Sutherland Theatre and the two northern foyers. The final visual correction terminates decorative concrete ribs at the stair opening; it does not alter physics or routes. Earlier intermediate captures with intersecting shells and louvres are rejected evidence. Local logs are `reports/opera-interiors-final-combined.log` and `reports/opera-interiors-final-native.log`; the component JSON is `reports/opera-interiors/report.json`.
