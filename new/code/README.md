# new/code：P0/P1/P2/Q2 日尺度数据、建模、拟合与不确定性

本目录是 Problem A 重建的新代码。旧代码在 `ws/old/code/matlab`，已冻结，不要修改。

## 状态

**P0（日尺度数据与配置）已完成（2026-11-11）。**

- 日序列：2026-06-21 至 2026-11-09，共 **142 天**；
- 最新日 2026-11-09：11,042 / 5,387；
- 拟合：2026-06-21 至 2026-10-25（127 天）；
- 验证：2026-10-26 至 2026-11-09（15 天）；
- 8 省、67 区、`N = 38,393,224`；
- 验收 **12/12 全部通过**。

**P1（日尺度三通道模型 + 6 参数拟合）已完成，2026-11-19 定版。**

- 模型：`βc I + βh Q + βf D`，`βh=ρh0 βc`、`βf=ρf0 βc`；
- 6 参数：`βc0, u1, u2, α0, μ, ρ_rep`；
- 基线：`ρ_rep` 固定为 1（可识别性考虑），`u2` 允许为负（晚期反弹）；
- 日 R² 0.9970/0.9931，周 R² 0.9968/0.9952，holdout 病例 MAPE 3.02%。

**P2（不确定性、敏感性与模型比较）已完成（2026-11-19）。**

- 7/14 天块 bootstrap 各 100 个有效 replicate；
- `u2` 与 `R0late` 区间很宽，晚期反弹不可稳定识别；
- `α0` profile 平坦；`ρRep` 自由估计 0.885；
- 固定假设中 `E0` 影响最大；
- AIC 选 2 节点反弹模型，3 节点未形成决定性改进。

**Q2 日尺度对齐（第二问方法）已完成（2026-11-19）。**

- Q2 日度观测表：142 天，fit 127 / holdout 15；
- 6 参数、`βc+ρh+ρf`、对数 NLS、CFR 软约束、MultiStart 8；
- 固定 `ρ_rep=1` 基线；自由 0.885 作敏感性；
- profile `α0/ρ_rep/ρh0`、2/3 节点 + τ 网格；
- 14/21 天块 bootstrap 500 次；
- τ 网格显示 9/20 节点优于 10/11（AIC −1359.97，holdout 1.91%/0.79%）。

## 文件清单

| 文件 | 作用 |
|---|---|
| `config.m` | 唯一配置入口：数据源、日尺度窗口、日速率、P1/P2 参数、路径 |
| `load_data.m` | 优先读日表；保留周表做聚合校验；8 省/67 区；响应、跨境、HCW |
| `state_at.m` | 分派器：有 `data.daily` 用日重建，否则用旧周重建 |
| `state_at_day.m` | **日尺度**重建 `[S;E;I;Q;R;D;M]`，带来源标记 |
| `state_at_week.m` | 旧周尺度重建（legacy 回归专用） |
| `build_tracker_snapshot.m` | 原始 CSV → 日表、周表、省日表、区快照、响应表 |
| `refresh_tracker_data.m` | 下载原始库 + 字典 + 页面指标，并重建快照 |
| `fetch_response_page.m` | 解析数据页面六项响应指标 |
| `latest_tracker_file.m` | 按文件名中的 8 位日期选最新快照 |
| `p0_check.m` | P0 验收：日锚点、守恒、日→周聚合、省/区、legacy |
| `daily_params.m` | P1 固定参数、初始参数和节点 |
| `daily_initial_state.m` | 2026-06-21 初值（首周 warm start） |
| `make_beta_fun_multi.m` | 任意节点数/任意 `u` 向量的 `βc(t)` |
| `make_beta_fun.m` | 两节点旧接口（legacy 兼容） |
| `simulate_daily_seiqrd.m` | 日尺度三通道 ODE |
| `r0_daily.m` | R0 通道分解 `Rc/Rh/Rf` |
| `fit_daily_seiqrd.m` | 兼容入口（转发到 core） |
| `fit_daily_seiqrd_core.m` | 通用拟合内核：可变参数集、固定参数、2/3 节点、初值缩放 |
| `run_p1_fit.m` | P1 主脚本：拟合、指标、表格、图 |
| `run_p2_uncertainty.m` | P2 主脚本：bootstrap、profile、敏感性、模型比较、图 |
| `p2_bootstrap.m` | 7/14 天块 bootstrap |
| `p2_profile.m` | profile likelihood 与 95% 区间 |
| `p2_sensitivity.m` | `ρH0/ρF0/ν/E0/D0` 单因素敏感性 |
| `p2_model_compare.m` | 2 节点 vs 2 节点约束 vs 3 节点 |
| `p2_opts_from_fit.m` | 从已拟合结构构造 P2 拟合选项 |
| `p2_summary_table.m` | 参数/派生量统计汇总 |
| `build_q2_daily_data.m` | Q2 日度观测表（C/M/Q/R/社区死亡/ETC 死亡/new_cases） |
| `run_q2_aligned.m` | Q2 日尺度对齐：固定/自由 rhoRep、profile、节点/τ、14/21 天 bootstrap |
| `run_q2_besttau.m` | Q2 第二节点 9/20 的完整拟合（固定/自由 rhoRep） |
| `task1_checks.m` | legacy R0 回归、闭式 R0 vs 数值谱半径 |
| `task1_state_diagram.py` | 生成 `ws/docs/SEIQRD_状态转移图.png` |

## 运行

```powershell
cd d:\MATHmodelAmericaschool2027\ws\new\code

p0_check                 # 验收，并更新 ws/new/outputs/p0
refresh_tracker_data     # 可选：重新抓取并生成新日期快照
run_p1_fit               # P1 拟合，写 ws/new/outputs/p1
run_p2_uncertainty       # P2 不确定性，写 ws/new/outputs/p2
run_q2_aligned           # Q2 日尺度对齐，写 ws/new/outputs/q2
run_q2_besttau           # Q2 第二节点 9/20 的最优 τ 拟合
task1_checks             # Task 1 R0 回归，写 ws/new/outputs/task1
python task1_state_diagram.py   # 生成状态转移图
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

## P1 日尺度建模与拟合（已完成）

### 模型

```text
Λ = S/N · (βc(t) I + βh(t) Q + βf(t) D)
βh(t) = ρh0 · βc(t)
βf(t) = ρf0 · βc(t)
βc(t) = βc0 · (1 − u1·1(t ≥ t1)) · (1 − u2·1(t ≥ t2))
t1 = 2026-08-17（疫苗 rollout），t2 = 2026-10-11（平台期）
```

- `u2` 允许为负：负值表示第二阶段的**反弹/放松**乘子；严格 `u2≥0` 的单调下降模型无法解释 W41–W45 的平台期。

### 固定与待估

| 类别 | 参数 | 值 |
|---|---|---|
| 固定 | `σ` | 0.10 /天 |
| 固定 | `γ = γQ` | 0.03 /天 |
| 固定 | `ν` | 0.50 /天 |
| 固定 | `ρh0` | 0.40 |
| 固定 | `ρf0` | 3.00 |
| 固定 | `ρM` | 1.00 |
| 待估 | `βc0, u1, u2, α0, μ, ρRep` | 6 个 |

基线把 `ρRep` 固定为 1：在累计曲线锚定到报告病例后，常数 `ρRep` 与 `βc0` 不可识别；自由估计会得到 ≈0.885，日中段拟合略好但 holdout 更差。自由估计作为敏感性保留（`fixRhoRep=false`）。

### 拟合结果（3 个初值）

| 参数 | 估计 |
|---|---:|
| `βc0` | 0.1217 /天 |
| `u1` | 0.4315 |
| `u2` | −0.4985 |
| `α0` | 0.3022 /天 |
| `μ` | 0.03485 /天 |
| `ρRep` | ≈1.00（固定） |

| 指标 | 值 |
|---|---|
| 日 R²（病例/死亡） | 0.9970 / 0.9931 |
| 周 R²（病例/死亡） | 0.9968 / 0.9952 |
| holdout RMSE（病例/死亡） | 320.1 / 82.8 |
| holdout MAPE（病例/死亡） | 3.02% / 0.57% |
| CFR 模型/观测 | 0.5307 / 0.5126 |
| R0 早期 | 1.3414 = Rc 0.3314 + Rh 0.6178 + Rf 0.3922 |
| R0 后期 | 1.1427 = Rc 0.2823 + Rh 0.5263 + Rf 0.3341 |

> 以上为 2026-11-19 在最终内核 `fit_daily_seiqrd_core.m` 上重跑的定版值；与 2026-11-11 初版差在拟合容差级别。

### 结构说明

- `α0=0.302/天`（约 3.3 天入院延迟），`μ=0.0348/天`；二者带弱先验（0.15、0.030），不是固定值。
- `u2` 落在下界 −0.5，说明数据希望更强的晚期反弹；当前边界是建模选择，后续可放宽或加第三节点。
- 严格单调模型（`u2≥0`）会把 W45 周新增压到约 222（实际 458），holdout 病例 RMSE 约 950；因此 P1 采用“允许反弹”的 6 参数版本。
- `R0` 后期 1.143 > 1，与 W41–W45 的平台期一致；早期 1.341。
- holdout 病例 R² 为负是因为 holdout 区间窄（15 天、增量约 982），R² 对系统偏差极敏感；应同时报告 MAPE 与 RMSE。

### 输出

`ws/new/outputs/p1/`：

- `P1_parameters.csv`；
- `P1_metrics.json`；
- `P1_observations.csv`（逐日观测/预测/Reff）；
- `P1_weekly_fit.csv`；
- `P1_R0_channels.csv`；
- `P1_fit.png`（累计病例/死亡、周新增、Reff 四联图）。

## P2 结果与下一步

P2 已完成（2026-11-19）：

- 7/14 天块 bootstrap 各 100 个有效 replicate；
- `α0`、`u1`、`ρRep` 的 profile likelihood；
- `ρH0/ρF0/ν/E0/D0` 单因素敏感性；
- 2 节点、2 节点 `u2≥0`、3 节点的 AIC/BIC 比较；
- 结果在 `ws/new/outputs/p2/`，说明见该目录 `README.md`。

核心结论：`u2` 与 `R0late` 不可稳定识别（区间几乎覆盖允许范围）；
`α0` profile 平坦；`ρRep` 自由估计 0.885，基线固定 1 落在 profile 区间外；
固定假设中 `E0` 影响最大；AIC 选 2 节点反弹模型，3 节点无决定性改进。

下一步进入 **Task 3 干预措施**（8 类干预、疫情持续时间、7 月中旬 vs 当前
时机反事实、78%→90%/95% 随访资源），再做 **Task 4 空间/跨境**。
