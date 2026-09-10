# Sydney Opera House exterior revision

Reviewed 10 September 2026. This is an original procedural game model based on photographs and architectural references. It is not a measured architectural/BIM model or a scan. No third-party photograph, texture, mesh or logo is redistributed in the game.

## References used

- [Sydney Opera House: The spherical solution](https://www.sydneyoperahouse.com/our-story/the-spherical-solution): shared spherical geometry, mirrored shell halves, 120 mm ceramic tiles and chevron arrangement.
- [Sydney Opera House: Dissecting Geometry teacher resource](https://sydneyoperahouse.api.collaboro.com/media/dissecting-geometry-teacher-resource): the official geometry/model and tile explanations, especially PDF pages 9–12.
- [Sydney Opera House conservation report, Getty Keeping It Modern](https://www.getty.edu/foundation/pdfs/kim/sydney_final_report.pdf): building dimensions of 183 m by 120 m, tallest sail approximately 67 m above sea level, and the exposed rib construction.
- [Northwest elevation photograph](https://imaginoso.com/australia/sydney/sydney-opera-house-northwest-elevation): directly inspected the real photograph for the rising north-facing shells, curved shoulders, deep soffits, bronze glazing and horizontal podium articulation.
- [Overhead photograph inspected in the browser](https://i.pinimg.com/originals/43/8e/4b/438e4bb7ecb01bea67545dbd715741cb.jpg): spatial reference only, provenance/licence not asserted. It shows the two unequal longitudinal groups, the narrow axial gap, southwest restaurant and broad southern stair approach.

## Model decisions

The 11 September [geographic audit](GEOGRAPHIC_ALIGNMENT.md) corrects the site reference to the OSM outer-footprint centroid `(427.29477, 4.5, -321.45441)` and its long-axis yaw `-13.23286°`. The previous `(421, 4.5, -326)` / `-12°` was an approximate placement. The western Concert Hall roof train is larger; the narrower eastern train is offset south. Their tall middle shells open north, the southern foyer roofs face the Monumental Steps, and the small Bennelong restaurant has two opposing shell ends southwest of the halls. Ten shell pairs are used to represent this form; they are game construction groups, not an asserted historic roof-count taxonomy.

Each half-roof lies on a 75.2 m radius sphere. Its central ridge is the circle where that sphere intersects `x = 0`, and the rounded shoulders follow spherical interpolation towards the springing point. Mirrored halves therefore share the same ridge positions. The largest roof reaches approximately 67.00 m above water. The 120 m wide podium and roughly 183 m north–south building/steps envelope preserve real-scale proportions; individual shell cuts, foyer mullions and podium subdivision are photo-based approximations.

The roofs have 320 mm geometric thickness with closed boundary faces. Eight bands per half, 160 in total, retain the `opera/shell/` damage namespace. Both visible ceramic skin and collision use the same triangulated surface. Fan ribs and edge strips belong to their matching band and disappear with it. The 61,440 roof triangles are batched through the existing world architecture cells, along with attached trim; details are not thousands of independently rendered roof nodes.

The material uses original analytic 120 mm tile cells, a subtle ivory/white chevron pattern and derivative filtering to suppress fine-pattern shimmer at distance. Undersides use a concrete tint and separate fan ribs. Six terminal foyers receive recessed bronze-glass curtains; intermediate roof joins remain roof/soffit geometry instead of enormous glass fin walls. The podium has warm stone, shallow southern steps, inset horizontal foyer glazing, sunshades and side colonnade glazing. The 48 visible shallow stair treads use eight continuous ramp colliders so walking does not repeatedly hit vertical stair faces. They are a navigation approximation, not a claim about the real step count.

## Verification

Run from the repository root:

```sh
./tools/runtime/godot --headless --path game --script ../source/opera_landmark_test.gd
./tools/runtime/godot --path game --script ../source/opera_landmark_test.gd -- --visual
```

All 17 native checks pass. They cover the site anchor, spherical error, mirrored ridge closure, springing points, normal/winding direction, triangle budget, closed band boundaries (vertices welded within 0.05 mm), height, ten exterior and ten interior physics rays, all 48 stair stations, and local roof/rib/collider damage and restoration. The visual mode runs Metal Forward+ and saves four actual engine renders under `/tmp/harbourlife-opera-review/` for northwest, aerial, stair and close tile review. Mathematical checks were supplemented with repeated visual comparison: the first radial-projection version was rejected because its mirror ridge separated, and the first glass placement was rejected because the intermediate curtains dominated the silhouette.

Auditorium interiors, exact structural rib schedules, surveyed restoration-era details and full construction-document accuracy are outside this exterior revision. Existing project permissions and third-party rights notices continue to apply.
