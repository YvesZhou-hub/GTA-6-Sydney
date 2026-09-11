# v0.1.5-preview.1 验证记录

本轮针对歌剧院大台阶被撞毁后产生长槽的问题。环境为 Apple M4 / 16 GB、macOS 26.5、Godot 4.7.2、Metal / Forward+、Jolt。此前版本的完整记录保留在 [v0.1.4](TESTING_0.1.4.md)，没有将旧包的 258 项验证算成本次结果。

## 最终下载包

`Harbourlife-macOS-arm64.zip`：32,880,630 字节，SHA-256：

```text
5837b657e7a7775f62f3f944f9fe0bd7092046343e9e789a021212832a1b9fc7
```

[构建清单](evidence/v015-app/build.json)核对 121 个游戏文件，在导出前、启动和打包后检查源码一致。玩家包为 Apple Silicon Mac 原生离线应用，ad-hoc 签名，未公证。最终独立 ZIP 与源码审计见发布资产 [release-validation.json](https://github.com/YvesZhou-hub/harbourlife/releases/download/v0.1.5-preview.1/release-validation.json)，包括全新解压启动、版本、权限、签名、PCK 资源与源码逐文件一致性。

## 导出 App 实测

| 流程 | 通过检查 | 证据 |
|---|---:|---|
| 楼梯完整状态、旧损坏状态重载、局部撞击，人物与平衡车跨接口、原生截图 | 29 | [启动](evidence/v015-app/opera-access-launch.json) · [结果](evidence/v015-app/opera-access-report.json) |
| 完整城市地标模块、八条公共路线、导航目的地和原生场景截图 | 101 | [启动](evidence/v015-app/precinct-launch.json) · [结果](evidence/v015-app/precinct-report.json) |

合计 130 项自动检查，包含截图保存与重复覆盖。两次均直接启动最终 App，报告和日志为本次新生成，正常退出、无 ERROR / WARNING。这不是 OS 硬件鼠标人工走查，也不是所有载具或长途航线重测。

楼梯专项每种状态检查 672 个位置，三种状态共 2,016 个采样；射线核对台阶或主平台的结构归属和预期坡面高度，不能用上层餐厅地板掩盖缺阶。人物与平衡车使用实际生产控制器连续移动，只在每条路线起点设置位置。局部 450 kJ 撞击实际移除了中央两块饰面，承重基座保持，人物和平衡车都从受损位置双向通过，没有跌破支撑面；平衡车健康保持 100。不同高度、任意速度和持续极端破坏不属于本次保证。

## 问题复现与旧存档

[旧版基线](evidence/v015-app/stair-baseline.json)使用隔离场景复现：移除 `opera/steps/7` 后，局部 x=0、z=67.5 的支撑从世界高度约 15.14 米降到 4.5 米。新版采用实体基座与独立饰面，旧八个损坏 ID 保留历史，但不会删除新基座。

[地图迁移夹具](evidence/v015-app/map-migration-source.json)共 83 项通过，使用实际保存/加载代码与真实楼梯网格验证旧 revision 4 的被困人物和悬浮车迁出，安全副本及状态保留。地图修订升级到 5，存档格式仍为 5；测试使用独立 QA 世界，不覆盖或删除玩家存档。[外壳组件](evidence/v015-app/opera-exterior-source.json)23 项通过，原有室内入口与开口继续保留。这两组属于源码夹具，未计入上面的导出 App 检查。

## 画面与范围

[三张最终包截图](evidence/v015-app/screenshots.json)分别对应完整楼梯、加载旧损坏记录、再次撞击后的同一位置。它们是原生画面，没有修图。README 中 `v014` 与 `v013` 图片是历史版本，本次只新增 `v015` 楼梯图片。歌剧院屋壳和室内布局不属于这次重新建模的范围。

复现：运行 `python3 tools/verify_native.py opera-access --app <Harbourlife.app路径>` 或将 mode 改为 `precinct`。源码迁移夹具运行 `tools/runtime/godot --headless --path game --script ../source/map_migration_test.gd`。完整验证范围和本地路径处理见 [证据来源](evidence/v015-app/provenance.md)。
