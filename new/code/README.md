# new/code：P0 日尺度数据与配置层

本目录是 Problem A 重建的新代码。旧代码在 `ws/old/code/matlab`，已冻结，不要修改。

## 状态

**P0（日尺度数据与配置）已完成（2026-11-11）。**

- 日序列：2026-06-21 至 2026-11-09，共 **142 天**；
- 最新日 2026-11-09：11,042 / 5,387；
- 拟合：2026-06-21 至 2026-10-25（127 天）；
- 验证：2026-10-26 至 2026-11-09（15 天）；
- 8 省、67 区、`N = 38,393,224`；
- 验收 **12/12 全部通过**。

## 文件清单

| 文件 | 作用 |
|---|---|
| `config.m` | 唯一配置入口：数据源、日尺度窗口、日速率、路径 |
| `load_data.m` | 优先读日表；保留周表做聚合校验；8 省/67 区；响应、跨境、HCW |
| `state_at.m` | 分派器：有 `data.daily` 用日重建，否则用旧周重建 |
| `state_at_day.m` | **日尺度**重建 `[S;E;I;Q;R;D;M]`，带来源标记 |
| `state_at_week.m` | 旧周尺度重建（legacy 回归专用） |
| `build_tracker_snapshot.m` | 原始 CSV → 日表、周表、省日表、区快照、响应表 |
| `refresh_tracker_data.m` | 下载原始库 + 字典 + 页面指标，并重建快照 |
| `fetch_response_page.m` | 解析数据页面六项响应指标 |
| `latest_tracker_file.m` | 按文件名中的 8 位日期选最新快照 |
| `p0_check.m` | P0 验收：日锚点、守恒、日→周聚合、省/区、legacy |

## 运行

```powershell
cd d:\MATHmodelAmericaschool2027\ws\new\code

p0_check                 # 验收，并更新 ws/new/outputs/p0
refresh_tracker_data     # 可选：重新抓取并生成新日期快照
```

## 日尺度数据选择

- 数据源：`ws/new/data/ebola_tracker/national_daily_<日期>.csv` 中最新的一个；
- 拟合：2026-06-21 至 2026-10-25（127 天）；
- 验证：2026-10-26 至 2026-11-09（15 天）；
- 日锚点：
  - 2026-06-21 = 1,048 / 267；
  - 2026-10-25 = 10,060 / 4,887；
  - 2026-11-09 = 11,042 / 5,387；
- 周表 `national_weekly_*.csv` 只用于聚合校验和论文主表；
- 8 省（含 Nord-Ubangi），总人口 38,393,224；
- 67 个卫生区（59 个有人口）；
- 响应指标来自数据页面；跨境来自 `cross_border_latest_20261108.csv`；
- HCW 序列来自 `legacy_weekly_supplement_W29-W41.csv`。

## `state_at` 的日尺度规则

```text
C, M  日累计确诊/死亡
R     累计康复；缺失时沿用上一个有效值（W25–W31 为空，因此为 0）
Q     有 etc_admitted 时用它；否则用 isolationRatio × (C-M-R)
I     max(C - M - Q - R, 0)          => I+Q+R+M = C 严格成立
E     日新增（优先 7 日滑动均值）/ sigma（日速率）
D     安葬延迟(天) × 日死亡（人/天 × 天 = 人）
S     N - E - I - Q - R - M          => 守恒严格成立
```

每个分量都带来源标记：

- `q_source`：`etc_admitted` / `isolation_ratio`；
- `r_source`：`observed` / `carried_forward` / `assumed_zero`；
- `e_source`、`d_source`：`reconstructed_7d` / `reconstructed_raw` /
  `reconstructed_diff` / `assumed_zero`。

## 日尺度速率（day⁻¹）

| 参数 | 周值 | 日值 |
|---|---|---|
| `sigma` | 0.70 /周 | 0.10 /天 |
| `gamma = gammaQ` | 0.21 /周 | 0.03 /天 |
| `mu = muQ` | 0.235 /周 | 0.03357 /天 |
| `alpha` | 1.244 /周 | 0.1777 /天 |
| `nu` | 3.5 /周 | 0.5 /天 |

延迟换算：`alpha = 1/d_alpha`、`nu = 1/d_nu`（d 以天计）。

## P0 验收（12 项，全部 PASS）

| 检查 | 含义 |
|---|---|
| `anchor_2026-06-21` | 1,048 / 267 |
| `anchor_2026-10-25` | 10,060 / 4,887 |
| `anchor_2026-11-09` | 11,042 / 5,387 |
| `conservation` | `S+E+I+Q+R+M = N` 误差 0 |
| `case_identity` | `I+Q+R+M = C` 误差 0 |
| `weekly_aggregation` | 21 个周日锚点与日表逐位一致（0 差异） |
| `province_population_sum` | 8 省人口合计 38,393,224 |
| `zone_count` | 67 区，59 个有人口 |
| `cross_border_rows` | 4 个国家/地区 |
| `legacy_regression` | 旧周代码 W25/W41 与初值仍可复现 |
| `daily_coverage` | 142 天 |
| `holdout_days` | 15 天 |

## 日尺度数据注意事项

- 日表有 4 个缺失日（6/26、7/16、7/28、7/29），累计值按 LOCF 补；
- 7/22、7/30 是 catch-up，10/30–31 是 harmonisation，日表用 flag 标记；
- `recovered` 在 W25–W31 为空，`R=0` 是假设（`assumed_zero`），会抬高早期 `I`；
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；
- 卫生区死亡合计 4,894 ≠ 国家 5,387，493 例未分配；
- Nord-Ubangi 人口为 150 万估计。

## 下一步（P1）

在同一目录实现**日尺度**三通道模型：

- `betaC / betaH / betaF`；
- `R0 = R_c + R_h + R_f`；
- `R_eff(t)` 与状态转移图；
- 仍复用 `config / load_data / state_at`。

规划文档见 `ws/docs/A_PROBLEM_ADAPTATION.md`。
