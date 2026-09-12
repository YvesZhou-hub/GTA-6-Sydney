# Aster F-27 原创战斗机

这是为 Harbourlife 创作的虚构双发战斗机，采用原创程序网格、原创涂装和街机飞行控制。它不是任何现役飞机的精确复制，也未使用第三方模型、贴图或实拍照片像素。

## 实际查看的公开图像

2026-09-12 在浏览器中打开并实际查看 Boeing 官方原图：

- [F-15EX 侧前方飞行照片](https://www.boeing.com/content/dam/boeing/v2/products/f-15ex-eagle/f-15ex-eagle-hero-mobile.jpg)：观察尖鼻、隆起的透明座舱、翼根过渡、后掠翼和机身侧进气口。模型使用这些通用形态关系；单座、机翼平面、外倾双垂尾和尺寸均是原创设计。
- [F-15EX 双发尾喷口照片](https://www.boeing.com/content/dam/boeing/v2/products/f-15ex-eagle/f-15ex-eagle-roadblock-1.jpg)：观察分瓣金属外环、深色内腔、左右独立喷口及机腹曲面。模型以 24 片喷口瓣、凹入内环和热色材质表达，未复制真实发动机内部构造。
- [Boeing 官方机型页面](https://www.boeing.com/defense/fighters-and-bombers/f-15ex-eagle)：其公布的 19.4 m 长、13 m 宽仅用于尺度常识核对。Aster F-27 不沿用这些尺寸或真实飞机性能。

## 实际几何与接口

模型坐标为米，+Y 向上、-Z 向前。程序采样的可见网格和碰撞总包络一致：最小 `(-6.8,-2.05,-9.4)`，最大 `(6.8,4.28,9.1)`；机长 18.50 m、翼展 13.60 m、含放下起落架总高 6.33 m。三个轮胎的最低接地面是局部 Y=-2.05 m。以上均为设计值，不称测绘尺寸。

41,492 个三角形；31 个直接刚体碰撞形状；通过现有工厂合并后 32 个 MeshInstance（含独立可动轮）。细节包括：闭合截面机身、双进气口凹腔、透明座舱及可见座椅/飞行员、机翼上下曲面、两组水平尾翼、两片外倾垂尾、24 瓣双喷口、三点轮式起落架、轮辋与刹车、收放舱门、控制面接缝、翼尖灯和原创橙色识别条。起落架当前固定放下，未实现收放动画。

`fighter_models.gd` 的 `build(body,mats,moving,factory)` 提供 `moving.weapon_muzzle`：局部 `(0,-0.08,-9.8)`、朝 -Z，位于鼻尖前 0.4 m，避免弹药生于机身内部；`moving.exhaust` 为两个喷口 Marker3D。武器发射和楼体破坏由共享战斗系统负责。

## 飞行与真实验证

`fighter_motion.gd` 的 `setup/tick` 使用连续力和转矩，没有每帧写位置、速度或关闭碰撞。助力升力抵消项目重力；W/S 改变保持式油门，A/D 协调转弯，R/F 俯仰，松手回到水平姿态，Space 空气刹车降到 70 m/s。最大速度为 `2000/3.6` m/s；推荐首积分初速 140 m/s、相对地面最低空域 90 m，完整城市的生成器使用更保守的净空搜索。质量 14,500 kg、控制助力及加速度是游戏设定。

Jolt 默认的 500 m/s 刚体速度上限实际限制了第一轮测试，不能仅靠 HUD 声称 2000 km/h。项目将 `physics/jolt_physics_3d/limits/max_linear_velocity` 设为 650 后验证实际可达；[Godot 官方 ProjectSettings 文档](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-jolt-physics-3d-limits-max-linear-velocity) 说明该物理上限。

源夹具 `source/fighter_flight_test.gd` 使用真实生产 HarborVehicle、Factory、Motion、Jolt 和 Input actions，隔离场景，不读取或写入玩家存档。21 项通过：冷启动冻结副本入座及首帧保存、首积分 140 m/s、15 秒不操作不下坠、W 加速实际约 1999.997 km/h、松油门保持、7 秒 65% 右转约 1.022 rad（高度变化 -2.68 m）、松手平稳回正、真实上升/下降、刹车、S 降油门、高速保存及重新加载。最大实测速度约 1999.9993 km/h。测试报告绑定生产源码哈希，位于 `reports/fighter-flight/checks.json`。

这个夹具证明控制与模型集成的物理行为；完整城市召唤、撞毁楼体、发射按钮和原生画面另由整合验收覆盖。当前文档不把未运行的原生画面检查记作通过。

另外 `source/combat_spawn_test.gd` 已在完整生产城市及机场通过 74 项：两种模式共新增 4 架战机和 4 辆坦克，旧副本从 11 个保留至 19 个，钱不变且每次即时入座；四条 420 m 离场走廊各以 5 m 间距检查 85 个完整包络，并实际飞行前三秒，无下坠或撞毁触发。新战机请求耗时 84.6–88.1 ms；首次冷缓存坦克请求 1171 ms，其余 22.7–24.2 ms。报告 `reports/combat-spawn/checks.json` 记录运行前后源码一致、无玩家存档读写。撞毁与武器效果仍由单独战斗测试验证。
