# new/data：新题数据（active = tracker）

## 1. 当前数据源：`ebola_tracker/`（2026-11-11）

`ws/new/code/load_data.m` 默认读取这里最新日期的快照：

- 最新日 2026-11-09：**11,042 例 / 5,387 死**（SitRep 179）；
- 周锚点 W25–W45；W45（2026-11-08）为 10,990 / 5,354；
- 8 个省（含 Nord-Ubangi），67 个卫生区；
- 总人口 `N = 38,393,224`；
- 拟合 W25–W43，验证 W44–W45；
- 快照由 `ws/new/code/refresh_tracker_data.m` 生成。

## 2. 目录中的文件

```text
new/data/ebola_tracker/
├── ebola-drc-database-20261111.csv              原始库（9,228 行）
├── ebola-drc-database-dictionary-20261111.csv   字段字典
├── national_weekly_20261111.csv                 W25–W45 周锚点
├── province_latest_20261111.csv                 8 省，2026-11-09
├── health_zone_latest_20261111.csv              67 区，2026-11-09
├── response_latest_20261111.csv                 页面六项指标，2026-11-11
├── snapshot_metadata_20261111.json              构建元数据
├── cross_border_latest_20261108.csv             跨境（最新可用）
├── legacy_weekly_supplement_W29-W41.csv         HCW/床位序列（最新可用）
├── zone_summary_to_20261025.csv                 区人口（59/66）
└── README.md                                    详细说明
```

> `cross_border`、`legacy_weekly_supplement`、`zone_summary` 这三份是
> 目前最新的可用输入，所以复制到了新数据目录；其余 2026-11-08 及更早
> 的 tracker 文件在 `ws/old/data/ebola_tracker/` 归档。

## 3. 旧数据（只读）

- 旧工作簿：`ws/old/data/outbreak_data.xlsx`（W25–W41，7 省，9,066/4,381）；
- 旧 tracker 归档：`ws/old/data/ebola_tracker/`（2026-11-08 及更早）。

旧代码 `ws/old/code/matlab` 仍使用旧工作簿；新代码使用本目录的 tracker。

## 4. 两套序列不能混用

| 序列 | W25 | 口径 |
|---|---|---|
| 旧工作簿 | 1,193 / 535 | WHO AFRO 回顾 |
| tracker | 1,048 / 267 | INSP 日度汇总 |

不要把 tracker 的累计值减去旧工作簿的周新增，也不要把两套 W25 锚点
拼在一起。

## 5. 关键数据口径提醒

- `recovered` 在 W25–W31 为空（W32 起才有 869）；重建状态时按 0 处理
  并标记 `assumed_zero`，会抬高早期 `I`。
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；W25 为 360，
  W45 为 882（11/09 为 904）。
- W30/W31 原始周新增含 catch-up（W30：839 vs 470）；W44 死亡含 Ituri
  校正；周新增用 `new_*_adj`。
- 卫生区死亡合计 4,894 ≠ 国家 5,387；493 例未分配。
- Nord-Ubangi 人口为 150 万估计。

更细的来源、抓取规则和字段说明见 `ebola_tracker/README.md`。
