# new/outputs：新题输出（P0）

## P0 数据层输出（2026-11-11）

`p0/` 由 `ws/new/code/p0_check.m` 生成，共 4 个文件：

| 文件 | 内容 |
|---|---|
| `P0_checks.csv` | 11 项验收检查（全部 PASS） |
| `P0_state_reconstruction.csv` | W25/W28/W32/W34/W41/W43/W45 的重建状态 |
| `P0_data_report.csv` | 序列中每一周的重建状态 |
| `P0_summary.json` | 配置、数据文件、最新日、初始状态、响应指标、检查结果 |

`P0_checks.csv` 的 11 项：

1. `anchor_W25`：1,048 / 267；
2. `anchor_W43`：10,060 / 4,887；
3. `anchor_W45`：10,990 / 5,354；
4. `conservation`：`S+E+I+Q+R+M = N`；
5. `case_identity`：`I+Q+R+M = C`；
6. `province_population_sum`：8 省人口合计 38,393,224；
7. `zone_count`：67 个卫生区，59 个有人口；
8. `cross_border_rows`：4 个国家/地区；
9. `legacy_regression`：旧代码 W25/W41 与初值仍可复现；
10. `holdout_points`：W44–W45；
11. `zone_population`：59/67 个区有人口。

`P0_state_reconstruction.csv` 的关键行（2026-11-11 数据）：

| 周 | C | M | Q | R | I | E | D |
|---|---|---|---|---|---|---|---|
| W25 | 1,048 | 267 | 360 | 0 | 421 | 342.9 | 21.4 |
| W43 | 10,060 | 4,887 | 982 | 2,684 | 1,507 | 725.7 | 81.4 |
| W45 | 10,990 | 5,354 | 882 | 2,951 | 1,803 | 654.3 | 65.1 |

## 旧结果

旧 Q1–Q4 结果已移到 `ws/old/outputs/matlab/`，说明见
`ws/old/outputs/README.md`。

## 注意

- P0 输出只覆盖“数据与配置层”，还不是三通道模型结果；
- 下一步 P1 的模型输出建议另建 `ws/new/outputs/p1/`，不要覆盖 P0；
- 正文引用数字时，以 `P0_summary.json` 和 `P0_checks.csv` 为准。
