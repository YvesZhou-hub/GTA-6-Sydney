# v0.1.8 验证记录

本页记录中文字体、炮击反馈和宣传片这一轮验证，不把 [v0.1.7 的 580 项检查](evidence/v017-app/evidence-index.json)计入本轮。

特效长轴方向修正后的最终 App 已重新完成 **189/189 项原生检查**。结果与文件身份见 [本轮证据索引](evidence/v018-app/evidence-index.json)和 [构建报告](evidence/v018-app/build.json)。旧候选运行与视频不作为本页最终结果。

| 最终产物 | SHA-256 |
| --- | --- |
| App 可执行文件 | `db79b1b102e9a069cee765b8a26cf329d574ef2e8391236d2985a50c0eb11994` |
| PCK | `078718563050a8baaad0ae86b5c08fd2e66f4ede5e94ce0c4e04ec509827ad33` |
| App ZIP | `7726d53f5c6615cfcc13ac9958c432eb93a8fa8c94de9ac98afe4f8db141d995` |

## 原生 App 检查

检查运行于导出的 Apple Silicon macOS App，而非编辑器中的孤立模型。最终运行的四份报告合计 **189/189 通过，产生 18 张截图**。

| 模式 | 通过数 | 截图数 | 实际范围 |
| --- | ---: | ---: | --- |
| [ui-font](evidence/v018-app/ui-font-report.json) | 30/30 | 3 | 完整世界加载后的实际标题、载具菜单、地图字体；运行时 TextServer 字形与界面可见性 |
| [combat](evidence/v018-app/combat-report.json) | 42/42 | 8 | 生产载具生成、武器按钮、炮塔动作、真实城市碰撞和炮击效果 |
| [navigation-input](evidence/v018-app/navigation-input-report.json) | 35/35 | 3 | 引擎输入事件、菜单焦点、地图点击与相机输入路由 |
| [experience](evidence/v018-app/experience-report.json) | 82/82 | 4 | 免费载具生成、原有载具保留、导航点及占用状态保存恢复、城市服务和抵达判断 |

每组对应的 `*-launch.json` 记录进程退出、报告新鲜度、运行错误及 App 可执行文件/PCK 的 SHA-256；它们应与同批 `build.json` 的 `app_identity` 一致。最终证据索引保存实际文件哈希，检查计数来自报告中的断言列表，不由日志中的总数推测。

字体三张最终 App 截图已经重新逐张查看：“无敌坦克”“无敌战斗机”的“敌”字完整，按钮文字没有截断；标题与地图中文正常。地图在该缩放比例仍有密集地名，不能由这三张图推断所有地图标签都不重叠。公开截图采用 `ui-font-01-title-menu.png`、`ui-font-02-tank-fighter-menu.png`、`ui-font-03-map-fonts.png` 命名，由证据索引关联。

字体流程使用实际界面的处理函数与滚动定位，并非启动过程截图或实体鼠标键盘测试。导航流程注入 `Viewport.push_input` 事件，属于引擎事件自动化。战斗流程为可重复截图冻结载具姿态、按固定步长推进炮弹；它不是驾驶、飞行或帧率基准。测试使用 QA 世界及专用存档夹具，不修改玩家现有存档。

## 开发阶段源码验证

这些是局部 headless 开发记录，与最终 App 原生检查分开计数。报告各自记录测试和声明依赖的 SHA-256；一个报告不能证明未声明依赖或其后改动的代码。

| 夹具 | 已记录通过数 | 范围与身份边界 |
| --- | ---: | --- |
| [`ui_font_test.gd`](../source/ui_font_test.gd) | 42/42 | 共享字体、实际 UI 文本与公开地图数据的字符覆盖、运行时字形检查；这是开发快照，之后录制脚本的字符串发生变化 |
| [`combat_effects_test.gd`](../source/combat_effects_test.gd) | 37/37 | 效果池、粒子提交参数、声音数据、生产载具接口，以及修正后的长轴方向回归 |
| [`combat_weapons_test.gd`](../source/combat_weapons_test.gd) | 49/49 | 修正后的局部生产武器、瞄准、扫掠及状态回归 |
| [`combat_vehicle_state_test.gd`](../source/combat_vehicle_state_test.gd) | 18/18 | 生产工厂、坦克瞄准存档、战斗机速度恢复及真实刚体积分 |

字体开发快照检查了 855 个去重字符，包含源码 UI 和公开地图 JSON 中的字符，缺字数为零。原生 App 另有独立的运行时字体检查，不能将局部测试的字符数量误写成最终 App 自动扫描了全部源码。字体来源、固定版本与许可见 [UI_FONTS](UI_FONTS.md) 和 [字体许可](../licenses/FONTS.md)。

局部源码夹具可用以下形式复现；实际结果以对应运行报告及依赖哈希为准：

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/ui_font_test.gd
```

headless 图形后端的参数断言不证明画面观感；声音数据断言也不代替听审。[炮击说明](COMBAT_EFFECTS.md)记录实现范围。

## 宣传片验证边界

宣传片使用实际生产世界、编排相机和固定步长录制。横屏目标为 1920 × 1080、30 fps、H.264/AAC；实际时长、帧数、解码结果、视频 SHA-256、源镜头与音频来源以各交付目录的 `video-verification.json` 为准。制作方法见 [PROMO](PROMO.md)。

最终主片为 **38 秒、1140 帧**，短版为 **16.5 秒、495 帧**；两者实际解码均为 1920 × 1080、30 fps。已从修正后成片重新抽取并逐张查看主片 0.5、11.5、23、36.5 秒及短版 0.5、15 秒共六帧：中文与片尾“关注我，评论「悉尼」领试玩”完整，未发现截字或字幕遮住主要角色/载具。该目检只覆盖这六个指定时刻，不冒充逐帧运动检查或听审。

| 最终视频 | SHA-256 |
| --- | --- |
| 横屏主片 | `b2649fe196a0cc4b69bffc602821ec0e08461ed9e8dbc0560f0158bcde6a6c51` |
| 坦克短版 | `b65bdcb4de5b9b9ad8e8f58721ca477d730c9eb15d141862b7831455396450fa` |

字幕安全区检查针对完整横屏，不包括平台按钮覆盖或竖屏裁切。固定步长导出不代表实时 30 FPS；日夜镜头使用明确记录的时间压缩，不是正常 12 倍速几秒走完整天。宣传片配乐与音效在剪辑时合成，不声称直接录下游戏完整实时混音，也不承诺播放量。

本轮验证不表示普通楼宇、地形或室内已经达到全区 1:1；建筑损坏仍是游戏构件系统。版本改动范围见 [FIXES_0.1.8](FIXES_0.1.8.md)。

下载档案另由 `tools/verify_archive.py` 检查签名、可执行架构、PCK资源、源码快照与公开文件清单。最终独立档案结果及源码提交对应关系见 [发布校验记录](https://github.com/YvesZhou-hub/harbourlife/releases/download/v0.1.8-preview.1/release-validation.json)。
