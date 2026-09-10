# Circular Quay tower exteriors

Research and native-model review: 10 September 2026. `quay_landmarks.gd` contains two distinct procedural exteriors, with explicit source confidence. This is a game reconstruction, not surveyed construction geometry, a complete interior, or a claim that Sydney is reproduced at 1:1 accuracy. No third-party photograph or texture is redistributed in the game.

## Location and height

| Model | Mapped world centre x/z, metres | Height used | Basis and limitations |
| --- | --- | --- | --- |
| Quay Quarter Tower, 50 Bridge Street | 94.871112 / 329.616717 | 206 m | Architect-published height; OSM base and four higher outlines. OSM marks geometry and its old 48/73/106/151 m part heights as estimated. Only the plan outlines are retained; heights are reconstructed to the published total. |
| Salesforce Tower, 180 George Street | -171.890096 / 264.077195 | 263 m | Developer-published height and mapped half-hexagonal outline; individual floor heights, crown setback and brace dimensions are inferred. |

The existing world projection is unchanged: `x=(longitude-151.2105)*92400`, `z=(-33.86-latitude)*111320`, base y=4.5. Footprints come from the existing `source/map-data/city.json` OpenStreetMap extract. Attribution and ODbL obligations remain those of the city dataset. Excluded ways are 312373859, 387782063, 1120046335–1120046338 and 1116329930, preventing generic buildings from occupying the same footprint.

## Quay Quarter Tower

[The architects' project description](https://www.archdaily.com/1003606/quay-quarter-tower-3xn) states 206 metres, 49 storeys and five shifted volumes turning east as they rise. The model preserves a common southern mass and the successively turning mapped northern faces. Its 49 upper floor slices are divided into groups of 9/10/10/10/10 above a 12 m lobby envelope; this distribution is a modelling estimate, not an as-built level schedule.

[BVN's project page](https://www.bvn.com.au/project/quay-quarter/) describes staggered projecting solar frames that alternate direction between volumes, and an open public podium. The model gives these frames real depth, ivory outer faces, bronze undersides, thick block-edge returns, and planted guards on exposed terrace edges. A recessed roof plant enclosure sits behind a separate structural parapet. Lobby and podium grade/columns are simplified; there is no simulated office, market interior or lift service.

Actual photographs inspected in the browser:

- [BVN aerial photograph](https://cdn.sanity.io/images/o5vscjl2/production/923db8a502d07ae969403f8748cb404dad83a2ef-1215x1620.jpg): five-village composition, terrace rotation and rooftop recess.
- [BVN copper-framed facade close-up](https://cdn.sanity.io/images/o5vscjl2/production/caf2c9437afaec8ac19f520ac7435b59e9283b8d-8380x10679.jpg): stagger, projection depth and warm frame undersides.
- [Phil Noller photograph published with the 3XN project](https://newatlas-brightspot.s3.amazonaws.com/16/07/1aa9cf834415baf52f49d791f64b/01-quay-quarter-tower-by-3xn-phil-noller.jpg): ground-view cantilevers and pale outer framing. Context: [New Atlas project article](https://newatlas.com/architecture/quay-quarter-tower-world-building-year-2022/).

Identity is verified independently of the historical AMP Centre name: [AMP's registered address](https://www.amp.com.au/help-and-support/need-to-serve-a-legal-document) lists AMP at Level 29, Quay Quarter Tower, 50 Bridge Street; [Deloitte's Sydney office page](https://www.deloitte.com/au/en/offices/australia-offices/sydney.html) lists its office here. Tenant identity is metadata, not fabricated retail signage.

## Salesforce Tower

[Developer Sydney Place](https://www.sydneyplace.com/workplace/workplace/) confirms 263 metres, 55 storeys, 180 George Street, and the externally expressed white tree structure. [Structural engineer Arup](https://www.arup.com/projects/salesforce-tower/) explains the half-hexagonal plan, rear core, and organic bracing on the northern facade linking to the twin northern columns. [Foster + Partners' project description](https://www.fosterandpartners.com/projects/salesforce-tower-at-sydney-place/) identifies three transparent lift banks book-ended by the southern concrete core. This page was available in the indexed primary-source result; live opening intermittently timed out.

Actual photographs inspected:

- [Arup / Foster + Partners / Brett Boardman, looking up at the northern apex](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-header-credit-foster-partners-brett-boardman-photography.jpg).
- [Same official project gallery, distant full-height view](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-1-credit-foster-partners-brett-boardman-photography.jpg).
- [Same gallery, crown detail](https://www.arup.com/globalassets/images/projects/s/salesforce-tower/salesforce-tower-3-credit-foster-partners-brett-boardman-photography.jpg).

The architect's [north elevation](https://www.metalocus.es/sites/default/files/metalocus_fosterpartners_salesforce-tower_27.jpg) and [south elevation](https://www.metalocus.es/sites/default/files/metalocus_fosterpartners_salesforce-tower_28.jpg), published with [Foster + Partners' project material](https://www.metalocus.es/en/news/a-new-icon-sydney-skyline-salesforce-tower-foster-partners), were also visually inspected. Six unequal branches per northern face were traced proportionally. Their outer junction heights in the model are 44/72/99/139/191/248 m; these are approximate values read from the elevation, not structural survey points. The northern twin trunks, shaded outer wings, southern concrete piers and three glass lift banks have separate geometry. The raised crown has a recessed roof and a structural parapet. The model uses a 14 m lobby and 54 upper floor slices; no underground or office interior is represented.

## Integration and validation

`build(world)`, `metadata()`, `footprints()` and `excluded_way_ids()` follow the earlier custom landmark API. Structural components use `quay/qqt/` and `quay/salesforce/` IDs. Fine geometry is joined by material per owner; tree branches are clipped at floor boundaries so the damaged floor removes the matching section of brace and its facade details. Rendered structural solids supply the same triangles as the collision shapes.

Run from the repository:

```sh
./tools/runtime/godot --headless --path game --script ../source/quay_landmark_test.gd --quit-after 600
./tools/runtime/godot --path game --script ../source/quay_landmark_test.gd --quit-after 600 -- --visual
```

19 checks passed in native Godot 4.7.2: mapping/exclusions, five QQT plan changes, six branch paths and floor clipping, nondegenerate triangles, outward winding, identical structural render/collision faces, total heights, physical roof rays, and destruction/restoration. Final module: 149 structural components and 98,888 triangles including repeated facade details. Native screenshot review covers `qqt_north.png`, `qqt_street.png`, `qqt_roof.png`, `salesforce_north.png`, `salesforce_south.png`, and `salesforce_roof.png`, written to `/tmp/harbourlife-quay-review/`. These isolated scene checks precede the parent's full-city integration regression.
