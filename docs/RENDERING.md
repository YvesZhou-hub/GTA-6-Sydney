# 晴日光照、水面与画质档位

渲染使用 CC0 天空 HDRI、方向一致的定向光和 ACES 色调映射。静态日间基准与原图太阳方向对齐，时间循环则按主时钟移动太阳。天空是艺术照明参考，不是悉尼实景摄影；来源、作者和文件摘要见[环境许可](../licenses/DAYLIGHT_ENVIRONMENT.md)。既有海面几何范围和波高保持不变。

## 三档画质

| 功能 | 轻盈 0 | 标准 1 | 精细 2 |
|---|---|---|---|
| HDR 天空与 ACES | 保留 | 保留 | 保留 |
| 实时阴影 | 关闭 | 主场景 350 m | 主场景 700 m |
| SSAO 接触层次 | 关闭 | 开启 | 开启 |
| 高亮 Glow | 关闭 | 强度 0.20 | 强度 0.27 |
| 屏幕空间反射 SSR | 关闭 | 关闭 | 64 步上限 |
| 全局体积雾 | 默认关闭 | 默认关闭 | 默认关闭，可显式试用 |

静态日间基准曝光为 1.0；开启时间循环后曝光、环境补光与太阳能量依时段变化。颜色对比度为 1.03、饱和度为 1.05。泛光的普通 Bloom 项为 0，HDR 阈值为 1.6，避免白墙与整片天空泛白。画质只在环境初始化或用户切换菜单时应用，不根据当前帧率反复切换 SSR。

SSAO、SSR 和体积雾要求 Forward+。SSR 只能反射当前屏幕可见信息；画面外、被遮住的物体不会因此产生完整倒影，环境天空反射提供剩余部分。它不是光线追踪或全场景反射。[Godot 4.7 后处理说明](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)

体积雾可通过 `apply_quality(env, 2, {"volumetric_fog": true})` 诊断试用，密度 0.0001、范围 128 m，默认产品档位不启用。其时域重投影可能使快速移动或短暂灯光产生拖影；短暂爆闪灯若与体积雾合用，应将该灯的 `light_volumetric_fog_energy` 设为 0。[Environment 与体积雾属性](https://docs.godotengine.org/en/4.7/classes/class_environment.html#class-environment-property-volumetric-fog-temporal-reprojection-enabled)

## 海面

实际 shader 为 `game/shaders/water.gdshader`，由 `harbor_world.gd` 的共享水材质使用。它保持不透明通道，以便写入深度并使用 Forward+ SSR；没有把海面改成透明屏幕贴图。Godot 的透明管线有排序和屏幕读取限制。[空间 shader 说明](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)

新表面采用非金属材质，保留深蓝绿色水体。原有三个长波分量总振幅上限仍为 0.455 m，各块海面使用同一世界坐标相位。近处使用三层不同方向、尺度与流速的连续噪声解析梯度，替换易形成长条纹的细波正弦；按每像素覆盖范围过滤，远处逐渐提高粗糙度。两处地铁入口的海面排除矩形保持原协议。

这些是程序水面与游戏颜色，不是现场水深、潮汐、风场或流体模拟。本轮没有新增水下折射、海底透视或物理焦散。表面法线扰动会影响反射和高光；载具原有浮力与水面碰撞逻辑未由此改变。

## 可重复诊断

`daylight_environment.gd` 提供 `quality_profile()`、`apply_quality()`、`apply_tuning()` 与 `runtime_parameters()`。`apply_tuning()` 仅接受已列出的有限数值，夹紧到允许范围并忽略 NaN、未知字段；不会悄悄切换渲染器或昂贵效果开关。

| 环境数值 | 默认或档位值 | 诊断允许范围 |
|---|---:|---:|
| `tonemap_exposure` | 1.0 | 0.5–1.5 |
| `ambient_light_energy` | 0.6 | 0.2–1.0 |
| `adjustment_contrast` | 1.03 | 0.9–1.15 |
| `adjustment_saturation` | 1.05 | 0.8–1.2 |
| `ssao_radius` | 0.95 m | 0.25–2.0 |
| `ssao_intensity` / `ssao_power` | 0.9 / 1.3 | 0–1.5 / 0.8–2.0 |
| `glow_intensity` | 0.20 / 0.27 | 0–0.6 |
| `glow_hdr_threshold` / `glow_hdr_scale` | 1.6 / 0.8 | 1–4 / 0.1–3 |
| `ssr_max_steps` | 64 | 16–96 |
| `ssr_depth_tolerance` | 0.25 m | 0.05–1.0 |
| `fog_density` | 0.000025 | 0–0.0001 |
| `volumetric_fog_density` / `volumetric_fog_length` | 0.0001 / 128 m | 0–0.001 / 32–256 |

水材质可以直接通过 `ShaderMaterial.set_shader_parameter` 调整：

| 水面 uniform | 默认 | Inspector 建议范围 |
|---|---:|---:|
| `wave_scale` | 1.0 | 0–2 |
| `normal_strength` | 0.60 | 0–2 |
| `ripple_strength` | 0.095 | 0–0.3 |
| `base_roughness` | 0.19 | 0.06–0.45 |
| `specular_strength` | 0.35 | 0.2–0.6 |
| `tint_variation` | 0.12 | 0–0.3 |
| `time_override` | −1，使用实时 TIME | 非负值固定波纹时刻，供 A/B |

Inspector 范围是调参提示，并非所有 shader 数值都有运行时自动夹紧。诊断结束应恢复 `time_override=-1`。`deep_color`、`crest_color` 是色彩输入；`dry_rect_a/b` 属于地铁净空协议，不应用作外观调参。

## 验证边界

`source/render_environment_test.gd` 当前 **31 / 31 headless** 通过，覆盖渲染档位与兼容分支、HDR 来源与太阳对齐、有限调参、既有波高和入口排除协议。该结果检查资源属性和源代码合同，不表示 GPU 已正确编译、SSR 已肉眼合格或全城达到某个帧率。

该脚本的 `--capture` 模式构建小型水边柱廊、颜色面板、不同粗糙度球体和发光物的校准场景，使用固定相机与同一波纹时刻比较旧版、标准、精细和可选薄雾。开发证据保存在 `reports/render-environment`，原生图需要实际审阅；校准场景不充当真实悉尼或最终发布截图。最终全城与应用验证由发布测试文档记录。

```sh
tools/runtime/godot --headless --path game --script ../source/render_environment_test.gd
# 由统一 GPU 验收时段执行；需要 ignored reports 中保留的基线文件。
tools/runtime/godot --path game --script ../source/render_environment_test.gd -- --capture
```

## 悉尼夏季时间循环

`apply_cycle(env, sun, state)` 接收主时钟提供的 `hour`、`elevation_deg`、`sun_direction`、`night_factor`、`sunrise_hour` 与 `sunset_hour`。主时钟负责悉尼夏季平均日出、日落和太阳运动；本模块负责连续照明、天空、环境反射和雾色。没有把天空照片的地理位置当作悉尼太阳观测。

新加入 Poly Haven 的 Qwantani Sunset 与 Qwantani Night 两张 2048 × 1024 CC0 原始 HDR，与原有白天天空平滑混合。照片中的固定太阳核心在 shader 中被弱化，另用主时钟方向绘制太阳圆盘并驱动同方向阴影光。日出与日落依太阳高度出现橙金与偏粉的云层过渡；夜空归一降低原始长曝光亮度，不生成虚构月亮，也不让地下太阳照亮夜景。天空与反射立方体使用同一 shader；新增作者、字节数、摘要及实际查看记录见[时间循环素材许可](../licenses/DAYLIGHT_CYCLE.md)和[机器可读素材清单](../game/assets/environment/sky_sources.json)。

暮光 HDR 先做亮度软压缩，再按朝向和云层局部着暖色，避免整片天空被乘成粉色或进入曝光肩部。夜间增加低亮度、偏蓝的城市天光底值；它同时进入天空、环境补光和水面反射，不通过水面自发光或虚构月亮提亮。此底值是游戏可读性处理，不是悉尼实测夜空亮度。

天空材质另公开 `twilight_radiance_limit`（默认 0.65）、`night_gain`（0.07）和线性颜色 `night_airglow`（0.028、0.046、0.075），可用于固定机位诊断。`sunset_tint` / `sunset_gain` 则由时间 profile 管理，不应把临时绝对值当作持久调参。夜间天光和暮光压缩没有切换任何昂贵渲染功能。

太阳与环境数值随时钟连续更新。天空使用 256 像素、增量处理的反射立方体，自然循环最多每 500 ms 更新一次 shader 参数，避免以每帧时钟刷新高成本环境贴图。显式菜单跳时、读档和初始化通过 `force_sky: true` 即时刷新，暂停状态下也生效。没有在循环内反复打开或关闭 SSAO、SSR、Glow。[Godot Sky 更新机制](https://docs.godotengine.org/en/4.7/classes/class_sky.html#enum-sky-processmode)

诊断面板采用相对时段的调参合同：`cycle_base_values` 提供 `exposure`、`ambient`、`sun_energy`、`fog_density`、`fog_light_energy`、`glow_intensity`、`ssao_intensity` 七个基准值；`cycle_tuning_multipliers` 保存用户乘数。推进时间不会把乘数覆盖掉；零太阳基准乘任何系数仍为零。最终夹紧范围分别为 0.1–3、0–2、0–4、0–0.002、0–2、0–2、0–4。

`source/daylight_cycle_test.gd` 当前 **22 / 22 headless** 通过，包括方向一致、不同日照时段、夜间零直射太阳、120 次快速更新的立方体节流、暂停跳时与同小时强制刷新、诊断乘数跨时间保留及安全范围。此夹具使用合成太阳输入检验渲染 API，不替代主时钟的天文校准测试。其 `--capture` 模式生成 12 张固定机位校准图，并测量天空广域白截断比例和夜水亮度；这些门槛只抓明显失效，不能替代实看。第一轮原生属性检查通过但审图发现暮光过曝、全局偏粉与夜水过暗，因此没有作为外观合格证据；最终第三轮原生 **42 / 42** 通过，12 张小型校准图均逐张复看：大面积过曝、全局粉色、旧太阳残环和规则细波条带已消除，夜水可辨。记录在 ignored `reports/daylight-cycle/visual-review.json`，含原图 SHA 和源代码绑定；这仍不是完整城市或最终应用验收。

```sh
tools/runtime/godot --headless --path game --script ../source/daylight_cycle_test.gd
# 仅在统一 GPU 时段运行：
tools/runtime/godot --path game --script ../source/daylight_cycle_test.gd -- --capture
```
