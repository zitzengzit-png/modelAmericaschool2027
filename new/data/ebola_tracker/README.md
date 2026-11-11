# Ebola Tracker 数据源（2026-11-11 快照）

本目录是 Problem A 重建的**新数据源**。`ws/new/code/load_data.m` 会自动
选择文件名中日期最大的快照。

旧代码仍读 `ws/old/data/outbreak_data.xlsx`（W25–W41，7 省），已冻结；
2026-11-08 及更早的 tracker 文件归档在 `ws/old/data/ebola_tracker/`。

## 来源

- 数据页：<https://ebola-tracker.org/en/database/>
- 原始 CSV：<https://ebola-tracker.org/data/ebola-drc-database.csv>
- 原始 JSON：<https://ebola-tracker.org/data/ebola-drc-database.json>
- 字段字典：<https://ebola-tracker.org/data/ebola-drc-database-dictionary.csv>
- 最新 SitRep：**N°179，2026-11-09**（2026-11-11 访问）
- 许可：**CC BY 4.0**（credit: Ebola Tracker；INSP 公报仍受 INSP 条款约束）

## 2026-11-11 快照（最新日 2026-11-09）

| 项目 | 数值 |
|---|---|
| 最新日 | 2026-11-09 |
| 累计确诊 | 11,042 |
| 累计死亡 | 5,387 |
| CFR | 48.8% |
| 累计康复 | 2,990 |
| ETC 住院 | 904（最新日）；W45 周日锚点为 882 |
| 省 / 卫生区 | 8 / 67（59 个有人口） |
| 周锚点 | W25–W45（21 个完整周日） |
| W45 锚点 | 2026-11-08：10,990 / 5,354 |
| 页面指标 | alerts 27,585；positivity 12.6%；contacts seen 79.3%；12 patients/100 beds；vaccinated 21,866；screened 276,403 |

## 本目录文件（由刷新脚本生成，不要手改）

- `ebola-drc-database-20261111.csv`：原始库，9,228 行（国家/省/区三级）；
- `ebola-drc-database-dictionary-20261111.csv`：字段字典；
- `national_weekly_20261111.csv`：21 个周锚点，W25–W45；
- `province_latest_20261111.csv`：8 省，截至 2026-11-09；
- `health_zone_latest_20261111.csv`：67 区，截至 2026-11-09；
- `response_latest_20261111.csv`：页面六项指标，截至 2026-11-11；
- `snapshot_metadata_20261111.json`：构建元数据与最新日行。

共享输入（最新可用，复制到本目录）：

- `cross_border_latest_20261108.csv`：肯尼亚 9、尼日利亚 1、乌干达 20、法国 1；
- `legacy_weekly_supplement_W29-W41.csv`：医护、床位、在隔序列；
- `zone_summary_to_20261025.csv`：66 个卫生区人口（59 个有值）。

## 2026-11-08 快照（已归档到 old）

| 项目 | 数值 |
|---|---|
| 截至 | 2026-11-08 |
| 累计确诊 | 10,990 |
| 累计死亡 | 5,354 |
| CFR | 48.7% |
| 累计康复 | 2,951 |
| ETC 住院 | 966（页面）/ 155（数据库 `etc_admitted`） |
| 省 / 卫生区 | 8 / 67 |
| 最新 24 小时 | +70 例，+31 死 |

对应的原始库、周表、省表、区表、响应表都在
`ws/old/data/ebola_tracker/`，仅用于复现旧结果和对照两套序列。

## 周表构建规则

`build_tracker_snapshot.m` 的规则（已用 2026-11-08 原始库回算，
与旧 `national_weekly_20261108.csv` 逐位一致）：

1. **周锚点**：每个周日取“日期 ≤ 周日且病例/死亡均非空”的最后一条国家行；
2. **new_confirmed / new_deaths**：与上一个周锚点相减；
3. **new_confirmed_adj / new_deaths_adj**：对该周内每日 `new_*` 求和，
   剔除 `note` 含 `catch-up` 或 `harmonisation` 的行；
4. **只写完整周日**：最后一个完整周日之后的日度数据放在
   `snapshot_metadata` 的 `latest_daily`，不强行补成一周；
5. **省/区表**：取各自最新日期的行；区人口从 2026-10-25 汇总表按
   “省 + 卫生区”合并（59/66 有值）。

## 响应指标

六项指标来自数据页面（不是原始库）：

- `alerts_received`：最近 7 期公报收到的警报数；
- `test_positivity`：最近 7 期检测阳性率；
- `contacts_seen`：最近 7 期接触者随访率；
- `patients_per_100_beds`：每 100 张床位的患者数；
- `vaccinated_total`：累计接种人数；
- `travellers_screened`：最近一期筛查旅客数。

原始库没有 `travellers_screened`，且 `lab_samples` 多数日期为空，
因此页面指标优先，原始库只作兜底。

## 数据注意事项

- `recovered` 在 W25–W31 为空（W32 起才有 869）。`state_at` 按 0 处理
  并标记 `assumed_zero`，会抬高早期 `I`；早期 `R` 应作为情景假设。
- 旧代码的 `R0=360` 实际是 `etc_admitted`，不是累计康复。
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；W25 为 360，
  W45 为 882（11/09 为 904）。
- W30/W31 原始周新增含 catch-up（W30：839 vs 470）；W44 死亡含
  Ituri 校正（+346/−269）；周新增用 `new_*_adj`，累计水平用累计序列。
- 卫生区死亡合计 4,894 ≠ 国家 5,387；493 例死亡未分配到卫生区，
  区级只能建模病例。
- Nord-Ubangi 人口为 150 万估计，不是 WorldPop 分区和。
- 2026-10-25 的日度表、66 区汇总、旧 vs 新对比在 `ws/old/data/ebola_tracker/`，
  新代码不使用。

## 引用

Ebola Tracker (ebola-tracker.org), database of the Bundibugyo Ebola outbreak
in the DRC, based on the situation reports of the National Institute of Public
Health (INSP), accessed 11 Nov 2026. CC BY 4.0.
