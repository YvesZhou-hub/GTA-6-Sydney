# Bundled Noto fonts

These original upstream font binaries are distributed with Harbourlife under the SIL Open Font License 1.1. No macOS system fonts are copied into the project. No glyphs were removed, renamed or modified. Godot’s normal import cache is derived from these source files.

The accompanying original license files are listed below. The application build copies this `licenses` directory into `Harbourlife.app/Contents/Resources/licenses`. Source distributions include the same licenses.

| Font | Role | Source | License | SHA-256 |
|---|---|---|---|---|
| `NotoSansCJKsc-Regular.otf` | CJK primary | [Pinned upstream file](https://github.com/notofonts/noto-cjk/blob/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf) | [NotoSansCJK-OFL.txt](NotoSansCJK-OFL.txt) | `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b` |
| `NotoSansCJKsc-Bold.otf` | Offline caption bold | [Pinned upstream file](https://github.com/notofonts/noto-cjk/blob/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Bold.otf) | [NotoSansCJK-OFL.txt](NotoSansCJK-OFL.txt) | `b5f0d1a190a7f9b43c310a8850630af12553df32c4c050543f9059732d9b4c0a` |
| `NotoSans[wdth,wght].ttf` | Latin fallback | [Pinned upstream file](https://github.com/google/fonts/blob/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/notosans/NotoSans%5Bwdth,wght%5D.ttf) | [notosans-OFL.txt](notosans-OFL.txt) | `bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d` |
| `NotoSansArabic[wdth,wght].ttf` | Arabic fallback | [Pinned upstream file](https://github.com/google/fonts/blob/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/notosansarabic/NotoSansArabic%5Bwdth,wght%5D.ttf) | [notosansarabic-OFL.txt](notosansarabic-OFL.txt) | `63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e` |
| `NotoSansMath-Regular.ttf` | Mathematical alphabet fallback | [Pinned upstream file](https://github.com/google/fonts/blob/809e4d8b8d7e9364a914909bb777679606c178b8/ofl/notosansmath/NotoSansMath-Regular.ttf) | [notosansmath-OFL.txt](notosansmath-OFL.txt) | `3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d` |

The CJK files are Noto Sans CJK SC version 2.004, from upstream release tag `Sans2.004`, commit `523d033d6cb47f4a80c58a35753646f5c3608a78`. Their embedded copyright notice reads: © 2014-2021 Adobe (http://www.adobe.com/).

The supplementary fonts are Noto Sans version 2.015, Noto Sans Arabic version 2.012 and Noto Sans Math version 3.000, retrieved from Google Fonts commit `809e4d8b8d7e9364a914909bb777679606c178b8` on 2026-09-13. Their embedded copyright notices identify the Noto Project Authors (Sans / Arabic) and Google LLC (Math); the original OFL notices are preserved verbatim alongside this document.

The machine-readable provenance file is [`game/assets/fonts/font_sources.json`](../game/assets/fonts/font_sources.json), including exact original font and license hashes. The Bold CJK file is available for offline promotional subtitles; the game’s regular UI chain does not load it.
