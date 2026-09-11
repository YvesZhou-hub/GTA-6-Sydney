# 0.1.4 组件验证

这些记录区分小型夹具、实际完整城市和导出应用。组件通过不替代最终下载包验收，重复检查也不代表独立功能数。

| 范围 | 结果 | 证据 |
|---|---:|---|
| 小型原生地图夹具：搜索、坐标、底图缓存、旋转、缩放 | 29 项通过 | [JSON](navigation-map.json) · [日志](navigation-map.log.txt) |
| 新旧存档格式、真实 v0.1.2 reader 拒绝格式 5、不重写原文件 | 20 项通过 | [JSON](save-format5.json) · [日志](save.log.txt) |
| 地图修订迁移、入口净空、副本 ID 与占用保留 | 52 项通过 | [JSON](map-migration.json) · [日志](map-migration.log.txt) |
| 现有与已退役组件损伤记录保留、显式修复 | 5 项通过 | [JSON](structure-state.json) · [日志](structure-state.log.txt) |
| Darling 局部地图/物理夹具：目录、到达点、设施碰撞及滑梯上下 | 101 项通过 | [JSON](darling-public-facilities.json) · [日志](darling-public-facilities.log.txt) |
| 歌剧院外壳：球面、裁切、碰撞、入口、楼板洞及包络 | 23 项通过 | [JSON](opera-exterior.json) |
| 歌剧院完整外壳与内厅局部夹具：五条实际往返路线、舞台视线、屋壳侵入扫描 | 42 项通过 | [JSON](opera-interiors.json) |
| 机场临时路退出真实城区、喷泉/建筑净空、2,499 条碰撞射线、跑车双向和弯道、步行接头 | 26 项通过 | [JSON](airport-connector.json) · [日志](airport-connector.log.txt) |
| 原有机场跑道、机位和几何回归 | 24 项通过 | [日志](airport-baseline.log.txt) |
| 打包防误报：缺日志/编译错误及导出中源码改变；含两个干净对照 | 4 个隔离场景通过 | [模拟工具链结果](packaging-guards.json) |

打包防误报使用临时假工具链，验证检查器会拒绝错误情况，不是实际 App 构建证据。Darling 记录是 headless 局部夹具；完整城市场景与原生画面由导出 App 验证。

最终 App 构建、鼠标输入、城市通行和截图记录见 [本轮验收](../../TESTING.md)。
