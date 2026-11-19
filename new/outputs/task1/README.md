# new/outputs/task1：Task 1 校验与 R0 回归

由 `ws/new/code/task1_checks.m` 生成（2026-11-19）：

| 文件 | 内容 |
|---|---|
| `T1_checks.csv` | 6 项检查：legacy R0 输出、legacy 谱半径、新模型早/晚谱半径、三通道非负、日速率单位 |
| `T1_R0_regression.csv` | legacy 与新版三通道的 `R0_formula / R0_spectral / R0_reference` 对照 |

当前结果：**6/6 PASS**。

关键数值：

| 场景 | 公式 R0 | 数值谱半径 | 参考 |
|---|---:|---:|---:|
| legacy early | 1.355789887 | 1.355789887 | 1.355789887（旧输出） |
| legacy late | 0.884312117 | 0.884312117 | 0.884312117（旧输出） |
| new early | 1.341443500 | 1.341443500 | — |
| new late | 1.142720773 | 1.142720773 | — |

状态转移图：`ws/docs/SEIQRD_状态转移图.png`，由
`ws/new/code/task1_state_diagram.py` 生成。
