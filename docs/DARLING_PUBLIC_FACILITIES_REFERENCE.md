# Darling Square, Darling Quarter and Tumbalong Park

Checked 11 September 2026. This is a selective, original geometric reconstruction using public references. It is not a survey, a complete replica of every shop, or a representation of every accessible room.

## Places and coordinate evidence

Darling Square's Exchange, Nicolle Walk and Steam Mill Lane are distinct from the Darling Quarter children's playground north of Tumbalong Park. The giant climbing net is about 400 metres north of the square's garden. The new models do not move the playground into the square.

The [official playground page](https://www.darlingharbour.com/see-do-stay/darling-harbour-children-s-playground) identifies Darling Quarter, the 8-metre-wide slide, climbing equipment, water play and the 21-metre flying fox. The [landscape architect's project](https://www.aspect-studios.com/projects/darling-quarter/) supplies actual aerial and close-up photographs. The [equipment supplier](https://playbydesign.com.au/portfolio/darling-quarter-playground/) identifies the 11-metre Giant Octanet, climbing valley, basket swing, pumps, water wheels and Archimedes screw. The supplier's dimensions support the large net and wide slide; all unmeasured fittings remain estimates.

The operator's [Mid Boulevard landscape plan](https://www.darlingharbour.com/getattachment/724fc83e-e6ab-45db-a604-b3e4add53355/file) was rendered and visually inspected. It confirms the relationship of Exhibition Centre, folded landscape, Tumbalong Park and the playground. Its cropped equipment area does not justify surveying each device from that drawing.

An additional OSM query fetched **18 equipment and water elements**. The public source subset is in [darling-play-equipment-osm.json](../source/precinct-data/darling-play-equipment-osm.json); the game uses [darling_public_facilities.json](../game/assets/darling_public_facilities.json). Equipment positions use the mapped nodes directly, with the project projection `x=(longitude−151.2105)×92400`, `z=(−33.86−latitude)×111320` and the existing flat ground `y=4.5`. OSM is not independently surveyed site data.

| Model | Source geometry | What was added |
|---|---|---|
| Giant Octanet | node 10590136162 | 11m central mast, eight cable sectors, diagonal and horizontal blue net, ground anchors, visible solid low traverse ropes |
| Climbing valley | node 10590136169 | Steel posts and undulating low net, distinct from the tall net |
| Wide slide | node 10590136159 | 8m face, curved sliding surface, side lips, rear steps with actual collision |
| Two smaller slides | nodes 10590136176/179 | Separate mapped devices with rear steps and sloped collision |
| Basket swing / swing | nodes 10590136175/157 | Frames, suspension, nest ring and seating |
| Water play | way 1136058495 and nodes 10696013709/713/714 | Shallow channel, pumps, wood platform, wheel and helical screw; detailed objects use the actual mapped points |
| Four fountain footprints | ways 183246961, 668599850, 730089774/775 | Irregular/rectangular mapped outlines, shallow surfaces, jets and approximate 1.4m paved margins |
| Playground shelter | way 1136058496 | Mapped roof outline, warm underside and slender open posts; replaces the erroneous generic 8m solid building |
| Membrane shade | way 1241018458 | Mapped nonrectangular outline, two-sided tensioned surface and four posts; removes generic building windows |
| Service room / toilets | ways 1241018456/457 | Existing mapped outlines retained as low 2.9m blocks with door details, replacing default 8m extrusions |

The 21m flying fox and newer Ribbon/Bay/Wave zones are **not fully reconstructed** in this module. The water wheel, pumps, screw and swings are visible geometry, not player-operated mechanical simulations. The low ropes have collision; the game does not yet implement hand-over-hand rope climbing to the 11m apex. The wide slide's steps and surface are physically traversable with the production player controller.

Shade elevations are photographic estimates. The membrane is centred about 5.4m above local ground with 6.6m support posts; the earlier lower estimate blocked the player's head on the top slide steps and was corrected. There is no invisible ramp to the net apex. The 72 existing OSM tree points around the playground remain the production vegetation source; this module does not duplicate them with a fabricated grove.

## Merchant coverage: all records, selective exterior reconstruction

The [official Darling Square directory](https://www.darlingsq.com/eat-drink-shop/) was expanded to all **71 visible cards**. Their names and listed addresses are preserved in [darling_precinct_directory.json](../game/assets/darling_precinct_directory.json), with a per-record location and modelling status. [derive_darling_businesses.py](../source/precinct-data/derive_darling_businesses.py) reproduces the OSM branch matching and street-wall projection. It does not fuzzy-match similarly named shops elsewhere in Sydney.

| Coverage | Records | Meaning |
|---|---:|---|
| Existing researched frontages | 15 | The 12 earlier frontages plus Auvers, Hakatamon and Chinta Ria; retained with their individual evidence limitations |
| Additional mapped frontages | 23 | Actual OSM branch point projected onto a mapped ground-level exterior wall; unmeasured widths, glazing and furnishings inferred |
| Exchange building directory | 14 | Shared public building forecourt, not a private stall door or reconstructed room |
| Directory only, unresolved location | 18 | Retained as records; no fabricated precise shop door |
| Occupancy conflict | 1 | XOPP remains on the directory while current Haidilao is also listed; no claim of a current exact XOPP location |

**The 23 new fronts are not 23 photo-identical replicas.** Three received more specific exterior/open-bar modelling after actual image inspection; two received only photograph-supported display contents:

| New shop | Actual inspected reference | Implemented evidence / remaining inference |
|---|---|---|
| Bendigo Bank | [Jodie Dang Architects, completed Darling Square branch](https://www.jodiedangarchitects.com/bendigo-bank) | Dark brick plinth, curved bronze-coloured glazing, upper louvres, right-hand door and vertical sign. Curvature/width approximated within mapped wall extent. The directory's stock meeting photograph was not used as facade evidence. |
| Thirteen Feet Tattoo | [Supplier's actual shopfront photograph](https://online.remondis.com.au/article/industries/simplifying-waste-management-for-tattoo-parlours/3v14nmy), [operator's Haymarket address](https://thirteenfeettattoo.com/about) | Gold fascia, left entry, right neon window, black brick piers, framed sheets and projecting sign. Abstract display drawings are newly authored; the photographed tattoo art was not copied. |
| Bar Bubu | [Official 2025 Kera Wong photo](https://www.darlingsq.com/eat-drink-shop/bar-bubu/) | Open black lift-up glazing, yellow fluted counter, red high stools, wooden bottle cubbies and gallery wall. A shallow representation visible from the street; no complete playable bar interior. |
| Puppuccino Pet Spa | [Operator's specifically labelled Darling Square interior](https://puppuccino.com.au/locate-us) | Yellow/white partition, timber base and product shelves. Exterior doorway and sign remain inferred. |
| Lillianna Gifts & Home | [Official display photograph](https://www.darlingsq.com/eat-drink-shop/lillianna-gifts-and-home/) | Colour-grouped gift boxes, diffuser bottles and shelving. Exterior frame and sign remain inferred. |

The original 18 remaining fronts had inferred retail fit-outs. The 12 September refinement below adds three photo-informed exteriors and one photo-informed counter display; 14 of those fronts still retain fully inferred fit-outs. The merchant name and geographic relationship are the supported facts; the construction details are not asserted to be measured or photographed. Existing solid OSM host buildings remain, so these shop doors do not falsely lead to remote boxes or invented private interiors.

### Address corrections

- [Lillianna's operator](https://lillianna.com.au/pages/contact-us) specifies **Shop 2/4 Steam Mill Lane**, not the directory card's 12 Steam Mill address.
- [Lermont's detailed precinct page](https://www.darlingsq.com/eat-drink-shop/lermont-laser-clinic/) distinguishes **Laser Clinic: 6 Steam Mill Lane** from **Skincare: 70 Hay Street**.
- [Darling Harbour's Uliveto listing](https://www.darlingharbour.com/offers/dine-sip-save-20-at-uliveto) places it at **3/35 Tumbalong Boulevard**; the directory card repeats DOPA's 2 Little Hay address.
- [Holy Basil's own branch page](https://holybasil.com.au/darling-square/) supports **SW08, 51 Tumbalong Boulevard**; the previously corrected frontage is retained.

The 14 Exchange records are labelled **“Exchange 楼栋入口”** in navigation. They do not represent 14 separately built entrances. Haidilao reuses the existing `exchange_haidilao` destination instead of adding a duplicate marker. The new module therefore provides 36 additional business destinations plus 4 facility destinations. Unresolved records are not silently mapped to the square's centre.

## Integration and verification

`darling_square_detail.build()` invokes both new modules; their builds are idempotent. World metadata keys are `darling_public_facilities` and `darling_precinct_businesses`; records expose `id`, `name`, `center`, `map_position`, `arrival`, and `position`. `capture_views()` provides 14 world-space camera/target triples. `walk_routes()` provides two public perimeter routes and the actual wide-slide stair/slope route. Damage IDs retain `darling_detail/` or `darling_square/` so the existing migration scope applies.

The four replaced facility ways must remain excluded from ordinary city extrusion. Geometry is submitted in material batches attached to each destructible structure. Compound equipment records expand their damage/migration bounds to the complete visible geometry; the implementation does **not** add large invisible collision boxes. Attached materials are retained through damage and repair.

[darling_public_facilities_test.gd](../source/darling_public_facilities_test.gd) originally ran **101 local checks** (the 12 September frontage refinement extends this to **123**): directory classification, mapped element counts, all 40 additional public arrivals, continuous 0.30m capsule/ground sweeps of the two perimeter routes, finite outward mesh faces, wide slide bounds, full 11m mast damage bounds, and destruction/repair of compound collisions and materials. It also moves the production `harbor_player.gd` via input actions up the visible steps and down the slide; only the test's starting point is positioned directly.

The local test's scene is a restricted map context, not a final exported-app test. Full-city vegetation, neighbouring landmarks, native game navigation and release packaging require the parent integration run. `reports/darling-v014` contains local QA captures and reports; no final release is implied by those component results.

All textures, labels and geometry are authored in code. Reference photographs and maps were inspected but are not bundled as game textures. OSM-derived coordinates retain the project's ODbL attribution and source records.


## Branch-specific shop refinement — 12 September 2026

Four existing mapped shop bays now have separate, original geometric treatments. **Three have exterior-photo evidence; Sushi Sei has room/counter evidence only.** This is not four fully surveyed facades. The 23-record directory classification remains a record of the initial OSM-derived placement, while each frontage now carries its more specific `model_status`, inspected image URLs, date and limitations.

| Shop | Actually viewed photographs | Implemented geometry and limits |
|---|---|---|
| Haven Specialty Coffee, 85 Harbour Street | [Branch-specific supplied exterior](https://cdn.concreteplayground.com/content/uploads/2020/02/Haven-Specialty-Coffee-Haymarket-supplied2.jpg), [counter](https://cdn.concreteplayground.com/content/uploads/2020/02/Haven-Specialty-Coffee-Haymarket-supplied3.jpg), identified by [Concrete Playground's Haymarket listing](https://concreteplayground.com/sydney/cafes/haven-specialty-coffee-darling-square) | Black brick base/piers, left glazing, tall vertical lettering, upper louvres and service window; punched wood panel, cold-drip tower, espresso machine and glazed pastry case. The model uses estimated proportions within the retained 6.5m bay. Rosebery and Darling Quarter pictures were rejected as different branches. |
| Pancakes On The Rocks, 55 Tumbalong Boulevard | [Original visitor photograph](https://pimg.1px.tw/doreenabc0527/1752653413-3569393096-g.jpg), [visit account explicitly distinguishing Darling Harbour from The Rocks](https://doreenabc0527.pixnet.net/blog/posts/9577962840) | Three red folding-arm awning spans, tall divided glass, double-sided red timber-look blade with cream lettering, horizontal slatted planter and broad leaves. Article published July 2025; photograph date was not independently verified. The real frontage is longer than this retained 8m representative bay; canopy depth, plant spacing and entrance offset are estimates, not a measured complete tenancy. |
| Bengong Black / Bengong's Tea, 91 Harbour Street | [Darling Square exterior dated October 2019](https://1.bp.blogspot.com/-Yy0B-uaLRq4/XaahZgyUgoI/AAAAAAADgjk/L8Meh7RKQbY4UJhKtVX46Zepwwrip3cPwCKgBGAsYHg/s1600/IMG_20191016_145640.jpg), [photographer's branch account](https://juliesdiningclub.blogspot.com/2019/10/bengong-black-sydney.html); [current precinct identity/address](https://www.darlingharbour.com/eat-drink/bengong-black) | Circular black blade, dark bronze-style full-height divisions, paired tall pull handles, low horizontal rails, tiered bakery case and interior lettering. Historical exterior is evidence for these features; the current directory confirms branch identity, not that every fitting remains unchanged. Retained width 5m; no outdoor seating added. |
| Sushi Sei, Shop 20/2 Little Hay Street | [Operator's actual room photograph](https://cloud.katana.nexigen.digital/katana/svcisREQdWtv6yWPKoO3VcNRi5kIZum3DYraI1BZ.webp), [chef/counter photograph](https://cloud.katana.nexigen.digital/katana/1hWLThKnIDOhwy8dqgzJk4DCeY6kfZo8LUdEnIVS.webp), [current operator website](https://sushisei.com.au/) | Pale wood counter, dark vertical screen, pale hanging rear curtain, warm cove strip and four representative counter seats, compressed into a shallow shop-window relief. **Exterior window/door/sign layout remains inferred**, and the display is not a complete dining room. Current operator address corrects the older SE04 field; mapped wall/node stay unchanged. The website's explicitly AI-labelled menu illustrations were not used. |

The Starbucks and McDonald's precinct banners were actually inspected and show generic drink/food imagery, which does not establish their shopfronts. They therefore remain inferred this round. Other unverified branches were not used as substitutes.

All four keep the existing map front, normal, width, public arrival and backing collision. The nominal backing height is 4.400m, and its plane is offset 0.420m outward from the mapped wall to clear the ordinary building's cornices. Generated mesh bounds, rounded to 1mm, are:

| Frontage | Maximum outward extent from backing | Maximum height above model ground |
| --- | ---: | ---: |
| Haven Specialty Coffee | 0.880m | 4.460m |
| Pancakes On The Rocks | 1.255m | 4.400m |
| Bengong Black | 1.190m | 4.400m |
| Sushi Sei | 0.840m | 4.400m |

The 1.360m depth value is the **QA allowance**, not a measured shop dimension or the actual maximum model extent. The Pancakes maximum comes from the projecting sign's outer edge; Haven's upper detail rises above its nominal 4.400m backing. Planters and counter fittings are visual details attached to their frontage's destructible body. Door approaches and the public strip in front remain clear, and there are no new traversable private rooms. Fonts, product shapes and signs are original approximations; reference photographs are not stored in game assets or the source package.

The first exported-App image review found three text/frame overlaps. Pancakes' horizontal identifier is now on the exposed red awning valance, Bengong's two lines fit within one uninterrupted glass pane, and Sushi Sei's secondary line sits within the fascia above the window cove. These changes correct the actual label/structure relationship, retain normal depth testing and leave the capture cameras unchanged. The awning identifier's exact placement and typeface remain approximated; no new claim of surveyed sign positioning is made.

`photo_capture_views()` supplies four eye-height review frames; `capture_views()` includes them in the parent native review. The focused source fixture additionally checks the four unchanged mapped placements, per-record provenance, finite outward faces, shallow visual bounds and continuous capsule/ground samples across each public frontage. Final visual quality must be judged from the parent's rendered captures; a headless geometry result alone does not establish photo likeness.

The corrected focused headless run passed **130/130** checks (the original 123 plus four measured-bound checks and three label-visibility regressions), with exit 0 and no `ERROR`, `WARNING` or `FAIL` messages. Evidence is in `reports/darling-frontage-sign-fix.log` and `reports/darling-frontage-sign-fix/checks.json`. Each changed label has 891 mesh sightline samples across its full text bounds, viewed frontally and at two horizontal oblique directions. All current samples are clear; replaying the old text layouts against the same geometry detects 135 blocked Bengong samples, 191 Pancakes samples and 198 Sushi samples. This checks the visual frame meshes directly, including details without physics colliders. The component run did not start native rendering; the parent release workflow owns the unchanged four capture views and final visual acceptance.
