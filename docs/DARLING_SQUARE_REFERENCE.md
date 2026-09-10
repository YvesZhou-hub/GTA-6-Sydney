# Darling Square street frontages — source and reconstruction record

Checked **10 September 2026**. This is original procedural game geometry, not a photogrammetric scan. The selected merchants are named in the precinct's [2026 participating retailer list](https://www.darlingsq.com/globalassets/urban-regen/darling-square/dsq-yummy-buddies-gift-with-purchase-tcs.pdf), with current precinct or merchant pages checked separately. This establishes a published listing, not whether an individual shop is open at this moment. Older photographs establish exterior details, not a guarantee that every fixture still exists.

## Geographic placement

All coordinates use the game's geographic metre frame, with X east and Z south. Each OSM shop point is projected to the **outward ground-level edge of its own street-facing building footprint**; it is not treated as a surveyed doorway. The offline derivation in `source/frontage-data/derive_frontages.py` selects the edge toward the named lane, checks that the entire estimated facade fits the edge, and rejects positions inside another ground-level building. Ground-level entrance approaches and the lane centre are verified with physics capsule queries. Store widths are visual estimates except Matcha-Ya's documented 4.5 m. Normal vectors below point out of the shop toward the public lane. This preserves opposite sides, ordering and relative position while allowing honest uncertainty in individual shop boundaries.

The reproducible records, original OSM IDs and points, source URLs, estimated widths, projected facade centres and normals are in `game/assets/darling_square_frontages.json`. Building outlines remain in `game/assets/city_map.json` under its OpenStreetMap attribution. The typical point-to-wall adjustment is 2–8 m because shop POIs often sit inside a building, not on its outside wall.

| Shop | Verified address / street | Facade centre X, Z (m) | Outward X, Z | Evidence |
|---|---|---:|---|---|
| Edition Roasters | 60 Darling Drive | -865.32, 2066.58 | -0.940, 0.341 | photo_details |
| Matcha-Ya | 10 Steam Mill Lane | -842.46, 2041.33 | 0.356, 0.935 | photo_details |
| Nakano Darling | 14 Steam Mill Lane | -828.99, 2036.20 | 0.356, 0.935 | photo_details |
| Marrickville Pork Roll | 16 Steam Mill Lane | -819.50, 2032.58 | 0.356, 0.935 | partial_photo |
| KUKI | 9/18 Steam Mill Lane | -814.00, 2030.49 | 0.356, 0.935 | photo_details |
| Kwang Jang Pocha | Steam Mill Lane | -844.47, 2050.38 | -0.364, -0.932 | photo_details |
| Wingboy | 7 Steam Mill Lane | -827.51, 2043.76 | -0.364, -0.932 | photo_details |
| Holy Basil | SW.08, 51 Tumbalong Boulevard | -801.74, 2033.72 | -0.360, -0.933 | partial_photo |
| Gelato Messina | Shop 02, 3 Little Hay Street | -736.11, 2076.30 | 0.211, -0.977 | photo_details |
| Kürtősh | Shop 1, 16 Nicolle Walk | -735.92, 2063.43 | -0.993, 0.115 | location_verified |
| DOPA Donburi | Shop 5/6, 2 Little Hay Street | -678.14, 2078.30 | -0.194, 0.981 | photo_details |
| Shortstop Coffee & Donuts | 15 Little Hay Street | -690.40, 2086.20 | 0.212, -0.977 | photo_details |

## Individually inspected reference photographs

The photographs listed here were viewed directly; no image pixels are downloaded into or redistributed with the game. Public photographic sources supplement the official name/address records. The native reconstruction uses individually authored geometry and lettering, with common geometry helpers but a different composition for each shop.

### Edition Roasters

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/edition-coffee-roasters/) · [Merchant/address source](https://editionroasters.com/) · [Photo source](https://sydneytales.com/edition-coffee-roasters/)

Dark grey panel pier, restrained small lettering, tall glazing and long slatted timber bench. Exterior photo June 2024.

### Matcha-Ya

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/matchaya/) · [Merchant/address source](https://matchaya.com.au/) · [Photo source](https://betterfutureawards.com/syd19/project.asp?ID=18744)

Documented 4.5 m facade. Black folding frame, low black awning, left fixed glazing/right entrance, green hexagonal tiles and zigzag interior light.

### Nakano Darling

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/nakano-darling/) · [Merchant/address source](https://nakanodarling.com.au/contact-us) · [Photo source](https://nakanodarling.com.au/about)

Dark horizontal roller/slat face, narrow entry, timber bench, hanging warm lanterns. Yellow noren is corroborated by the venue-linked Time Out review.

### Marrickville Pork Roll

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/marrickville-pork-roll/) · [Merchant/address source](https://www.darlingharbour.com/eat-drink/marrickville-pork-roll) · [Photo source](https://www.kuki.au/)

Neighbour visible at the left of KUKI official 2024 photograph: black brick, small illuminated badge, red interior. Official precinct confirms a small counter and neon tiger; no Illawarra Road awning copied.

### KUKI

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/kuki/) · [Merchant/address source](https://www.kuki.au/) · [Photo source](https://incostudio.co/projects/kuki-softserve-and-cookies)

Two asymmetric apertures, peach order canopy, square KU/KI blade, cream lightbox, pink stone counter, timber counter base. Yusuke Oba March 2024 photography.

### Kwang Jang Pocha

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/kwang-jang-pocha/) · [Merchant/address source](https://www.darlingsq.com/eat-drink-shop/kwang-jang-pocha/) · [Photo source](https://www.darlingsq.com/eat-drink-shop/kwang-jang-pocha/)

Official night photo: dark glazed facade, red vertical lettering, cream canopy, colourful plastic stools and flags.

### Wingboy

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/wingboy/) · [Merchant/address source](https://wingboy.com.au/) · [Photo source](https://www.opentable.com.au/r/wingboy-darling-square-haymarket)

Merchant listing exterior: dark green vertical wainscot, timber sill, large dark-framed glass, white sign and red neon. Exterior menu board remains beside the door.

### Holy Basil

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/holybasil/) · [Merchant/address source](https://holybasil.com.au/darling-square/) · [Photo source](https://www.notquitenigella.com/2023/05/23/holy-basil-darling-square/)

Open alfresco shop edge, warm metal trim and purple seating reference the photographed Darling Square venue. Exact street glazing subdivisions are inferred.

### Gelato Messina

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/gelato-messina/) · [Merchant/address source](https://gelatomessina.com/pages/stores) · [Photo source](https://madebytait.com.au/stories/gelato-messina/)

Actual Darling Square supplier photography: tall transom with white MESSINA letters, timber ceiling, folding glazed doors, yellow/white striped parasols, white wire chairs and timber planters.

### Kürtősh

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/kurtosh/) · [Merchant/address source](https://kurtosh.com.au/locations/)

Official branch/address and OSM point verified; exterior is an explicitly inferred glazed bakery frontage with timber pastry display and ochre ceramic details. No claim of photographed facade replication.

### DOPA Donburi

[Merchant/address source](https://www.darlingharbour.com/eat-drink/dopa-by-devon) · [Photo source](https://concreteplayground.com/sydney/restaurants/dopa-don-and-milk-bar)

Jasper Avenue Darling Square photo: narrow glazed door left, dark bronze divider with vertical gold DOPA lettering, broad right glazing, red tiled counter and pale furniture.

### Shortstop Coffee & Donuts

[Precinct listing](https://www.darlingsq.com/eat-drink-shop/shortstop-coffee-donuts/) · [Merchant/address source](https://www.short-stop.com.au/) · [Photo source](https://www.sydney.com/destinations/sydney/sydney-city/chinatown-and-haymarket/food-and-drink/shortstop-coffee-and-donuts-darling-square)

Darling Square tourism image confirms round navy SHORT/STOP projecting blade. Nick De Lorenzo Darling Square 2019 exterior photo confirms narrow left entry, timber jambs and right display, tall transom, blue tables and striped side panels. Approximate width 4.2m; supplied photo showing street number 19 excluded as unproven branch.

For Shortstop, the additional [actual Darling Square exterior by Nick De Lorenzo](https://www.broadsheet.com.au/sydney/food-and-drink/article/good-things-small-packages-third-store-shortstop-coffee-donuts), published in 2019, shows the small left entrance, timber display/window on the right, tall transom, circular blade, blue tables and striped side panels. The article confirms the 23 m² shop and 15 Little Hay Street address. The game's frontage was narrowed to approximately 4.2 m and rebuilt from that composition after inspection. The [official tourism image](https://www.sydney.com/destinations/sydney/sydney-city/chinatown-and-haymarket/food-and-drink/shortstop-coffee-and-donuts-darling-square) independently verifies the navy round blade.

Wingboy's [own location page](https://wingboy.com.au/locations/) confirms 7 Steam Mill Lane. Messina's [current store list](https://gelatomessina.com/pages/stores) gives **Shop 02, 3 Little Hay Street**; this is used instead of the conflicting address in its 2019 opening article. Matcha-Ya's [own contact details](https://matchaya.com.au/) give NW.05, 10 Steam Mill Lane.

## Limits and branch disambiguation

- **Nine facades use photographs of the identified Darling Square branch:** Edition, Matcha-Ya, Nakano, KUKI, Kwang Jang Pocha, Wingboy, Messina, DOPA and Shortstop. The models retain specific visible composition, not exact measured building-shop dimensions. Some transparent glazing and interior glimpses are represented as closed glazing.
- **Two use partial branch photos:** Marrickville Pork Roll is visible beside KUKI in the merchant's 2024 photograph; its narrow black/red counter is corroborated by precinct descriptions. Holy Basil's identified branch photographs show the gold trim, lighting and seating, but the precise street glazing pattern remains inferred.
- **Kürtősh is location-verified only.** Its own House No. 5 address and mapped position are verified; the glazed bakery facade is an explicitly inferred interpretation. Do not call this an exact photographed reproduction.
- Marrickville Pork Roll search results predominantly show the original Illawarra Road shop. Its broad red awning is deliberately **not** used for this branch. A Shortstop supplied photo showing number 19 was excluded because the branch was not proven. Unidentified Kürtősh branch photos were excluded.
- [The Exchange](https://www.darlingsq.com/discover/the-exchange/) includes interior food-hall tenants; they are not copied onto Steam Mill Lane. Haidilao remains within its separately modelled building and actual upper-level location. No claim is made that its interior is reproduced by these street frontages.
- This module makes exterior approaches and public lanes accessible. Doors are currently closed collision-backed exteriors, not playable restaurant interiors. Seats and umbrellas are visual street furniture. Their positions and dimensions are inferred within the lane-side envelope; historic photography does not establish current exact furniture placement.
- No artificial establishment, invented street address, menu transaction, or business affiliation is claimed. This is an independent game reconstruction.

## Integration and verification

`darling_square_frontages.gd.build(world)` adds 12 persistent destructible frontage bodies, unique `darling_square/<shop>/frontage` IDs and `shop_<shop>` navigation anchors, and publishes metadata under `darling_square_frontages`. It is idempotent for a given world. The JSON asset must ship with the game. Frontage meshes use CPU triangle construction with one mesh per material per shop, then participate in the world's ordinary structure batching and damage system.

`source/darling_square_frontage_test.gd` creates an isolated local Darling Square context with actual mapped building collision and roads, validates all 12 frontage records, exterior projection, full-height capsule approaches, outward triangle winding, distinct geometry/material compositions, and 81 lane-centre walking probes. Native `--capture` additionally builds normal world render batches and writes 12 facade views and a lane view to `reports/darling-square-frontages/`. No user saves are loaded, overwritten or deleted. Full-scene validation and release packaging are separate integration checks.


## v0.1.3: Nicolle Walk and the public square

[darling_square_detail.gd](../game/scripts/darling_square_detail.gd) retains the original 12 frontages and adds **three** identified street businesses. Sources were checked on 11 September 2026. Reference photographs were actually viewed; no third-party pixels are distributed. This is not a model of every precinct tenant or private interior.

| Venue | Mapped facade centre X, Z (m) | Identity and actual branch photograph |
| --- | --- | --- |
| Auvers · Shop 4 / 12 Nicolle Walk | −740.2197, 2026.2798 | [Operator address](https://www.auverscafe.com.au/reservations); [2019 branch report and exterior](https://www.broadsheet.com.au/sydney/food-and-drink/article/auvers-cafe-serving-van-gogh-inspired-art-plate-its-second-outpost-darling-square). Black blade with white hexagon, left entry, timber gable lines, wire chairs, host stand and patio heaters. |
| Hakatamon Ramen | −742.1580, 2009.5517 | [Precinct listing](https://www.darlingsq.com/eat-drink-shop/hakatamon-ramen/); [designer's project and Darling Square frontage](https://harleyjohnston.com/project/hakatamon-ramen/). Two glazed bays, red wave marks in the transoms, pale curtains, outward window hardware, timber counters and black stools. |
| Chinta Ria Buddha Love | −738.6480, 2039.8518 | [Precinct listing](https://www.darlingsq.com/eat-drink-shop/chinta-ria/); [2020 branch report and exterior](https://www.broadsheet.com.au/sydney/food-and-drink/article/giant-buddha-back-malaysian-comfort-food-simon-gohs-reborn-chinta-ria-darling-square). Red two-line window sign, bronze/dark frames, lantern forms and outdoor tables. The interior Buddha is not transplanted onto the street. |

The directly inspected images are [Auvers](https://cdn.broadsheet.com.au/cache/ac/f8/acf8aa0d4fef508d3bbfc3c34a924fb0.jpg), [Hakatamon](https://harleyjohnstondesign.imgix.net/uploads/2024/03/Hakatamon-ramen-store-front-DS.jpg) and [Chinta Ria](https://cdn.broadsheet.com.au/cache/17/0f/170fe1eb1f1df608c6aed5ca8483612a.jpg). Their publication dates do not imply a fresh 2026 facade survey.

OSM POIs 10590131122 / 9480685417 / 11834192053 are projected onto the west edge of ground-level podium **way/614603732**, not its upper residential parts. Projection distances are approximately 3.77 / 2.54 / 6.31 m. Widths 9.0 / 11.8 / 9.0 m and small fittings are photo estimates. Arrival anchors use left doorways with an outward stand-off, while map markers remain at facade centres. The common charcoal brick receives mortar joints and a glazed arcade roof; each business has a separate composition. Glazing remains a closed exterior representation, not a playable private interior.

The landscape follows [ASPECT Studios' official project](https://www.aspect-studios.com/projects/darling-square-2), its [built canopy photograph](https://aspect.imgix.net/ASPECT_DarlingSquare_000033_2022-07-27-083047_vguv.jpg), and the architect-supplied [project and numbered plan](https://mooool.com/en/darling-square-a-public-space-for-all-by-aspect-studios.html). The plan distinguishes The Exchange, Square, Canopy Edge, Lawn, Grove, Northern Steps and Tumbalong Boulevard. Approximate registration uses three existing mapped anchors: Exchange centre, Steam Mill/Tumbalong junction and Little Hay/Nicolle junction.

The addition includes the western canopy's curved pale ribbons and slender posts, timber-capped stone seats, a bounded lawn and eight planted grove positions. Original procedural fan-pattern paving covers the public square; it uses no photographic texture. Sparse branched tree geometry keeps the pedestrian space and shop approaches visible. Canopy endpoints are approximately (−780.912, 2017.617) and (−772.525, 2058.565). Furniture spacing, planting dimensions and elevations remain inferred. The original street centre-lines, existing stairs and Exchange geometry are retained. This flat-ground landscape does not claim surveyed topography or exact recreation of the lighting artworks.

Metadata group `darling_square_detail` publishes `id`, `center`, `map_position`, `arrival`, `source` and confidence; `anchors[id]` identifies the public approach. The combined [precinct test](../source/precinct_detail_test.gd) checks the additions against real local building and road collision. Its final runs pass **72/72 headless and 72/72 native checks** across both precincts, including all three new shop arrivals and the restored ground-level podium. Eleven native images were inspected, including all six new shops and the public-square/canopy views. This is an isolated mapped-precinct fixture; final complete-city and exported-application checks remain separate release evidence. No user save is loaded or changed.
