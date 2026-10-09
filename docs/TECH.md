# Zoo Breakout — 技术落地

## 栈

- Godot **4.7** · GDScript（静态类型）
- 分层：Core / GamePlay / Content — 见 [ARCHITECTURE.md](ARCHITECTURE.md)
- 世界：Node3D 灰盒 · 45° 正交跟随相机
- 数据：`AnimalDef` Resource · `GameConst` / `EventNames`

## Autoload

`Bus` · `Game` · `Clock` · `Alert` · `OfficeStorage` · `CaptureFlow`

## 目录

```text
core/ gameplay/ content/
scenes/ prototypes/ tools/ docs/
```

## 状态（2026-10-09）

- **P0 Done**：围栏封闭、重力、Debug 默认关、QA 门闩回归全绿
- **P1 Done**：通关 + Prep + 动词灰盒/猴开局/出生点数据化；套件面板 UI → backlog — 见 [P1_CHECKLIST.md](P1_CHECKLIST.md)
- **P2 进行中**：M0–M1 Done（外墙挖爬 + 白天先捡再准备）；下一刀 M2 情报点或 M3 回归 — 见 [P2_CHECKLIST.md](P2_CHECKLIST.md)
- **2026-10-09 Claude 接管**：Clock 标题界面不走时 + `RunLifecycle.reset()`；昼夜光照随时段过渡；`tools/run_tests.sh` 统一门禁（10 套件）
- **昼夜 M2 Done**：`Clock.day` + `Bus.day_changed/day_summary`；`RunSession` 每日结算/警戒冷却/封园期限；`content/ui/day_banner.gd`；测试门禁 11 套件
- **昼夜 M3 Done**：`GatherPoint` + `content/levels/zoo_p0_gather.gd`（数据驱动）；零件 `KitIds.PART`；测试门禁 12 套件
- **被抓改短押 Done**：`CaptureFlow` 短押计时/释放；`Interactable.reinforced`；`StaffActor` 记录发现方式；同伴撬门营救；门禁 13 套件
- **昼夜 M4 Done**：`ObservePoint` + `IntelIds` + `zoo_p0_intel.gd`；`RunSession.intel`；HUD 歇岗倒计时改为情报解锁；巡逻路线预览；门禁 14 套件
- **昼夜 M5 Done**：夜间施工分档（`Interactable.tiers`）、`BreachBuilder` 从 Interactable 拆出（挖洞/攀爬几何）、`RunSession.route_tiers`；移除白天 Prep；端到端 `p2_full_loop`；门禁 14 套件
- **标签可读性 Done**：`content/ui/proximity_label.gd`（固定字号 + LOD）
- **平衡 v2**：路线 4 档、期限 5 天、Open 75s、职员每日增强（`StaffActor.apply_day_scaling`）；全套 14 门禁绿
- **材料 v2 Done**：`KitIds` 三原料；`Interactable.tier_cost` 路线配方；`StaffCart` 偷取；`StaffActor` 巡逻停步；门禁 15 套件
- **技术债清理 Done**：legacy `scripts/`、`resources/` 迁入 core/gameplay/content；`RunLifecycle.reset()` 取代 `Game.reset_run_state()`（Core 不再认识 Alert/Clock）；`ProximityLabel` 升为 Core 通用件；OfficeChest 数据化+防连按；`p2_hygiene` 静态依赖门禁；门禁 16 套件
- Architect 基线门禁：见 [ARCHITECTURE.md](ARCHITECTURE.md)
- 重构落地：`RunSession` 场景级进度；`zoo_p0` 几何子场景；Capture 守门偏移门配置化；Interactable / AnimalDef / FollowCamera 按层迁移
