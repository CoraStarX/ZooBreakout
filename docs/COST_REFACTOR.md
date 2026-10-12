# 行动成本 / 才能硬区分 — 本轮实作计划（已批准）

> **本文件只记录刀次、进度与待调参数。** 规则与设计意图以 [DESIGN.md](DESIGN.md) 为准；两者冲突时以 **DESIGN.md** 为准。

> 2026-10-12 拍板。节奏：**每刀完成后停下等人手玩确认**，再进下一刀。  
> 原独立任务单 **R2 / R3 / R4 并入本计划，不再另发 R2**。

## 与原 R2 / R3 / R4 的覆盖关系

| 原编号 | 原主题 | 本计划落点 | 说明 |
|--------|--------|------------|------|
| **R2** | 能力 / 背包 / 行动成本 | **刀 1** Params+`ActionCostTable`；**刀 2** Soft/Hard 成本、`allow_hard`、**背包容量与重物**；**刀 4** 叫嚷上限、THROW 投掷、Gather **B 接口** | 能力池扩展（THROW）+ 背包规则补齐 + 统一成本表。**不需要另开 R2。** |
| **R3** | 路线资料化 / 强行 | **刀 1** `RouteWorkParams`；**刀 2** 点位 `allow_hard`、最后一档禁强行、Hard 倍率（时×3 / 噪×2 / 痕×2） | 强行**不**直接 `Alert+1`（已从规格移除）。 |
| **R4** | 噪音 → 痕迹 → 警戒 | **刀 2** 痕迹生成与「已结算」；**刀 3** Alert 2–5 后果表 + UI 预警 | 噪音本身不加 Alert；痕迹被发现 / 被看见才升档。 |

未覆盖而刻意外置：R6 材料点全面风险（仅 B 接口）、R7 前往标记点、R8 夜间保安、推倒物、第二职员、NavMesh、存档。

## 刀次

| 刀 | 内容 | 人手玩点 |
|----|------|----------|
| **0** | 文档：DESIGN 支柱与连带条目；本文件 | — ✅ |
| **1** | Params 骨架 + `GameConst` 转发；先对齐旧值全绿，再改 Open→**180s**（两步提交） | 评估 Open 180 | ✅ |

### 刀 1 进度笔记

- 提交 `8627119`：Params + 转发，Open **75**（可回退至此再改 `.tres`）
- 提交（Open 180）：仅改 `day_cycle_params` 默认 / `.tres`
- **已转发**（唯一数据源 = `.tres`）：`OPEN/CLOSE/NIGHT_*`、`DEADLINE_DAY`、`MAX_ALERT_LEVEL`、`BASE_HEARING_RADIUS`、`HEARING_PER_ALERT`、`SOFT/HARD_INTERACT_SEC`、`GATHER_*`、`SHOUT_*`、`ROUTE_TIERS`、`KIT_TIERS`、`TIER_SOFT/HARD_SEC`
- **仍待删的 GameConst 本地 const**（刀 2+ 再迁或保留）：`HARD_INSTANT_CATCH_RANGE`、`GRAVITY`、`DETENTION_SEC`、`REINFORCE_*`、`OBSERVE_*`、`CART_*`、`STAFF_DWELL_SEC`、`FOOTSTEP_*`、`RUN_SPEED_FOR_FOOTSTEP_NOISE`、`STAFF_VISION/SPEED_PER_DAY`、`STAFF_SCALE_MAX_DAYS`
- Alert 后果倍率已在 `AlertParams` 占位（×1.3 等），**玩法接线在刀 3**
| **2（A）** | 夜间施工 Soft/Hard；`allow_hard`；痕迹（单次结算）；背包容量（浣熊 4 / 猴 2）+ 重物（移速 −40%、禁攀爬）；`p2_action_cost` | Soft/Hard/背包体感 |
| **3（C）** | Alert 后果表；头上 ?/!；Alert4 预警文案；Alert5 中止施工原因；`p2_alert_tiers` | 升档可读性 |
| **4** | 叫嚷每日 4；投掷 T（冷却 8s、无消耗石子）；Gather B 接口预留 | 声东击西 |
| **5** | `p2_full_loop` 预算断言；全量 `run_tests.sh` | 闭环 |

## 已锁定数值 / 规则（摘）

- Hard（允许时）：时间 ×3、噪音 ×2、痕迹 ×2；**不**直接 Alert+1  
- 同一痕迹 Alert 增量**只结算一次**（`settled` / 等价状态 + 测试）  
- Alert3 施工噪音倍率起点 **×1.3**（`AlertParams`）  
- Alert4 UI：「再升一档将全园搜查」；Alert5 中止施工须明确原因  
- 叫嚷：每日 4 + 冷却；用尽「嗓子哑了」；不计 Alert  
- 投掷：键 T、冷却 8s、无材料消耗（石子表现）；`CapabilityIds.THROW`  
- 痕迹：跨天保留至被发现；天亮衰减 **50%**（比例入 Params）  
- 无员工在场时，任何噪音**不得**使 Alert 上升（`p2_action_cost` / `p2_alert_tiers` 断言）  
- 背包：**浣熊容量 4 / 猴子 2**；重物：移速 −40%、禁用攀爬（现状无实现 → **刀 2**）  
- 测试：`p2_full_loop` 改预算断言（3–5 天正解线；材料不够双线；无料拒最后一档）

## 不做

推倒物噪音、第二职员、NavMesh、存档、危险区自动待命、单一 `BalanceParams.tres`。
