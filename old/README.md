# old：旧题 / 旧数据 / 旧代码 / 旧结果（已冻结）

本目录保存整理前的课程实验版本，**不再修改**。它有两个用途：

1. 保留旧题（SEIQRD、W25–W41、7 省）的可复现记录；
2. 作为新代码的 legacy 回归基线：`load_data(false)` 必须仍能读出
   W25 的 1,193 / 535 和 W41 的 9,066 / 4,381，且初值仍为
   `Q0=196、I0=350、R0=112、E0=300、D0=20`。

## 目录结构

```text
old/
├── code/
│   ├── README.md            旧代码说明
│   └── matlab/              13 个 .m 文件
├── data/
│   ├── README.md            旧数据说明
│   ├── outbreak_data.xlsx   W25–W41、7 省、9,066/4,381
│   └── ebola_tracker/       2026-11-08 及更早的 tracker 归档（22 个文件）
├── outputs/
│   ├── README.md            旧结果说明
│   └── matlab/              旧 Q1–Q4 输出（18 个文件）
└── referrence/
    └── 计算机学院微分方程综合实验3.docx
```

## 旧版的核心结论（仅供对照，不要直接写进新论文）

- 模型：SEIQRD 六仓室 + 累计死亡 `M`；`Q` 不传染；感染力为
  `βS(I+κD)/N`；`β` 只有 W32 前后两段常数。
- 拟合：`β0/β1 = 1.298/0.847`，`α = 1.244`，`μ = 0.235`，
  `R0 = 1.356/0.885`，`R² = 0.9995/0.9913`。
- 干预：只有 4 类；Q3 的临界值为 `d_α* = 2.59 天`、`d_ν* = 0.79 天`、
  `φ_C* = 26.3%`、`φ_T* = 65.6%`、`κ* = 4.34`。
- 空间：7 省元群、24 周、10 个情景。

这些结论都建立在“无院内传播 + 旧基线”上，**不能直接用于新题**。
新题需要重新计算，差异和改法见 `ws/docs/A_PROBLEM_ADAPTATION.md`。

## 运行旧代码

```powershell
cd d:\MATHmodelAmericaschool2027\ws\old\code\matlab

q1_model
q2_fit
q2_fit_appendix
q3_interventions   # 计算量大（约 1,900 次 ODE 仿真）
q4_metapopulation
```

旧代码的根目录按“上三级 = `ws/old`”计算：

- 数据：`ws/old/data/outbreak_data.xlsx`
- 结果：`ws/old/outputs/matlab`

因此旧代码不需要改路径即可运行。
