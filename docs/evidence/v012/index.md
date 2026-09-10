# v0.1.2 源码运行时测试证据

本目录收录本轮实际完成的源码运行时检查。`headless` 没有渲染截图；`native Metal` 使用带脚本入口的 Godot 原生运行时。它们与发布 `.app` 的内置验证入口、导出构建及原生飞行证据分别记录，不能互相替代。各项的生产场景或隔离 fixture 范围、原始日志路径和摘要见 [manifest.json](manifest.json)。重复执行的检查不叠加成独立覆盖率。

| 检查 | 结果 | 运行方式 | 证据 |
| --- | --- | --- | --- |
| 经济与真实地点体验 | 40 通过 | headless | [txt](economy.txt) |
| 地图与小地图 | 22 通过 | native Metal; source runtime | [txt](navigation.txt) / [json](navigation.json) |
| 跑车/摩托/787 几何 | 33 通过 | headless | [txt](vehicle-model-headless.txt) |
| 跑车/摩托/787 原生 | 33 通过 | native Metal; source runtime | [txt](vehicle-model-native.txt) |
| 快艇/游艇 几何 | 41 通过 | headless | [txt](boat-model-headless.txt) |
| 快艇/游艇 原生 | 48 通过 | native Metal; source runtime | [txt](boat-model-native.txt) / [json](boat-model.json) |
| 无限副本与即时驾驶 | 79 通过 | headless | [txt](spawn.txt) / [json](spawn.json) |
| 系统整合 | 43 通过 | headless | [txt](integration.txt) |
| 世界破坏与修复 | 10 通过 | headless | [txt](damage.txt) |
| 悉尼机场 | 24 通过 | headless | [txt](airport.txt) |
| ICC 室内通行 | 27 通过 | headless | [txt](icc.txt) |
| 原子保存与恢复 | 8 通过 | headless | [txt](save.txt) |
| 旧载具与南坡迁移 | 21 通过 | headless | [txt](model-migration.txt) |
| 地图版本迁移 | 38 通过 | headless | [txt](map-migration.txt) / [json](map-migration.json) |
| 完整城市地图接口 | 21 通过 | headless | [txt](city-map.txt) / [json](city-map.json) |
| 八类载具物理 | 23 通过 | headless; Jolt 60Hz | [txt](physics.txt) / [json](physics.json) |
| 完整UI与控制器流程 | 60 通过 | headless | [txt](experience-flow-headless.txt) / [json](experience-flow-headless.json) |

旧 `vehicle-spawn-fixes.json` 仍包含“召唤不登车”的旧断言，因此没有复制；本目录 [spawn.json](spawn.json) 从最终79项日志的 `VEHICLE_SPAWN_REPORT` 提取。车型迁移使用最后21项结果，包含新增13项南坡检查。地图迁移38项也已在该修复后重跑。

## 镜头插值的受控验证

[调查汇总](camera-v012-investigation.json)保留了两次20Hz物理样本及一次10Hz物理样本。两次20Hz样本分别在 [1440×900窗口](camera-motion-1440x900-physics20.json)和 [960×600窗口](camera-motion-960x600-physics20.json)运行；绘制频率仍约20Hz，没有足够重复物理帧证明错频插值，因此结论为 **inconclusive**。原始 `failures` 字段如实保留，其内容是验证前提未满足，不能转述为产品插值失败。

最后 [10Hz受控结果](camera-motion-960x600-physics10.json)与[原生日志](camera-v012-compact10.txt)匹配：步行151帧、驾驶153帧；原物理位置重复76/77次，插值后重复0/0次；平均俯仰速度跳变分别为0与约0.00002464。它证明在实测约20Hz原生绘制、10Hz物理的条件下，镜头使用了连续插值后的运动位置。

三个样本的 `focused_frames` 都是0；当时macOS处于锁屏状态。小窗口实验的逻辑viewport仍为1440×900，不能据此声称GPU像素负载已经降低。这些记录不证明正常前台FPS、可见窗口呈现或操作系统真实鼠标键盘输入。早期1440报告的 `performance_note` 使用了“presented”措辞，实际可核对的是原生绘制计数，不能把它读作锁屏外用户可见的呈现证明。生产物理默认60Hz没有被改成10Hz；降频仅用于该隔离的插值验证启动参数。

## 文件处理与适用范围

原始数值、通过/失败项及fixture标识保持不变；仅本机绝对路径被替换为 `$PROJECT`、`$USER_DATA` 或 `$USER_HOME`。没有复制个人世界存档、参考照片、临时配置或截图像素。每个文件的原报告SHA-256与公开副本SHA-256保留在清单里；原报告哈希不等于最终发布二进制的来源绑定。

完整UI headless入口现为 [experience_flow_test.gd](../../../source/experience_flow_test.gd)，调用随包的 [experience_validation.gd](../../../game/scripts/experience_validation.gd)。几何图由 [vehicle_model_test.gd](../../../source/vehicle_model_test.gd)和 [boat_model_test.gd](../../../source/boat_model_test.gd)进行局部原生检查。总体交付结论及导出App证据见 [TESTING.md](../../TESTING.md)。
