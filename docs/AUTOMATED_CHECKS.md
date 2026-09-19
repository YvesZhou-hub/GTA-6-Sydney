# 每个 PR 自动跑的回归检查

每次开 PR、每次往 `main` 推送，GitHub 都会自动把回归检查跑一遍。结果显示在 PR 页面底部；有没过的检查时，运行页面的摘要里会列出是哪一项、第一条出错信息是什么，完整日志可以在运行页面下载（保留 14 天）。

## 跑什么

清单只有一份：[`tools/checks.json`](../tools/checks.json)。

- **86 个源码测试**：战斗、敌人、生存、载具、地标、交通规则、加载界面、跨海大桥驾驶与计时赛等，每个都用真实的游戏脚本。
- **10 个游戏内检查**：驾驶、连续遭遇、武器与空袭、街上人车、主线、生存、港区、战斗手感、战斗，以及完整城市的交互启动。

一项检查只有同时满足三点才算通过：Godot 正常退出（退出码 0）；日志里没有任何 ERROR、WARNING 或 FAIL；并且确实报告了自己跑完（有 PASS 或 COMPLETE，交互启动要看到 `INTERACTIVE_QA_READY`）。只看退出码不够：脚本出错时 Godot 不一定会以失败退出。

## 怎么跑

GitHub 上分成 6 组同时跑（4 组源码测试、2 组游戏内检查），在 Ubuntu 上用官方 Godot 4.7.2（下载后核对 SHA-256）。第一次实测：游戏内检查 2–4 分钟，源码测试每组 12–15 分钟，整轮大约 15 分钟。导入过的素材会缓存，之后的运行更快。

本地用同一个脚本：

```sh
python3 tools/run_checks.py                          # 全部，约 50 分钟
python3 tools/run_checks.py --group qa               # 只跑游戏内检查
python3 tools/run_checks.py --only attack_delivery_test street
python3 tools/run_checks.py --group source --shard 2/4   # 和 CI 第 2 组一样
```

日志和结果写在 `reports/checks/`。

## 没有放进来的

`tools/checks.json` 的 `not_run` 里逐条写了原因，分三类：

| 原因 | 检查 |
| --- | --- |
| 一项就要 7 分钟以上 | `survival_boost_test`、`vehicle_boost_test`、`vehicle_speed_test` |
| 需要真实窗口或声音 | `camera_motion_test`、`ui_font_test`、`roof_visual_check`、`world_visual_probe`、`audio_shutdown_test`、HUD 检查（`--hud-qa`） |
| 只是测量数据，没有对错 | `encounter_baseline`、`world_physics_probe`、`world_winding_check` |

需要真实窗口的检查（HUD、街上人车的帧时间、截图）仍在发布前用打好的 App 在 Mac 上跑，见 [验证记录](TESTING.md)。

## 曾经长期失败、后来修好的 5 个测试

加入自动检查时，有 5 个测试在 `main` 上本来就不通过。逐个查过后，游戏行为都是对的，是测试的预期停在了旧版本：

| 测试 | 过时在哪里 | 现在检查什么 |
| --- | --- | --- |
| `combat_vehicle_state_test` | 读档速度上限还按固定的 620 / 240 米每秒；加入 Shift 三倍加速后，上限改成最高速的 3.25 倍，免得存档里的加速状态被截断 | 超速的存档被压到当前上限，而且上限不低于三倍最高速 |
| `vehicle_spawn_test` | 要求存档版本等于 5（现在是 7）；要求每辆副本血量独立，而奶龙危机加入后同款车共享耐久（防止靠新叫一辆车回血） | 存档是当前格式；位置和油量按副本还原，血量按同款共享，一辆的损伤不会被同款副本洗掉 |
| `experience_flow_test` | 要求车库按钮上写"免费"；按钮后来改成显示耐久，"全部免费"移到面板说明 | 面板写明全部免费，余额为 0 时仍能新增并入座 |
| `world_road_probe` | 用早期程序生成城市的北岸轮廓判断"水面"，换成真实地图后判断失效 | 全城 7 万个车行道采样点下面都有地面；只有 4 段船只下水坡道和码头混凝土通道伸进水里，这是地图里的真实情况 |
| `bridge_drive_test` | 把驾驶期间的全部进账都当成比赛奖金；主线第一步"坐进一辆载具"同时发了 $2,000 | 比赛奖金单独核对（$2,000 + 时间奖金），主线奖励另外记账 |

## 和发布检查的关系

`windows-package-check.yml` 是发布时手动触发的：打 Windows 包、解压后运行、上传到发布页。这里的回归检查不打包，只保证每次改动合进 `main` 之前，已有的测试都还是绿的。

## 为什么要加

v0.5.0 的评审发现，连击伤害被玩家的受伤保护吞掉了一半，但当时的测试全绿：测试只检查奶龙"发出了多少伤害"，没检查玩家"实际掉了多少血"。之后补上了看最终结果的测试（例如 `attack_delivery_test`），这里再保证它们每次都会被跑到。在旧的连击间隔上运行，`attack_delivery_test` 会直接失败并指出"喷吐三发只打中两发"。
