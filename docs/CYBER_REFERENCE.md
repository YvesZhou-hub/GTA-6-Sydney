# CyberCX and Cloudflare Sydney office exteriors

Verified 10 September 2026. These are original exterior reconstructions of the buildings containing two current Sydney offices. No company photographs, textures or third-party 3D models are redistributed, and no oversized company facade logo is invented. Office interiors and tenancy fit-outs are outside this module.

## Correct current identity

- **CyberCX NSW office:** Level 23, 2 Market Street, Sydney, verified against [CyberCX's official contact page](https://cybercx.com.au/contact-us/). The same page identifies its Australian headquarters at 330 Collins Street, Melbourne. The map destination is therefore “CyberCX · Sydney office”. The older 117 York Street address is not used.
- **Cloudflare Sydney office:** 388 George Street, Sydney, verified against [Cloudflare's official office directory](https://www.cloudflare.com/en-ca/about-overview/). The building is also known historically as King George Tower, NRMA House and IAG House. The destination does not imply that the entire building belongs to Cloudflare.

## Map position and source interpretation

All six parent/part outlines retain the exact OpenStreetMap vertices from `source/map-data/city.json`, whose base timestamp is 2026-09-10T10:26:34Z. Coordinates use the existing game projection, +X east and +Z south, origin −33.86, 151.2105. The recorded 2 Market Street model reference point is approximately −33.87057312, 151.20423377; 388 George Street is approximately −33.86836328, 151.20744805. These reference points are inside the buildings; separate `arrival` positions in metadata lie at the street approach.

| Building | Parent OSM way | Part ways replaced |
| --- | --- | --- |
| 2 Market Street | 1521293802 | 335699164 main tower; 335699165 seven-level Forecourt building; 1521293801 connecting atrium |
| 388 George Street | 386563854 | 386563852 tower |

The snapshot incorrectly names way 386563854 “Queen Victoria Building”. Address, footprint and official owner evidence identify this site as 388 George Street; that wrong name is not propagated. Sydney's actual Queen Victoria Building is a different landmark. Neighbouring Hooker House, way 386563855, is not included in the exclusions.

`excluded_way_ids()` lets the ordinary map builder omit these six replaced volumes. `footprints()` retains their map polygons for shared building/vegetation reservations. Map-derived geometry is © OpenStreetMap contributors, ODbL, with the game's existing attribution.

## Exterior evidence and modeling decisions

For **2 Market Street**, the [official property homepage](https://www.2marketstreet.com.au/home/) and its [full exterior photograph](https://www.2marketstreet.com.au/images/librariesprovider15/homepage/2mkthomepagehead5688x2792px.jpg?sfvrsn=5a125a0e_2), viewed directly in the browser, show blue glazing, broad silver horizontal bands, paired round vertical strips, stepped upper massing, and the much lower adjoining Forecourt building with projecting roof blades. These features are modeled geometrically with filtered window detail. The [CVU/CTBUH Allianz Centre record](https://www.skyscrapercenter.com/building/allianz-centre/19314) supplies the 83m architectural height. Individual roof steps and the Forecourt's 29.5m roof / 32.5m blades are photo-based estimates. Seven mapped Forecourt levels are retained. Level numbering and the operator's 17 leased tower office levels are not treated as a surveyed facade elevation. [COX's completed refurbishment account](https://www.coxarchitecture.com.au/project/2-market-street/) documents the renewed street entrance and bronze/timber material palette; its private lobby is not claimed as modeled.

For **388 George Street**, [Singapore Land's property record](https://www.singaporeland.com/portfolio/388-george-street/) confirms the tower and five-storey pavilion. Its [current exterior photograph](https://www.singaporeland.com/wp-content/uploads/2025/01/pic1.jpg), viewed directly in the browser, informed the diagonal main facade, tall rounded edge piers, large stacked atrium windows, and curved, layered street pavilion. The [CVU/CTBUH IAG House record](https://www.skyscrapercenter.com/building/iag-house/19697) supplies 131m architectural height and 32 total floors. Owner/contractor descriptions count 28 office levels or a 30-storey commercial building; these differing level conventions are not used to invent precise floor-by-floor occupancy.

[Multiplex's completed project account](https://www.multiplex.global/projects/388-george-street/) identifies five four-level atria and the five-level pavilion. All five atrium groups have actual recessed geometry behind their glazed screens; their 6m recess depth and individual floor spacing are estimates. [FJC's project description](https://fjcstudio.com/projects/388-george-street/) identifies the diagonal public arcade and gently curved concrete/louvre pavilion. The [completed arcade photograph](https://fjcstudio.com/wp-content/uploads/2023/11/5-scaled.jpg) and [canopy photograph](https://fjcstudio.com/wp-content/uploads/2023/11/2-scaled.jpg), both viewed directly, informed the overhead zigzag ribs, timber inserts and glazing.

The current pavilion has no separate suitable OSM part in the snapshot. Its rounded footprint is an explicitly photo-based reconstruction contained within the parent outline, separated from the tower to preserve the George Street–King Street pedestrian connection. Its roof terrace is at an estimated 22.05m; railing and facade details are approximate. No real tenancy interior, operating lift, underground retail level or complete rooftop hospitality venue is claimed.

## Integration and validation

The module uses the same `build`, `metadata`, `footprints`, and `excluded_way_ids` API as the bank models. Repeated facade details are constructed in CPU arrays before submission; they do not require one GPU mesh readback per mullion. Damage and repair use stable component IDs and the existing world registry.

```sh
./tools/runtime/godot --headless --path game --script ../source/cyber_landmark_test.gd
./tools/runtime/godot --path game --script ../source/cyber_landmark_test.gd -- --capture
```

The isolated test uses the production world geometry helpers and physics. It checks all six original OSM outlines within 2mm, architectural heights, real tower and pavilion collision, five physically recessed atria, and 120 human capsule positions along the public arcade. It also checks outward mesh winding, nondegenerate triangles, bounded geometry, and collision removal/restoration on damage/repair. Local render captures are written to `reports/cyber-refinement/`; these are model inspection views, not proof that the final surrounding city has been reimported and integrated.

Final validation: **17 assertions passed** in native Godot 4.7.2 / Metal on Apple M4, with **53,464 triangles and 71 damage components** (`reports/cyber-refinement/native-final.log`). Five native captures were inspected: both Market Street massing/roof views and the George Street tower, curved pavilion and traversable arcade. White pier cladding has matching cylindrical collision. Stone cladding is separated from glazing and the site's paving finish sits above the shared city ground to avoid coplanar flicker; no extra ground collision seams were introduced.
