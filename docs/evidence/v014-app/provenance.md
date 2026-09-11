# 公开证据中的路径

JSON 数值、检查结果、源码及图片 SHA256 保持原值。公开副本将本机绝对路径归一化为 `${PROJECT}`、`${APP}`、`${USER_DATA}`、`${HOME}` 和 `${QA_TMP}`；原始日志留在本机报告目录。

这些路径标记用于公开阅读，不能直接作为本机文件路径执行。复现时请重新构建，使用生成的 `reports/release-v014-native/build.json`。场景截图没有修改；每张图片的散列与独立视觉复核见 `screenshots.json` 和各项 `visual-review.json`。

五组最终导出 App 验证、原生图形镜头夹具、局部组件夹具和未完成的候选包 OS 输入尝试分别记录，不能互相替代。`candidate-os-input-attempt.json` 属于早期候选包，只说明当时的桌面工具限制，没有计入最终通过检查。
