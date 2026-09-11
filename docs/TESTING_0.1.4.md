# v0.1.4-preview.1 验证记录

验证环境为 Apple M4 / 16 GB、macOS 26.5、Godot 4.7.2、Metal / Forward+ 和 Jolt。玩家包是 Apple Silicon Mac 原生离线应用。历史记录独立保留：[v0.1.3](TESTING_0.1.3.md)、[v0.1.2](TESTING_0.1.2.md)。

## 最终下载包

`Harbourlife-macOS-arm64.zip` 为 32,868,830 字节，SHA-256：

```text
612f8c9c3a99ac06b8681cdfbce91d0024eec9a7fea206e3c8425c38e390bcec
```

[构建清单](evidence/v014-app/build.json)记录 **119 个游戏文件**的散列，取样于导入完成、开始导出之前，并在启动检查及 ZIP 打包后再次核对。该清单与本页所有导出 App 验证对应同一个包，没有把中途候选包的结果算作最终包实测。

[独立 ZIP 检查](evidence/v014-app/archive-validation.json)的 **13 项全部通过**：CRC、全新解压、arm64、版本 0.1.4、0755 执行权限、严格 ad-hoc 签名、PCK 及许可文件、28 个资源加载和实际存档 `VERSION = 5`。全新解压的 App 从 `/tmp` 启动，22.007 秒进入完整世界 READY，生成 15,123 个建筑节点和 21,577 个结构组件，无脚本错误。该时间仅属于此机器和该次 headless 启动，不是普遍启动时长保证。应用未公证。最终源码 ZIP 的逐文件清单与散列检查随发布资产 [release-validation.json](https://github.com/YvesZhou-hub/harbourlife/releases/download/v0.1.4-preview.1/release-validation.json) 提供。

## 最终 App 的操作与场景

五组均重新启动上述导出 App，保留新鲜输出、原始结果和引擎日志；正常退出，未记录到运行时 ERROR / WARNING。

| 验证流程 | 通过检查 | 启动与结果 |
|---|---:|---|
| 地图真实 GUI 事件分发：M / Esc、鼠标释放、点击、拖动、滚轮、名称搜索、车辆占用、Option 失焦恢复 | 35 | [启动](evidence/v014-app/navigation-input-launch.json) · [结果](evidence/v014-app/navigation-input-report.json) |
| 完整城市模块、地点目录、八条玩家路线、地图迁移净空、原生截图 | 101 | [启动](evidence/v014-app/precinct-launch.json) · [结果](evidence/v014-app/precinct-report.json) |
| 滑翔机与滑翔伞创建、初始下沉、15 秒无动力飞行、重新入座及空中保存加载 | 20 | [启动](evidence/v014-app/air-vehicle-launch.json) · [结果](evidence/v014-app/air-vehicle-report.json) |
| 九类载具免费新增并立即入座、原副本保留、导航、22 项体验目录、消费与存档 | 70 | [启动](evidence/v014-app/experience-launch.json) · [结果](evidence/v014-app/experience-report.json) |
| 基础世界、九类载具实际移动、破坏及持久化 | 32 | [启动](evidence/v014-app/qa-launch.json) · [结果](evidence/v014-app/qa-report.json) |

合计 **258 项检查**，包含重复覆盖和 26 项截图保存检查，不代表 258 个独立功能。完整场景检查必须确认两厅座席、全部模块和八条路线实际存在，不能只因进程退出成功就判断通过。发布检查器同时检查报告、控制台和本次引擎日志；缺日志或编译错误会判失败。

八条路线包括票务大厅楼梯、音乐厅南入口、音乐厅北侧门厅、Joan Sutherland 厅内及北侧门厅、Tumbalong 喷泉公共边缘、Darling Quarter 西侧入口及宽滑梯台阶和坡面。每条只在起点设置测试人物，后续使用生产玩家控制器和前进输入连续行走，所有路段到达且无位置跳变。这不是覆盖所有门、座位和私有通道的通行证明。

鼠标测试向真实 Viewport 分发输入事件，覆盖游戏和 GUI 路径；窗口失焦由引擎通知注入。它不同于操作系统硬件鼠标人工试玩。本轮较早尝试桌面控制时 Mac 锁屏；窗口后来有过获焦采样，未修改锁屏或安全设置。这些自动验证仍不是 OS 层人工走查。此前候选包的 [系统输入尝试](evidence/v014-app/candidate-os-input-attempt.json)确认 M 可打开地图，但桌面工具点击时报 `noWindowsAvailable`，因此没有取得完整 OS 层鼠标通过记录，也没有计入最终包的 258 项。

## 原生场景画面

最终 App 直接生成歌剧院外部 4 张、内部 8 张、Darling 区 14 张，以及地图操作 3 张。公开图和来源见 [截图索引](evidence/v014-app/screenshots.json)；没有修饰或合成画面。逐张实际观察独立于截图保存检查：[外壳](evidence/v014-app/opera-exterior-visual-review.json)、[内部](evidence/v014-app/opera-interiors-visual-review.json)、[Darling 区](evidence/v014-app/darling-visual-review.json)、[地图](evidence/v014-app/map-visual-review.json)。

两座主厅的舞台、座席、木饰曲顶、管风琴、反射板和公众楼梯已在最终 App 中显示。外壳的间壳铜色区域、基座、玻璃分格与周边地形仍有明显简化；部分室内台阶可见细亮缝，东南岸边仍有分离的浅色铺装条带待校准。早期候选图暴露了树冠遮挡，以及穿过喷泉区的旧机场临时路和巨大开发说明牌。该几何遗留问题随后修正；最终场景验证重新运行，并调整文档机位保留全部树木来检查设施。旧候选图未作为最终画面发布。

README 中 `v014` 图片属于本轮；保留的 `v013` 机场、大桥、ICC、W 等图片属于历史版本，不能当作本次全部重拍。更早的机场往返航线记录继续归属 v0.1.3，本轮没有重新执行完整往返试飞。

## 组件与存档

[组件证据索引](evidence/v014/index.md)明确区分局部夹具和最终 App。当前组件记录包括地图 29 项、存档 20 项、地图迁移 52 项、损伤记录 5 项、Darling 局部 101 项、歌剧院外壳 23 项、完整外壳加内厅局部 42 项，机场连接路 26 项、原机场 24 项，以及打包检查器的 4 个模拟工具链场景。

歌剧院局部夹具用实际玩家走完五条路线并返回，同时对真实外壳、玻璃和百叶三角形执行 2,960,318 个占用体采样，两座观众厅没有检出外壳侵入。该数字是两个厅共用的总采样数；不是测绘精度，也不代表后台已建好。最终装饰肋条的楼梯洞裁切只改变非碰撞视觉，完整城市路线在最终 App 另行通过。

存档格式继续为 5、地图修订为 4。回归使用实际 v0.1.2 reader，确认旧版拒绝格式 5，读取不会覆盖原文件；新版保留原副本、占用关系和历史损伤 ID。QA 使用独立标识的测试世界，不读取、覆盖或删除玩家已有世界；测试保存及备份保留。

## 镜头运动复测

相同 119 个游戏文件另由官方 Godot 运行 [独立镜头夹具](../source/camera_motion_test.gd)，完整城市内在机场地面测试步行和跑车。物理刻意降至 20 Hz，原生绘制上限 120 Hz，每种采样 8 秒（前 1.5 秒预热）。[结果](evidence/v014-app/camera-motion.json)分别捕获 232 / 243 帧，原始物理位置重复 102 / 112 帧，插值位置重复均为 0；镜头俯仰连续性检查通过。[测试范围](evidence/v014-app/camera-motion-scope.json)

此前一次未隔离硬件输入的尝试在获焦后被鼠标改变了视角，步行俯仰断言失败；已保留本地失败日志并排除。修正的是测试夹具的输入隔离，生产游戏源码未变。复测既有获焦帧也有未获焦帧，不能作为正常前台稳定帧率保证，也不证明全部街区、所有硬件都没有卡顿。

## 验证边界

没有多小时稳定性或跨硬件矩阵测试。固定步长的场景/航空检查及锁屏时原生绘制不代表正常前台 FPS；静态截图也不能证明所有移动情形都无抖动。

项目是有公开地图、平面和照片依据的原创重建，尚未完成全悉尼一比一复刻。[机场连接路修正](AIRPORT_CONNECTOR_REFERENCE.md)只在导入地图边缘接出游戏路线，不是现实机场驾车路线。普通楼宇、地形、高架和地下网络仍简化；歌剧院没有全部后台，商户目录不等于每家外观和内部都已还原。细化范围以 [歌剧院外部](OPERA_REFERENCE.md)、[内部](OPERA_INTERIOR_REFERENCE.md)和 [Darling 区](DARLING_PUBLIC_FACILITIES_REFERENCE.md) 为准。

## 复现

从仓库根目录运行，官方 Godot 和匹配导出模板安装方式见 README：

```sh
./tools/runtime/godot --headless --path game --script ../tools/test_save.gd
./tools/runtime/godot --headless --path game --script ../source/map_migration_test.gd
./tools/runtime/godot --headless --path game --script ../source/structure_state_test.gd
./tools/runtime/godot --headless --path game --script ../source/darling_public_facilities_test.gd
./tools/runtime/godot --headless --path game --script ../source/opera_landmark_test.gd
./tools/runtime/godot --headless --path game --script ../source/opera_interior_test.gd
HARBOURLIFE_REPORT_DIR="$PWD/reports/release-v014-native" ./tools/build.sh
python3 tools/verify_native.py navigation-input
python3 tools/verify_native.py precinct
python3 tools/verify_native.py air-vehicle
python3 tools/verify_native.py experience
python3 tools/verify_native.py qa
python3 tools/verify_archive.py --manifest reports/release-v014-native/build.json
python3 tools/package_source.py
```

原生图形验证顺序运行，不并发争用 GPU。构建默认报告位置可由 `HARBOURLIFE_REPORT_DIR` 指定；核查时必须传入本次真实构建清单。公开源码包按明确文件名单打包，不包含引擎、模板、玩家存档、私人文件或外部参考照片。
