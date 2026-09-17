# v0.3.0 主线、设置、画面与加载验证

## 最终 Mac App

`Harbourlife-macOS-arm64.zip` 由 `tools/build.sh` 从提交后的源码构建，249 个游戏文件的哈希与 git 跟踪文件逐一一致。[构建清单](evidence/v030-app/build.json) · [校验和](evidence/v030-app/Mac-SHA256SUMS.txt)

- **压缩包审计 13/13**：版本 0.3.0、arm64、签名校验、PCK 与全部源文件身份、从解压副本启动完整城市。第一次构建因 `Info.plist` 仍写着 0.2.2 被审计拦下，修正导出配置后重新构建。[审计报告](evidence/v030-app/archive-validation.json)
- **原生玩法与界面 295/295**，全部用打好的 App 在 Metal 窗口运行，退出码 0，日志无错误或警告，EXE/PCK 哈希前后不变：

| 专项 | 检查 | 范围 |
| --- | ---: | --- |
| [主线与成就](evidence/v030-app/campaign/report.json) | 71/71 | 8 个步骤的正确与错误条件、奖励总额与不重复发放、导航切换、成就与平台接口、改键与手柄文字、暂停菜单、存读档与旧存档 |
| [HUD 与设置](evidence/v030-app/hud/report.json) | 53/53 | 6 种分辨率步行与驾驶的重叠、越界与黑边，设置清洗、FSR、视野、改键及提示同步、手柄 Start/B 与右摇杆 |
| [连续遭遇](evidence/v030-app/encounter/report.json) | 96/96 | 家门口、歌剧院、机场和 CBD 的刷新与追击，V/B/H |
| [原有生存](evidence/v030-app/survival/report.json) | 40/40 | 五类敌人、H 治疗、坦克击杀奖励、B 补给与维修 |
| [武器与空袭](evidence/v030-app/arsenal/report.json) | 35/35 | 选装购买与三槽、主炮中心/边缘伤害、两类空中敌人、激光与闪电 |

[汇总与哈希](evidence/v030-app/native-index.json)。QA 进程与上一版一样使用 Dummy 音频驱动，**不验证实际扬声器声音**；也不代表长期帧率或所有硬件。打包后的 App 完整城市启动约 11–12 秒。

遭遇与歌剧院专项会故意清空键盘绑定，防止真实键盘干扰测试，所以这些截图底部提示显示“未绑定”；正式游戏不会这样修改按键。

## 源码检查

- Windows 发布门禁要求的 5 个无界面专项在源码上全部通过，日志零错误或警告：交互启动、驾驶 32、生存 30、自然遭遇 82、武器 25。修复前，按键提示在无界面模式下查询键盘布局，每次都记一条错误（交互启动 94 条），会让 Windows 门禁失败。
- `tools/test_save.gd` 42/42（存档格式 7）；`source/cell_batch_equivalence_test.gd` 8/8；`source/key_hint_test.gd` 9/9。
- 36 个城市、地标与世界测试中 34 个通过；`world_road_probe` 与无界面 `bridge_drive_test` 在未改动的代码上结果相同。
- `--visual-qa` 前后 14 个机位逐像素比较，差异只在随时间变化的水面上。详见 [运行性能](PERFORMANCE.md)。

Windows 包的实际构建与运行结果见 [Windows 验证记录](WINDOWS.md#windows-验证记录)。下方 v0.2.2 及更早的结果是历史数据，不计入 v0.3.0。

---

# v0.2.2 武器选装与空中战斗验证

本轮新增伤害浮字、两类飞行敌人、四类付费武器与最高 Lv.30 的渐进增援。冻结源码的16个玩法 / 存档专项 **817/817 通过**，全部进程正常退出、日志无错误或警告，235个游戏输入文件在验证前后保持一致。[各专项结果、源码哈希和原始证据](evidence/v022-app/source-checks/index.json)

完整城市的源码版 Arsenal 检查 **25/25 通过**，与817项定向夹具分开记录。[完整城市原始报告](evidence/v022-app/source-checks/full-city/arsenal.json)

另外，Arsenal报告负向门禁17/17、Windows流程门禁模拟62/62、ZIP审计工具负例37/37通过；这些检查验证工具如何拒绝错误证据，不作为游戏玩法断言或平台实测。[Windows门禁](evidence/v022-app/windows-ci-gates.json) · [ZIP门禁](evidence/v022-app/archive-gates.json)

Mac最终包已通过13项独立ZIP审计，包括235个源文件身份、真实包内EXE/PCK哈希、版本0.2.2、存档格式7、80资源加载与完整城市启动。[真实包审计](evidence/v022-app/archive-validation.json)

第一次默认CoreAudio的最终App运行：新玩法35/35通过并生成5张实机图，但退出时15个播放对象未释放、56个ObjectDB对象泄漏，因此外部原生门禁判为失败。[原始失败门禁](evidence/v022-app/initial-default-audio/arsenal-launch.json)

独立单播放器在不加载任何游戏代码时，也出现默认CoreAudio真实4秒内零混音与2个对象泄漏；同一脚本用进程内Dummy时正常混音，约49ms释放，零警告。[最小脚本](evidence/v022-app/audio-diagnostic/minimal-player.gd) · [CoreAudio日志](evidence/v022-app/audio-diagnostic/coreaudio.txt) · [Dummy对照](evidence/v022-app/audio-diagnostic/dummy.txt)。这支持宿主音频回调停滞的判断，但不能将完整App的56个对象全部归类为同一类型；系统根因未确认。未改系统或游戏音频设置，失败报告保留。后续原生画面/玩法采用进程内Dummy单列，不能据此声称真实扬声器声音已测试。

同一个最终Mac App的三个原生专项共 **171/171 通过、16张实际Metal截图**，全部退出0、外部门禁无错误或警告、EXE/PCK前后哈希不变：

| 专项 | 检查 | 截图 | 实际范围 |
| --- | ---: | ---: | --- |
| [武器与空袭](evidence/v022-app/arsenal/report.json) | 35/35 | 5 | B与真实按钮回调购买、三槽更换、主炮中心/边缘真实扣血、两类空袭、方向输入躲避与实体墙遮挡、激光/闪电攻击飞行敌人、Lv.6增援 |
| [连续遭遇](evidence/v022-app/encounter/report.json) | 96/96 | 7 | 家门口、歌剧院台阶、机场和CBD的自然刷新/追击，旧怪未清时换区增援，V/B/H、付费火控与快修 |
| [原有生存](evidence/v022-app/survival/report.json) | 40/40 | 4 | 原五类敌人、人物伤害和H治疗、坦克真实击杀奖励、B补给和完整维修 |

[实际App、各报告与截图的哈希绑定](evidence/v022-app/native-index.json)。三次成功验收均仅在QA进程指定Dummy，仍使用原生Metal画面与Jolt；不修改正式包的默认音频设置。**这些结果不验证实际扬声器音效或CoreAudio硬件路径**，也不证明长期FPS和全地图无缺陷。

Windows同一候选提交实际构建与解压执行后，48项门禁、169项玩法断言、42项独立身份核验全部通过：驾驶32、生存30、连续遭遇82、Arsenal25。使用headless Jolt 60Hz，无Windows原生画面或音频实听结论，不能把Mac截图计为Windows证明。[原始Windows报告](evidence/v022-windows/windows-validation.json) · [范围和校验和](WINDOWS.md#v022-最终包证据)。下方 v0.2.1 和更早的结果是历史数据，不计入 v0.2.2 通过数。

复现新版本的完整城市检查：

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 -- --arsenal-qa
python3 tools/verify_native.py arsenal --app /path/to/Harbourlife.app --output reports/v022-final-app/arsenal
```

`--arsenal-qa` 使用隔离的内存世界与受控初始站位；购买操作、真实主炮弹道、飞行敌人攻击与实际方向输入躲避均运行生产逻辑。源码门禁的合成报告用于检验验证器是否拒绝不完整证据，不作为游戏玩法通过数。

---

# v0.2.1 持续遭遇验证

最终导出的 Mac App 已通过 **136/136 项原生检查，生成 11 张新截图**。两次运行均使用默认音频驱动、Metal 画面与同一 EXE/PCK，正常退出，日志零错误/警告。截图 SHA-256 已逐张核对；歌剧院同平台攻击、B 火控菜单，以及坦克底部两行按键和炮管角度均做了图像检查。

| 最终 Mac 原生回归 | 通过数 | 截图 | 范围 |
| --- | ---: | ---: | --- |
| [自然遭遇](evidence/v021-app/encounter/report.json) | 96/96 | 7 | 默认家门口、歌剧院上平台、机场、CBD 自动刷新追击，90 米换区旧怪仍存活时增援，V/B/H 输入、火控升级与持续战斗 |
| [受控生存](evidence/v021-app/survival/report.json) | 40/40 | 4 | 五类敌人、人物扣血与治疗、真实坦克炮弹击败奖励、战斗中补给与安全完整维修 |

[产物与截图哈希索引](evidence/v021-app/native-index.json) · [自然遭遇外部门禁](evidence/v021-app/encounter/app-binding.json) · [生存外部门禁](evidence/v021-app/survival/app-binding.json) · [构建清单](evidence/v021-app/build.json)。实际退出清理分别跟踪 13/14 个音频播放对象，44/37 毫秒后全部释放。默认音频路径已执行，**声音未人工实听**；这些自动输入、固定场景检查也不代表长期玩家试玩或全地图性能。Windows 验收另列，不借用 Mac 通过数。

本轮十一份局部生产脚本报告合计 **515/515 项通过**，包括管理器满容量时的换区增援边界和歌剧院上平台近身攻击站位。这些检查使用实际敌人、载具、武器和物理脚本，但多数场景是受控夹具，不能替代完整城市或下载包的验收。

| 局部源码验证 | 通过数 |
| --- | ---: |
| [连续增援、压力控制与旧波次恢复](evidence/v021-app/source-checks/encounter-director.json) | 37/37 |
| [追踪、绕障与攻击视线](evidence/v021-app/source-checks/enemy-pursuit.json) | 15/15 |
| [歌剧院真实台阶上的接近、冷却站位与扣血](evidence/v021-app/source-checks/opera-encounter.json) | 23/23 |
| [战地快修、原子计费与冷却](evidence/v021-app/source-checks/field-service.json) | 35/35 |
| [五类敌人、等级与奖励](evidence/v021-app/source-checks/nailong-enemies.json) | 52/52 |
| [战斗、经济、共享车队与恢复](evidence/v021-app/source-checks/survival-loop.json) | 60/60 |
| [载具耐久、损毁与武器状态](evidence/v021-app/source-checks/survival-vehicle.json) | 113/113 |
| [11 类载具的自动追踪辅助武器](evidence/v021-app/source-checks/vehicle-support.json) | 47/47 |
| [主炮范围、伤害与装填升级](evidence/v021-app/source-checks/weapon-upgrade.json) | 47/47 |
| [生命、载具快修与辅助武器 HUD](evidence/v021-app/source-checks/survival-hud.json) | 37/37 |
| [实际炮弹、碰撞与爆炸判伤](evidence/v021-app/source-checks/combat-weapons.json) | 49/49 |

上述计数逐份核对本地报告的检查列表，不累计本页后面的历史版本结果。报告证明其记录的源码运行；只有最终导出文件的外部 EXE/PCK 哈希与构建清单可以确认发行包身份。

管理器容量夹具另外把 24 个旧敌人放在 80–89 米外，观察到约 0.6 秒出现新敌人，6 秒时本地 4 只、全局仍为 24 只；同时检查不删除可见/近身敌人、只回收必需的远处名额、不发击败奖励。这是受控容量边界，区别于下面的自然完整城市遭遇。

歌剧院专项使用生产平台/楼梯、玩家胶囊和敌人脚本，交叉检查两种避障方向及近处/22 米起点。修复后四组怪物都留在约 15.7 米高的平台上，保护时间后约 12.15–12.20 秒发生真实扣血，避免冷却中把玩家当成障碍而绕下楼梯。该专项不替代最终 App 的自然刷新回归。

## 新增完整城市自然遭遇回归

[`--encounter-qa`](../game/scripts/encounter_validation.gd) 从默认家门口开始，让人物实际落地并等待**生产管理器自行生成和追击**；另外检查歌剧院公开上平台、悉尼机场地面和 Pitt Street Mall。它不会调用手动造怪、直接伤害或跳过保护时间来制造成功。

检查包括首次生成、开始追近和第一次真实攻击的时间；实际行走与坦克驾驶；移动 90 米后，旧怪仍存活、未清完甚至零击败时，新位置仍能增援；跨区离开的名额回收；合成陈旧波次记录恢复；实际 V/B 输入、菜单当前/下一级火控数值与付费升级。连续战斗段采用**自动副炮 + 玩家 H 付费快修**，验证达到清理奖励后仍继续补怪；报告记录实际金币、耐久增量和冷却，不能理解为纯挂机自动清场。地区起点与两段换区位置是测试设置，未模拟一路从市区开到机场；未使用的停放载具被冻结。

早期完整城市对比中，旧管理器在家门口约 **26.02 秒**出现第一只、**39.07 秒**第一次受伤；新管理器约 **1.02 秒**出现、**13.37 秒**受伤。机场的 90 米换区观察中，保留 3 只旧怪，约 1.28 秒出现新怪，击败数、清理数和金币没有变化。这些是对应场景的观察值，不保证全城任意位置都能使用同一时间。

先前首次导出的 v0.2.1 Mac App 自然遭遇为 **95/96**，受控生存为 **40/40**；两次均产生新鲜报告，包体哈希未变且日志无错误/警告。自然遭遇唯一失败是歌剧院上平台：怪物实际接近并开始前摇，但 30 秒观察内没有产生真实伤害。该结果保留为缺陷证据，不能算全通过。该次自动副炮配合真实 H 快修的连续战斗已通过，实际三次各花 1125 金币、各恢复 25 点耐久，并验证重复按 H 不重复收费。

[首次自然遭遇报告](evidence/v021-app/initial-app/encounter/encounter-report.json) · [首次 App 身份绑定](evidence/v021-app/initial-app/encounter/encounter-launch.json) · [同包生存报告](evidence/v021-app/initial-app/survival/survival-report.json) · [首次构建清单](evidence/v021-app/initial-app/build.json)。这些先前包体的证据与页首最终通过的包体分别绑定，未被覆盖。

修复歌剧院站位与底部按键提示后的第二次验证，游戏断言分别为 **96/96、40/40**；歌剧院约 11.95 秒实际扣血，底部两行提示均在画面内。但当时两次退出分别出现 48/44 个 ObjectDB 对象泄漏警告，外部原生门禁因此判为失败，没有放行。[自然遭遇退出门禁](evidence/v021-app/initial-exit-warning/encounter/encounter-launch.json)与[生存退出门禁](evidence/v021-app/initial-exit-warning/survival/survival-launch.json)保留原始失败状态；不能只引用游戏内部通过数。

同包 `--verbose --survival-qa` 将 44 个泄漏对象定位为 22 个 `AudioStreamWAV` 和 22 个 `AudioStreamPlaybackWAV`。[音频退出诊断及五组日志](evidence/v021-app/audio-diagnostic/diagnostic.json)进一步记录：宿主 CoreAudio 在 22 辆真实车的 1 秒观察中没有混音周期，最小单音频播放器的 3 秒观察也未混音。Dummy 仅等待原来的五帧同样泄漏；等待实际三个混音周期、约 205 毫秒后才零泄漏。因此只换驱动或用渲染帧数代替音频清理都不充分，宿主 CoreAudio 未混音的原因尚未确认。

新的 [`audio_shutdown.gd`](../game/scripts/audio_shutdown.gd) 在停止声音前仅保留播放对象的弱引用，停止并清空音频流后，等待这些对象实际释放；实际墙钟 1 秒只是防止异常设备阻止退出的上限，不是固定等待时长。它解决正常混音状态下过早退出的竞争问题，未修改音频设备或默认驱动。上面的未混音观察属于早前的宿主状态，不能据此断言 CoreAudio 始终失效。

该退出契约的原生小场景分别通过 [Dummy 11/11](evidence/v021-app/audio-diagnostic/shutdown-dummy.json) 和[恢复混音后的 CoreAudio 11/11](evidence/v021-app/audio-diagnostic/shutdown-coreaudio-restored.json)。22 辆真实车的播放对象分别在约 44/6 毫秒释放，另测普通/2D 音频节点、重复退出和已到期限时如实返回未完成；两组均零泄漏警告。它们是同一套专项在两个驱动下的结果，单列而不加入上方 515 项；设备后来恢复混音的原因未确认，声音仍未人工实听。

最终 App 的两组验收已采用默认 CoreAudio 路径通过，没有使用 Dummy 替代。工具仍保留显式 `--audio-driver Dummy` 供单独的图形/物理诊断使用；它不输出可听声音，只作用于该 QA 进程，不改游戏包、系统设备或默认音效，也不证明 CoreAudio 设备问题已修复。运行记录包含是否覆盖驱动和 `audio_listening_verified: false`，任何驱动下的错误或警告仍会令外部门禁失败。

现有 [`--survival-qa`](../game/scripts/survival_validation.gd) 继续检查五型模型、实际炮弹、治疗和付费维修；为了验证主炮的单次击败奖励，该受控回归会关闭自动副武器，结束时恢复。当前规则允许战斗中补充医疗包，完整维修仍受安全停车和脱战条件限制。

复现命令，在仓库根目录运行：

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/encounter_test.gd -- --encounter-qa
python3 tools/verify_native.py encounter --app /path/to/Harbourlife.app --output reports/v021-final-app/encounter
python3 tools/verify_native.py survival --app /path/to/Harbourlife.app --output reports/v021-final-app/survival
```

原生运行器绑定运行前后的 App/PCK SHA-256，并收集新鲜报告、截图和日志。省略 `--audio-driver` 则使用引擎默认音频驱动，仍不代表人工实听。自然回归使用固定物理步长，不能当作 FPS 或长期难度平衡测试。所有游戏 QA 跳过真实设置、槽位及玩家存档的读取，不保存测试世界。

## Windows CI 门禁的本地验证

新增自然遭遇阶段后，Windows 工作流包含 **37 项聚合门禁**，其中核对 12 个驾驶、16 个受控生存及 42 个自然遭遇的必需检查名称。每阶段从同一最终 ZIP 解出的 EXE 运行，独立临时用户目录、300 秒时限，并要求报告新鲜、全部检查通过且名称唯一、计数与完成标记一致、完整世界就绪、存档隔离，以及无运行错误或警告。

[`windows_package_gate_test.py`](../source/windows_package_gate_test.py) 已通过 **34/34 项本地门禁检查**，YAML 与全部 7 段嵌入 Python 均可解析/编译。测试把合成证据交给工作流真实聚合代码，确认缺报告、缺必需项、失败项、重复名称、伪造计数、超时、旧报告、关闭自动刷新、访问存档及日志告警会被拒绝。另外以完全拦截 GitHub 命令的方式执行真实资产上传步骤，验证完整提交/标签绑定、草稿、注解标签、同名文件 SHA-256，以及拒绝浮动分支和不同版本覆盖。该模拟结果本身不能代替实际 Windows 执行证据，后者在下方单列；这些数字也不与游戏源码检查数相加。

## Windows 最终 EXE 的独立验证

[云端运行 34769213189](https://github.com/YvesZhou-hub/GTA-6-Sydney/actions/runs/34769213189) 已实际完成导出 ZIP 解压后的 Windows EXE 启动、驾驶、生存及自然遭遇四阶段：**23/23 包检查、37/37 聚合门禁，以及 32/32 驾驶、30/30 生存、82/82 自然遭遇断言全部通过**。223 个游戏文件与 Mac 构建清单及提交 `44cdc69987fa3f9f946afb9d875e3ed34d1b499e` 的 Git 文件逐一一致；EXE/PCK 运行前后身份未变，12 份日志无错误或警告，测试未读写玩家存档。

[原始报告](evidence/v021-windows/windows-validation.json)和[原始校验和](evidence/v021-windows/Windows-SHA256SUMS.txt)按发布资产的原始字节保存；[交叉核验记录](evidence/v021-windows/verification.json)再确认实际运行提交、全部必需项、唯一名称、计数/完成标记、源清单，以及 GitHub 服务器 ZIP 摘要。Windows 使用 headless Jolt 60 Hz，无原生截图、GPU、人工操作或声音实听结论。32 + 30 + 82 是 144 项游戏断言，包检查/聚合门禁不另算作玩法断言，Mac 136 项也不并入 Windows。详细哈希与范围见 [Windows 说明](WINDOWS.md)。

以下保留各版本的原始验证记录，不将旧包通过数计入 v0.2.1。

---

# v0.2.0 奶龙危机验证

最终导出的 Apple Silicon Mac App 已通过 **40/40 原生完整城市检查**，退出码为 0，并人工检查四张截图。验证包括五型奶龙真实落地、攻击前摇和人物扣血、H 治疗与冷却、坦克弹丸击杀并增加金币、B 暂停/鼠标释放，以及付费维修和装甲减伤。

[最终 App 生存报告](evidence/v020-app/survival/report.json) · [外部 EXE/PCK 哈希与新鲜截图绑定](evidence/v020-app/survival/app-binding.json) · [构建清单](evidence/v020-app/build.json)

| 局部生产脚本验证 | 通过数 |
| --- | ---: |
| [战斗、收益、维修、补油与状态恢复](evidence/v020-app/survival-loop.json) | 57/57 |
| [人物、载具损毁与升级武器](evidence/v020-app/survival-vehicle.json) | 113/113 |
| [有限耐久下的驾驶](evidence/v020-app/survival-driving.json) | 32/32 |
| [有限耐久下的各类载具加速](evidence/v020-app/survival-boost.json) | 111/111 |
| [五类敌人、等级、奖励与物理](evidence/v020-app/nailong-enemies.json) | 52/52 |
| [生命 HUD 与交互隔离](evidence/v020-app/survival-hud.json) | 31/31 |
| [实际存档 API、旧版本迁移与备份](evidence/v020-app/save-v020-format6.json) | 32/32 |

原生测试使用引擎输入事件和真实物理，不是手持鼠标的长时间试玩；角色/载具初始位置及证据镜位固定。局部测试与最终 App 测试分别列出，不当作全覆盖或长期难度平衡结论。全部使用独立 QA 世界，未访问玩家存档。

Apple M4、1440×900、五个活动 AI、固定镜位的 90 帧短样本平均 8.24 ms、P95 25.09 ms；它不代表持续驾驶、地图流式加载或其他硬件性能。编译后的 .gdc 不能拿空源码哈希证明身份，最终产物由外部 EXE/PCK SHA-256 绑定。Windows 构建与测试另见 [Windows 说明](WINDOWS.md)。

以下保留 v0.1.9 历史证据，不将它们充作本轮验证。

---

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
