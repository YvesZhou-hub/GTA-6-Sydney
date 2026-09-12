# 实测高程资料与离线工具

本目录提供下一阶段的**地形数据准备**。游戏尚未接入这些高程，现有道路、建筑、机场、入口和存档坐标均未改变；这不代表整个悉尼已经做到实测 1:1，也不提供建筑外立面或公共室内模型。

## 已实际取得的数据

[NSW Elevation Data Service](https://portal.spatial.nsw.gov.au/portal/home/item.html?id=437c0697e6524d8ebf10ad0d915bc219) 的 [Elevation Index API](https://portal.spatial.nsw.gov.au/server/rest/services/Hosted/Elevation_Index_Public/FeatureServer/0) 在 CBD、Manly 和 Sydney Airport 三个点均返回 SYDNEY、mapsheet 9130。其索引经纬范围约为 151.0–151.5°E、34.0–33.5°S，覆盖三个地点；这只是分区覆盖，不表示每个海面网格都有有效陆地高度。

实际下载 [Sydney-DEM-AHD_56_5m.zip](https://portal.spatial.nsw.gov.au/download/dem/56/Sydney-DEM-AHD_56_5m.zip)：153,867,492 bytes，SHA-256 `0b8773943d50eb3c1000c61da27a793538d398d1938ef34bf231b834b851cd14`。ZIP 内有 ASC、PRJ 和 `Eastern-DEM-AHD_56_5m_Metadata.html`，**没有 DSM 或建筑高度**。原始大包仅保存在本地忽略目录，未放进公开源码。

| 项目 | 包内原始元数据和网格 |
|---|---|
| 地表类型 | 裸地 DEM；混合 1 m、2 m LiDAR DEM 和 5 m 摄影测量 DEM，经 TIN 生成 |
| 栅格 | 5 m；9,452 列 × 11,247 行，北到南行序 |
| 投影 | EPSG:28356，GDA94 / MGA zone 56，单位米 |
| 垂直基准 | AHD71，使用当地 geoid model；不是椭球高 |
| 裸露地面标称精度 | 水平 ±1.25 m、垂直 ±0.9 m，95% 置信区间 |
| 数据采集日期 | 元数据写 `Varies`，需逐原始瓦片查日期；本包没有逐瓦片年份表 |
| 不能替代采集日期的时间 | 服务目录 2023 年 currency、2026 年 HTTP Last-Modified 均不能证明 2023/2026 年实测 |
| 其它限制 | 非水文强制 DEM；不是建筑 DSM，不应当作海底水深 |

三个已提取的 505 m 方窗各有 101 × 101 个真实源网格，没有生成填补值。这些窗口内均无 NoData。下表为指定经纬点所在源网格的高度，**不是测量控制点或机场公布标高**；坐标转换本身也有误差。

| 窗口 | 经度、纬度 | 中心源网格 AHD/m | 窗内最小–最大/m |
|---|---|---:|---:|
| Circular Quay | 151.210000, -33.860000 | 1.780 | 0.009–28.973 |
| Manly | 151.285000, -33.800000 | 3.370 | -0.530–23.203 |
| Sydney Airport | 151.176000, -33.947000 | 6.352 | 0.301–7.505 |

可分发小样在 [source/elevation-data](../source/elevation-data/)，许可和来源在 [provenance.json](../source/elevation-data/provenance.json)。三个窗口及出处合计不足 0.2 MB。

## 许可

以实际 ZIP **包内**元数据为准：CC BY 3.0 Australia，[许可原文](https://creativecommons.org/licenses/by/3.0/au/)。不要因其它 NSW 图层采用 CC BY 4.0 而替换本包许可。公开小样保留 `© Department Customer Service`、DCS Spatial Services 出处、2026-09-12 提取日期、下载 URL、许可 URL、原包 SHA 和裁切说明。其额外条款要求衍生产品注明提取日期，并在外部云平台保存 Spatial Services 的知识产权；小样保留该条款和署名，原始高度未变。

## 复现和查询

[tools/import_elevation.py](../tools/import_elevation.py) 仅离线读取 ASC/ZIP 和小样 JSON，不自动下载、不写入游戏资产。读取 ZIP 时完整遍历源行并由 `zipfile` 校验该 ASC 的 CRC，核对所有行/列数量，仅对选中窗口的值核对有限数值，记录整个输入文件 SHA；这不是对整幅约 790 MB ASCII 每个数值的语义验收。多窗口接口可一次读取提取多个窗口。错误行长、截断、越界和 NoData 会明确失败，不会默默返回 0 或补假高度。

无额外依赖的米制坐标查询：

```sh
python3 tools/import_elevation.py query source/elevation-data/manly.json \
  --easting 341244.1522066523 --northing 6258697.285379964
```

重现一个窗口；将 `SOURCE.zip` 换成已下载的上述官方原包：

```sh
python3 tools/import_elevation.py extract SOURCE.zip \
  --member Sydney-DEM-AHD_56_5m.asc --name manly --cells 101 \
  --easting 341244.1522066523 --northing 6258697.285379964 \
  --provenance source/elevation-data/provenance.json --output manly.json
```

经纬查询需另行安装 `pyproj`。转换使用 PROJ 的 EPSG 定义、`always_xy=True`、禁用 ballpark 转换，并记录实际选择的变换和标称精度。该变换精度是坐标操作的误差说明，不是测量精度，也不能消除 GDA94、GDA2020、WGS84 与不同观测年代的差异。没有 pyproj 时不以纬度比例冒充 EPSG 转换：

```sh
python3 tools/import_elevation.py query source/elevation-data/manly.json \
  --longitude 151.285 --latitude -33.8
```

默认查询源网格值；`--method bilinear` 明确启用四邻格插值，边缘邻格不足或触及 NoData 会拒绝。输出仍为源垂直基准下的高度；工具没有把 AHD 换成游戏 y（例如现有地面 y=4.5），也没有改变 `import_city.py` 的既有平面投影。

本轮独立检查为 [source/elevation_data_test.py](../source/elevation_data_test.py)：带 pyproj 运行 **20/20 PASS**，无需大包、网络或 Godot；不安装 pyproj 时 **19 项 PASS、1 项明确跳过**。它验证格式、边界、插值、空值、CRC/文件绑定、三地实际小样及地理转换，**不验证游戏地形、导航或全区建筑高度**。

## 其它官方路径及边界

- [City of Sydney Terrain contours](https://data.cityofsydney.nsw.gov.au/datasets/cityofsydney::terrain-contours/about)：[API](https://services1.arcgis.com/cNVyNtjGVZybOQWZ/arcgis/rest/services/Terrain_Contours/FeatureServer/0)，2020 年航空测量生成的 **1 m 等高距**，CC BY 4.0，建筑下地面由插值得到。1 m 等高距不等于 1 m 平面测量精度。适用于 City LGA，不覆盖 Manly 或全部机场。目录/图层实际可读；本次小范围完整曲线下载超时，未声称已取得可用全区副本。
- [GA 5 m DEM 2025 WCS](https://services.ga.gov.au/gis/services/DEM_LiDAR_5m_2025/MapServer/WCSServer?service=WCS&request=GetCapabilities)：公开 capability 明确 CC BY 4.0。名称带 2025，但数据描述为 **2001–2015 年 236 次 LiDAR 测量**合并的裸地 DEM。本次 capability/DescribeCoverage 成功，GetCoverage 小窗实际返回 HTTP 400，故尚不能替代已验证的 NSW ZIP 路径。
- [ELVIS](https://elevation.fsdf.org.au/) 与 [GA elevation 说明](https://www.ga.gov.au/scientific-topics/national-location-information/digital-elevation-data)：可继续按地区获取更细的 LiDAR/DEM 及逐瓦片日期，需确认具体调查的覆盖、许可、格式和点分类。本次没有取得悉尼可用的 DSM 或 LAZ 样本，不把目录中“有 LiDAR”写成已经有全区建筑高度。
- NSW SDT 的公开 I3S 服务中发现 CityWest reality meshes，但若干 item 的 `licenseInfo` 为空，已抽查的范围不等于 Sydney/Manly/airport 全区。`Building_N_Central` 实际范围仅约 9 × 9 m；不是城市建筑库。均未下载模型/纹理，也未批准进离线源码包。
- City of Sydney `FES2017 3D Building Model` Web Scene 可读，但实际指向的 SceneServer 在本次访问返回 `400 Invalid URL`，Web Scene 本身没有模型许可。[市府模型要求](https://www.cityofsydney.nsw.gov.au/design-codes-technical-specifications/requirements-scale-models) 提供的是申请人模型规范与 IDE 申请流程，不是开放再分发的全城模型下载。
- 官方 EPI “Height of Buildings” 是**规划限高**，不能替代楼宇实测高度。NSW RelativeHeight 查询只找到零散旧点，没有与全区 building footprints 一一对应的屋顶高度依据。本轮不据此覆写已知楼高。

下一步可将同一年代/投影的分类 LiDAR 或 DSM 与 DEM 配对，才计算缺失建筑的屋顶离地高度；必须排除树冠和屋顶设备、记录统计方法与年代，保留可信原有高度。现有 DEM 单独不能做这件事。

全区接入地形时，必须同时安排道路、广场、地基、公共入口、码头/桥的独立标高及存档迁移。平坦广场/跑道不能逐顶点盲从噪声地形；桥梁也不能投到桥下裸地。本轮没有实施这些运行时变更。

## 公共室内

室外点云不能补出室内。公开室内继续采用可核对的场馆资料：[SOH CMP 2017](https://www.sydneyoperahouse.com/about-us/how-we-work/strategies-and-action-plans/conservation-management-plan)、[Concert Hall 2024 技术规格](https://www.sydneyoperahouse.com/sites/default/files/collaborodam_assets/SOHVenueTechnicalSpecifications_ConcertHall202401.pdf)、[ICC 公开楼层图与虚拟导览](https://www.iccsydney.com/organisers/organiser-toolkit/floor-plans/)。它们可供理解和独立建模参考，本次未找到允许离线再分发的完整 IFC/Revit 场馆模型；公开能观看不等于原文件/纹理可随游戏分发。

[Google Map Tiles 政策](https://developers.google.com/maps/documentation/tile/policies) 限制离线使用及地理数据提取；[Cesium 内容使用指南](https://cesium.com/learn/ion/content-usage-and-attribution-guide/) 要求按具体内容条款使用。不能把 API 可访问或平台账号可观看，当作 Google/Cesium 三维瓦片离线再分发授权。本工具没有抓取这类模型。
