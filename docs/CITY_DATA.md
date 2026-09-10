# 城市数据、覆盖范围与精度

这一版用真实地图轮廓替换了随机街区。它仍不是全悉尼一比一数字孪生：地图定位、外形重建和测量精度是三件不同的事。普通建筑的窗格、层高和地形没有逐栋实测，不能把地图上的毫米级数字当成现实测量精度。

## 可复现的数据

`source/map-data/` 保留 OpenStreetMap 原始快照，`tools/import_city.py` 离线编译为 `game/assets/city_map.json`。源文件和改编数据库均随源码提供，适用 ODbL 1.0，署名为 © OpenStreetMap contributors。没有复制 Google 地图瓦片、街景照片或第三方城市模型。

| 范围 | 纬度区间 | 经度区间 | 快照日期 |
| --- | --- | --- | --- |
| CBD、Barangaroo、Darling Harbour、Darling Square | -33.892 至 -33.846 | 151.195 至 151.223 | 2026-09-10 |
| 海港大桥北岸、Milsons Point、North Sydney 部分 | -33.848 至 -33.833 | 151.196 至 151.233 | 2026-09-10 |
| Manly、Corso、Wharf 与海滩 | -33.806 至 -33.780 | 151.276 至 151.301 | 普通街区 2026-05-06；精细地标另取 2026-09-10 数据 |

Manly 普通街区来自后备服务较旧的快照，不能声称所有商户均为今天的状态。各次查询与实际数据基准时间保存在源 JSON 内。岸线覆盖 -33.895 至 -33.770、151.18 至 151.31；没有把整个海港误填成陆地。

编译数据库包含 15,508 个建筑轮廓或分体、19,680 条道路/轨道中心线记录、5,103 个命名地点、23 个海滩区域、847 个公园区域和 6,739 个树木定位点。这些是**地图记录数，不是精细建模建筑数，也不是全部可驾驶道路数**。其中 961 条道路/轨道记录带高架或非零层级等标签，普通地面道路渲染器会跳过这些记录，避免错误压平到街面。293 个父级轮廓已有 `building:part`，只在二维地图显示父轮廓，三维使用分体，避免把整片塔楼基座错误拉到楼顶。此规则依据 [OSM Simple 3D Buildings](https://wiki.openstreetmap.org/wiki/Simple_3D_Buildings)。

230 个记录有高度标签，其中至少 4 个明确写了估算；7,539 个仅有层数，需换算层高。其余采用明确标注的类型估算。地图标签自身也可能过时或错误，单有 `height` 不表示已独立测量。

坐标沿用项目原点：纬度 -33.86、经度 151.2105；X 向东、Z 向南，米制。全城共用这个固定投影，因此机场、大桥、歌剧院、CBD 与 Manly 不会各自重新缩放或随意平移。

## 标签驱动的普通屋顶

`tools/city_roofs.py` 从明确的 OSM `roof:shape` 标签生成 524 个坡顶：Manly 406 个、CBD 110 个、北岸 8 个；形状为四坡顶 `hipped` 280 个、双坡顶 `gabled` 212 个、单坡顶 `skillion` 29 个、锥形顶 `pyramidal` 3 个。未支持的屋顶类型没有据此重建。

只有 7 个带 `roof:height`，其余 517 个的屋顶升高根据轮廓宽度估算，并受建筑高度约束。标签高度本身也未经独立实测。屋脊默认沿轮廓最小旋转外接矩形的长轴；`roof:orientation=across` 会转为横向，`along` 保持长轴方向。当前 4 个显式方向标签均为 `along`；另有 8 个 `roof:direction` 方位标签，当前算法尚未使用。复杂轮廓的屋脊和坡面因此仍是近似，不能视作现场测绘结果。

屋顶三角形保留地图轮廓与院落洞口。有总高度标签时坡面置于该高度范围内；只有层数时，层高换算还需加上屋顶升高，并分别记录它来自标签还是估算。普通屋面使用着色几何及可用的材质/颜色标签，不是逐瓦建模或照片贴图。

## 按照片单独建模的区域

| 模型 | 依据与重建范围 |
| --- | --- |
| 海港大桥 | 双拱、桥塔、桁架、桥面、轨道、步道与可驾驶引桥；[参考](BRIDGE_REFERENCE.md) |
| 悉尼歌剧院 | 两组不等长屋顶、球面壳、肋骨、瓷砖、玻璃及台阶；[参考](OPERA_REFERENCE.md) |
| HSBC 所在 Tower One、Bank of China、W Sydney、The Exchange / 海底捞 | 不同的塔楼、网格、弧形和木格栅外立面；[参考](CITY_REFERENCE.md) |
| Westpac Place、Commonwealth Bank Place South / North | 当前总部地址，成组外形和楼顶；[参考](BANK_REFERENCE.md) |
| Quay Quarter Tower、Salesforce Tower | 分段错动体量、遮阳框、树状结构与电梯侧立面；[参考](QUAY_REFERENCE.md) |
| CyberCX 悉尼办公室所在 2 Market Street、Cloudflare 悉尼办公室所在 388 George Street | 玻璃塔楼、台阶式屋顶、凹入中庭、曲面裙楼和公共通廊；不是两家公司的悉尼总部或私人办公室内景；[参考](CYBER_REFERENCE.md) |
| Darling Square 12 家店面 | 逐店记录地址、门面朝向、照片证据与未核实部分；[参考](DARLING_SQUARE_REFERENCE.md) |
| Manly Wharf、Hotel Steyne、The Corso | 码头屋盖、真实院落、阳台、步行街和真实树位；[参考](MANLY_REFERENCE.md) |
| Barangaroo、Martin Place 北入口 | 地面出入口、扶梯和第一层地下门厅，可实际往返；[参考](METRO_REFERENCE.md) |
| ICC Sydney Convention Centre、Exhibition Centre、TikTok Entertainment Centre | 独立场馆外形、Convention 公共门厅及夹层、Exhibition 下层四展厅、Theatre 门厅与简化观众席/舞台；[参考](ICC_REFERENCE.md) |

Cyber 专项模型替换 6 个普通 OSM 体量：2 Market Street 的 `1521293802`、`335699164`、`335699165`、`1521293801`，以及 388 George Street 的 `386563854`、`386563852`。相邻 Hooker House 不在替换范围。公司官方地址和物业照片用于核对建筑身份；外立面没有添加未经照片支持的大型公司标志。CyberCX 的澳大利亚总部在墨尔本，这里是其 NSW 办公室。

ICC 三处场馆已通过 `game/scripts/icc_landmarks.gd` 纳入主世界，地图轮廓保存在 `game/assets/icc_geometry.json`。这里的 TikTok 名称指演出场馆，不是公司的办公室。公开平面图和照片支持所列公共区域的重建；整体高度、楼层标高、座椅数量与看台坡度仍有明确估算，未制作完整后台、机房或私人空间。范围与证据见 [ICC 参考说明](ICC_REFERENCE.md)。源码整合及回归结果不代表最终发行包已发布。

## 道路接缝与铺面校验

普通道路现在使用沿原中心线的连续平面路带，共享节点和转角补圆角；没有移动真实中心线或抬高地面来遮住缺口。机动车路面优先占用其轮廓，人行铺面在重合部分做几何相减，避免同一高度的两种材质互相闪烁。铺面裁边保留 2mm 数值容差，吸收公里级投影坐标的浮点误差；路面本身的宽度和高度不因此改变。地铁洞口对路带和新增连接面都真实裁切。

`source/road_join_test.gd` 的 17 项几何检查通过，包含最初 14 项接缝/洞口检查和新增 3 项跨材质覆盖检查。Fairy Bower Road 与 Darling 样本中复现的 131 + 185 个旧接缝采样点已全部覆盖；Darling 样本中两种铺面材质的三角形交叠面积、两处真实地铁洞口的路面侵入面积均为零。检查报告见 [道路几何结果](evidence/road-joins.json)。这些结果验证模型的覆盖与裁切，不是道路现场测绘精度，也不能代替原生画面的独立复核。

## 当前仍有的近似

- 普通街区使用地图轮廓和材质类别，窗格、雨檐等为推断，尚未逐店按照片复原；已完成表中银行和 CyberCX、Cloudflare 所在建筑，未覆盖所有公司或总部。
- 大部分地面仍为 4.5m 平坦游戏基准，未接入完整高程/激光雷达。山坡、复杂高架道路、全部轨道高差和完整城市地下网络未重建。
- 地铁模型只含明确记录的入口和第一层门厅，扶梯静止可行走，没有运营列车或完整站台。下降高度为估算。
- Manly 保留真实岸线、街道和所列地标；沙滩坡度、全部商店外立面、住宅屋顶与内部尚未一比一制作。
- Fairy Bower Road 回转端中央约 3.7m² 的未铺面区域，是由三条地图中心线及其 6.5m 宽度标签推导出的闭环内部空余地；[实际查看的卫星影像](https://www.google.com/maps/@-33.8027451,151.2907738,20z/data=!3m1!1e3)可见带树和浅色尖端的三角分隔区，支持保留中央岛。3.7m² 的精确边界和当前草地材质仍由道路缓冲推断，未经现场测绘；没有下载或分发卫星图像。
- 机场跑道位置和长度有公开数据；航站楼、周边岸线与机场至城区的中间走廊仍有简化，二维地图会用斜纹标明简化地形。
- 个人工作室、车库、部分船坞和可驾驶桥梁接地段是明确的游戏调整，不是现实设施的完整复原。

## 离线重建与校验

```sh
python3 -m venv tools/map-runtime
tools/map-runtime/bin/pip install shapely==2.1.2
tools/map-runtime/bin/python tools/import_city.py
tools/map-runtime/bin/python source/test_city_data.py
```

默认使用已提交快照，不会在玩家启动时联网。校验覆盖建筑及院落的三角形面积、坡顶投影面积和高度范围、关键陆地/水域位置、原始轮廓投影一致性、地下路线过滤和两个地铁洞口；地形、道路、公园都必须真正让出洞口。
