# new/outputs/q4：8 省空间 SEIQRD（修正版）

由 `ws/new/code/run_q4_spatial.m` 生成（2026-11-19）。

## 文件

| 文件 | 内容 |
|---|---|
| `Q4_province_fit.csv` | 10/25、11/09 省级观测/模型/留出净增/持平基线 |
| `Q4_beta_mult.csv` | 高负担省标定后的 `beta_mult`；低负担省固定 1 |
| `Q4_Rnet.csv` | 省级 `R_local` |
| `Q4_strategies.csv` | 基线/旅行限制/区域协同/环形接种/组合 |
| `Q4_border_risk.csv` | Kenya 9、Nigeria 1 的负二项输入风险 |
| `Q4_summary.json` | 机器可读汇总 |
| `Q4_figures/` | 8 省网络、P 热图、10/25 拟合、留出、R_net、跨境风险 |

## 关键结果

- 10/25 高负担省拟合：Ituri 7421 vs 7211，Nord-Kivu 2310 vs 2309，
  Haut-Uele 448 vs 436，Tshopo 83 vs 83；
- 留出期 MAE：模型 **179.06** vs 持平基线 **18.04**；
- `R_net=2.31`，`R_local` 高负担省 >1；
- 策略：旅行限制单独效果很小；区域协同 R_net 1.93；
  环形接种 R_net 1.04；组合 R_net 0.86。

## 结果边界（必读）

- `P` 是引力/停留份额代理，不是实测 OD；
- 10/25 后模型仍按同一 `beta_mult` 增长，观测已减速，因此留出期高估；
- 低负担省固定 `beta_mult=1`，6/21 无记录按 0 初始化；
- `R_net=2.31` 是**条件诊断**，不是真实阈值/预测；
- `rho_rep=1` 是近似，模型 C 与确诊口径不完全一致。

详见 `ws/docs/第四问建模.md` §9。
