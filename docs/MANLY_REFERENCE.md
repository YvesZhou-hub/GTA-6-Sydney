# Manly exterior reconstruction

Reviewed 10 September 2026. All game geometry is original procedural work. Photographs were viewed in a browser for proportions and architectural features; no photographic pixels or third-party 3D assets are shipped.

## Map evidence

- `source/map-data/manly.json`: OpenStreetMap / Overpass source, base timestamp 6 May 2026. Manly Ferry Terminal is way **7981564**; The Corso pedestrian area is **223785178**, with route **546705240**. Its western end also contains actual vehicle streets: this model does not pave over that traffic loop.
- `source/map-data/manly_landmark_detail.json`: targeted additional Overpass query from `https://overpass-api.de/api/interpreter`, base timestamp **10 September 2026 10:41:50 UTC**. Hotel Steyne is multipolygon **relation 7889573**, outer way **223786812**, inner courtyard way **552008767**. The true courtyard was retained; an offline constrained triangulation covers 1,560.175 m² of the building ring without filling the courtyard.
- `source/map-data/trees.json` and the compiled `game/assets/city_map.json`: mapped tree points. Species `Araucaria heterophylla`, genus Araucaria, Norfolk pine names and needle-leaved categories receive a branch-whorl pine model. Exact mapped positions are retained. Unclassified tree points inside The Corso are rendered as palms based on the inspected streetscape photograph; that species choice is an inference. Other Manly trees use the game's ordinary canopy model.
- Mapped bus platform nodes: Stand A **6388477486**, Stand B **6388478985**, Stand C **497623847**. Signs identify the physical stops without inventing live services, schedules or a working transit simulation.

All coordinates use the existing origin latitude −33.86, longitude 151.2105 and the existing planar metres-per-degree scale. OpenStreetMap geometry is © OpenStreetMap contributors, ODbL; the distributed map attribution and source data remain separate from the original model geometry.

## Visual references actually viewed

- [Manly Wharf photo, July 2022](https://www.pittwateronlinenews.com/resources/Entrance_to_Manly_Ferry_Wharf_July_2022.jpg.opt1498x899o0%2C0s1498x899.jpg), used from [Pittwater Online News](https://www.pittwateronlinenews.com/Manly-Wharf-plan-relocates-fauna-Freshwater-Ferry.php): wide curved entrance, white Art Deco facades, open columned concourse, dark roof fascia and finned clock tower.
- [Heritage NSW: Manly Wharf](https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=5051365): 1939–1941 Arthur Baldwinson reconstruction, arc-shaped entrance, clock tower fins, concrete platform and T-shaped clerestory. These features inform the model, not the precise as-built dimensions.
- [Hotel Steyne exterior photograph](https://cdn.concreteplayground.com/content/uploads/2022/08/HotelSteyne_Manly2_Supplied.jpg): two-storey brick building, raised corner parapet lettering, pale green window frames and awnings, small first-floor balconies and low toothed parapet.
- [Hotel Steyne official site](https://hotelsteyne.com.au/): identity and Corso location. The OSM address uses the adjacent South Steyne frontage; the model follows the actual corner footprint rather than either street-name label alone.
- [The Corso photograph from its beach end](https://sydney.com.au/images/the-corso-manly1.jpg), from [Sydney.com.au's Corso page](https://sydney.com.au/the-corso-manly.htm): fan palms, circular timber seating, pale paved surface with dark bands and low shopfront/awning proportions.
- [Manly Council Heritage Committee plaques](https://www.manlyaustralia.com.au/info/thingstodo/walks/manly-heritage-plaques/): Corso's former pines replaced by palms; Norfolk Island pines along the ocean foreshore.

## Scope and limits

The three detailed groups are Manly Wharf, The Corso and Hotel Steyne. The surrounding terrain, roads and ordinary building footprints come from the separate city map system. Wharf superstructure height (13.2m clock tower), Hotel Steyne height (11.4m to raised parapet), window rhythm, columns, awnings and timber seat placement are photo-based estimates, not survey measurements. Tree heights are illustrative. The platform and city use the game's 4.5m flat ground datum. Interiors, ferry services, individual shop stock and a fully surveyed city elevation model are not implemented by this module.

The Corso centreline remains physically clear. Its pavement is 9.5cm above the terrain datum to sit above the city's road ribbon without flickering. Wharf entrances are open columns, not a single solid building box. Hotel Steyne's courtyard remains a real physical opening. Building components use the game's existing persistent damage IDs; street furniture and foliage use spatial instancing.

## Validation

```sh
./tools/runtime/godot --headless --path game --script ../source/manly_landmark_test.gd
./tools/runtime/godot --path game --script ../source/manly_landmark_test.gd -- --capture
```

The test verifies integration, mapped tree population, the hotel courtyard collision void, actual Corso paving, an unobstructed 1.2m-wide / 2m-high pedestrian sweep along the Corso route, the open wharf entrance and damage registration. The full-scene headless run passed all seven assertions. For independent model review during the city-renderer refactor, the native Metal run used `--capture --local-context` (1,357 surrounding real buildings / 5,035 road segments) and passed the same seven assertions. All four resulting images in `reports/manly-refinement/` were visually inspected. This local native review does not substitute for the final full-city performance check. The module currently handles 185 mapped Manly tree points, including 138 pine/needle-leaved classifications.
