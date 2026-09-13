# v0.1.9 验证记录

本轮验证漂移、急刹、三倍加速和载具耐久。最终导出的 Apple Silicon macOS App 完成 **156/156 项原生检查，产出 13 张截图**；局部源码夹具另有 **233/233 项检查**，两类结果分别计数，不累计旧版本结果。文件身份、逐项计数与截图哈希见 [证据索引](evidence/v019-app/evidence-index.json)。

| 最终 Mac 产物 | SHA-256 |
| --- | --- |
| App 可执行文件 | `3d05c1b919acd41b8a937dd2b7395838be6b9c0762d8af7a997e426b59ae9086` |
| PCK | `53844990698de431b561b098b6c0c68e2316c4b5160e3225f63564553a74e3b7` |
| App ZIP | `5256d85d716f22fa8812d0c66ac1e342255e7097e305052677ea46f67feae638` |

## 最终 App 原生检查

| 模式 | 通过数 | 截图 | 实际范围 |
| --- | ---: | ---: | --- |
| [driving](evidence/v019-app/driving-report.json) | 39/39 | 6 | 生产跑车和摩托车在隔离平直路面上的真实刚体、输入、急刹、漂移、恢复抓地、稳定转向和三倍加速 |
| [experience](evidence/v019-app/experience-report.json) | 82/82 | 4 | 免费生成并入座、原载具保留、导航和占用状态保存恢复、城市服务与抵达判断 |
| [navigation-input](evidence/v019-app/navigation-input-report.json) | 35/35 | 3 | 地图选点、拖动、缩放、搜索、暂停、鼠标释放与重新捕获、相机事件路由 |

三组 [driving 启动](evidence/v019-app/driving-launch.json)、[experience 启动](evidence/v019-app/experience-launch.json)、[navigation-input 启动](evidence/v019-app/navigation-input-launch.json)记录同一组可执行文件和 PCK 哈希，均正常退出、报告新鲜且无运行错误。导出前的 205 个游戏文件及哈希见 [构建报告](evidence/v019-app/build.json)。导出版本的 `driving-report.json` 中逐脚本哈希为空，不能作为源码身份依据；本页使用外部启动记录的产物哈希与构建清单关联身份。

驾驶截图记录的实际速度约为跑车 **1259.995 km/h**、摩托车 **959.995 km/h**；漂移截图的侧滑角约为 **27.8° / 19.9°**。车辆运动由力和输入产生，测试开始摆放后没有通过写位置或速度完成动作。固定 60 Hz 步长用于重复验证控制，不代表城市游玩帧率或现实车辆性能。截图的存在也不等于逐帧画面或声音已经人工检查。

地图测试通过 `Viewport.push_input` 进入实际 GUI 和未处理输入路由，焦点通知的专项检查通过 `Object.notification` 注入。它属于引擎事件自动化，不是实体鼠标键盘操作证明。测试使用专用 QA 世界及存档夹具，报告声明未触碰玩家存档。

## 保留的首次导航失败

首次导航运行只有 **33/35 通过**：“新世界捕获鼠标”和“普通游戏鼠标转动相机”两项启动检查失败，其余地图交互正常，运行日志未报告错误。[首次报告](evidence/v019-app/navigation-initial-report.json)和 [首次启动记录](evidence/v019-app/navigation-initial-launch.json)完整保留，不计入最终通过数。

随后使用**同一可执行文件和同一 PCK**重跑得到 35/35。该现象可能与启动时窗口焦点有关；两次报告没有记录检查当时的真实窗口焦点，因此原因仍是推断，不能写成已定位或已修复的相机缺陷。成功重跑不覆盖或删除首次失败证据。

## 局部源码夹具

以下六份报告的断言列表独立合计 **233/233**，不属于上面的 156 项原生 App 检查。

| 夹具及报告 | 通过数 | 范围 |
| --- | ---: | --- |
| [`vehicle_durability_test.gd`](../source/vehicle_durability_test.gd) · [报告](evidence/v019-app/vehicle-durability.json) | 83/83 | 撞击阈值、每次伤害上限、同一接触去重与离开后重新计数 |
| [`hoverboard_immunity_test.gd`](../source/hoverboard_immunity_test.gd) · [报告](evidence/v019-app/hoverboard-immunity.json) | 9/9 | 平衡车无损、旧受损状态恢复，以及普通载具状态保留 |
| [`vehicle_contact_test.gd`](../source/vehicle_contact_test.gd) · [报告](evidence/v019-app/vehicle-contact.json) | 5/5 | 生产车辆与受控实体表面的实际物理接触 |
| [`test_vehicles.gd`](../tools/test_vehicles.gd) · [报告](evidence/v019-app/vehicle-physics.json) | 23/23 | 生产载具在确定性测试表面上的基础运动回归 |
| [`vehicle_boost_test.gd`](../source/vehicle_boost_test.gd) · [报告](evidence/v019-app/vehicle-boost.json) | 100/100 | 11 类载具的加速目标、力学运动、松键回落、制动覆盖和无人驾驶状态 |
| [`specialty_boost_test.gd`](../source/specialty_boost_test.gd) · [报告](evidence/v019-app/specialty-boost.json) | 13/13 | 坦克、战斗机和平衡车高速转向、平顺减速，以及 600 km/h 平衡车避墙 |

特殊载具夹具实测约为坦克 **321.73 km/h**、平衡车 **600.00 km/h**、战斗机 **5999.99 km/h**。坦克的 330 km/h 是控制目标，实际速度仍受阻力影响。平衡车以约 600 km/h 接近测试墙，最终与厚 2 m 墙体中心保持至少 4.67 m 的距离。这些是受控场景结果，不能推断全城所有路口、台阶与碰撞组合都已验证。

部分源码报告没有完整依赖哈希，不能单独用来证明最终 App 的全部代码身份。特殊载具报告包含自身及声明依赖的 SHA-256；源码快照、导出清单和原生运行证据的范围仍需分别理解。

复现示例，在仓库根目录运行：

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/specialty_boost_test.gd
python3 tools/verify_native.py driving --app /path/to/Harbourlife.app
```

## 平台与内容边界

**v0.1.9 Windows** 另经 [云端运行 34734507798](https://github.com/YvesZhou-hub/harbourlife/actions/runs/34734507798)验收：最终 ZIP 的 23 项包检查、16 项运行门禁，以及门禁内核验的 32 项驾驶物理断言全部通过。205 个游戏源文件与 Mac 构建逐项一致；实际从 ZIP 解压的 EXE 完成生产世界初始化与驾驶测试，日志没有错误或警告。[Windows 报告](evidence/v019-windows/windows-validation.json)与 [SHA-256](evidence/v019-windows/Windows-SHA256SUMS.txt)来自发布资产，保留原始字节。Windows 使用 headless Jolt 60 Hz，未实测 GPU 画面、实体鼠标键盘或音效，不把 Mac 的截图或检查数计入 Windows。

历史 [v0.1.8 验证](TESTING_0.1.8.md)及宣传片保留各自版本身份。

本轮未新增城市建筑或一比一还原证明，也不是驾考模拟认证。改动与玩家操作见 [FIXES_0.1.9](FIXES_0.1.9.md)和 [DRIVING](DRIVING.md)。
