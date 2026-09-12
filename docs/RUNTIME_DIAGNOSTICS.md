# F3 运行诊断与实时画面调节

按 **F3** 打开面板。主程序暂停角色/物理并释放鼠标；画面继续渲染。调整数值立即生效，关闭面板继续驾驶。面板不单独改变全局暂停状态，也不处理战斗输入；主程序使用 `toggled(opened)` 钩子处理这些状态，防止拖动滑条时瞄准或开火。

## 指标从哪里来

`RuntimeDiagnostics.snapshot()` 返回实际 Godot `Performance.get_monitor()` 数据：FPS、帧处理及物理处理秒数、节点/对象/资源数量、渲染对象、draw calls、primitives、显存/贴图/缓冲区内存、静态内存、活跃刚体、碰撞对、物理岛和五种管线编译计数。面板把处理时间换算为毫秒。

这些值与编辑器 **Debugger → Monitors** 使用相同来源。部分监视器最多延迟约一秒；primitives 包含阴影等绘制遍数，不能作为原创模型三角形数。静态内存在 release 构建不可用；headless 无有效渲染数据。面板明确标出这些限制，不把未提供的 GPU 耗时、瓦片统计或显存读数冒充零消耗。[Godot Performance 文档](https://docs.godotengine.org/en/stable/classes/class_performance.html)

同时展示生产世界的已注册结构、仍在注册表中的已破坏结构、破坏历史 ID 数、建筑网格批次/单元、玩家世界坐标、全部载具数量、实际弹药/爆炸池，以及最近生成的模型构建/占用缓存/净空搜索耗时。建筑批次数专指世界 `_visual_cells` 中实际有网格的主建筑/细节 Mesh，不等于所有渲染 draw calls。若世界提供 `streaming_stats()`，原样保留其近距离立面作用范围、驻留/上限、构建与上传时间及基础碰撞仍驻留的标记；没有接口时显示不可用。

管线编译读数是 Godot 本身的累计监视器，不能直接套用外部 Babylon.js 8.56 案例的 shader variant 机制。某次生成变慢究竟来自模型、空间占用缓存、搜索、上传还是管线编译，需要对照实际阶段计时；单次耗时不证明是着色器卡顿。Godot 的 CPU 渲染准备计时与 GPU 耗时也不同。[RenderingServer 文档](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)

## 可调数值与恢复

`tune(Dictionary)` 只接受以下有限数值，超界会夹到范围并在结果中列出；未知键、布尔值、字符串、NaN、Infinity 被拒绝。混合请求会应用合法项，同时在 `rejected` 中列出无效项。不会切换透明、阴影、雾、SSAO、SSR、辉光等结构/功能开关，不会重建网格或材质资源。

| 键 | 范围 | 实际目标 |
| --- | --- | --- |
| exposure | 0.10–3.0 | Environment.tonemap_exposure |
| ambient | 0–2.0 | Environment.ambient_light_energy |
| sun_energy | 0–4.0 | 原 DirectionalLight3D.light_energy |
| fog_density | 0–0.002 | Environment.fog_density |
| fog_light_energy | 0–2.0 | Environment.fog_light_energy |
| glow_intensity | 0–2.0 | Environment.glow_intensity |
| ssao_intensity | 0–4.0 | Environment.ssao_intensity |
| glass_roughness | 0–1.0 | 材质角色 glass 的 roughness |
| glass_metallic | 0–1.0 | 材质角色 glass 的 metallic |

未启用的效果在面板中显示“关”，滑条不偷偷打开该效果。玻璃同时通过 `material_roles` 覆盖已登记地标材质与普通城市立面 Shader 的玻璃参数。未统一调整时显示“按各材质”，不虚构一个共同初值；恢复使用角色的逐资源快照，保留不同玻璃原本的数值，以及 Shader 的原始 null/default 状态。调节期间后来流入的材质也恢复其原始属性。[Environment 文档](https://docs.godotengine.org/en/stable/classes/class_environment.html)

昼夜系统通过 Environment metadata 提供 `cycle_base_values` 和 `cycle_tuning_multipliers`。滑条使用绝对值，内部记录相对当前时刻基准的乘数；时间推进后继续保留调整比例。夜间某项基准为零时不允许通过乘数凭空创建阳光，面板会解释并禁用该项。内部乘数限制在 0–100，昼夜应用端仍夹紧最终参数。恢复会清除乘数并使用当前时刻基准，避免恢复成过去中午的亮度。没有昼夜基准时则恢复本次环境的精确初值。

数值同步到主程序内存中的 `settings.render_tuning`；昼夜乘数独立放在 `settings.cycle_tuning`，旧绝对值偏好可迁移。即使诊断先于第一次昼夜初始化，已保存的合法乘数也会保留；在初始化前点恢复可取消这些乘数。不存在的太阳节点不会接受调节，也不会把被拒绝的数值偷偷存成乘数。模块不直接读写设置文件或玩家存档，持久化由主程序现有显式保存设置流程负责。

快照的 `city_clock` 同时提供真实时钟状态和太阳状态：时刻、倍速、运行状态、日出/日落、太阳高度、夜间权重及三元素数组形式的太阳方向。F3 显示当前悉尼夏季时间和速率；T 面板由主程序提供，用于拖动时间、选择日出/日落等时刻、定格和改变倍速。

## 开发接口与 Remote Inspector

自动加载节点 `/root/RuntimeDiagnostics` 提供：`setup(game)`、`snapshot()`、`limits()`、`values()`、`tune(changes)` 和 `reset_tuning()`。读取和调整都在本地执行，不启动 HTTP、WebSocket 或其他网络服务器。

从编辑器启动游戏后，在 **Remote** 场景树选择该节点：

- `inspector_snapshot` 显示最近一次真实快照，含采样时间。F3 打开期间每半秒更新，关闭后不做后台轮询。
- 勾选 `refresh_inspector` 可获取新快照，该操作字段立即回到 false。
- 编辑 `inspector_tune_request`，例如 `{ "exposure": 1.15, "glass_roughness": 0.25 }`，再勾选 `apply_inspector_tuning`。`inspector_tune_result` 显示实际应用、夹紧和拒绝项。
- 勾选 `reset_inspector_tuning` 恢复原始数值/当前昼夜基准。

F3 面板 `setup(game,singleton)`、`toggle()`、`close()` 和 `toggled(bool)` 不依赖外部调试连接。关闭后停止面板 `_process`；诊断自动加载本身不逐帧扫描城市、不同步读回 GPU、不强制渲染。

## 验证范围

`source/runtime_diagnostics_test.gd` 的 84 项隔离 headless 检查已通过：真实引擎计数、可用性标记、缺失/已释放世界、有限数值验证、精准恢复、阳光、普通城市 Shader 与异质玻璃及后来注册材质、实时 Control 滑条回调、Remote Inspector 操作、昼夜 metadata 合约与偏好迁移。还直接调用生产 Daylight 资源检查白天/日落/夜间变化和恢复，并核对真实 CityClock 状态的 JSON 表达；不把这些测试说成原生画面验收。

`game/scripts/diagnostics_validation.gd` 提供 `run(game)`，供主程序 `--diagnostics-qa` 启动。它用 Viewport 真实 GUI 事件路由操作 F3/T、鼠标拖动/滚轮、下拉选单与按钮，核验鼠标和暂停归属、武器隔离、倍率保留及恢复。自动时钟在 QA 中关闭，停止/恢复检查使用显式的 0.25 秒生产时钟更新。原生捕获先等待当前视角的立面加载稳定；其按键事件由引擎注入，不声称模拟了操作系统硬件输入。该整合夹具的实际运行结果单独记录，不能从源码存在推定通过。

该整合夹具在原生模式还会先执行两次真实 `request_vehicle("tank")`，把每次模型/占用缓存/净空/总耗时，以及前后六个绘制帧采样的 draw、mesh、surface 管线累计计数写入 `spawn_profiles`。新副本保留并冻结，随后恢复原来的 QA 驾驶车辆。计数变化与阶段耗时只用于定位线索，不把重合时间直接归因为 shader，不使用固定步进帧率宣称实际性能。

结果和对应源码 SHA256 位于 `reports/runtime-diagnostics/checks.json`，该报告不把 headless 控件测试称为原生视觉通过。

首轮完整原生 GUI 运行有 43 项检查，其中 42 项通过，唯一失败是 QA 对顶部关闭按钮要求额外 4 像素边距，导致没有实际发出点击。已在局部生产面板复现并修正测试可见性判定，真实滚轮到顶部、点击关闭新增回归通过；产品关闭行为未改。4 张原生截图均已实际查看，修正后的完整原生结果由后续报告记录。
