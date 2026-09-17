# 第三方美术素材

这些模型不是本项目原创，全部采用 **CC0 1.0（公共领域）**：可自由用于个人和商业项目，不要求署名。这里仍然记录来源，方便核对和更新。本仓库其余美术仍按根目录 LICENSE 的说明保留权利。

Everything in this folder is third-party art released under **CC0 1.0 Universal (Public Domain Dedication)**: free for personal and commercial use, no attribution required. Sources are recorded anyway.

| 目录 | 内容 | 作者 | 许可 | 来源 |
| --- | --- | --- | --- | --- |
| `characters/` | 10 个城市人物，每个带 24 个动作（站立、走、跑、挥手、受击、倒地等） | Quaternius | CC0 1.0 | [Ultimate Modular Men Pack](https://poly.pizza/bundle/Ultimate-Modular-Men-Pack-ZiH8muWqwQ) · [Ultimate Modular Women Pack](https://poly.pizza/bundle/Ultimate-Modular-Women-Pack-aCBDXDdTNN) |
| `vehicles/` | 7 辆车（轿车、出租车、跑车、SUV、警车） | Quaternius | CC0 1.0 | [Cars Bundle](https://poly.pizza/bundle/Cars-Bundle-FE5IWe6OMk) |
| `nature/` | 树、棕榈、灌木、草丛、蕨类、石块 | Quaternius | CC0 1.0 | [Stylized Nature MegaKit](https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm) · [Ultimate Stylized Nature Pack](https://poly.pizza/bundle/Ultimate-Stylized-Nature-Pack-zyIyYd9yGr) |
| `city/` | 路灯、长椅、消防栓、垃圾箱、红绿灯、箱子、石块、灌木 | Kay Lousberg (KayKit) | CC0 1.0 | [City Builder Bits](https://poly.pizza/bundle/City-Builder-Bits-1wLdnIddSx) |

许可原文：<https://creativecommons.org/publicdomain/zero/1.0/>

## 选择理由

- 人物、车辆和植被来自同一位作者，风格统一：低多边形、平滑造型、柔和配色，与城市现有的简洁几何一致。
- 人物自带完整动作集，且单个模型不到 6,000 个三角面，可以在街上同时出现很多人。
- 尺寸即真实尺寸：人物约 1.85 m，轿车约 4.2 m，树约 9 m，进游戏不需要猜比例。
- 城市小件选 KayKit，因为同类里只有它是 CC0（另一套街道道具需要署名）。

## 更新方式

模型直接从上述来源下载 `.glb` 放进对应目录，Godot 会自动导入。删除不再使用的文件时，记得同时删除旁边的 `.import` 文件。
