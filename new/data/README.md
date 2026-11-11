# new/data：新题数据（日尺度，active = tracker）

## 1. 当前数据源：`ebola_tracker/`（2026-11-11）

`ws/new/code/load_data.m` 默认读取这里最新日期的快照：

- 日序列：2026-06-21 至 2026-11-09，共 **142 天**；
- 最新日 2026-11-09：**11,042 例 / 5,387 死**（SitRep 179）；
- 8 个省（含 Nord-Ubangi），67 个卫生区；
- 总人口 `N = 38,393,224`；
- 拟合：2026-06-21 至 2026-10-25；
- 验证：2026-10-26 至 2026-11-09；
- 日表、周表、省日表都由 `ws/new/code/refresh_tracker_data.m` 生成。

## 2. 目录中的文件

```text
new/data/ebola_tracker/
├── ebola-drc-database-20261111.csv              原始库（9,228 行）
├── ebola-drc-database-dictionary-20261111.csv   字段字典
├── national_daily_20261111.csv                  **日表（主数据）**
├── province_daily_20261111.csv                  省 × 日表
├── national_weekly_20261111.csv                 周表（仅聚合校验）
├── province_latest_20261111.csv                 8 省，2026-11-09
├── health_zone_latest_20261111.csv              67 区，2026-11-09
├── response_latest_20261111.csv                 页面六项指标，2026-11-11
├── snapshot_metadata_20261111.json              构建元数据
├── cross_border_latest_20261108.csv             跨境（最新可用）
├── legacy_weekly_supplement_W29-W41.csv         HCW/床位序列（最新可用）
├── zone_summary_to_20261025.csv                 区人口（59/66）
└── README.md                                    详细说明
```

> `cross_border`、`legacy_weekly_supplement`、`zone_summary` 三份是目前
> 最新的可用输入，所以复制到了新数据目录；2026-11-08 及更早的 tracker
> 文件在 `ws/old/data/ebola_tracker/` 归档。

## 3. 日表字段

`national_daily_20261111.csv`：

- `date`、`t_day`（以 2026-06-21 为 0）；
- `cum_confirmed`、`cum_deaths`；
- `new_confirmed`、`new_deaths`（日差分）；
- `new_confirmed_7d`、`new_deaths_7d`（7 日滑动均值，状态重建用）；
- `recovered`、`etc_admitted`；
- `community_deaths`、`etc_deaths`；
- `alerts_received`、`lab_samples`、`lab_positives`；
- `contacts_to_follow`、`contacts_seen`；
- `vaccinated_total`；
- `sitrep`、`note`、`flag`。

`flag` 可能包含：

- `observed`：当日有公报行；
- `missing_day_locf`：当日缺报，累计值沿用上一天；
- `special_report`：catch-up / harmonisation；
- `negative_revision`：当日累计值被下调。

## 4. 旧数据（只读）

- 旧工作簿：`ws/old/data/outbreak_data.xlsx`（W25–W41，7 省，9,066/4,381）；
- 旧 tracker 归档：`ws/old/data/ebola_tracker/`（2026-11-08 及更早）。

旧代码 `ws/old/code/matlab` 仍使用旧工作簿；新代码使用本目录的日表。

## 5. 两套序列不能混用

| 序列 | W25 | 口径 |
|---|---|---|
| 旧工作簿 | 1,193 / 535 | WHO AFRO 回顾 |
| tracker | 1,048 / 267 | INSP 日度汇总 |

不要把 tracker 的累计值减去旧工作簿的周新增，也不要把两套 W25 锚点
拼在一起。

## 6. 日尺度关键数据提醒

- 日表有 4 个缺失日（6/26、7/16、7/28、7/29），累计值按 LOCF 补；
- 7/22、7/30 是 catch-up，10/30–31 是 harmonisation，日表用 flag 标记；
- `recovered` 在 W25–W31 为空（W32 起才有 869），`R=0` 是假设，
  会抬高早期 `I`；
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；W25 为 360，
  W45 为 882（11/09 为 904）；
- 卫生区死亡合计 4,894 ≠ 国家 5,387；493 例未分配；
- Nord-Ubangi 人口为 150 万估计。

更细的来源、抓取规则和字段说明见 `ebola_tracker/README.md`。
