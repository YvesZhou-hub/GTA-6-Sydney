# Geography, original architecture and landmark rights

## OpenStreetMap

© OpenStreetMap contributors. Data is available under the [Open Data Commons Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Attribution and licence information: [openstreetmap.org/copyright](https://www.openstreetmap.org/copyright).

The files `source/world_osm_reference.json`, `source/world_osm_water.json`, `source/world_geography.json`, and `game/assets/world_geography.json` contain OSM data or a transformed/simplified database derived from it. Those data files are distributed under ODbL 1.0; the transformed database is included so recipients have access to the adapted data. Do not remove the OSM attribution from the game's credits/map or these data files. OSM contributors' upstream metadata remains in the raw extracts.

The same ODbL terms apply to the expanded raw snapshots in `source/map-data/`, the compiled `game/assets/city_map.json`, and OSM-derived coordinate records in `game/assets/darling_square_frontages.json`. `tools/import_city.py` and `source/frontage-data/derive_frontages.py` preserve the conversion process. Detailed coverage, snapshot ages and confidence limits are in [CITY_DATA.md](../docs/CITY_DATA.md). In particular the ordinary Manly extract is dated 6 May 2026; it must not be represented as a fully current September survey.

Queries were made to the Overpass API on 10 September 2026, for the Sydney Harbour area (-33.876,151.187,-33.833,151.241). A second query retrieved water relation members with expanded geometry bounds (-33.880,151.180,-33.830,151.245). This is data access, not extraction of Google/Bing imagery. No map tile artwork, aerial imagery, photogrammetry, satellite texture or third-party 3D building model is in the harbour assets.

## Original generated world assets

The reusable world modeling source is `game/scripts/harbor_world.gd`; original procedural facade/water shaders are `game/assets/world_facade.gdshader` and `game/shaders/water.gdshader`. Building shells, bridge pieces, studio furnishings, shop signs, poles, benches, garden vegetation and tile textures are generated from these authored algorithms. No resource pack, marketplace download, image-generator output, font download, or paid art service was used for the world geometry. Godot's engine/default font licensing is recorded separately by the project.

Architecture/factual sources are listed in `reports/GEOGRAPHY.md`. Reading a publicly available architectural description does not grant a licence to that site's photography or drawings. None of those media is redistributed here.

## Unresolved commercial clearance: Sydney Opera House

This local build is **not a declaration of commercial clearance** for reproducing or promoting the Sydney Opera House. Original mesh authorship does not establish every applicable architectural, landmark-image, trademark, merchandising or promotional right. No approval or licence from the Sydney Opera House Trust has been obtained, and no affiliation or endorsement is claimed.

The Opera House's official [media image gallery](https://www.sydneyoperahouse.com/media/media-image-gallery) limits its supplied images to media use and excludes commercial purposes. Those images have not been downloaded or included. Its official [brand/image policy](https://sydneyoperahouse.api.collaboro.com/direct?Guid=1bbd6463-1bd4-4e67-9715-b92558e2f0fb) discusses control of the brand and image. These materials support flagging the issue; they do not by themselves decide the full legal status of an independently modeled, fictional interactive game in every territory.

Before paid public distribution or storefront advertising centered on the landmark, the publisher must resolve appropriate legal/rights review and any permissions that review identifies. This record intentionally does not invent an approval, presume that renaming the landmark solves rights issues, or use the local playable build as proof of commercial publishability.

The bridge and real place names also require ordinary publisher review for promotional use and non-endorsement. No government or real transport operator's logo, livery or claimed endorsement is included in the world assets.
