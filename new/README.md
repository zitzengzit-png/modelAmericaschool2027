# new：新题（Problem A）的数据、代码与 P0 结果

## 当前进度

**P0（数据与配置）已完成，2026-11-11。**

- 数据：ebola-tracker.org 2026-11-11 快照（SitRep 179）。
- 最新日 2026-11-09：**11,042 例 / 5,387 死**。
- 周锚点 W25–W45；W45（2026-11-08）为 10,990 / 5,354。
- 8 个省、67 个卫生区，`N = 38,393,224`。
- 拟合 W25–W43（19 点），验证 W44–W45（2 点）。
- P0 验收：**11/11 全部通过**。
- 结果：`ws/new/outputs/p0/`。

## 目录结构

```text
new/
├── code/                  P0 代码（8 个 .m 文件）
├── data/
│   ├── README.md
│   └── ebola_tracker/     2026-11-11 快照 + 3 个共享输入
├── outputs/
│   ├── README.md
│   └── p0/                P0 验收输出（4 个文件）
└── ideas/
    └── 埃博拉传播动力学模型_第一问.md
```

## 下一步（P1）

在 `code/` 中实现三通道模型：

- `betaC / betaH / betaF`（人际 / 医院 / 葬礼）；
- `R0` 分解为 `R_c + R_h + R_f`；
- `R_eff(t)`、状态转移图；
- 复用 `config.m`、`load_data.m`、`state_at.m`。

## 相关文档

- 新旧差异、改造清单、P0 记录：`ws/docs/A_PROBLEM_ADAPTATION.md`
- 旧模型方程与参数：`ws/docs/MODEL_ARCHITECTURE.md`
- 新代码说明：`ws/new/code/README.md`
- 新数据说明：`ws/new/data/README.md`
- tracker 数据细节：`ws/new/data/ebola_tracker/README.md`
- P0 结果说明：`ws/new/outputs/README.md`
