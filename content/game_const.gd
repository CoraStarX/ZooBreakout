class_name GameConst
extends RefCounted

const MAX_ALERT_LEVEL := 5
const BASE_HEARING_RADIUS := 3.2
const HEARING_PER_ALERT := 1.2
## Night quiet window base length (seconds of night phase before rest). Alert pushes rest later.
const NIGHT_PATROL_BASE_SEC := 28.0
const NIGHT_PATROL_PER_ALERT_SEC := 8.0
const NIGHT_QUIET_SEC := 32.0
## Open long enough to gather + watch ~2 patrol loops.
const OPEN_PHASE_SEC := 75.0
const CLOSE_PHASE_SEC := 15.0
## 封园检修：第 DEADLINE_DAY 天结束仍未出园 → 失败。
const DEADLINE_DAY := 5

## Soft vs Hard interact timing (seconds).
const SOFT_INTERACT_SEC := 0.45
const HARD_INTERACT_SEC := 2.0
## Hard noise only auto-captures within this distance; else investigate.
const HARD_INSTANT_CATCH_RANGE := 1.6
## Character gravity (m/s²). Keeps climb/ledges from becoming flight.
const GRAVITY := 22.0
## 被抓：短押秒数（笼内可搜集），期间职员守在笼门前；笼门当天加固。
const DETENTION_SEC := 15.0
## 加固笼门：开锁额外消耗的原料数（任意种）；没有则耗时 ×REINFORCE_TIME_MULT。
const REINFORCE_EXTRA_MATERIALS := 1
const REINFORCE_TIME_MULT := 2.0
## 情报观察：累计看到职员的秒数；可观察的最大距离。
const OBSERVE_SEC := 4.0
const OBSERVE_VIEW_RANGE := 13.0
## 职员工具车：每天可偷金属的件数；偷取读条秒数；车跟在职员身后的距离；巡逻点停留秒数。
const CART_LOOT_PER_DAY := 1
const STEAL_SEC := 1.6
const CART_TRAIL_DIST := 1.4
const STAFF_DWELL_SEC := 3.0
## 白天搜集：有动词 / 无动词的读条秒数。
const GATHER_SEC := 0.7
const GATHER_POOR_SEC := 2.0
## 每过一天职员更警觉：视野(米)与速度的每日增量（上限 STAFF_SCALE_MAX_DAYS 天）。
const STAFF_VISION_PER_DAY := 0.5
const STAFF_SPEED_PER_DAY := 0.12
const STAFF_SCALE_MAX_DAYS := 4
## 夜间施工：路线档数；每档按路线配方耗原料，或用套件（套件顶 KIT_TIERS 档）；每档读条秒数（Soft/Hard）。
const ROUTE_TIERS := 3
const KIT_TIERS := 2
const TIER_SOFT_SEC := 6.0
const TIER_HARD_SEC := 14.0
