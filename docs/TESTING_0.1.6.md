# v0.1.6-preview.1 验证记录

这轮覆盖歌剧院、悉尼塔、码头与连接桥、W Sydney、ICC 场馆、银行与写字楼、部分达令广场店面。环境：Apple M4 / 16 GB、macOS 26.5、Godot 4.7.2、Metal / Forward+、Jolt。旧版记录保留在 [v0.1.5](TESTING_0.1.5.md)，未混入本次计数。

## 最终下载包

Apple Silicon 原生离线应用，ad-hoc 签名，未公证。ZIP 大小 32,940,060 字节，SHA-256：

```text
9269a3f9a39c79b23ef1a2ac349cad535a4d275d37866f3a5c10d236948b33e8
```

[构建清单](evidence/v016-app/build.json)核对 124 个游戏文件，导出前冻结，启动与打包后再次比对。最终全新解压、签名、版本、PCK 资源和源码 ZIP 对应检查在发布资产 [release-validation.json](https://github.com/YvesZhou-hub/harbourlife/releases/download/v0.1.6-preview.1/release-validation.json)。

## 最终 App 实测

| 流程 | 通过检查 | 证据 |
|---|---:|---|
| 完整城市、公共路线、地图目的地与新增模型原生画面 | 188 | [启动](evidence/v016-app/precinct-launch.json) · [结果](evidence/v016-app/precinct-report.json) |
| 歌剧院大台阶完整、旧损坏重载与撞击后人物/平衡车通行 | 29 | [启动](evidence/v016-app/opera-access-launch.json) · [结果](evidence/v016-app/opera-access-report.json) |
| 免费新增载具、即时乘坐、地图/体验与存档回归 | 70 | [启动](evidence/v016-app/experience-launch.json) · [结果](evidence/v016-app/experience-report.json) |

合计 287 项自动检查，均正常退出，无运行时 ERROR / WARNING；计数包括截图保存和重复覆盖。街区专项包含 22 条实际控制器连续行走路线、63 张原生截图。只在路线起点设置人物位置，随后使用生产输入与物理移动。这不是 OS 硬件输入人工验收，也不代表所有载具的每条长途航线均重测。

## 源码夹具与视觉核对

- 地图修订 6：87 项通过，包含上一版 revision 5 的实际加载、固体占用恢复、正常位置与源存档字节保留。[结果](evidence/v016-app/map-migration-source.json)
- 码头及沿街局部场景：83 项通过，含五个入口多偏移胶囊通行、每个码头 41 点连续支撑、14 个原地图雨棚与网格朝向。[结果](evidence/v016-app/quay-source.json)
- 歌剧院局部：外部 24 项、内部完整往返路线 49 项；另跑新增相机与几何 52 项、坡中迁移 22 项，修复前六个安全站位误判、修复后全部通过。这几次是不同范围的独立跑次。[全路线](evidence/v016-app/opera-interior-full-source.json) · [坡中存档](evidence/v016-app/opera-slope-source.json)
- 达令广场与公共设施局部：130 项通过，包含四家本分店照片细化、已定位入口和损坏归属。[结果](evidence/v016-app/darling-source.json)
- Man O’War 码头：30 项通过，包含两座浮码头、两条连接桥的完整往返和坡中存档正反例。[结果](evidence/v016-app/manowar-source.json)
- ICC 三馆：50 项通过，保留公共路线与结构损坏关系。[结果](evidence/v016-app/icc-source.json)
- W Sydney、HSBC Tower One、中国银行及保留的 Exchange：56 项通过，包含中国银行柱廊与 W 入口的生产控制器双向行走。[结果](evidence/v016-app/city-buildings-source.json)
- Westpac / CBA 三栋：93 项通过，三条生产角色连续公共路径、雨棚净空及损坏归属。[结果](evidence/v016-app/bank-source.json)
- Quay Quarter / Salesforce 两塔：28 项通过，149 个结构、138,552 个三角形；贴附细节随原结构损坏和修复。[结果](evidence/v016-app/quay-towers-source.json)
- 悉尼塔：30 项通过，33 个结构 ID、121,772 个三角形，检查平台几何、窗格、损坏/恢复、行人落点；另有局部原生五视图。[日志](evidence/v016-app/tower-source.log.txt)

[63 张画面的视觉核对](evidence/v016-app/visual-review.json)记录最终图片哈希与观察；其中 [19 张代表画面](evidence/v016-app/screenshots.json)原样收入公开源码。历史图片保留原版本标识。可见几何已对照真实参考照片，但没有用自动检查证明现实中的厘米级准确性；场景范围与估算尺寸见 [更新说明](FIXES_0.1.6.md)。

复现：`python3 tools/verify_native.py precinct --app <Harbourlife.app路径>`；另可选 `opera-access` 或 `experience`。证据路径处理见 [来源说明](evidence/v016-app/provenance.md)。
