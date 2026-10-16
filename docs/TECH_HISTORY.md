> 歷史快照：2026-10-16 整理前內容；其中待驗項與舊數值不代表現行狀態。現行範圍見 [P2 清單](P2_CHECKLIST.md)。

# Zoo Breakout — 技术落地

## 栈

- Godot **4.7** · GDScript（静态类型）
- 分层：Core / GamePlay / Content — 见 [ARCHITECTURE.md](ARCHITECTURE.md)
- 世界：Node3D 灰盒 · 45° 正交跟随相机
- 数据：`AnimalDef` Resource · `GameConst`（过渡）· `EventNames` · 平衡 Params（见下）

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
- **平衡 v2**（※历史纪录：当时路线曾调 4 档、Open 75s；现行 3 档 / Open 见 `DayCycleParams`）：期限 5 天、职员每日增强（`StaffActor.apply_day_scaling`）；当时全套 14 门禁绿
- **材料 v2 Done**：`KitIds` 三原料；`Interactable.tier_cost` 路线配方；`StaffCart` 偷取；`StaffActor` 巡逻停步；门禁 15 套件
- **技术债清理 Done**：legacy `scripts/`、`resources/` 迁入 core/gameplay/content；`RunLifecycle.reset()` 取代 `Game.reset_run_state()`（Core 不再认识 Alert/Clock）；`ProximityLabel` 升为 Core 通用件；OfficeChest 数据化+防连按；`p2_hygiene` 静态依赖门禁；门禁 16 套件
- **UI/引导 Done**：`GameHUD`（顶栏/目标/状态/消息）、`HintDirector`（一次性新手提示，`UserPrefs` 持久化，无头不落盘）、`PauseMenu`（Esc）、调试面板改 F3；`p2_ui` 门禁（共 17 套件）；`.github/workflows/tests.yml`（CI，未在远端验证）
- **职员手感降难 Done**：`StaffActor` 增 `SUSPECT` 反应前摇、听力改调查、抓捕读条、抓后硬直、脱视宽限、视野锥 Telegraph 变色；参数全 `@export`；偷车/观察改认 `is_hostile()`；17 套件全绿
- **职员巡逻丰富化 Done**：`ZooP0Patrol` 巡逻册（主环/宽环/工具间支线/广场支线）；停步扫视、定期岔线与掉头；警戒/时段提高岔线频率；对抗参数略回收（手玩「太好躲」）；情报预览画全册
- **职员 AI P2-A Done**：`StaffAiParams` + awareness 状态机 + Sense/Motor；门禁 `p2_staff_awareness`
- **职员 AI P2-B Done**：加權巡邏點網 `PatrolNetwork`（預約 API）；`Bus.noise_made`；玩家 G 叫嚷／奔跑腳步噪音接口；硬闖改走总线；门禁 `p2_staff_patrol`；舊 `route_book` 標記廢棄保留
- **职员 AI P2-C Done**：F3 勾选职员 AI Debug；`StaffDebugDraw`；文档 `docs/STAFF_AI.md`
- **伙伴跟随修正 Done**：面包屑轨迹 `FollowTrail`；卡住阶梯恢复+视野外传送；危险区仅提示不强制待命；V 标记点 GOTO；换控退下待命；门禁 `p2_follow_trail`
- **行动成本重构（进行中）**：见 [COST_REFACTOR.md](COST_REFACTOR.md)。目标资源：
  - `content/balance/day_cycle_params.gd|.tres` — Open/Close/夜巡/歇岗/期限（Open 试 180s）
  - `content/balance/route_work_params.gd|.tres` — 档数、Soft/Hard 基线与倍率、痕迹衰减
  - `content/balance/alert_params.gd|.tres` — 档位后果（含施工噪音×1.3 起）
  - `content/balance/action_cost_table.gd|.tres` — 统一行动成本查询（含 gather 预留键）
  - 痕迹：`gameplay/trace/*`（单次 Alert 结算）；投掷 `CapabilityIds.THROW` + 键 T
- Architect 基线门禁：见 [ARCHITECTURE.md](ARCHITECTURE.md)
- 重构落地：`RunSession` 场景级进度；`zoo_p0` 几何子场景；Capture 守门偏移门配置化；Interactable / AnimalDef / FollowCamera 按层迁移

- **R5.5-A 已實作，待手玩**：Content 層 `GuidanceModel` 唯讀快照推導＋`GuidanceParams`；頂部單行目標／收合詳情；不改玩法，B／C 尚未開始。新增門禁 `p2_guidance`。

- **擬態移動切片 A 已實作，待手玩**：獨立 `movement_lab.tscn`、本地 TraversalActor、資料化攀爬／跳點、可選鏡頭高度跟隨；舊關卡保持原入口，新增 `p2_traversal`。見 [MOVEMENT_SLICE.md](MOVEMENT_SLICE.md)。

- **移動 A 邊緣保護已實作，待複測**：地面步行分段支撐檢查＋沿邊方向保留＋終點檢查；Resource 調整允許落差與安全距離；修正返回斜坡接縫，合法跳躍仍需主動按鍵。

- **移動 A 斜坡上行修復（2026-10-15）**：返回斜坡改凸楔形，碰撞／網格共用頂點，修正坡頂端面阻擋；新增上坡與十次上下往返回歸。

- **猴形態移動 A 可用性修正（2026-10-15，待手玩）**：意圖自動附牆／屋頂下牆、Space 統一、寬邊緣跳躍＋土狼／緩衝、主動下行、噪音與合法恢復；場景級 TraversalMetrics 接既有 F3 的分段／複製／重置。

- **移動 A 診斷補強（2026-10-15，待複測）**：修正淺接觸誤判卡住；F3 分開完成／進行中／圈外、各返回方式中位數；加入最近一秒輸入與恢復快照及原生 JSONL。原手玩恢復根因因舊版無追蹤仍待確認。

- **移動 A 第二輪輸入修正（2026-10-15，待手玩）**：附牆過渡放手請求、跨越／下行共同方向選點、提前下行預覽與具體拒絕、混合返回統計；既有邊緣保護與碰撞門禁保留。

- **移動 A 第三輪選點修正（2026-10-15，待手玩）**：由邊緣用途先定跨越／下行，Space 鎖定預覽、受阻不跨種類補救，保留斜向緩衝；F3 加首次跨越前中途下行的重試分類。

- **移動 A 第四輪修正（2026-10-15，待手玩）**：放手落地清除舊輸入鎖、跨越入口限同高度與附近、鎖定起跳先於步行，修正牆底持續輸入與斜坡誤判。

- **移動 A 最後縮限修正（2026-10-15，待五圈手玩）**：移除一般接地抬升循環、Resource 引擎安全邊距、ReturnRamp 縮窄右移、預檢碰撞體／路徑段診斷、重複返回排除驗收；不加落點取樣。原生 InputMap 五圈零錯誤，手玩失敗則改討論固定寬下行帶。

- **員工可讀性 B（2026-10-15，待手玩）**：獨立 StaffReadabilityLab 重用凍結移動灰盒；共享地面感知輪廓、局部員工／搜索冷卻／每圈歇崗聽覺、F3追溯與雙目標淡出；不接正式警戒／抓捕／日程。見 STAFF_READABILITY.md。

- **員工 B 手玩後修正（2026-10-15，待複測）**：聲音接收端以事件位置實際支撐面分類；延長限同來源高處搜索；員工改選既有可達接近點且保留記憶。原生71項與七秒實機重播通過，移動／幾何／鏡頭凍結。

- **員工 B 試玩前修訂**：安全出生、攀爬接收節流／聽覺衰減、搜索地面再接觸、真實歇崗聽覺、F3預設摘要與選擇性完整匯出；原生／headless專項各97項，移動凍結，待陌生玩家驗收。

- **變形原型 A（2026-10-16，待手玩）**：獨立form_lab、FormDef／初始化／冷卻／完整體型與合法退回；31套件全綠，原生71項與雙解析度檢查通過。移動／員工凍結，B/C未開始，見FORMS_SLICE.md。

- **變形A／B前置提示設定**：F3可隱藏任務／被動能力／路線提示，UserPrefs保存，恢復時重繪標題；31套件全綠、原生77項。C已決定封裝既有ReadabilityStaff Actor場景，B/C實作尚未混入。

- **A邊緣變形修復**：FormController新增目標體型完整支撐預檢，避免本體可站／猴不可走的狀態；只拒絕並引導往內站穩，不傳送／放寬邊緣保護。31套件全綠、原生91項，待使用者複測。

- **A有界自動推開（取代拒絕版）**：0.32m內尋最近合法候選，本體掃掠／同層支撐保障，原子切換與最終位置事件。31套件全綠、Metal／headless各106項；凍結移動／員工不改。直牆原位變形中心間距實測約0.32m，詳見FORMS_SLICE.md。

- **白盒基線結項（2026-10-16，使用者驗收通過）**：移動／獨立員工可讀性／變形A凍結作基線，本輪驗證結束；B窄縫與C員工整合延後、尚未驗收，後續切片範圍另議。
