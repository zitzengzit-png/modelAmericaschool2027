# SEIQRD 模型架构说明（MATLAB 版）

> 版本：v1.2（legacy，已冻结）  
> 代码目录：`ws/old/code/matlab`  
> 范围：只包含 MATLAB；不包含 Python。  
> 本文说明“当前整理版”的建模思路、代码架构，并备注旧版与 tracker 辅助数据的差异。
>
> **新标准：2026-11-11 起全部用日。** 本文描述的是旧版**周尺度**模型，
> 仅作 legacy 参考；日尺度规则见 `A_PROBLEM_ADAPTATION.md` 第 11 节。

## 0. 一句话概括

旧版**使用旧工作簿 W25–W41 / 7 省基线**作为模型数据源：

- Q1：六仓室 SEIQRD（外加累计死亡 M）连续时间模型；
- Q2：W25–W41 周度数据（17 个观测点）的两段常数 β 加权最小二乘拟合；
- Q3：收治隔离、安全安葬、社区宣传、接触者追踪四类干预的单因素/组合分析；
- Q4：七省 SEIQRD 元群模型，含人口流动、收治容量、环围接种和 10 个情景。

`ws/old/data/ebola_tracker/`（2026-11-08，W25–W45，8 省/67 区，10,990/5,354）只作为**辅助对照**保留；`load_data.m` 中 `useTracker = false`，默认不参与建模。

它**不是**当前 A 题的 8 省 66 区、跨境、医院传播、时变参数、8 类干预版本；A 题扩展见第 8 节。

## 1. 文件地图

| 文件 | 作用 | 状态 |
|---|---|---|
| `q1_model.m` | Q1 基线模型演示：加载数据、积分、R0、Rt、四联图 | 新增 |
| `q2_fit.m` | Q2 主拟合：`load_data` + `fit_seiqrd`，4 参数，ν 固定 | 原有 |
| `q2_fit_appendix.m` | Q2 附录版拟合：5 参数向量，ν 用紧边界固定 | 新增（从 docx 整理） |
| `q3_interventions.m` | Q3 干预分析：单因素、二维响应面、672 组合、κ 稳健性 | 新增（从 docx 整理） |
| `q4_metapopulation.m` | Q4 七省元群：流动、容量、环围接种、10 情景 | 新增（从 docx 整理） |
| `simulate_seiqrd.m` | Q1/Q2 通用 SEIQRD 积分与 Rt/峰值 | 原有 |
| `fit_seiqrd.m` | Q2 主拟合函数：τ 网格 + 多初值 + `lsqnonlin` | 原有 |
| `load_data.m` | 默认读取 `ws/old/data/outbreak_data.xlsx`（W25-W41）；`useTracker=true` 时改读 tracker | 更新 |
| `default_params.m` | 旧工作簿用 reference 参数；tracker 数据源才用 provisional fit | 更新 |
| `r0_seiqrd.m` | 下一代矩阵 R0 | 原有 |
| `alpha_eff.m` | 追踪覆盖到有效收治率的映射 | 原有 |
| `delay_to_alpha.m` | 入院延迟（天）→ 周收治率 | 原有 |
| `nu_from_delay.m` | 安葬延迟（天）→ 周安葬率 | 原有 |

## 2. Q1：SEIQRD 模型

### 2.1 状态变量

```text
S : 易感者
E : 潜伏者（假设无明显传染性）
I : 有症状但未隔离的感染者
Q : 隔离收治者（假设社区接触被切断，不产生新感染）
R : 康复者（假设获得免疫）
D : 未安全安葬、仍有传染性的遗体
M : 累计疾病死亡（辅助量，不参与传染）
C : 累计确诊 = I + Q + R + M
```

### 2.2 微分方程组

```text
dS/dt = -lambda
dE/dt =  lambda - sigma*E
dI/dt =  sigma*E - (alpha + gamma + mu)*I
dQ/dt =  alpha*I - (gammaQ + muQ)*Q
dR/dt =  gamma*I + gammaQ*Q
dD/dt =  mu*I + muQ*Q - nu*D
dM/dt =  mu*I + muQ*Q

lambda = beta * S * (I + kappa*D) / N
```

### 2.3 基本再生数

用下一代矩阵法，取感染仓室 `x = (E, I, Q, D)`，得到：

```text
R0 = beta/(alpha+gamma+mu)
   + beta*kappa/nu * [ mu/(alpha+gamma+mu)
                       + alpha/(alpha+gamma+mu) * muQ/(gammaQ+muQ) ]
```

在 `muQ = mu`、`gammaQ = gamma` 下可化简为：

```text
R0 = beta * [ 1/a + kappa*mu/(nu*(gamma+mu)) ]，a = alpha+gamma+mu
```

关键解析结论（Q3 会复用）：

- `alpha -> infinity` 时，`R0 -> beta*kappa*mu/(nu*(gamma+mu)) = 0.588 (beta0)`，收治率再高也消不掉尸体通道；
- 单独安全安葬的临界延迟约 `0.79 天`，低于 1 天现实下限；压到 1 天时 `R0` 仍约 1.06；
- 单独收治的临界入院延迟约 `2.59 天`，现状约 `5.63 天`；
- 社区宣传临界约 `26.3%`，追踪临界约 `65.6%`。

> 以上解析数值对应 reference W41/7 省基线（`beta0=1.298、alpha=1.244、mu=0.235`）。tracker 新参数（`beta0=1.5069、alpha=1.2878、mu=0.2756`）会给出不同的阈值；Q3 目前仍用 reference 基线。

### 2.4 模型假设

1. 研究窗口内总人口 `N` 近似不变，忽略出生、自然死亡和非疾病迁移。
2. 潜伏者 `E` 无明显传染性。
3. 隔离收治者 `Q` 的社区接触被切断，不产生社区新感染；`Q` 仍可康复或病死。
4. `D` 只经安全安葬移出传染系统；`M` 只用于观测统计。
5. 康复者 `R` 在模拟期内获得免疫，不再回到 `S`。
6. Q2 reference 拟合把 `beta` 写成 W32 前后两段；tracker provisional fit 的变点是 W30。Q3 做静态情景扫描；Q4 把 7 省作为相互连接的子区域。

## 3. Q2：参数估计与拟合

### 3.1 数据与初值（旧工作簿 W25–W41）

- 数据源：`ws/old/data/outbreak_data.xlsx` 的 `01b_两套序列对比`；
- 窗口：`W25–W41`，共 17 个周度观测点；
- 序列：WHO AFRO 回顾口径累计确诊/累计死亡；
- `W25`：确诊 `1193`、死亡 `535`、在隔离/住院 `196`、累计康复 `112`；
- 派生：`I0 = 1193 - 196 - 112 - 535 = 350`；
- 情景假设：`E0 = 300`、`D0 = 20`；
- 总人口：`N = 36,893,224`（7 个受影响省）；
- W43 端点 `10,060 / 4,887` 作为 holdout，不参与拟合；
- tracker 数据（W25–W45，8 省/67 区）只作为辅助对照，默认不参与建模。

### 3.2 固定参数与待估参数

| 参数 | 值 | 来源/处理 |
|---|---|---|
| `sigma` | 0.70 周⁻¹ | 平均潜伏期约 10 天 |
| `gamma` | 0.21 周⁻¹ | BDBV 临床病程 |
| `gammaQ` | 0.21 周⁻¹ | 取 `gammaQ = gamma` |
| `kappa` | 3.0 | 文献基线，不单独估计 |
| `nu` | 3.5 周⁻¹ | 文献基线（约 2 天安葬延迟） |
| `muQ` | `mu` | 简化假设 |
| 待估 | `beta0, beta1, alpha, mu` | 两段 `beta`，变点 `tau` 网格搜索 |

### 3.3 目标函数

```text
rC  = (C_model - C_obs) ./ max(C_obs, 50)
rM  = (M_model - M_obs) ./ max(M_obs, 20)
rW  = (diff(C_model) - diff(C_obs)) ./ max(diff(C_obs), 30)
rMw = 0.5*(diff(M_model) - diff(M_obs)) ./ max(diff(M_obs), 15)
rCFR = 5*(M_model(end)/C_model(end) - M_obs(end)/C_obs(end))
res = [rC; rM; rW; rMw; rCFR]
```

- `tau` 在 `W26–W38` 逐周搜索；
- `q2_fit.m` 使用 3 个初值（reference 流程）；
- 主脚本 `q2_fit.m` 用 `fit_seiqrd.m`，固定 `nu`；
- 附录版 `q2_fit_appendix.m` 把 `nu` 放进参数向量，但上下界只差 `2e-6`，实际仍是固定值。

### 3.4 主要结果

**当前 active：旧工作簿 reference baseline（W25–W41，7 省，3 starts）**：

| 指标 | 值 |
|---|---|
| `beta0 / beta1` | 1.298 / 0.847 周⁻¹ |
| `alpha / mu` | 1.244 / 0.235 周⁻¹ |
| `tau` | W32（t=7） |
| `R0` 早期 / 后期 | 1.356 / 0.885 |
| `R²` 确诊 / 死亡 | 0.9995 / 0.9913 |
| `RMSE` 确诊 / 死亡 / 周新增 | 58.6 / 118.9 / 53.4 |
| `CFR` 模型 / 观测 | 0.490 / 0.483 |
| 周新增峰值 | 观测 657（W33）；模型 639（W32） |
| W43 holdout | 模型 9,735 / 4,842；观测 10,060 / 4,887（-3.2% / -0.9%） |

> 本机 `q2_fit` 3 初值结果为 `beta0/beta1 = 1.295/0.845`、`alpha/mu = 1.238/0.235`、`R² = 0.99947/0.99132`、`RMSE = 58.81/118.55/53.46`；`q2_fit_appendix` 5 参数写法复现 reference 的 `1.2977/0.8466`、`1.2437/0.2348`、`R0 = 1.356`。这些是当前 active 结果。

**辅助对照：tracker provisional fit（W25–W45，tau=5，one start，不参与 active 模型）**：

| 指标 | 值 |
|---|---|
| `beta0 / beta1` | 1.5069 / 0.8938 周⁻¹ |
| `alpha / mu` | 1.2878 / 0.2756 周⁻¹ |
| `R0` 早期 / 后期 | 1.583 / 0.939 |
| `R²` 确诊 / 死亡 | 0.9985 / 0.9897 |
| `RMSE` 确诊 / 死亡 / 周新增 | 122.1 / 165.7 / 72.6 |
| `CFR` 模型 / 观测 | 0.512 / 0.487 |
| 周新增峰值 | 模型 632（W31）；观测原始峰值 839（W30，受 catch-up 影响） |
| W45 端点 | 模型 10,732 / 5,490；观测 10,990 / 5,354（-2.4% / +2.5%） |

> tracker fit 只用于对照，不是当前模型结果；`load_data` 默认 `useTracker=false`。

## 4. Q3：干预分析

### 4.1 干预到参数的映射

| 干预 | 模型落点 | 说明 |
|---|---|---|
| 病例收治隔离 | `alpha = 7/d_alpha` | 入院延迟 `d_alpha`（天） |
| 安全安葬 | `nu = 7/d_nu` | 安葬延迟 `d_nu`（天） |
| 社区风险宣传 | `beta -> beta*(1-phi_C)` | 接触率下降比例 |
| 接触者追踪 | `alpha -> 7/((1-phi_T)d_alpha + phi_T*d_T)` | 追踪覆盖 `phi_T`，`d_T=1` 天 |

### 4.2 分析结构

1. **单因素扫描**：`d_alpha`、`d_nu`、`phi_C`、`phi_T` 各自变化，其余取基线；输出 `C52`、峰值、`R0`。
2. **二维响应面**：收治×安葬、宣传×安葬、宣传×收治；画 `C52` 热力图和 `R0=1` 等值线。
3. **组合网格**：`8×7×4×3 = 672` 组，先按 `R0(beta0)<1` 筛选，再对前 120 组做仿真；施加“不劣于现状”约束后输出推荐方案。
4. **κ 稳健性**：`kappa = 1,2,3,4`，固定 `R0(beta0)=1.356` 反标定 `beta0`，重算临界入院/安葬延迟。
5. **输出**：`Q3_criteria.csv`、`Q3_combinations_*.csv`、`Q3_kappa.csv`、`Fig3-1` 至 `Fig3-5`。

### 4.3 关键结论

- 收治隔离不能消除尸体通道：`alpha -> infinity` 时 `R0` 仍有 0.588；
- 单独安全安葬的临界延迟低于 1 天现实下限，单独不可控；
- 按每日边际效果，安葬约为收治的 2.92 倍；按弹性两者只差约 3.8%；
- 追踪与收治共用同一通道，`(d_alpha=3.5, phi_T=0.2)` 与 `(d_alpha=3.0, phi_T=0)` 数值等价；
- 组合方案中，`d_alpha=4.0 天、phi_C=20%` 对应 `R0≈0.943`、W52 累计约 4174 例；`d_alpha=5.0 天、phi_C=30%` 对应 `R0≈0.904`、约 3849 例。

## 5. Q4：七省元群模型

### 5.1 结构

- 7 个省：Ituri、Nord-Kivu、Haut-Uele、Tshopo、Sud-Kivu、Bas-Uele、Sud-Ubangi；
- 每个省复制 `S,E,I,Q,R,D,M`；
- 仅 `S,E,I,R` 跨省流动；`Q,D` 留在本地；
- 邻接权重矩阵 `W` 行归一化，基线流动强度 `m=1.5%/周`；
- 收治容量：`alpha_j* = alpha(1+r_j)*min(1, K_j/(I_j+Q_j))`；
- 环围接种：省级有效保护比例 `rho=10%`，以 `(1-rho)` 折减感染力；
- 前推 24 周，10 个情景 A–J。

### 5.2 情景与结果

| 情景 | 参数变化 | 24 周累计病例（约） |
|---|---|---|
| A 当前拟合控制 | 后期参数 | 32.6 万 |
| C 仅资源调度 | 收治率 +100% | 2.47 万 |
| D 仅安全安葬 | `nu` +100% | 3.13 万 |
| E 仅环围接种 | `rho=10%` | 7.15 万 |
| F 反弹、无行动 | `beta` +15%，`Re≈1.018` | 387.7 万 |
| G 反弹、仅交通管制 | F + `m` 降至 30% | 496.5 万 |
| H 反弹、仅资源调度 | F + 收治率 +100% | 5.04 万 |
| I 反弹、仅安全安葬 | F + `nu` +100% | 15.8 万 |
| J 反弹、组合包 | F + `m=40%`、`nu` +50%、收治 +60%、`rho=10%`、`phi=10%` | 1.61 万 |

> 以上为确定性情景量级，不是病例预报；reference 也明确说明流动矩阵是邻接代理，不是实测 OD。


## 6. 运行顺序与数据流

```powershell
cd d:\MATHmodelAmericaschool2027\ws\src\matlab

q1_model              # Q1 基线
q2_fit                # Q2 主拟合
q2_fit_appendix       # Q2 附录版拟合（可选）
q3_interventions      # Q3 干预分析
q4_metapopulation     # Q4 七省元群
```

数据流：

```text
ws/old/data/outbreak_data.xlsx
   ├─ Sheet 2 (01b_两套序列对比) -> load_data -> q1_model / q2_fit
   └─ Sheet 4 (02b_卫生区快照_1014) -> load_data -> province_table

Optional tracker source (disabled by default, useTracker=false):
ws/old/data/ebola_tracker/ebola_daily_to_20261025.xlsx   (daily table)
ws/old/data/ebola_tracker/ebola-drc-database-20261108.csv   (raw, 9,152 rows)
   ├─ national_weekly_20261108.csv -> load_data (useTracker=true)
   └─ province_latest_20261108.csv -> load_data (useTracker=true)

Q3/Q4 使用脚本内 reference W41/7 省参数，不读取 tracker。
所有输出写入 ws/old/outputs/matlab/。
```

输出文件：

```text
ws/old/outputs/matlab/
├── q1_baseline.csv
├── fig_q1_baseline.png
├── fit_parameters_matlab.csv
├── fit_observations_matlab.csv
├── fit_metrics_matlab.json
├── fit_result_matlab.mat
├── fig_fit_matlab.png
├── q2_appendix_parameters.csv
├── q2_appendix_observations.csv
├── fig_q2_appendix_fit.png
├── Q3_criteria.csv
├── Q3_combinations_by_effect.csv
├── Q3_combinations_by_cost.csv
├── Q3_combinations_robust.csv
├── Q3_kappa.csv
├── Fig3-1_one_factor.png ... Fig3-5_kappa.png
├── Q4_scenario_results.csv
├── Q4_total_cases.png
└── Q4_provincial_burden.png
```

> 当前工作区已生成 Q1、Q2、Q2 附录、Q3 criteria/Fig3-1–3-4、Q4 全部输出；Q3 的 `Q3_combinations_*.csv`、`Q3_kappa.csv` 和 `Fig3-5` 需要完整运行 Q3 才会生成。

## 7. 旧版备注（reference docx 附录）

### 7.1 旧版是什么

旧版指 `ws/old/referrence/计算机学院微分方程综合实验3.docx` 的正文与附录代码。它的定位是**课程实验报告**，不是 A 题论文：

- 4 个问题：Q1 建模、Q2 拟合、Q3 干预、Q4 七省元群；
- 数据截至 `2026-10-11`，W41，7 省 65 区，9066 例/4381 死；当前 tracker 数据已更新到 `2026-11-08`，W45，8 省 67 区，10,990/5,354；
- 模型没有医院传播项，`Q` 假设不传染；
- 只有 `beta` 在 W32 两段常数，`alpha、nu、sigma、gamma` 固定；
- 只有四类干预，没有院感、疫苗、治疗、PEP；
- Q4 只有 7 省、没有跨境肯尼亚/尼日利亚/乌干达；
- 没有参数置信区间、全局敏感性、成本/资金缺口；
- 报告格式是课程实验报告，不是 MCM 的 25 页/一页摘要/目录/AI 报告格式。

### 7.2 本次整理做了什么

| 项目 | 旧版（docx 附录） | 当前整理版 |
|---|---|---|
| 编码 | 含中文注释、中文图例、中文场景名 | `.m` 文件统一 ASCII；中文说明移到本 md |
| 数据源 | 旧工作簿 W25–W41、7 省 65 区 | 旧工作簿为 active；tracker W25–W45、8 省 67 区仅作辅助对照（`useTracker=false`） |
| Q2 | 自包含脚本，硬编码观测 | `q2_fit_appendix.m` 改用 `load_data`/`default_params`，保留 5 参数写法 |
| Q3 | 脚本末尾 `End`（大写，易报错） | 改为 `end` |
| 输出路径 | 当前工作目录 | 统一写入 `ws/old/outputs/matlab/` |
| Q4 场景名 | 中文 | 英文 ASCII |
| Q4 图日期格式 | 中文 `MM月dd日` | `MM-dd` |
| Q1 | 只有函数，没有演示脚本 | 新增 `q1_model.m` |
| 文件组织 | 附录里三段代码 | `q1_model.m`、`q2_fit_appendix.m`、`q3_interventions.m`、`q4_metapopulation.m` 四个脚本 + 原有函数 |
| 结果 | reference 表 6–12 | 方程/参数/数值不变；Q4 已实际运行，结果与表 12 一致 |

### 7.3 没有改的部分

- SEIQRD 方程、`lambda`、R0 公式；
- Q2 的加权最小二乘目标函数和 τ 网格；
- Q3 的四类干预映射、672 组合网格、κ 稳健性；
- Q4 的七省、邻接矩阵、1.5%/周流动、容量上限、环围接种近似、10 个情景；
- Q3/Q4 保留 reference 的 W41/7 省基线参数；Q1/Q2 也使用同一旧工作簿 W25–W41 数据与 reference fit。tracker W25–W45 仅作辅助对照。

### 7.4 旧版本身的已知局限

1. 只有 7 省、省级分辨率，没有 8 省 66 区；
2. `Q` 不传染，没有医院/院内传播；
3. `beta` 只有一个变点，其他参数不随时间变化；
4. 没有疫苗 `V`、治疗 `T`、PEP 状态；
5. Q3 是“从 W25 起就到位”的静态反事实，不是“现在加码”的动态反事实；
6. `phi_T` 基线取 0，与 A 题“随访率约 78%”不是同一个量；
7. Q4 环围接种是省级 `(1-rho)` 折减，不是真正的接触者环；
8. 没有跨境节点、边境筛查/检疫、输入病例持续传播概率；
9. 没有参数置信区间/全局敏感性/成本模型/资金缺口；
10. 课程报告格式，不符合 MCM 25 页、一页摘要、目录、AI 报告要求。

## 8. 与当前 A 题的差距（下一版要补）

> 条目级差距见下表；**完整的适配方案（方程、数据口径、拟合、8 类干预、跨境、SA、成本、分阶段计划）见 `ws/docs/A_PROBLEM_ADAPTATION.md`**。本节保留为速查，具体改动以该文为准。

| A 题要求 | 当前版状态 | 下一版建议 |
|---|---|---|
| 医院传播 | 缺失（`Q` 不传染） | 加 `betaH*Q` 项（等效院内传播）或 `H` 仓室；用 HCW 269 例/47 死校准 |
| 时变参数 | 只有 `beta` 两段常数 | 加 `beta(t)、alpha(t)、nu(t)、kappa_Q(t)` |
| 8 省 66/67 区 | Q1-Q4 仍是 7 省基线；tracker 仅辅助 | 把 active 版本扩到 8 省 66/67 区 |
| 跨境肯尼亚/尼日利亚/乌干达 | 缺失 | 加跨境节点、流动矩阵、边境筛查/检疫 |
| 8 类干预 | 只有 4 类 | 加院感、疫苗、MBP134/瑞德西韦、奥贝德西韦 PEP |
| 干预时机（2073 vs 10060） | 缺失 | 重建 W29/W43 状态，做早/晚干预平行世界 |
| 随访 78%→90%/95% 资源 | 缺失 | 建随访率→有效追踪→传播减少+成本映射 |
| 全局敏感性/不确定性 | 只有 OAT + κ | LHS/Sobol/PRCC + bootstrap/profile likelihood |
| 成本/资金缺口/执行摘要 | 缺失 | 加单位成本、资源需求、>4 亿美元缺口、捐助方摘要 |
| 25 页 MCM 格式 | 课程报告 | 重排摘要页/目录/参考文献/AI 报告 |

## 9. 已知问题与运行注意

1. **数据源状态**：旧版数据源 = `ws/old/data/outbreak_data.xlsx`（W25–W41，7 省，9,066/4,381）；`load_data` 中 `useTracker=false`。tracker `ws/old/data/ebola_tracker/`（2026-11-08，8 省/67 区，10,990/5,354）只作辅助；改成 `useTracker=true` 才读取 W25–W45。
2. **Q3 是 reference 基线**：Q3 脚本内参数/初值仍是 W41、7 省（1.298/0.847、1.244/0.235），`Q3_criteria.csv` 的解析值是 reference 值（`d_alpha_crit=2.59`、`d_nu_crit=0.788`、`phiC_crit=26.3%`、`phiT_crit=65.6%`、`R0=1.356/0.885`）。
3. **Q4 是 reference 基线**：`Q4_scenario_results.csv` 是 7 省、W41 初值、reference 参数的结果。
4. **MATLAB 版本**：代码使用 `ode15s`、`exportgraphics`、`turbo`、`xline/yline`、`sgtitle`，建议 R2020b 及以上；本机 R2025b 的 `checkcode` 通过。
5. **Q2 附录版**：`nu` 的上下界只差 `2e-6`，是“显式固定”的写法，不是自由估计；主结果仍以 `q2_fit.m` 为准。
6. **Q4 环围接种**：`ring=s.vax*(I+Q>0)` 是省级近似，不是接触者环；A 题需要改成按接触者圈层/卫生区。
7. **数据口径**：旧工作簿 W25 是 WHO 回顾 1193/535；tracker W25 是 INSP 日度 1048/267。当前 active 模型使用旧工作簿，tracker 只用于对照，两套序列不要混用。

## 10. 建议的下一步

1. 确认 `ws/old/data/outbreak_data.xlsx` 的旧版 W25–W41 数据源（`useTracker=false`）可用，先跑通 `q1_model` 和 `q2_fit`；
2. 在 `q1_model`/`simulate_seiqrd` 上增加医院传播项和时变参数；
3. 把 Q3 的四类干预扩成 A 题的八类，加时机/资源/成本；
4. 把 Q4 的 7 省扩成 8 省 66 区 + 肯尼亚/尼日利亚/乌干达；
5. 加 bootstrap/profile likelihood 与 LHS/Sobol/PRCC；
6. 最后按 MCM 25 页格式重写论文与执行摘要。

