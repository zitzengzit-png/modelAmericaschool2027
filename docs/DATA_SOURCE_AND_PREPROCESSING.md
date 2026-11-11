# 数据来源与预处理方法（Task 2）

> **版本**：v1.0（2026-11-11，日尺度）
> **适用范围**：Problem A 的 Task 2 数据侧；P0 数据层、P1 日尺度模型和后续空间模型共用。
> **配套文档**：`ws/docs/数据处理方案确定.md`（参数化与拟合方案）、
> `ws/docs/A_PROBLEM_ADAPTATION.md` 第 11 节（日尺度标准）。
>
> **一句话**：主数据来自 ebola-tracker.org 对 INSP 疫情简报的日度汇编；
> P0 把原始库整理成 142 天日表、21 个周日校验表、8 省日表和 67 区最新快照，
> 并用 6/21、10/25、11/09 三个日锚点、日→周 0 差异和守恒检查锁定口径。

---

## 0. 结论摘要

| 项目 | 内容 |
|---|---|
| 主数据源 | ebola-tracker.org DRC 数据库（基于 INSP SitReps） |
| 抓取日期 | 2026-11-11 |
| 最新简报 | SitRep **179**，最新日 **2026-11-09** |
| 原始规模 | **9,228 行**：国家 172、省 913、区 8,143 |
| 日表 | 2026-06-21 至 2026-11-09，共 **142 天** |
| 拟合/验证 | 拟合 6/21–10/25（127 天）；验证 10/26–11/09（15 天） |
| 空间范围 | 8 省、67 个卫生区；`N = 38,393,224` |
| 日锚点 | 6/21 = 1,048/267；10/25 = 10,060/4,887；11/09 = 11,042/5,387 |
| 周校验 | 21 个周日锚点，与日表 **0 差异** |
| 质量标记 | `observed / missing_day_locf / special_report / negative_revision` |
| 许可 | CC BY 4.0（Ebola Tracker；INSP 公报受 INSP 条款约束） |

---

## 1. 数据来源

### 1.1 主数据源

- 数据页：<https://ebola-tracker.org/en/database/>
- 原始 CSV：<https://ebola-tracker.org/data/ebola-drc-database.csv>
- 字段字典：<https://ebola-tracker.org/data/ebola-drc-database-dictionary.csv>
- 响应指标页：<https://ebola-tracker.org/en/data/>
- 最新 SitRep：**N°179，2026-11-09**；抓取日期：**2026-11-11**
- 引用格式：

> Ebola Tracker (ebola-tracker.org), database of the Bundibugyo Ebola outbreak
> in the DRC, based on the situation reports of the National Institute of Public
> Health (INSP), accessed 11 Nov 2026. CC BY 4.0.

**说明**：本工作区保存的是 ebola-tracker.org 的**汇编 CSV**，不是 INSP 原始 PDF。
论文中应写“数据来自 ebola-tracker.org 对 INSP SitReps 的汇编”，不要声称直接
下载了全部 INSP 原始简报。

### 1.2 本目录中的来源文件

| 文件 | 内容 | 行数/规模 |
|---|---|---|
| `ebola-drc-database-20261111.csv` | 原始库，国家/省/区三级 | 9,228 行 |
| `ebola-drc-database-dictionary-20261111.csv` | 字段字典 | 28 列定义 |
| `national_daily_20261111.csv` | 日表（主数据） | 142 行 |
| `province_daily_20261111.csv` | 省 × 日表 | 1,136 行 |
| `national_weekly_20261111.csv` | 周日校验表 | 21 行 |
| `province_latest_20261111.csv` | 8 省最新快照 | 8 行 |
| `health_zone_latest_20261111.csv` | 67 区最新快照 | 67 行 |
| `response_latest_20261111.csv` | 页面六项指标 | 6 行 |
| `snapshot_metadata_20261111.json` | 机器可读元数据 | — |

### 1.3 辅助输入（当前最新可用）

| 文件 | 用途 | 说明 |
|---|---|---|
| `cross_border_latest_20261108.csv` | 肯尼亚 9、尼日利亚 1、乌干达 20、法国 1 | 页面快照，非历史序列 |
| `legacy_weekly_supplement_W29-W41.csv` | 医护、床位、在隔序列 | 用于 βh 下界/院感锚定 |
| `zone_summary_to_20261025.csv` | 66 区人口（59 个有值） | 区级人口合并 |

### 1.4 旧数据（只做回归，不混用）

- `ws/old/data/outbreak_data.xlsx`：W25–W41、7 省、9,066/4,381；
- `ws/old/data/ebola_tracker/`：2026-11-08 及更早的 tracker 归档。

旧代码 `ws/old/code/matlab` 使用旧工作簿；新代码只使用 `ws/new/data/ebola_tracker/`。
**两套序列不能混用**：tracker W25 = 1,048/267，旧工作簿 W25 = 1,193/535。

---

## 2. 数据范围与字段口径

### 2.1 空间与时间范围

| 维度 | 取值 |
|---|---|
| 日表窗口 | 2026-06-21 至 2026-11-09（142 天） |
| 拟合窗口 | 2026-06-21 至 2026-10-25（127 天） |
| 验证窗口 | 2026-10-26 至 2026-11-09（15 天） |
| 省 | 8 个：Ituri、Nord-Kivu、Haut-Uele、Tshopo、Bas-Uele、Nord-Ubangi、Sud-Kivu、Sud-Ubangi |
| 卫生区 | 67 个（2026-10-25 为 66 个，第 67 个在此后出现） |
| 总人口 | `N = 38,393,224`（7 省 WorldPop 2026 + Nord-Ubangi 150 万估计） |

### 2.2 原始字段与含义

| 字段 | 含义 | 单位 | 使用注意 |
|---|---|---|---|
| `date` | 简报日期 | 日期 | 国家/省/区三级共用 |
| `level` | 行级别 | — | `country / province / zone`，**三级会重叠，求和前必须过滤** |
| `province` | 省名 | — | 省级/区级行有值 |
| `zone` | 卫生区名 | — | 区级行有值 |
| `sitrep` | 简报号 | — | 最新 179 |
| `cases` | 累计确诊 | 人 | 含已死亡确诊 |
| `new_cases` | 日新增 | 人/日 | 由累计差分；负数表示向下修订 |
| `days_covered` | 差值覆盖天数 | 天 | >1 表示补报/跨天 |
| `deaths` | 累计死亡 | 人 | 含社区与 ETC 死亡 |
| `new_deaths` | 日新增死亡 | 人/日 | 同上 |
| `cfr` | 病死率 | % | 累计死亡/累计确诊 |
| `recovered` | 累计康复 | 人 | 仅国家级；W25–W31 为空 |
| `community_deaths` | 当日社区死亡 | 人/日 | 2026-07-13 起 |
| `etc_deaths` | 当日 ETC 内死亡 | 人/日 | 2026-07-13 起 |
| `alerts_received` | 当日收到警报 | 个/日 | 响应指标 |
| `alerts_validated` | 当日核实警报 | 个/日 | 响应指标 |
| `lab_samples` | 当日检测样本 | 份/日 | 多数日期为空 |
| `lab_positives` | 当日阳性 | 份/日 | 用于阳性率 |
| `etc_admitted` | ETC 住院人数 | 人 | **库存，不是确诊隔离人数** |
| `etc_beds` | ETC 床位 | 张 | 部分日期为空 |
| `etc_occupancy` | 床位占用 | % | 部分日期为空 |
| `contacts_to_follow` | 在管接触者 | 人 | 库存 |
| `contacts_seen` | 已随访接触者 | 人 | 当日 |
| `contacts_seen_pct` | 随访率 | % | 公报值 |
| `vaccinated_total` | 累计接种 | 人 | 省级、部分日期 |
| `note` | 行标记 | — | catch-up / harmonisation / reconstructed / WHO manual |
| `source_pdf` | 简报 PDF 地址 | — | 部分行为空 |

### 2.3 关键口径（必须写进论文）

1. **三级行会重叠**：国家、省、区三级不能直接相加；必须先按 `level` 过滤。
2. **累计确诊含死亡**：`cases` 包含已死亡确诊，因此模型 `C=I+Q+R+M` 与数据口径一致。
3. **`etc_admitted` 不是 `Q`**：它是 ETC 住院人数（库存，可能含疑似），
   模型 `Q` 是“确诊且在隔离”。P0 在缺失时用隔离比反推，并标记来源。
4. **`recovered` 只有国家级**，且 W25–W31 为空；模型 `R` 早期为 0 是假设，
   不是观测。
5. **卫生区死亡不完整**：67 区死亡合计 4,894，国家 5,387，**493 例未分配**；
   区级只建模病例，死亡在省级校准。
6. **`community_deaths` / `etc_deaths` 从 2026-07-13 开始**；此前为空。
7. **`vaccinated_total` 只有省级、部分日期**；不能当全国日序列。
8. **`N` 含估计值**：Nord-Ubangi 人口为 150 万估计，不是 WorldPop 分区和。
9. **as-of 日期不完全一致**：省/区最新快照为 11/09，响应指标为 11/11 页面值；
   论文中要分别标注。

---

## 3. 预处理流程

### 3.1 总流程

```text
ebola-drc-database-20261111.csv（原始 9,228 行）
        │
        ├─ 日表 national_daily（142 天）
        │     ├─ 缺失日 LOCF
        │     ├─ 累计值 → 日差分 → 7 日均值
        │     └─ flag：observed / missing / special / negative
        │
        ├─ 周表 national_weekly（21 个周日，仅校验）
        │
        ├─ 省日表 province_daily（8 × 142 = 1,136 行）
        │
        ├─ 省最新 province_latest（8 行）
        ├─ 区最新 health_zone_latest（67 行）
        └─ 响应指标 response_latest（6 行，页面值）
```

### 3.2 日表（主数据）

文件：`national_daily_20261111.csv`，142 行。

步骤：

1. **建完整日历**：从 2026-06-21（W25 周日）到 2026-11-09，共 142 天；
2. **取国家行**：每个日期取 `level=country` 的最后一条有效行；
3. **缺失日**：无国家行的日期，累计值按 **LOCF**（沿用上一天），
   `flag=missing_day_locf`；
4. **累计值**：`cum_confirmed`、`cum_deaths` 直接取当日累计；
5. **日新增**：`new_confirmed = diff(cum_confirmed)`，
   `new_deaths = diff(cum_deaths)`；
6. **7 日均值**：`new_*_7d = movmean(new_*, [6 0])`，用于状态重建；
7. **其他字段**：`recovered`、`etc_admitted` 按日，缺失 LOCF；
   `community_deaths`、`etc_deaths`、`alerts_*`、`lab_*`、`contacts_*`、
   `vaccinated_total` 按日保留；
8. **flag**：
   - `observed`：当日有国家行；
   - `missing_day_locf`：当日缺报；
   - `special_report`：`note` 含 catch-up 或 harmonisation；
   - `negative_revision`：当日累计值被下调。

### 3.3 周表（仅聚合校验）

文件：`national_weekly_20261111.csv`，21 行（W25–W45）。

步骤：

1. 每个周日取“日期 ≤ 周日且病例/死亡均非空”的最后一条国家行；
2. `new_*` 与上一个周锚点相减；
3. `new_*_adj` 对该周每日 `new_*` 求和，剔除 `note` 含 `catch-up` 或
   `harmonisation` 的行；
4. `recovered`、`etc_admitted`、`etc_beds`、`contacts_*`、`vaccinated_total`
   取锚点行；
5. 只写完整周日；W46 尚未完整，不进入周表。

**校验**：用 2026-11-08 原始库回算，周表与旧
`national_weekly_20261108.csv` **逐位一致（0 差异）**。

**累计值不要用调整值累加**：

- 确诊：W25→W45 累计差 9,942；`new_confirmed_adj` 合计 9,452（少 490）；
- 死亡：累计差 5,087；`new_deaths_adj` 合计 4,749（少 338）。

因此：累计水平用累计序列；`new_*_adj` 只做周诊断。

### 3.4 省日表

文件：`province_daily_20261111.csv`，8 省 × 142 天 = 1,136 行。

步骤：

1. 按省过滤省级行；
2. 对每个省、每个日期取当日值；
3. 缺失日期按省做 LOCF；
4. 计算 `new_confirmed`、`new_deaths`（省内累计差分）；
5. 保留 `population`、`vaccinated_total`，其余字段不进省日表。

### 3.5 省/区最新快照

**省**：`province_latest_20261111.csv`（8 行，截至 2026-11-09）

- 累计确诊/死亡、份额、24 小时新增、30 天新增、CFR、受影响区数、总区数；
- 30 天新增 = 当前累计 − 30 天前累计；
- 区数来自最新区表。

**区**：`health_zone_latest_20261111.csv`（67 行，截至 2026-11-09）

- 累计确诊/死亡、24 小时新增、CFR；
- 人口从 `zone_summary_to_20261025.csv` 按“省 + 卫生区”合并（59/66 有值）；
- 区死亡合计 4,894，国家 5,387，**493 例未分配**。

### 3.6 响应指标

文件：`response_latest_20261111.csv`（6 行，截至 2026-11-11 页面）。

| 指标 | 2026-11-11 值 | 口径 |
|---|---:|---|
| `alerts_received` | 27,585 | 最近 7 期警报 |
| `test_positivity` | 12.6% | 最近 7 期阳性率 |
| `contacts_seen` | 79.3% | 最近 7 期随访率 |
| `patients_per_100_beds` | 12 | 最新 |
| `vaccinated_total` | 21,866 | 累计接种 |
| `travellers_screened` | 276,403 | 最近一期筛查 |

说明：

- 六项指标从数据页面解析，`source=data page`；
- 原始库没有 `travellers_screened`，且 `lab_samples` 多数日期为空；
- 这些是“最近 7 期/最新”指标，**不是完整日序列**。

### 3.7 初值状态重建

`ws/new/code/state_at_day.m`：

| 分量 | 规则 |
|---|---|
| `C, M` | 日累计值 |
| `R` | 累计康复；缺失沿用上一个有效值；W25–W31 为空 → 0 |
| `Q` | `etc_admitted`；缺失用 `isolationRatio × (C−M−R)` |
| `I` | `max(C−M−Q−R, 0)` |
| `E` | 日新增（优先 7 日均值）/ `σ_day` |
| `D` | 安葬延迟（天）× 日死亡 |
| `S` | `N − E − I − Q − R − M` |

来源标记：`q_source`、`r_source`、`e_source`、`d_source`。

边界：

- 2026-06-21 的 `E=0、D=0` 是首日边界（没有前一天），`assumed_zero`；
- `R=0` 在 2026-08-09 之前是假设；
- 2026-07-14 正好是 2,073 例（C=2,073；7/13 为 2,011）。

---

## 4. 质量标记与异常处理

### 4.1 日表 flag

| flag | 含义 | 处理 |
|---|---|---|
| `observed` | 当日有国家行 | 直接使用 |
| `missing_day_locf` | 当日无国家行 | 累计值 LOCF；日新增按差分 |
| `special_report` | `note` 含 catch-up / harmonisation | 保留累计值；周诊断剔除 |
| `negative_revision` | 当日累计值被下调 | 标记；不强行修正 |

### 4.2 具体异常日期

| 日期 | 异常 | 影响 |
|---|---|---|
| 2026-06-26 | 缺报 | LOCF |
| 2026-07-16 | 缺报 | LOCF |
| 2026-07-22 | catch-up（多天补报） | 日新增虚高；周诊断剔除 |
| 2026-07-28 | 缺报 | LOCF |
| 2026-07-29 | 缺报 | LOCF |
| 2026-07-30 | catch-up | 日新增虚高；周诊断剔除 |
| 2026-10-30 | harmonisation（Ituri +346 死） | 死亡虚高 |
| 2026-10-31 | harmonisation（−269 死） | 负修订；净 +77 |
| 2026-11-02 | reconstructed（SitRep 142 缺失） | 保留并标记来源 |

### 4.3 其他数据限制

- `recovered` 在 W25–W31 为空（W32 起才有 869）；
- `etc_admitted` 是 ETC 住院人数，不是确诊隔离人数；
- 区死亡合计 4,894 ≠ 国家 5,387（493 例未分配）；
- Nord-Ubangi 人口为 150 万估计；
- 省/区最新快照是 11/09，响应指标是 11/11 页面值；
- `vaccinated_total` 只有省级、部分日期；
- `lab_samples` 多数日期为空，阳性率主要用页面值。

---

## 5. 验证结果

### 5.1 日锚点

| 日期 | 模型数据 | 期望 |
|---|---|---|
| 2026-06-21 | 1,048 / 267 | 1,048 / 267 |
| 2026-10-25 | 10,060 / 4,887 | 10,060 / 4,887 |
| 2026-11-09 | 11,042 / 5,387 | 11,042 / 5,387 |

### 5.2 日 → 周聚合

- 21 个周日锚点与周表逐位一致；
- **最大差异 0 例 / 0 死**。

### 5.3 守恒与恒等

- `S+E+I+Q+R+M = N`：最大误差 **0**；
- `I+Q+R+M = C`：最大误差 **0**。

### 5.4 P0 验收

`ws/new/outputs/p0/P0_checks.csv`：**12/12 PASS**。

### 5.5 legacy 回归

旧工作簿仍可复现：

- W25 = 1,193 / 535；W41 = 9,066 / 4,381；
- `Q0=196, I0=350, R0=112, E0=300, D0=20`。

---

## 6. 可复现性

### 6.1 运行

```powershell
cd d:\MATHmodelAmericaschool2027\ws\new\code

refresh_tracker_data   # 重新下载并生成新日期快照（需要联网）
p0_check               # 重新验收，并更新 ws/new/outputs/p0
```

### 6.2 主要脚本

| 脚本 | 作用 |
|---|---|
| `refresh_tracker_data.m` | 下载原始 CSV + 字典 + 页面指标，调用构建器 |
| `build_tracker_snapshot.m` | 生成日表、周表、省日表、省/区快照、响应表 |
| `load_data.m` | 读取日表，锚点断言，拟合/验证切分 |
| `state_at_day.m` | 日尺度初值状态重建 |
| `p0_check.m` | 12 项验收 |

### 6.3 机器可读元数据

`snapshot_metadata_20261111.json` 记录：

```text
raw_file, max_date,
rows_total=9228, rows_country=172,
rows_province=913, rows_zone=8143,
weekly_rows=21, week_range=[25 45],
daily_rows=142, daily_range=2026-06-21..2026-11-09,
latest_daily, rules.daily
```

---

## 7. 数据限制与论文写法

| 限制 | 影响 | 建议写法 |
|---|---|---|
| 数据来自 ebola-tracker.org 汇编，不是 INSP 原始 PDF | 无法逐条核对原始简报 | 写“based on INSP SitReps, compiled by Ebola Tracker”，不要声称直接下载全部 INSP PDF |
| 未保存数据页 HTML 快照 | 六项指标只能追溯到 CSV 和访问日期 | 写“data page, accessed 11 Nov 2026”，并保留 `response_latest_20261111.csv` |
| 4 个缺失日 | 日表有 LOCF | 明确列出 6/26、7/16、7/28、7/29，并说明 LOCF |
| catch-up / harmonisation | 日新增/死亡有尖峰 | 用 flag 标记；周诊断剔除；累计值保留 |
| `recovered` W25–W31 为空 | 早期 `R` 是假设 | 明确 `R=0` 是 assumption，不是 observation |
| `etc_admitted` 不是确诊隔离 | `Q` 口径偏差 | 写“ETC hospitalisation, used as a proxy for the isolated stock” |
| 493 例死亡未分配 | 区死亡合计偏低 | 写“zone deaths sum to 4,894; 493 deaths are reported only at province level” |
| Nord-Ubangi 人口为估计 | `N` 有不确定性 | 写“1.5 million estimate; N has negligible effect on R0” |
| 省/区快照 11/09，响应指标 11/11 | as-of 不一致 | 分别标注日期 |
| 报告延迟/漏报 | 模型 C 与报告确诊不等 | 引入 `ρ_rep` 与延迟核；CFR 只做软约束 |
| 没有区日表/OD 矩阵 | 区级时空模型只能做情景 | 明确“zone-level analysis is scenario-based” |
| 响应指标不是日序列 | 不能逐日拟合 | 只作 P1/P3 的情景锚点或先验 |

---

## 8. 论文用简版

### 8.1 中文版（可直接改写）

> 数据来自 Ebola Tracker 数据库（ebola-tracker.org，访问日期 2026-11-11），
> 该库汇编刚果（金）国家公共卫生研究院（INSP）的每日疫情简报。所用快照对应
> SitRep 179（2026-11-09），包含国家、省、卫生区三级共 9,228 条记录。我们构建了
> 2026-06-21 至 2026-11-09 的完整日序列（142 天）：每个日期取最后一条有效的国家行，
> 4 个缺失日（6/26、7/16、7/28、7/29）用 LOCF 补齐；累计确诊和死亡直接使用，
> 日新增由一阶差分得到，并计算 7 日滑动均值。对 7/22、7/30 的补报，10/30–31 的
> Ituri 死亡校正，以及 11/02 的重建日，均保留来源标记。周表只用于校验：21 个周日
> 锚点与公布值逐位一致（0 差异）。研究范围为 8 个省、67 个卫生区，总人口
> 38,393,224。省级/区级快照截至 2026-11-09，六项响应指标为 2026-11-11 页面值。
> 累计确诊包含已死亡病例；ETC 住院人数仅作为隔离库存的代理，不解释为确诊隔离；
> 493 例死亡只在省级发布，未分配到卫生区；康复数从第 32 周起才有国家级数据，
> 早期康复库存按假设处理，不作为观测。

### 8.2 英文版（MCM 论文可直接改写）

> Data were obtained from the Ebola Tracker database (ebola-tracker.org, accessed
> 11 November 2026), which compiles the daily situation reports of the DRC
> National Institute of Public Health (INSP). The snapshot corresponds to SitRep
> 179 (9 November 2026) and contains 9,228 country-, province-, and health-zone-level
> records. We constructed a complete daily national series from 21 June to
> 9 November 2026 (142 days), using the latest valid country-level record on each
> date and last-observation-carried-forward for four missing days (26 June, 16 July,
> 28 and 29 July). Cumulative confirmed cases and deaths were used directly; daily
> incidence was obtained by first differences and a 7-day trailing mean. Flags were
> retained for catch-up reports (22 and 30 July), a source harmonisation of Ituri
> deaths (30–31 October), and one reconstructed day (2 November). Weekly Sunday
> anchors were used only for validation; they reproduce the 21 published weekly
> cumulative values exactly (zero difference). The analysis covers eight provinces
> and 67 health zones (N = 38,393,224). Province and zone snapshots are as of
> 9 November 2026; the six response indicators are the values published on the data
> page on 11 November 2026. Confirmed cases include deaths. ETC admissions are used
> only as a proxy for the isolated stock and are not interpreted as confirmed
> isolation. A total of 493 deaths are reported at province level only and are not
> assigned to a health zone. Recovered counts are available at country level only
> from week 32 onward; the early-period recovered stock is therefore treated as an
> assumption, not an observation.

---

## 9. 相关文件索引

| 内容 | 文件 |
|---|---|
| 本文件 | `ws/docs/DATA_SOURCE_AND_PREPROCESSING.md` |
| 数据决策（参数化、拟合） | `ws/docs/数据处理方案确定.md` |
| 日尺度标准与 P0 记录 | `ws/docs/A_PROBLEM_ADAPTATION.md` §10–§11 |
| 数据源/文件/构建规则/注意事项 | `ws/new/data/ebola_tracker/README.md` |
| active 数据源与口径提醒 | `ws/new/data/README.md` |
| 数据选择、`state_at`、验收 | `ws/new/code/README.md` |
| 机器可读元数据 | `ws/new/data/ebola_tracker/snapshot_metadata_20261111.json` |
| P0 输出 | `ws/new/outputs/p0/` |
