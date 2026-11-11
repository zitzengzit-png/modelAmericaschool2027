# old/outputs：旧结果（只读）

`matlab/` 是旧 Q1–Q4 在 W25–W41、7 省基线上的输出，当前共 18 个文件。

## 文件清单

**Q1 基线**

- `q1_baseline.csv`：逐周状态、累计病例/死亡、Rt；
- `fig_q1_baseline.png`：S/E/I/Q、R/D/M、累计曲线、Rt 四联图。

**Q2 主拟合**

- `fit_parameters_matlab.csv`：参数估计表；
- `fit_observations_matlab.csv`：观测与拟合对比；
- `fit_metrics_matlab.json`：R²、RMSE、峰值、端点误差等；
- `fit_result_matlab.mat`：完整拟合结果（MATLAB 数据）；
- `fig_fit_matlab.png`：累计病例/死亡、周新增、Rt 四联图。

**Q2 附录版**

- `q2_appendix_parameters.csv`；
- `q2_appendix_observations.csv`；
- `fig_q2_appendix_fit.png`。

**Q3 干预**

- `Q3_criteria.csv`：解析临界值；
- `Fig3-1_one_factor.png`：四类干预单因素响应；
- `Fig3-2_isolation_burial.png`：收治 × 安葬响应面；
- `Fig3-3_communication_burial.png`：宣传 × 安葬响应面；
- `Fig3-4_communication_isolation.png`：宣传 × 收治响应面。

> `Q3_combinations_*.csv`、`Q3_kappa.csv`、`Fig3-5_kappa.png` 只有在完整
> 跑完 `q3_interventions` 后才会生成，当前目录未包含。

**Q4 七省元群**

- `Q4_scenario_results.csv`：10 个情景的 24 周结果；
- `Q4_total_cases.png`：观测 + 10 条情景曲线；
- `Q4_provincial_burden.png`：分省 24 周新增对比。

## 主要数字

- `β0/β1 = 1.295/0.845`，`α/μ = 1.238/0.235`；
- `R² = 0.99947/0.99132`，`RMSE = 58.81/118.55/53.46`；
- W43 端点：模型 9,735 / 4,842，观测 10,060 / 4,887。

## 注意

- 这些是**旧基线**结果，不是新题结果；
- Q3 的临界值（2.59 天、0.79 天、26.3%、65.6%）和 Q4 的情景病例数
  都建立在“无院内传播 + 旧基线”上，不能直接引用；
- 旧 tracker 临时拟合 `fit_latest_tracker_metrics_aux.csv` 在
  `ws/old/data/ebola_tracker/`，仅作历史对照。
