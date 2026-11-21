# 第四问交付包（跨区域传播与跨境风险）

本文件夹收录问题四用到的全部代码、数据、文档与复算结果，可直接运行复现。

## 一、代码清单

| 文件 | 作用 | 依赖 | 对应报告章节 |
|---|---|---|---|
| `task4_common.m` | **共享 setup（单一事实来源）**：8 省人口、邻接、Haversine 距离、引力矩阵 P、Q2 9/20 日尺度参数、6/21 锚定初值 | 数据 CSV、`task4_initial_active` | 全部 |
| `task4_spatial_skeleton.m` | 主模型单次运行：留出期验证、累计病例排序、R_net、R_local | `task4_common`、`task4_integrate` | §4.2、§4.3 |
| `task4_strategies.m` | 8 情景策略对比（旅行限制、协同、折减代理、接种环机制、组合） | `task4_common`、`task4_integrate` | §4.4 |
| `task4_sensitivity.m` | 流动性敏感性驱动：9 组合 × 8 情景 = 72 次求解 | `task4_strategies` | §4.4.1 |
| `task4_holdout_table.m` | 模型筛选：共享 Q2 vs 常数/淡出倍数（证明 beta_mult=1） | `task4_common`、`task4_integrate` | §4.2 |
| `task4_border_screening.m` | 境外筛查与持续传播风险（负二项分支过程） | 无（自足） | §4.5 |
| `task4_q2_uncertainty.m` | Q2 参数不确定性下的 R_net 稳健性（冻结参数扫 ρh0/ρf0） | `task4_common` | §4.4.2 |
| `task4_integrate.m` | ODE 积分：在 t1/t2 节点重启、逐日输出（避免参数跳变误差） | 被各脚本调用 | — |
| `task4_initial_active.m` | 准稳态初值（I*=inc/a、Q*=αI*/b，按可用人数截断） | 被 `task4_common` 调用 | — |

**依赖关系**：`task4_sensitivity` → `task4_strategies` → `task4_common` → `task4_integrate` / `task4_initial_active`。`task4_holdout_table` 与 `task4_spatial_skeleton` 同样依赖 `task4_common`。`task4_border_screening`、`task4_q2_uncertainty` 可独立运行。

## 二、数据文件（`data/ebola_tracker/`）

| 文件 | 用途 |
|---|---|
| `province_latest_20261111.csv` | 8 省人口、累计确诊/死亡（代码直接读取） |
| `province_daily_20261111.csv` | 省日表（代码直接读取，构造锚定初值与留出观测） |
| `cross_border_latest_20261108.csv` | 境外计数（肯尼亚 9、尼日利亚 1，报告 §4.5 引用） |
| `health_zone_latest_20261111.csv` | 卫生区快照（区级校验，报告 §4.6 引用） |
| `response_latest_20261111.csv` | 筛查规模 276,403 人（报告 §4.5 引用） |
| `national_weekly_20261111.csv` | 周度快照 W41（报告 §4.5 引用） |
| `legacy_weekly_supplement_W29-W41.csv` | 旧周度补充（报告 §4.5 引用） |
| `README.md` | 字段定义与快照构建说明 |

## 三、文档

| 文件 | 说明 |
|---|---|
| `文档/第四问_跨区域传播与跨境风险.md` | **主报告**（题目要求的完整解答） |
| `文档/第四问建模数据修正.md` | 数据改正（10/25 锚点、D0=2·dinc 等） |
| `文档/第四问_评审与改进建议.md` | 方案评审与改进记录 |
| `文档/第四问_程序说明与差距清单.md` | 旧程序说明（历史记录，已由主报告取代） |
| `文档/要求一建模.md` | 模型符号约定（报告 §4.6 引用） |
| `文档/第二问_参数确定与数据使用方法.md` | Q2 参数来源（报告 §4.6 引用） |
| `题目/A.txt` | 题目原文 |

## 四、复算步骤

在 MATLAB 中 `cd` 到本文件夹，依次运行：

```matlab
task4_spatial_skeleton   % 主模型 + 留出期验证 + R_net/R_local
task4_strategies         % 策略对比表（含接种环机制）
task4_sensitivity        % 72 次求解 → output/task4/sensitivity.csv
task4_holdout_table      % 模型筛选（证明共享参数优于倍数模型）
task4_q2_uncertainty     % Q2 参数不确定性表
task4_border_screening   % 境外筛查有效性表
```

关键复现值：留出期 MAE（模型 77.16 / 持平基线 18.04）、参考情景 R_net 1.035、接种环机制降幅 −22.2%、协同降幅 −44.8%、Q2 不确定性下基线 R_net 0.926–1.209。

## 五、本轮清理说明

- **融合**：原骨架/策略/留出/不确定性四个脚本各自重复的 setup（省名、人口、邻接、Haversine、引力矩阵、Q2 参数、锚定初值约 40 行）已抽取为唯一的 `task4_common.m`，消除参数漂移（如 `alpha`/`alpha0`、`q2_uncertainty` 中硬编码的人口）。
- **删除**：`task4_holdout_table.m` 中从未调用的死函数 `nz`；`task4_spatial_skeleton.m` 中未使用的 `origin` 播种模式（TODO，未用）。
- 重构后各脚本输出与重构前逐位一致，已重新运行全部 6 个脚本验证。
