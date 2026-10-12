# 职员 AI（P2 第一阶段）

> 目标：行为会变化，但可观察、可推理、可智取。不追求更强，追求可读、公平、不可背板。

## 状态机

```text
WORK ──(awareness↑)──► SUSPICIOUS ──► INVESTIGATE ──► CHASE
  ▲                         │                │           │
  │                         ▼                ▼           ▼
  └──────── RETURN ◄──── SEARCH ◄────(丢失目标/搜完)────┘

REST   夜歇岗（独立）
GUARD  短押守门（独立）
Return 结束后回到「当前时段应有状态」（Work / REST / GUARD）
```

| 状态 | 含义 |
|------|------|
| WORK | 加权巡逻点网选点 + 停步扫视 |
| SUSPICIOUS | 起疑预警（黄锥），尚未追击 |
| INVESTIGATE | 前往 last_known / 声源 |
| SEARCH | 丢失目标后局部采样搜索（射线避开穿墙） |
| RETURN | 放弃搜索回岗位，抬升附近点 heat |
| CHASE | 看见时刷新 last_known；看不见追冻结位置，宽限后 Search |
| REST / GUARD | 既有日夜／岗位态，不并入巡逻流 |

**公平性**：进入 CHASE 前 `min_telegraph_sec ≥ 0.5`。  
**不作弊**：决策层不持有玩家 Node；`last_known` 仅由感知/噪音写入。

## 资料流

```text
动物位置/速度 ──► StaffSense ──► Snapshot(visibility, last_known)
Bus.noise_made ──► StaffActor._on_bus_noise ──► awareness / Investigate
Snapshot + spike ──► StaffAwarenessMath.tick ──► awareness 0~100
awareness 带 + 流程 ──► 状态 ──► StaffMotor.move_to / 巡逻点网
```

个体警觉 = **`awareness`**（0~100）。  
跑团警戒档 = 全局 Autoload **`Alert.level`**（勿混用）。

## 关键文件

| 路径 | 说明 |
|------|------|
| `gameplay/staff/staff_ai_params.gd` + `content/staff/default_staff_ai_params.tres` | 集中调参 |
| `gameplay/staff/staff_awareness_math.gd` | 累加/衰减/可见度纯函数 |
| `gameplay/staff/staff_sense.gd` | 感知 |
| `gameplay/staff/staff_motor.gd` | 可替换移动接口 |
| `gameplay/staff/patrol_*.gd` | 点网、评分、预约 |
| `gameplay/staff/staff_debug_draw.gd` | F3 Debug 叠加 |
| `gameplay/staff_actor.gd` | 编排器 |
| `content/levels/zoo_p0_patrol.gd` | 点网数据（`route_book` 废弃保留） |

## 参数建议范围（`StaffAiParams`）

| 参数 | 建议 | 说明 |
|------|------|------|
| `accumulate_per_sec` | 30~55 | 暴露时 awareness 爬升 |
| `decay_per_sec` | 15~30 | 躲视野后下降 |
| `suspicious_threshold` | 18~30 | 起疑 |
| `investigate_threshold` | 40~55 | 前往查看 |
| `chase_threshold` | 70~85 | 追击（仍需预警秒数） |
| `min_telegraph_sec` | ≥0.5 | 公平底线 |
| `lose_target_grace_sec` | 1.0~2.0 | 丢视宽限 |
| `mult_still` / `mult_slow` | 0.4~0.8 | 静止/慢走可见度折扣 |
| `hear_noise_range` | 16~24 | 总线噪音最大听距（×loudness） |
| `dwell_sec_min/max` | 3~8 | 停步随机区间 |
| `weight_*` / `score_noise_*` | 见 Resource | 选点权重与有界噪声 |

玩家叫嚷：`GameConst.SHOUT_*`，键位 **G / 手柄 B**。

## Debug

1. 按 **F3** 打开开发面板  
2. 勾选 **职员 AI Debug**  
3. 可见：视锥（跟 `_facing`）、听觉圈、目标点、路径、头顶状态/awareness、各巡逻点 heat/age  

## 门禁

- `p2_staff_awareness` — awareness 纯函数  
- `p2_staff_patrol` — 选点评分、预约、噪音  
- 合并前：`tools/run_tests.sh` 全绿  

## 与警戒 / 痕迹（COST_REFACTOR）

- 玩家噪音经 `Bus.noise_made`；**无员工在场时噪音不得升 Alert**（门禁断言）。
- 施工 Hard 留**痕迹**；员工发现痕迹 → `Alert.bump`（每条痕迹只结算一次）。
- Alert 档对员工：听距×1.25（≥2）、对 kind=`construction` 噪音听距再×1.3（≥3）、收缴视野内 `ground_items`（≥3）、awareness 上升×1.35（≥4）；Alert5 目前只中止施工，员工行为未另做「全园搜查」姿态。数值见 `AlertParams`，经 `Alert` 查询。
- **玩家可读**：员工头上 `HeadIcon`（起疑 `?` → 调查/搜索 `!` → 追捕 `!!`）；精确 `awareness` 仅 F3。门禁 `p2_alert_tiers`。
- **投掷**（本轮）：有 `THROW` 者键 T，冷却 8s，石子表现、无拾取系统；落地噪音 kind=`throw` 引开。

## 后续建议（本阶段刻意不做）

- NavigationRegion3D / NavigationAgent（Motor 已预留 `set_target`）  
- 真正蹲伏输入、阴影、掩体（可见度已预留 `extra_mults`）  
- HD-2D 精灵与 `_facing` 对齐  
- 推倒物噪音（投掷已列入 COST_REFACTOR 刀 4）  
- 删除废弃 `ZooP0Patrol.route_book`  
- 多职员协作、攻击令牌、个性、排班、气味、动态难度  
- R8 夜间保安（另开任务）
