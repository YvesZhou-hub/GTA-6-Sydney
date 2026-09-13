# Windows x86_64 试玩说明

本页操作说明对应 Harbourlife v0.2.1，游戏为离线单人试玩。**v0.2.1 Windows 下载包尚待云端构建与最终 EXE 验收**；当前源码通过不代表 Windows 包已通过。已完成的 v0.2.0 Windows 记录保留在下方，其附件在 [v0.2.0-preview.1 发布页](https://github.com/YvesZhou-hub/GTA-6-Sydney/releases/tag/v0.2.0-preview.1)。Windows GPU 画面与人工操作尚未实测。

## 下载与启动

1. 在发布页面的 **Assets** 中选择 `Harbourlife-Windows-x86_64.zip`。GitHub 的 **Code → Download ZIP** 和 `Source code` 是源码，不是可直接运行的游戏。
2. 在资源管理器中对 ZIP 选择 **“全部解压缩”**，解压到一个独立文件夹。
3. 打开解压后的文件夹，运行其中的 **`Harbourlife.exe`**。保留它旁边的 **`Harbourlife.pck`**和 `licenses` 目录；移动游戏时移动整个文件夹。
4. 等待加载完成，再从标题页选择 **“奶龙危机 · 开始生存”**、**“自由观光 · 无敌人”** 或 **“从悉尼机场起飞”**。加载时间取决于设备；本页没有给出 Windows 启动耗时保证。

`Harbourlife.pck` 是游戏资源包，不能单独打开或与其他版本的 EXE 混用。Godot 的 Windows 导出采用可执行文件配合 PCK，发布时也可以选择嵌入 PCK；本项目采用外部 PCK，必须与 EXE 一起分发。[Godot 官方 Windows 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

若 Windows 显示未知发布者或安全提示，先核对下载来源和该版本提供的 SHA-256。数字签名和安全软件提示是独立事项；导出成功不代表文件已签名，也不保证不会出现提示。本页不要求关闭系统防护。

## 系统与显卡

这个包用于 **64 位 Windows 的 Intel / AMD x86_64 处理器**。它不是 Windows ARM 原生包，也不是 32 位 Windows 包。

截至 2026-09-13，Godot stable 官方文档给出的简单原生项目基线包括 **Windows 10、支持 SSE4.2 的 x86_64 CPU**。本项目使用 **Forward+** 渲染；官方列出的相应图形 API 基线是完整 Vulkan 1.0 支持；本包采用 Vulkan，不提供额外的 Direct3D 12 启动入口。[Godot 官方系统要求：导出项目](https://docs.godotengine.org/en/stable/about/system_requirements.html#exported-godot-project)

上述是引擎运行简单项目的基线，**不是 Harbourlife 已测得的最低配置**。城市规模、分辨率和可用内存都会影响实际表现；尚未通过硬件测试确定本游戏的最低 RAM、显存或推荐显卡，不把引擎示例中的内存与磁盘数字当作本游戏保证。下载和解压所需空间应以该版本 ZIP 及解压后大小为准。

## 常用操作

奶龙模式中，有效地面会自动增援，换街区不必先清完旧怪；开场 12 秒保护期间也能看见敌人接近。击败里程碑只发金币与医疗包，不安排固定休息期。旧观光世界可从“继续并开启奶龙危机”保留财富、车队和位置进入战斗；也能继续无敌人的观光模式。

左键 / X 发射免费主炮或人物武器。11 类载具默认开启免费自动辅助武器，V 切换。H 在步行时用医疗包治疗，驾驶时付费快修最多 25 个耐久百分点；B 暂停并打开补给、维修与升级，列出当前和下一级火控伤害、爆炸半径及装填时间。高等级怪物奖励更多金币。车型损毁后先 E 离舱或 Home 救援，再 B 远程维修；新增同款副本不会恢复共享耐久。

以下按键来自当前游戏输入绑定。进入游戏后，鼠标控制观察；菜单和地图打开时会释放鼠标。

| 操作 | Windows 按键 |
| --- | --- |
| 行走；多数载具的油门、转向 | W / A / S / D，或方向键 |
| 观察；坦克鼠标瞄准 | 移动鼠标 |
| 步行时奔跑 | 按住 Shift |
| 所有载具三倍极速加速 | 按住 Shift；松开后平顺回到正常速度范围 |
| 跑车、摩托车漂移 | 按住 Ctrl，同时按 A / D 转向 |
| 步行时跳跃 | 空格 |
| 跑车、摩托车、平衡车、坦克急刹 | 空格；优先于 Shift 加速 |
| 交互、上车或下车 | E |
| 免费新增载具并立即驾驶 | Tab，然后点击车型 |
| 自动追踪辅助武器开关 | V；默认开启，弹药免费 |
| 人物急救 / 当前载具战地快修 | H；各有 12 秒冷却，快修付费 |
| 暂停战斗并打开补给、维修与火控升级 | B |
| 工作与活动 / 城市体验 | J / K |
| 拿起或放下物件 | G |
| 打开或关闭地图 | M |
| 暂停、设置、存档菜单；关闭当前面板 | Esc |
| 时间、日夜速度与定格 | T |
| 运行诊断与画面参数 | F3 |
| 手动保存世界 / 保存截图 | F5 / P |
| 返回个人空间 | Home |
| 临时显示鼠标，点击小地图或界面按钮 | 按住 Alt，松开后继续观察 |

笔记本若把 F3 / F5 用作亮度或音量键，需要用设备对应的 Fn 组合发送功能键。文本输入框获得焦点时，先完成输入并返回游戏，再使用玩法快捷键。

**地图：**左键选择地点或空白处标点，按住左键拖动平移，滚轮缩放，右键清除标记。选择地点只设置导航，不会传送。地图打开时步行与驾驶暂停；按 M / Esc 或点击右上角 **“返回游戏”** 继续。

**驾驶与加速：**跑车和摩托车用 Ctrl + A / D 做出侧滑，松开 Ctrl 后恢复抓地；空格用于急刹。所有 11 类载具的 Shift 都提高可用极速，通过推力加速；转弯、坡度和飞行姿态会影响实际速度。空格会取消 Shift 加速，但不同载具的制动方式不同。

**坦克：**W / S 驱动履带，A / D 转向；鼠标瞄准，也可用 Q / Z 转动炮塔、R / F 调整炮管俯仰。X 或鼠标左键发射。

**固定翼飞机与战斗机：**W / S 增减推力，A / D 转弯，R / F 俯仰，空格减速；战斗机用 X 或左键发射。标题页的 **“从悉尼机场起飞”** 会进入客机：按住 W 加推力，约 250 km/h 时按 R 抬头。这里是游戏操纵提示，不是现实飞行操作规程。

**其他载具：**直升机 R / F 升降；空格可取消其 Shift 加速，仍按住 W 时会继续普通前进，不能把它当作地面载具的急停。反重力平衡车 R / F 调整悬浮高度，空格急刹。快艇和游艇用空格减速。滑翔机与滑翔伞正常状态下无动力滑翔，A / D 转弯、R / F 俯仰、空格减速；按住 Shift 会获得科幻辅助推力，以正常滑翔速度的三倍为加速目标，松开后恢复无动力滑翔。具体提示也会显示在载具界面中。

## 存档、截图与问题记录

在资源管理器地址栏输入以下路径，可打开默认用户数据目录：

```text
%APPDATA%\Godot\app_userdata\Harbourlife · 悉尼海港\
```

这是 Godot 默认 Windows `user://` 规则与本项目名称组合出的路径；云端验证使用隔离的临时用户目录，未读取真实玩家存档。[Godot 官方用户数据路径说明](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#accessing-persistent-user-data-user)

其中 `worlds` 保存世界 JSON 和前次成功保存的 `.bak`，`photos` 保存 P 键截图，`settings.json` 保存设置。正常游玩约每 60 秒自动保存，也可按 F5 手动保存；没有云同步。更新前退出旧版，保留这份用户数据，不要把自己的存档覆盖到下载包中。

若异常中断后某个世界从列表消失，请先退出游戏并备份整个 `worlds` 文件夹。恢复菜单依赖主 `.json`：若主文件缺失但对应 `.json.bak` 仍存在，可复制该备份，将复制件改成原 `.json` 文件名再启动；保留原 `.bak`。这是此前源码审查记录的恢复入口限制。

如果无法启动或遇到显示问题，请记录 Windows 版本、CPU、显卡和驱动版本、错误原文、下载包名称及 SHA-256。游戏能打开时可补充 F3 诊断信息和截图。缺少 PCK 时先核对是否完整解压。

## Windows 验证记录

### v0.2.1：源码与门禁已验，Windows 最终 EXE 待验

开发源码已有逐模块的局部检查报告；自然遭遇源码回归已在真实家门口、歌剧院平台、机场和 CBD 观察到自行生成、追近及攻击。详细范围、当前通过数与中间原生运行的未解决验证事项见 [测试说明](TESTING.md)。这些结果不计为 Windows 的通过记录。

[Windows 工作流](../.github/workflows/windows-package-check.yml) 默认版本已设为 `v0.2.1-preview.1`。最终运行将比对同版 `docs/evidence/v021-app/build.json` 的游戏源清单和 SHA-256，再从下载 ZIP 解压出的实际 EXE 执行启动、驾驶、受控生存及新增 `--encounter-qa` 四个阶段。每个测试进程使用新临时目录、300 秒时限；自然遭遇阶段包括 90 米换区且旧怪仍在、V/B 操作、付费火控升级，以及自动辅助武器配合实际 H 快修的持续战斗。

37 项聚合门禁要求进程正常结束、日志无错误或警告、世界就绪、无玩家存档访问、新鲜报告的计数与完成标记一致，所有检查通过且名称唯一，必需的驾驶/生存/自然遭遇名称齐全。门禁自身及资产上传步骤的 34 项本地合成/模拟验收已通过，7 段嵌入 Python 与 YAML 编译/解析已通过；**目前尚无 v0.2.1 Windows 云端运行编号、下载包哈希或通过报告**。完成后应以该次发布的 `windows-validation.json` 和 `Windows-SHA256SUMS.txt` 为准。

验证通过后，上传步骤可向已存在的草稿或公开发布添加资产，必须使用本次构建的完整 40 位提交 SHA 作为 `targetCommitish`，并匹配指定标签；现存 Git 标签也必须解引用到同一提交。草稿尚未生成 Git 标签时允许暂存资产，工作流不会改变草稿/公开状态。所有同名资产先核对 SHA-256，字节不同即拒绝整个上传，不使用覆盖参数。

### v0.2.0：Windows 构建、驾驶与奶龙生存无窗口验证通过

2026-09-13，[Windows 云端构建与验收运行 34748565393](https://github.com/YvesZhou-hub/GTA-6-Sydney/actions/runs/34748565393)通过。构建提交为 `a5878918436ea90df635075093e204e059602847`，引擎为 Godot `4.7.2.stable.official.ed1daf0bf`。下载该次运行产物后再次核对了报告、日志、ZIP 中的全部文件和源文件清单。

| 项目 | 实际结果 |
| --- | --- |
| 下载包 | `Harbourlife-Windows-x86_64.zip`，85,371,170 字节；17 个随包文件合计 189,057,526 字节 |
| 包与源码身份 | 23/23 项包检查通过；215 个游戏源文件逐一匹配同版 Mac 构建；AMD64 PE32+、Godot 4.7.2 外部 PCK、ZIP CRC 与逐文件 SHA-256 均复核通过 |
| 运行门禁 | 26/26 项通过；从最终 ZIP 解压后启动实际 EXE，城市启动、驾驶和生存三个进程退出码均为 0，九份运行日志无错误或警告 |
| 世界初始化 | `HARBOR_WORLD_READY buildings=15097 structure_components=21697`；实际城市与机场完成初始化 |
| 驾驶专项 | Jolt 60 Hz 检查 32/32 通过，覆盖跑车与摩托车急刹、漂移、转向、三倍极速、松开恢复及独立载具状态 |
| 生存专项 | 30/30 通过：五种奶龙在真实城市地面生成与落地、敌人攻击扣血、程序化 H/B 输入与治疗冷却、战斗期间禁止补给、免费新增并驾驶坦克、实际炮弹击败奖励、坦克受损与共享耐久、付费维修及离开菜单恢复游戏 |
| 存档与运行身份 | 驾驶和生存分别使用新的临时用户目录，新鲜报告均通过检查；跳过玩家存档读取，未写存档。运行后的 EXE / PCK 哈希与下载 ZIP 中的文件一致 |
| 验证边界 | 使用 `--headless`；生存报告明确记录 `native=false`、`display_driver=headless`，没有 Windows 截图。GPU 画面、中文视觉效果、音效听感、人工鼠标/驾驶/炮击、FPS、完整游玩与存档重开未实测 |
| 签名 | 未配置数字签名证书 |

26 项运行门禁包含对包检查、32 项驾驶检查和 30 项生存检查的核验，这些层级不相加作为独立测试总数。驾驶和生存分别从同一份最终 EXE 运行 `--headless --fixed-fps 60 -- --driving-qa` 和 `--headless --fixed-fps 60 -- --survival-qa`，各设 300 秒运行时限。脚本以编译资源导出，因此包内脚本可加载不等于逐字节源码证明；测试版本由外部 EXE / PCK 哈希和构建源清单共同确认。

ZIP SHA-256：

```text
d0b919ed6cd51f7f68d7a7a2f1eb63adfe0794c4ee20dda8bf7529b459ae7d3b
```

[v0.2.0 完整 Windows 验证报告](evidence/v020-windows/windows-validation.json)包含 26 项门禁、全部驾驶与生存检查、215 个源文件身份及运行日志哈希。发布附件中的 `Windows-SHA256SUMS.txt` 用于核对 ZIP 和该验证报告。

### v0.1.9：Windows 构建与物理验证通过

2026-09-13，[Windows 云端构建与验收运行](https://github.com/YvesZhou-hub/harbourlife/actions/runs/34734507798)通过。构建提交为 `abff72723a7a7fe0718a6284029f19c3d5d0e64e`，引擎为 Godot `4.7.2.stable.official.ed1daf0bf`。205 个游戏源文件与同版 Mac 构建证据逐一匹配。

| 项目 | 实际结果 |
| --- | --- |
| 下载包 | `Harbourlife-Windows-x86_64.zip`，85,299,027 字节（约 85 MB） |
| 解压布局 | `Harbourlife/Harbourlife.exe`、`Harbourlife.pck`、`START-HERE.txt`、`LICENSE`、`PLAY_PERMISSION.md` 和 `licenses/`；共 17 个文件，188,983,965 字节（约 189 MB） |
| 包与源身份 | 23/23 项包检查通过：版本与源身份、ZIP CRC 和路径、AMD64 PE32+、外部 PCK 及哈希 |
| 运行验收 | 16/16 项汇总门槛通过；从最终 ZIP 解压后启动 EXE，并运行驾驶专项；两个进程退出码均为 0，日志无错误或警告 |
| 世界初始化 | `HARBOR_WORLD_READY buildings=15097 structure_components=21697`；隔离试玩世界达到 READY |
| 驾驶专项 | 导出 EXE 中的 Jolt 60 Hz 物理检查 32/32 通过，覆盖跑车与摩托车急刹、漂移、回正、反打、三倍极速及松开恢复，以及静止、腾空和独立载具状态 |
| 存档隔离 | 全新 Windows 云端环境，启动与驾驶检查均跳过玩家存档读取，未创建存档、未接触既有玩家存档；运行后 EXE / PCK 哈希不变 |
| 未验证范围 | Windows GPU 画面、中文视觉效果、音效听感、人工鼠标/驾驶/炮击、FPS 和完整游玩及存档重开未实测；Mac 验证不计入 Windows |
| 签名 | 未配置数字签名证书 |

上述 16 项运行门槛包含对包检查和 32 项驾驶子报告的核验，三个数字按层级记录，不相加作为独立测试总数。启动使用 `--headless --quit-after 15 -- --interactive-qa`，其中 15 指引擎迭代次数；驾驶专项另外运行生产载具与实际输入动作。

ZIP SHA-256：

```text
38b0bdac943e1b1f6c62d9c451c9780a603382f0c72771127b1150118665abdd
```

[v0.1.9 完整 Windows 验证报告](evidence/v019-windows/windows-validation.json)包含逐文件身份、运行记录和驾驶专项结果；[v0.1.9 校验和](evidence/v019-windows/Windows-SHA256SUMS.txt)记录下载包与报告哈希。

### v0.1.8：历史基线

2026-09-13，[Windows 云端构建与验收运行](https://github.com/YvesZhou-hub/harbourlife/actions/runs/34727607243)通过并上传到现有 [v0.1.8-preview.1 发布页](https://github.com/YvesZhou-hub/harbourlife/releases/tag/v0.1.8-preview.1)。构建提交为 `57d153c20bc163b63cf41e206a979380bc6975ae`，引擎为 Godot `4.7.2.stable.official.ed1daf0bf`。199 个游戏源文件与原 v0.1.8 发布证据逐一匹配，Windows 构建在临时副本中导入。

| 项目 | 实际结果 |
| --- | --- |
| 下载包 | `Harbourlife-Windows-x86_64.zip`，85,277,110 字节（约 85 MB） |
| 解压布局 | `Harbourlife/Harbourlife.exe`、`Harbourlife.pck`、`START-HERE.txt`、`LICENSE`、`PLAY_PERMISSION.md` 和 `licenses/`；共 17 个文件，188,961,043 字节（约 189 MB） |
| 包与源身份 | 19 项包检查通过：ZIP CRC、路径、AMD64 PE32+、外部 PCK 及哈希、原始游戏源文件；完整逐文件清单见报告 |
| 实际 Windows 启动 | 从最终 ZIP 解压后运行 EXE；7 项运行检查通过，退出码 0，日志无错误/警告 |
| 世界初始化 | `HARBOR_WORLD_READY buildings=15097 structure_components=21697`；隔离的试玩世界也达到 READY |
| 测试方式 | GitHub Windows Server 2025（10.0.26100）全新 VM；`--headless --quit-after 15 -- --interactive-qa`，15 指引擎迭代次数 |
| 图形与操作范围 | 无窗口 CPU/资源加载验证；Windows GPU 画面、中文视觉效果、音效听感、人工鼠标/驾驶/炮击以及保存重开未实测。Mac 的 189 项验证不计入 Windows |
| 签名 | 本次构建未配置数字签名证书 |

ZIP SHA-256：

```text
e693672c39dc3fdbde40622875dcc5680c78c36eb246cd54efa30dba81f8a052
```

[完整 Windows 验证报告](evidence/v018-windows/windows-validation.json)包含 EXE / PCK 哈希、全部随包文件清单、运行状态和日志哈希；[校验和](evidence/v018-windows/Windows-SHA256SUMS.txt)与发布页附件一致。原 Mac 包、源码下载档案、视频及其校验文件保持原样。原发布标签保留游戏源代码；Windows 构建工具及本文随后补充到仓库 `main`。
