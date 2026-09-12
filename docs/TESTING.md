# v0.1.7-preview.1 验证记录

本轮覆盖公共建筑与通道、地图步行区域、坦克与战斗机、撞毁及射击、共享材质调参、近景立面加载，以及悉尼夏季 12 倍连续昼夜和日落。实际引擎、启动参数、源文件与 App 身份以证据清单为准。[v0.1.6 记录](TESTING_0.1.6.md)保留原版本身份。

## 最终下载包

macOS Apple Silicon 离线预览 App；签名情况见构建清单，不把 ad-hoc 签名称为公证。ZIP 共 42,470,888 字节，SHA-256：

```text
b0b6f8dc09e20f39f971ec6bdc805e5756efb7176bc1fc0f394318f0fd2f057b
```

[构建清单](evidence/v017-app/build.json)的 172 个游戏文件均与当前源码一致。七个原生启动记录的可执行文件与 PCK 哈希均匹配此 ZIP 中的实际文件。[证据索引](evidence/v017-app/evidence-index.json)记录原始报告、日志和各源码夹具依赖哈希。归档解压、版本与签名审计另由 `tools/verify_archive.py` 执行，本汇总不代替该审计。

## 最终 App 原生自动验证

| 流程 | 通过检查 | 证据 |
|---|---:|---|
| 完整城市、公共路线与建筑画面 | 295 | [报告](evidence/v017-app/precinct-report.json) · [启动](evidence/v017-app/precinct-launch.json) |
| 歌剧院台阶与人物/平衡车通行 | 32 | [报告](evidence/v017-app/opera-access-report.json) · [启动](evidence/v017-app/opera-access-launch.json) |
| 新增载具与城市体验 | 82 | [报告](evidence/v017-app/experience-report.json) · [启动](evidence/v017-app/experience-launch.json) |
| 地图输入与返回游戏 | 35 | [报告](evidence/v017-app/navigation-input-report.json) · [启动](evidence/v017-app/navigation-input-launch.json) |
| 坦克、战斗机、瞄准开火与撞毁 | 42 | [报告](evidence/v017-app/combat-report.json) · [启动](evidence/v017-app/combat-launch.json) |
| F3 诊断、材质调参与 T 时间控制 | 43 | [报告](evidence/v017-app/diagnostics-report.json) · [启动](evidence/v017-app/diagnostics-launch.json) |
| 最终 App 昼夜、日落与夜窗画面 | 51 | [报告](evidence/v017-app/daylight-report.json) · [启动](evidence/v017-app/daylight-launch.json) |

合计 **580 项**原生检查；各流程正常退出，报告和日志新鲜且无 ERROR/WARNING。街区流程记录 28 条连续路线及 75 张截图。检查可能重复覆盖同一行为，数量不表示独立功能数或全区覆盖率。自动输入也不等同于人工硬件输入测试。

## 源码夹具与数据检查

以下数量来自各自实际报告/完成日志，按夹具声明及直接 load/preload/extends 引用的依赖哈希与最终源码核对；不宣称完整追踪所有传递依赖。来源可为局部场景或 headless 源码世界；它们不计入上面的最终 App 原生总数，彼此覆盖可能重叠，因此不另求和。

| 范围 | 通过检查 | 证据 |
|---|---:|---|
| QVB 公共首层、屋顶与旧存档 | 63 | [报告](evidence/v017-app/qvb-source.json) · [日志](evidence/v017-app/qvb-source.log.txt) |
| Manly 公共大厅、通道与地面恢复 | 109 | [报告](evidence/v017-app/manly-source.json) · [日志](evidence/v017-app/manly-source.log.txt) |
| 索引与手工三角网格合并 | 9 | [报告](evidence/v017-app/mesh-composition-source.json) · [日志](evidence/v017-app/mesh-composition-source.log.txt) |
| 步行区域与道路真实裁切 | 24 | [报告](evidence/v017-app/roads-source.json) · [日志](evidence/v017-app/roads-source.log.txt) |
| 大小地图共享填面与导航 | 30 | [报告](evidence/v017-app/navigation-map-source.json) · [日志](evidence/v017-app/navigation-map-source.log.txt) |
| 生活玩法与公共到达点 | 40 | [日志](evidence/v017-app/life-experience-source.log.txt) |
| 步行面积源数据编译器 | 24 | [报告](evidence/v017-app/city-fidelity-source.json) · [日志](evidence/v017-app/city-fidelity-source.log.txt) |
| 旧存档地面恢复与姿态保护 | 91 | [报告](evidence/v017-app/map-migration-source.json) · [日志](evidence/v017-app/map-migration-source.log.txt) |
| 达令公共设施网格与损坏回归 | 148 | [报告](evidence/v017-app/darling-source.json) · [日志](evidence/v017-app/darling-source.log.txt) |
| 坦克地面驾驶、坡道与制动 | 19 | [报告](evidence/v017-app/tank-motion-source.json) · [日志](evidence/v017-app/tank-motion-source.log.txt) |
| 战斗载具存档与姿态恢复 | 18 | [报告](evidence/v017-app/vehicle-state-source.json) · [日志](evidence/v017-app/vehicle-state-source.log.txt) |
| 履带支撑与撞毁负例 | 6 | [报告](evidence/v017-app/crush-envelope-source.json) · [日志](evidence/v017-app/crush-envelope-source.log.txt) |
| 战斗机生产飞行与高速恢复 | 21 | [报告](evidence/v017-app/fighter-flight-source.json) · [日志](evidence/v017-app/fighter-flight-source.log.txt) |
| 武器弹道、损坏与瞄准存档 | 49 | [报告](evidence/v017-app/combat-weapons-source.json) · [日志](evidence/v017-app/combat-weapons-source.log.txt) |
| 完整源码世界中的载具复制与起飞 | 74 | [报告](evidence/v017-app/combat-spawn-source.json) · [日志](evidence/v017-app/combat-spawn-source.log.txt) |
| 生产碰撞扫掠与撞毁回调 | 10 | [报告](evidence/v017-app/combat-crush-source.json) · [日志](evidence/v017-app/combat-crush-source.log.txt) |
| 载具模型缓存、独立状态与碰撞一致性 | 131 | [报告](evidence/v017-app/vehicle-factory-cache-source.json) · [日志](evidence/v017-app/vehicle-factory-cache-source.log.txt) |
| 生产存档读写、旧版本兼容与时钟保存 | 31 | [报告](evidence/v017-app/save-source.json) · [日志](evidence/v017-app/save-source.log.txt) |
| 共享材质角色与精确恢复 | 41 | [报告](evidence/v017-app/material-roles-source.json) · [日志](evidence/v017-app/material-roles-source.log.txt) |
| 稳定夜窗与数值曝光 | 29 | [报告](evidence/v017-app/facade-night-source.json) · [日志](evidence/v017-app/facade-night-source.log.txt) |
| 近景立面加载、损坏持久性与容量 | 27 | [报告](evidence/v017-app/facade-stream-source.json) · [日志](evidence/v017-app/facade-stream-source.log.txt) |
| 运行时诊断与昼夜调参恢复 | 84 | [报告](evidence/v017-app/runtime-diagnostics-source.json) · [日志](evidence/v017-app/runtime-diagnostics-source.log.txt) |
| 悉尼夏季时钟、暂停与存档 | 29 | [报告](evidence/v017-app/city-clock-source.json) · [日志](evidence/v017-app/city-clock-source.log.txt) |
| 光照周期资源接口与参数 | 22 | [报告](evidence/v017-app/daylight-cycle-source.json) · [日志](evidence/v017-app/daylight-cycle-source.log.txt) |
| 公共前厅与入口的夜间照明 | 31 | [报告](evidence/v017-app/public-lighting-source.json) · [日志](evidence/v017-app/public-lighting-source.log.txt) |
| 环境与水面数值参数 | 31 | [报告](evidence/v017-app/render-environment-source.json) · [日志](evidence/v017-app/render-environment-source.log.txt) |

夜窗数值夹具使用 CPU 编译的实际纯着色器函数，不能证明 GPU 画面。近景加载只覆盖 160 m 格子的立面细节，最多驻留 64 格；基础外壳和碰撞仍常驻。检查通过不证明 FPS、内存节省或完整飞行路线没有卡顿。[加载范围](CITY_STREAMING.md) · [材质与夜窗范围](MATERIAL_ROLES.md)。

[最终 App 原图与逐图说明](evidence/v017-app/screenshots.json)保留未经编辑的截图。普通距离裁剪与近景加载照常生效。当前普通楼宇、高程、地下网络及大量公开室内仍有简化；本记录不宣称全区 1:1、真实照片完整复刻或每条道路均已人工验收。[本版范围](FIXES_0.1.7.md)

复现：`python3 tools/verify_native.py <mode> --app <Harbourlife.app路径>`，mode 为 precinct, opera-access, experience, navigation-input, combat, diagnostics, daylight。各源测试入口及依赖列在证据索引中。源图、私有设置和玩家存档不应加入发布证据。
