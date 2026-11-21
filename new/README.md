# new：新题（Problem A）的数据、代码与 P0/P1 结果

## 当前进度

**P0（日尺度数据与配置）已完成，2026-11-11。**

- 数据：ebola-tracker.org 2026-11-11 快照（SitRep 179）。
- 日序列：2026-06-21 至 2026-11-09，共 142 天。
- 最新日 2026-11-09：**11,042 例 / 5,387 死**。
- 8 个省、67 个卫生区，`N = 38,393,224`。
- 拟合：2026-06-21 至 2026-10-25（127 天）。
- 验证：2026-10-26 至 2026-11-09（15 天）。
- P0 验收：**12/12 全部通过**。
- 结果：`ws/new/outputs/p0/`。

**P1（日尺度三通道模型 + 6 参数拟合）已完成，2026-11-19 定版。**

- 日 R² 0.9970/0.9931，周 R² 0.9968/0.9952。
- holdout 病例 MAPE 3.02%，死亡 MAPE 0.57%。
- R0 早期 1.341，后期 1.143（Rc/Rh/Rf 分解）。
- 结果：`ws/new/outputs/p1/`。

**P2（不确定性、敏感性与模型比较）已完成，2026-11-19。**

- 7/14 天块 bootstrap 各 100 个有效 replicate；
- `u2` 与 `R0late` 区间几乎覆盖允许范围，晚期反弹不可稳定识别；
- `α0` profile 平坦；`ρRep` 自由估计 0.885；
- `E0` 是影响最大的固定假设；
- AIC 选 2 节点反弹模型，3 节点无决定性改进；
- 结果：`ws/new/outputs/p2/`。

**Task 1 收尾已完成，2026-11-19。**

- `要求一建模.md` 全部速率统一为天；
- 状态转移图：`ws/docs/SEIQRD_状态转移图.png`；
- legacy R0 1.355789887/0.884312117 与新版谱半径校验 6/6 PASS；
- 结果：`ws/new/outputs/task1/`。

**Q2 日尺度对齐（第二问方法）已完成，2026-11-19。**

- `q2_daily_observations_20261111.csv`：142 天，fit 127 / holdout 15；
- 6 参数、`βc+ρh+ρf`、对数 NLS、CFR 软约束、MultiStart 8；
- 固定 `ρ_rep=1` 基线；自由 0.885 作敏感性；
- profile `α0/ρ_rep`；`ρh0` 三点敏感性、2/3 节点 + τ 网格、14/21 天块 bootstrap；
- τ 网格显示 9/20 优于 10/11（AIC −1359.97，holdout 1.91%/0.79%）；
- 结果：`ws/new/outputs/q2/`。

**Q4 旧空间骨架（2026-11-19，legacy）。**

- 8 省 SEIQRD 元群、Q2 9/20 参数、引力 `P` 代理；
- 高负担省 `beta_mult` 标定到 10/18+10/25；
- `R_net/R_local`、策略、跨境分支、图；
- 结果：`ws/new/outputs/q4/`；
- 留出期 MAE 179.06 vs 持平基线 18.04，`R_net=2.31`，仅作条件骨架。

**Task 3 八类干预（已实现，2026-11-21）。**

- `task3_*` + `run_task3_interventions.m`；基线 Q2 9/20；
- 14 情景 × 2 个启动时点（7/14、10/25），365 天；
- B0 141 天 10,855.6（观测 11,042，−1.69%）；5 项检查 PASS；
- 结果：`ws/new/outputs/task3/`（情景表、轨迹、资源、检查、图）。

**Task 4 交付版（正式流水线，2026-11-21）。**

- `task4_*` 全部为函数，`run_task4_delivery.m` 一次跑完主模型/策略/敏感性/留出/跨境；
- 共享 Q2 9/20、`beta_mult=1`、8 省引力 `P`；
- 留出 MAE 77.16（持平 18.04），`R_net=1.035`；
- 结果：`ws/new/outputs/task4/`。

## 目录结构

```text
new/
├── code/                  P0/P1/P2/Q2/Task1/Task3/Task4 代码（55 个 .m + 1 个 .py）
├── data/
│   ├── README.md
│   └── ebola_tracker/     2026-11-11 日表/周表/省日表 + 共享输入
├── outputs/
│   ├── README.md
│   ├── p0/                P0 验收输出（4 个文件）
│   ├── p1/                P1 拟合输出（6 个文件）
│   ├── p2/                P2 不确定性输出（24 个文件，含 README）
│   ├── q2/                Q2 日尺度对齐输出（参数/profile/节点/τ/bootstrap）
│   ├── q4/                Q4 旧空间输出（legacy）
│   ├── task1/             Task 1 R0 回归与校验（2 个 CSV + README）
│   ├── task3/             Task 3 八类干预（28 行情景表 + 轨迹 + 资源 + 图）
│   └── task4/             Task 4 交付版（主模型/策略/敏感性/留出/日志）
└── ideas/
    ├── 埃博拉传播动力学模型_第一问.md
    ├── 数据处理方案确定(1).md
    ├── 当前建模思路_20261119.md
    ├── 第三问干预思路_20261119.md
    ├── 任务三_八类干预动态影响_最终建模.md
    ├── 第四问交付/         Task 4 交付包（代码/数据/文档/日志）
    └── 第五问敏感性思路_20261119.md
```

## 下一步（2026-11-21 更新）

- **Task 5**：Morris → LHS/PRCC → Sobol + 结构/情景层（`ws/docs/第五问建模.md`）；
- **Task 6**：成本、资金缺口（>4 亿美元）与执行摘要；
- **论文**：25 页排版、AI 使用报告、图表统一；
- **口径**：Task 4 旧 `q4_*`（MAE 179.06、`R_net=2.31`）与新 `task4_*`（MAE 77.16、`R_net=1.035`）
  并存，正文统一用新口径，详见 `ws/docs/PROJECT_OVERVIEW.md` §8。

## 相关文档

- **全局速查**：`ws/docs/PROJECT_OVERVIEW.md`
- 新旧差异、改造清单、P0/P1/P2 记录：`ws/docs/A_PROBLEM_ADAPTATION.md`
- 第一问模型与 R0 推导：`ws/docs/要求一建模.md`
- 旧模型方程与参数：`ws/docs/MODEL_ARCHITECTURE.md`
- 新代码说明：`ws/new/code/README.md`
- 新数据说明：`ws/new/data/README.md`
- tracker 数据细节：`ws/new/data/ebola_tracker/README.md`
- P0/P1/P2/Task1 结果说明：`ws/new/outputs/README.md`
- P2 结果细节：`ws/new/outputs/p2/README.md`
