# 每个 PR 自动跑的回归检查

每次开 PR、每次往 `main` 推送，GitHub 都会自动把回归检查跑一遍。结果显示在 PR 页面底部；有没过的检查时，运行页面的摘要里会列出是哪一项、第一条出错信息是什么，完整日志可以在运行页面下载（保留 14 天）。

## 跑什么

清单只有一份：[`tools/checks.json`](../tools/checks.json)。

- **81 个源码测试**：战斗、敌人、生存、载具、地标、交通规则、加载界面等，每个都用真实的游戏脚本。
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

`tools/checks.json` 的 `not_run` 里逐条写了原因，分四类：

| 原因 | 检查 |
| --- | --- |
| 在没改动的 `main` 上也失败，需要单独处理 | `bridge_drive_test`、`world_road_probe`、`vehicle_spawn_test`、`experience_flow_test`、`combat_vehicle_state_test` |
| 一项就要 7 分钟以上 | `survival_boost_test`、`vehicle_boost_test`、`vehicle_speed_test` |
| 需要真实窗口或声音 | `camera_motion_test`、`ui_font_test`、`roof_visual_check`、`world_visual_probe`、`audio_shutdown_test`、HUD 检查（`--hud-qa`） |
| 只是测量数据，没有对错 | `encounter_baseline`、`world_physics_probe`、`world_winding_check` |

需要真实窗口的检查（HUD、街上人车的帧时间、截图）仍在发布前用打好的 App 在 Mac 上跑，见 [验证记录](TESTING.md)。

## 和发布检查的关系

`windows-package-check.yml` 是发布时手动触发的：打 Windows 包、解压后运行、上传到发布页。这里的回归检查不打包，只保证每次改动合进 `main` 之前，已有的测试都还是绿的。

## 为什么要加

v0.5.0 的评审发现，连击伤害被玩家的受伤保护吞掉了一半，但当时的测试全绿：测试只检查奶龙"发出了多少伤害"，没检查玩家"实际掉了多少血"。之后补上了看最终结果的测试（例如 `attack_delivery_test`），这里再保证它们每次都会被跑到。在旧的连击间隔上运行，`attack_delivery_test` 会直接失败并指出"喷吐三发只打中两发"。
