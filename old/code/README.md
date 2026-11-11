# old/code：旧 MATLAB 实现（已冻结）

本目录保存旧课程实验的 MATLAB 代码，**不再修改**。它只用于：

1. 复现旧题结果；
2. 作为新代码的 legacy 回归基线。

新代码全部在 `ws/new/code/`，不要在这里继续开发。

## 文件清单

```text
old/code/
├── README.md
└── matlab/
    ├── q1_model.m            Q1 基线仿真、R0/Rt、四联图
    ├── q2_fit.m              Q2 主拟合（4 参数，ν 固定）
    ├── q2_fit_appendix.m     Q2 附录版（5 参数，ν 用紧边界固定）
    ├── q3_interventions.m    Q3 单因素、二维响应面、672 组合、κ 稳健性
    ├── q4_metapopulation.m   Q4 七省元群：流动、容量、环围接种、10 情景
    ├── simulate_seiqrd.m     SEIQRD 积分、Rt、峰值
    ├── fit_seiqrd.m          τ 网格 + 多初值 + lsqnonlin
    ├── load_data.m           旧工作簿读取（默认 `useTracker=false`）
    ├── default_params.m      基线参数（tracker/旧工作簿两套）
    ├── r0_seiqrd.m           下一代矩阵 R0
    ├── alpha_eff.m           追踪覆盖 → 有效收治率
    ├── delay_to_alpha.m      入院延迟（天）→ 周收治率
    └── nu_from_delay.m       安葬延迟（天）→ 周安葬率
```

## 运行

```powershell
cd d:\MATHmodelAmericaschool2027\ws\old\code\matlab

q1_model
q2_fit
q2_fit_appendix
q3_interventions
q4_metapopulation
```

路径说明：

- 数据读 `ws/old/data/outbreak_data.xlsx`；
- 结果写 `ws/old/outputs/matlab/`；
- 旧代码里的 `root` 是 `mfilename` 往上三级，正好是 `ws/old`，所以无需改代码。

## 旧基线数字

- 窗口 W25–W41（17 个周点），7 省，W41 为 9,066 / 4,381；
- 拟合：`β0/β1 = 1.295/0.845`，`α/μ = 1.238/0.235`；
- `R² = 0.99947/0.99132`，`RMSE = 58.81/118.55/53.46`；
- W43 端点：模型 9,735 / 4,842，观测 10,060 / 4,887。

## 注意

- 旧代码没有院内传播（`Q` 不传染），只有两段 `β` 和 4 类干预；
- 旧 Q3 的临界值和 Q4 的情景数不能直接引用到新题；
- 新题的三通道模型、时变参数、8 类干预、跨境与全局敏感性见
  `ws/docs/A_PROBLEM_ADAPTATION.md`；
- 旧模型的方程与参数细节见 `ws/docs/MODEL_ARCHITECTURE.md`。
