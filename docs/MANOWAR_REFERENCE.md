# Man O’War Steps · mapped pier reconstruction

## Evidence inspected on 12 September 2026

The existing full-city roof-plan screenshot showed disconnected pale strips east of the Opera House. Source inspection identified eight actual OSM footways, including two `bridge=yes` timber gangways. The generic road renderer drew the ground-level paths over water and omitted the elevated gangways; the corresponding piers were absent. These are real marine structures, so removing the paths would erase a real place.

- [Heritage NSW, item 5051356](https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=5051356), current entry viewed: stone pier, stone steps, bitumen surface and two entrance columns; the heritage listing excludes the adjoining contemporary pontoons.
- [Floatspace operator location page](https://www.floatspace.com/boat-hire/boat-hire-sydney/man_o_war_steps), actually opened and viewed: the blue north/east direction board, dog-leg masonry pier, two open floating berths, narrow railed gangways and white-capped piles. Its three photographs have no capture dates supplied; they are visual references, not confirmation of every fitting in 2026. Images actually inspected: [pier from above](https://floatspace.imgix.net/production/wharves/5/1000472-Man-OWar-Steps-orig.jpeg), [water-side view](https://floatspace.imgix.net/production/wharves/5/1000473-Man-OWar-Steps-orig.jpeg), and [direction board](https://floatspace.imgix.net/production/wharves/5/1000623--orig.jpeg).
- [OpenStreetMap public map API](https://api.openstreetmap.org/api/0.6/map?bbox=151.2154,-33.8586,151.2163,-33.8575), retrieved 12 September 2026. Raw retained response selection is [manowar-piers.json](../source/map-data/manowar-piers.json); projected runtime outlines are [manowar_piers.json](../game/assets/manowar_piers.json). OSM contributors, ODbL. No source photo is redistributed in the game.

## Geometry and limitations

The stone pier uses way `1218228840`; the north and east floating platforms use ways `354759944` and `392403849`. Every source outline vertex is projected into the existing world coordinate system. Existing mapped gangway endpoints are retained. Eight original road records remain in the snapshot and are suppressed only in generic rendering because the authored solid structures replace them.

The fixed pier top is 4.58 m and the pontoon top 2.55 m in the game's flat world, estimated to meet the existing promenade and marine datum. These are not surveyed elevations or a tide simulation. Gangway width is estimated at 2.30 m, with 0.20 m overlapping ends to avoid a gameplay seam; render and collision use the same closed sloping wedge. The north bridge keeps a level apron over the masonry before descending; this avoids embedding its footway beneath the stone edge. Both side rails have collision barriers. Pier height, course joints, pile dimensions/locations, fittings and sign lettering are reconstructed approximations. The six-step count comes from the existing OSM footway record; risers are estimated at 0.20 m. The historical plaque inscription is not invented.

The masonry, floating platforms, gangways and fittings have independent, persistent `quay/manowar/` owners. Attached decoration disappears/restores with its owner. The pontoons are static and no scheduled boat service is added. North and east destinations have real platform support and map pins; navigation uses separate walking arrivals.

## Validation

[manowar_detail_test.gd](../source/manowar_detail_test.gd) checks source outline retention, structural mesh/collider agreement, winding, closed gangway edges, actual player walks in both directions to both berths, supported arrivals, actual settled capsule save poses and buried-pose rejection, plus damage/repair ownership. The final exported App also walks both berth routes and captures the complete waterfront in the city. Exact final run results and image hashes are recorded separately in [TESTING.md](TESTING.md).
