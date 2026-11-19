# new/outputs/q2：第二问日尺度对齐版

由 `ws/new/code/run_q2_aligned.m` 生成（2026-11-19）。保留 P0 日尺度
（142 天；127 天拟合、15 天 holdout），采用
`ws/new/ideas/数据处理方案确定(1).md` 的好方法，但不退回周尺度。

## 文件

| 文件 | 内容 |
|---|---|
| `Q2_fixed_parameters.csv` / `Q2_fixed_metrics.json` | `ρ_rep=1` 基线（8 初值） |
| `Q2_free_parameters.csv` / `Q2_free_metrics.json` | `ρ_rep` 自由估计敏感性 |
| `Q2_profile_alpha0.csv` / `Q2_profile_rhoRep.csv` | profile 曲线 |
| `Q2_profile_ci.csv` | `α0`、`ρ_rep` 的 95% profile 区间 |
| `Q2_rhoH_sensitivity.csv` | `ρh0=0.3/0.4/0.5` 的 R0 分解与拟合指标 |
| `Q2_node_comparison.csv` | 2 节点 vs 3 节点 AIC/BIC |
| `Q2_tau_grid.csv` | 第二节点 `9/20`、`10/11`、`11/01` 的 τ 网格 |
| `Q2_besttau_fixed_*` / `Q2_besttau_free_*` | 9/20 最优 τ 的完整拟合（固定/自由 `ρ_rep`） |
| `Q2_bootstrap_*.csv` | 14/21 天块 bootstrap（500 次） |
| `Q2_summary.json` | 机器可读汇总 |

## 主要结果

| 模型 | R² 病例/死亡 | holdout MAPE 病例/死亡 | AIC | BIC |
|---|---:|---:|---:|---:|
| 10/11，固定 `ρ_rep=1`，8 初值 | 0.9964 / 0.9934 | 3.95% / 1.23% | −1352.64 | −1334.96 |
| 10/11，自由 `ρ_rep=0.885` | 0.9961 / 0.9873 | 5.52% / 2.67% | — | — |
| **9/20，固定 `ρ_rep=1`，8 初值** | **0.9972 / 0.9942** | **1.91% / 0.79%** | **−1359.97** | **−1342.28** |
| 9/20，自由 `ρ_rep=0.851` | 0.9979 / 0.9831 | 2.23% / 6.38% | — | — |

- 自由 `ρ_rep` 训练更好但 holdout 更差（尤其死亡），**主结果保留固定 1**；
- τ 网格的 **9/20** 在 AIC/BIC/holdout 病例上均优于 10/11；
  10/11 是干预时间线节点，9/20 是数据驱动变点，两者都应报告；
- 9/20 基线：`βc0=0.1125`、`u1=0.4892`、`u2=-0.5000`、
  `α0=0.1698`、`μ=0.03488`、`R0=1.3443`、`R0late=1.0300`。

### 块 bootstrap（500 次）

- 14 天块：500/500 有效；`α0` 95% CI `[0.1232, 0.2575]`，
  `u2` 几乎覆盖 `[-0.500, 0.950]`；
- 21 天块：500/500 有效；`α0` 95% CI `[0.1175, 0.2686]`，
  `u2` 仍覆盖整个允许范围；
- 说明 `α0` 在 Q2 固定 `ρ_rep` 的设定下比 P2 更可识别，但 `u2` 仍然弱识别。

## 数据

Q2 日度观测表：

- `ws/new/data/ebola_tracker/q2_daily_observations_20261111.csv`
- `ws/new/data/ebola_tracker/q2_weekly_validation_20261111.csv`

累计值来自原始累计序列；`new_*_adj` 只做周诊断，不用于还原累计值。
