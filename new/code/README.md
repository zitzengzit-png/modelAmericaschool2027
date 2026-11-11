# new/code：P0 数据与配置层

本目录是 Problem A 重建的新代码。旧代码在 `ws/old/code/matlab`，已冻结，不要修改。

## 状态

**P0 已完成（2026-11-11）。**

- 数据快照：2026-11-11（SitRep 179），最新日 2026-11-09：11,042 / 5,387；
- 周锚点 W25–W45；
- 拟合 W25–W43，验证 W44–W45；
- 8 省、67 区、`N = 38,393,224`；
- 验收 11/11 全部通过。

## 文件清单

| 文件 | 作用 |
|---|---|
| `config.m` | 唯一配置入口：数据源、拟合/验证窗口、模型开关、所有路径 |
| `load_data.m` | 优先读 tracker；保留 legacy 分支；8 省/67 区；响应、跨境、HCW；锚点断言 |
| `state_at.m` | 在任意周重建 `[S;E;I;Q;R;D;M]`，并记录每个分量的来源标记 |
| `build_tracker_snapshot.m` | 原始 tracker CSV → 周表、省表、区表、respond 表 |
| `refresh_tracker_data.m` | 下载最新原始库 + 字典 + 页面指标，并重建快照 |
| `fetch_response_page.m` | 解析数据页面的六项响应指标 |
| `latest_tracker_file.m` | 按文件名中的 8 位日期选最新快照 |
| `p0_check.m` | P0 验收：锚点、守恒、省/区、legacy 回归，并写 `ws/new/outputs/p0` |

## 运行

```powershell
cd d:\MATHmodelAmericaschool2027\ws\new\code

p0_check                 # 验收，并更新 ws/new/outputs/p0
refresh_tracker_data     # 可选：重新抓取并生成新日期快照
```

`refresh_tracker_data` 需要联网；它不会删除旧快照，只会新增
`<name>_<YYYYMMDD>.csv`，`load_data` 自动选最新日期。

## 数据选择规则

- 数据源：`ws/new/data/ebola_tracker/national_weekly_<日期>.csv` 中最新的一个；
- 拟合窗口：W25–W43（19 点），由 `cfg.fitWindow` 控制；
- 验证窗口：W44–W45（2 点），由 `cfg.holdout` 控制；
- 锚点断言：W25 = 1,048/267，W43 = 10,060/4,887，W45 = 10,990/5,354；
- 8 个省（含 Nord-Ubangi），总人口 38,393,224；
- 67 个卫生区（59 个有人口）；
- 响应指标来自数据页面；跨境来自 `cross_border_latest_20261108.csv`；
- HCW 序列来自 `legacy_weekly_supplement_W29-W41.csv`。

## `state_at` 的重建规则

```text
C, M  直接取累计序列
R     累计康复；缺失时沿用上一个有效值（W25–W31 为空，因此为 0）
Q     有 etc_admitted 时用它；否则用 isolationRatio × (C-M-R)
I     max(C - M - Q - R, 0)          => I+Q+R+M = C 严格成立
E     周新增 / sigma（legacy 模式用固定 W25 值）
D     安葬延迟(天)/7 × 周死亡
S     N - E - I - Q - R - M          => 守恒严格成立
```

每个分量都带来源标记：

- `q_source`：`etc_admitted` / `isolation_ratio` / `fixed`；
- `r_source`：`observed` / `carried_forward` / `assumed_zero`；
- `e_source`、`d_source`：`reconstructed` / `fixed`。

## P0 验收结果

11 项全部 PASS：

- W25 / W43 / W45 三个锚点精确匹配；
- `S+E+I+Q+R+M = N`、`I+Q+R+M = C` 误差为 0；
- 8 省人口合计 38,393,224；11/09 省合计 11,042 / 5,387；
- 67 个卫生区，59 个有人口；
- 跨境 4 国（肯尼亚 9、尼日利亚 1、乌干达 20、法国 1）；
- legacy 回归：W25 1,193/535、W41 9,066/4,381、`Q0=196, I0=350`；
- 2,073 例锚点：W28（1,963，07-12）–W29（2,423，07-19），插值约 07-13。

## 数据注意事项

- tracker 的 `recovered` 在 W25–W31 为空（W32 起才有 869）；
  `state_at` 按 0 处理并标记 `assumed_zero`，会抬高早期 `I`；
  早期 `R` 应作为 P1/P2 的情景假设。
- 旧代码的 `R0=360` 实际是 `etc_admitted`，不是累计康复；P0 已修正。
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；W25 为 360，
  W45 为 882（11/09 为 904）。
- W30/W31 原始周新增含 catch-up（W30：839 vs 470）；W44 死亡含
  Ituri 校正；周新增用 `new_*_adj`，累计水平用累计序列。
- 卫生区死亡合计 4,894 ≠ 国家 5,387；493 例未分配，区级只建模病例。
- Nord-Ubangi 人口为 150 万估计，不是 WorldPop 分区和。

## 下一步（P1）

在同一个目录实现三通道模型：

- `betaC / betaH / betaF`；
- `R0 = R_c + R_h + R_f`；
- `R_eff(t)` 与状态转移图；
- 仍复用 `config / load_data / state_at`。

规划文档见 `ws/docs/A_PROBLEM_ADAPTATION.md`。
