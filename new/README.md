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

## 目录结构

```text
new/
├── code/                  P0/P1/P2/Task1 代码（27 个 .m + 1 个 .py）
├── data/
│   ├── README.md
│   └── ebola_tracker/     2026-11-11 日表/周表/省日表 + 共享输入
├── outputs/
│   ├── README.md
│   ├── p0/                P0 验收输出（4 个文件）
│   ├── p1/                P1 拟合输出（6 个文件）
│   ├── p2/                P2 不确定性输出（24 个文件，含 README）
│   └── task1/             Task 1 R0 回归与校验（2 个 CSV + README）
└── ideas/
    └── 埃博拉传播动力学模型_第一问.md
```

## 下一步（Task 3）

- 8 类干预的单因素与组合情景；
- 疫情持续时间定义与输出；
- 7 月中旬（2,073 例）vs 当前（10,060 例）的时机反事实；
- 随访率 78%→90%/95% 的资源需求与传播减少量；
- 之后进入 Task 4 空间/跨境扩展。

## 相关文档

- 新旧差异、改造清单、P0/P1/P2 记录：`ws/docs/A_PROBLEM_ADAPTATION.md`
- 第一问模型与 R0 推导：`ws/docs/要求一建模.md`
- 旧模型方程与参数：`ws/docs/MODEL_ARCHITECTURE.md`
- 新代码说明：`ws/new/code/README.md`
- 新数据说明：`ws/new/data/README.md`
- tracker 数据细节：`ws/new/data/ebola_tracker/README.md`
- P0/P1/P2/Task1 结果说明：`ws/new/outputs/README.md`
- P2 结果细节：`ws/new/outputs/p2/README.md`
