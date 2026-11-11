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

**P1（日尺度三通道模型 + 6 参数拟合）已完成，2026-11-11。**

- 日 R²≈0.997/0.993，周 R²≈0.997/0.995。
- holdout 病例 MAPE≈3.0%，死亡 MAPE≈0.5%。
- R0 早期 1.342，后期 1.144（Rc/Rh/Rf 分解）。
- 结果：`ws/new/outputs/p1/`。

## 目录结构

```text
new/
├── code/                  P0/P1 代码（日尺度，15 个 .m）
├── data/
│   ├── README.md
│   └── ebola_tracker/     2026-11-11 日表/周表/省日表 + 共享输入
├── outputs/
│   ├── README.md
│   ├── p0/                P0 验收输出（4 个文件）
│   └── p1/                P1 拟合输出（6 个文件）
└── ideas/
    └── 埃博拉传播动力学模型_第一问.md
```

## 下一步（P2）

- 7–14 天块 bootstrap；
- `ρRep`、`α0`、`u1` 的 profile likelihood；
- `ρh0/ρf0` 敏感性（0.3–0.5 / 2.86–3.83）；
- 第三节点/反弹约束的 AIC/BIC 比较；
- 之后进入 Task 3 干预与 Task 4 空间扩展。

## 相关文档

- 新旧差异、改造清单、P0 记录：`ws/docs/A_PROBLEM_ADAPTATION.md`
- 旧模型方程与参数：`ws/docs/MODEL_ARCHITECTURE.md`
- 新代码说明：`ws/new/code/README.md`
- 新数据说明：`ws/new/data/README.md`
- tracker 数据细节：`ws/new/data/ebola_tracker/README.md`
- P0 结果说明：`ws/new/outputs/README.md`
