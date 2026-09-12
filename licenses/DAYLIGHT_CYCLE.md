# Day/night cycle sky assets

The two new sky-only HDR panoramas below were downloaded directly from Poly Haven's official asset CDN on **2026-09-12**. Both are **CC0 1.0 Universal**; they may be redistributed with this game. Their original pixels are unchanged. The blend, horizon colour treatment and moving solar disc are original Harbourlife shader code.

| Asset | Authors | File | Bytes | SHA-256 |
|---|---|---|---:|---|
| [Qwantani Sunset (Pure Sky)](https://polyhaven.com/a/qwantani_sunset_puresky) | Greg Zaal — Photography; Jarod Guest — Processing | `qwantani_sunset_puresky_2k.hdr` | 4,171,959 | `d66e08231e9c09ca40c6d035214ae8efb638782745c82addbb2a063fa32cabef` |
| [Qwantani Night (Pure Sky)](https://polyhaven.com/a/qwantani_night_puresky) | Greg Zaal — Photography; Jarod Guest — Processing | `qwantani_night_puresky_2k.hdr` | 5,461,210 | `d458fe7f20969d89eedbb7ae12d346abf68c86d844235696e7d70baad3e04cf0` |

Both files are 2048 × 1024 pixels. [Poly Haven licence](https://polyhaven.com/license); [CC0 dedication](https://creativecommons.org/publicdomain/zero/1.0/).

Direct originals: [sunset HDR](https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/qwantani_sunset_puresky_2k.hdr), [night HDR](https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/qwantani_night_puresky_2k.hdr). [Machine-readable attribution and local hashes](../game/assets/environment/sky_sources.json).

The original asset pages were read to verify attribution and CC0. The official API returned HTTP 403 during this acquisition; no API-provided MD5 verification is claimed. Byte counts, SHA-256 and MD5 in the manifest were measured locally from the downloaded files.

Both original HDRs were decoded and visually inspected with a temporary tone-mapped preview. The sunset photograph contains a low solar disc, pale warm horizon and wispy clouds. The night photograph contains stars and a Milky Way band; its long-exposure brightness is reduced in the game. Inspection previews remain in ignored development reports and are not shipped as replacement sky pixels.

These photographs depict a source sky outside Sydney. They provide artistic light and cloud detail, not surveyed Sydney scenery, actual local weather, or measured stars over the current player position. The main city clock independently provides the Sydney summer solar direction; this is not a lunar ephemeris or a calibrated weather simulation. The existing daytime panorama remains credited in [DAYLIGHT_ENVIRONMENT.md](DAYLIGHT_ENVIRONMENT.md).
