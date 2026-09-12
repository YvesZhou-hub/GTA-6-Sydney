# Sydney Opera House public interiors

This original procedural reconstruction covers the ticket foyer, southern entrance foyers, Concert Hall, Joan Sutherland Theatre and the two northern harbour foyers. It is a playable interpretation of published plans and photographs, not an architectural survey or complete building information model. The exterior is documented separately in [OPERA_REFERENCE.md](OPERA_REFERENCE.md).

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

## September 2026 foyer detail pass (v0.1.6)

The [official December 2025 Weddings Event Kit](https://sydneyoperahouse.api.collaboro.com/media/SOH_Weddings_Event_Kit_December_2025.pdf), printed pages 9–12 (PDF pages 8–9), was rendered and visually inspected. Its current photographs show red and purple sweeping stairs, deep angled bronze curtain framing and folded timber finishes. The historical CMP photographs on printed pages 132–133 were also revisited for the enduring folded concrete geometry of the ticket foyer.

The ticket foyer now has 22 profiled concrete beams with sloping cheeks, narrow soffits, construction joints and recessed lighting, replacing plain rectangular bars. The existing stair opening remains clear. Beam cross-section (2.36 m at its upper shoulder, 0.56 m soffit, approximately 1.22 m deep) is inferred from photographs.

Both northern foyers now use curved carpet treads and corresponding continuous ramp collision, with 14 representative treads, 2.2 m rise and 1.2 m lateral plan bow. These are game dimensions, not surveyed stair counts or setting-out dimensions. Each flight reaches an actual upper landing at local y=13.4 m, plus a folded timber backdrop. The original approach points are preserved; the two northern routes now continue from their old stair-top endpoints onto the upper landings. The screens and upper slabs use independent damage components; stair rails stay attached to their supporting flight. No artwork, event table arrangement or copyrighted mural has been substituted with an invented replica.

The real foyers span four levels. This model still covers the playable two-level public route described below; it does not claim that every real foyer level is open or reconstructed. The exterior monumental stairs retain the v0.1.5 load-bearing foundations and legacy damage compatibility unchanged.

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

Prior v0.1.4 local exterior-plus-interior integration: **42/42 checks passed**, using Godot 4.7.2 / Jolt. All five routes were walked forward and back with the production player. The check includes approximately 2.96 million samples from actual exterior shell, glazing and louvre triangles, with no intrusion into either acoustic room; both audience-to-stage sightlines and the two rear stage enclosure rays passed. This fixture includes the complete Opera exterior and interior, plus a small replacement strip for the surrounding promenade ground. It is distinct from the parent task's complete-city validation.

Eight native Metal views were rendered and inspected: ticket foyer, entry stairs, Concert Hall audience and stage, organ, Joan Sutherland Theatre and the two northern foyers. The final visual correction terminates decorative concrete ribs at the stair opening; it does not alter physics or routes. Earlier intermediate captures with intersecting shells and louvres are rejected evidence. Local logs are `reports/opera-interiors-final-combined.log` and `reports/opera-interiors-final-native.log`; the component JSON is `reports/opera-interiors/report.json`.

Current v0.1.6 checks additionally cover the curved flights, new upper-landing approaches and production migration decisions for buried versus safely standing players on both actual upper slabs. Current local logs are `reports/opera-v016-interior-headless.log` and `reports/opera-v016-exterior-headless.log`; final native and exported-App acceptance is recorded separately in [TESTING.md](TESTING.md). New geometry must be visually inspected in native captures; the prior eight-image review above is historical evidence, not acceptance of this detail pass.

The v0.1.6 local evidence is intentionally separated:

- **49/49 full-route checks** passed before adding the dedicated lower stair camera and slope-migration probes; `reports/opera-v016-interior-full49.json` preserves that complete forward/return run.
- **22/22 migration-only checks** passed after the production migration fix. Six real settled capsule positions remain on the foyer slopes, while six positions buried by 4 cm are correctly rejected. The earlier six safe-position false positives are diagnostic evidence, not accepted results.
- **52/52 final geometry checks** passed with the new lower stair camera, slab and slope migration probes, route support/clearance and 2,449,318 exterior-triangle samples. `reports/opera-v016-interior-geometry52.json` explicitly records that continuous route walking was not repeated in this run.
- The parent task captured and reviewed the initial eight local native interior views; the lower Concert stair viewpoint was added afterward so final capture can show the curved risers directly. These local renders do not include the complete city background and are not final exported-App evidence.
