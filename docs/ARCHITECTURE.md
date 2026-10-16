# Zoo Breakout — 架构

依赖只允许向下：**Content → GamePlay → Core**（Content 也可虚线依赖 Core 工具）。

## 三层职责

| 层 | 职责 | 禁止 |
|----|------|------|
| **Core** | Autoload、事件总线、输入引导、日后存档/音频/UI 栈 | 引用关卡、AnimalActor、具体物种 |
| **GamePlay** | 队伍/换控、交互规则、警戒与日程、抓捕、准备/套件、通关条件 | 写死浣熊/某扇门坐标 |
| **Content** | AnimalDef、关卡场景、具体 Interact 配置、UI 文案与面板 | 把规则塞进 Autoload |

## 与参考图对照

| 图中模块 | 本项目落点 |
|----------|------------|
| Singleton / Event | Autoload + `Bus` + `content/event_names.gd` |
| Save / Audio / UI Stack | `core/` 预留，P1+ 实现 |
| Input | `Game` Autoload InputMap |
| RoleState / Party | `gameplay/party_controller.gd` |
| Interactions | `gameplay/interaction/` |
| GameManager / Conditions | 场景级 `RunSession` + escape conditions |
| Item / Kit | Prep 套件 Resource（P1+） |
| Levels / Items / UI | `content/` + `scenes/` |

## 目录

```text
core/                 # 基础设施脚本（可与 autoload 路径并存迁移）
gameplay/             # 规则框架
content/              # 常量、事件名、内容侧脚本
scenes/               # boot / actors / levels / ui / world
prototypes/           # 验证场景与回归测试，禁止被 gameplay 引用
docs/
```

## 铁律

1. Core 不 `preload` 关卡，不引用 `AnimalActor`。
2. GamePlay 只认 `CapabilityId` / Resource，不写死物种名做分支。
3. Content 可依赖 GamePlay API；禁止反向。
4. Autoload 保持瘦：状态优先场景 Manager 或 RunSession。
5. `prototypes/` 验证通过后 **重写进 gameplay**，不直接升格。

## 模块地图（当前）

| 模块 | 路径 |
|------|------|
| Event bus | `core/autoload/bus.gd`（信号名同步登记在 `content/event_names.gd`，由 `p2_hygiene` 校验） |
| Clock / Alert | `gameplay/clock.gd`, `gameplay/alert.gd` |
| 开局重置 | `gameplay/run_lifecycle.gd`（`RunLifecycle.reset()`） |
| 世界标签 | `core/ui/proximity_label.gd`（通用，靠 `controlled` 组取焦点） |
| Party | `gameplay/party_controller.gd` |
| Capture / Office | `gameplay/capture_flow.gd`, `gameplay/office_storage.gd` |
| Run session | `gameplay/run_session.gd`（场景级，非 Autoload） |
| Interactions | `gameplay/interaction/interactable.gd`（含 `allow_hard`） |
| Action cost / balance | `content/balance/*_params.gd|.tres`, `action_cost_table.gd|.tres`（见 [COST_REFACTOR.md](COST_REFACTOR.md)） |
| Traces | `gameplay/trace/`（发现→Alert，单次结算） |
| AnimalDef / Caps | `content/animal_def.gd`, `content/capability_ids.gd`（含 THROW） |
| Follow camera | `core/camera/follow_camera.gd` |
| Level geometry | `scenes/world/zoo_p0_geometry.tscn` + `content/levels/zoo_p0_geometry.gd` |
| Level root | `content/levels/zoo_world.gd` + `scenes/world/zoo_p0.tscn` |
| 动物演员 | `gameplay/animal_actor.gd`；动物数据 `content/animals/*.tres` |
| Start select | `content/ui/start_select.gd` + `scenes/boot/start_select.tscn` |

## P0→P1 门禁（Architect 基线 · 2026-10-01）

### 三项触发域裁决

| 域 | 裁决 |
|----|------|
| **相机** | Keep `FollowCamera` 45° 正交跟随；P1 前禁止 look-ahead / shake / 多机位。改数学/投影/跟机手感须再审。 |
| **全局状态** | Keep 分治：`Clock.Phase`（日程）+ `StaffActor.State`（本地 AI）+ 场景级 `RunSession`（通关进度）。**拒绝**单体 `GameStateMachine` Autoload。 |
| **Shader** | 灰盒继续 `StandardMaterial3D`；首个自定义 Shader（视野锥/描边/夜间调色）须先 Architect 评。 |

### Dev 触及须先贴方案

- 修改 `FollowCamera` 数学/投影/跟机手感
- 新增或改 `.gdshader`
- 新增全局/Autoload 状态机，或扩展 `Clock.Phase` 语义
- 把 `PartyController` / `CaptureFlow` 升格为 Autoload

关卡坐标微调、文案、AnimalDef 数值 → 走 QA↔Dev，无需 Architect。

### 重构顺序（勿并行大拆）

1. 关卡几何场景化；`zoo_world` 只留 Session / 接线 / 输入  
2. Capture 守门偏移改为门配置，禁止物种 id 分支  
3. 分层机械迁移（resources → content；interactable → gameplay；camera → core）  
4. 禁止 `prototypes/` 直接升格  

每步后跑：`p0_walkthrough` + `p0_regression`。

### 性能（灰盒）

正交单相机 + 少量 Box：无瓶颈。职员射线角色数 &lt;10 可接受；P1 不引入对象池/多线程。

## 依赖门禁（自动）

`prototypes/p2_hygiene.gd`（并入 `tools/run_tests.sh`）静态扫描：Core 不得出现玩法/内容符号；GamePlay 不得依赖具体关卡/UI/交互物脚本（数据类 `GameConst`/`CapabilityIds`/`KitIds`/`IntelIds`/`AnimalDef` 视为共享数据，允许）。新增违规会让门禁变红。

## 工作流纪律

1. 新功能先定落层，再写 Resource/接口，再铺场景。  
2. 里程碑结束：可玩 + 更新 `TECH.md` 一句状态。  
3. 垂直切片：每加 P1 系统只抽相关层，不预建空 Manager。

## 2026-10-14 移動切片 Architect 核准

使用者已核准獨立移動試驗與鏡頭方案。`FollowCamera.follow_target_height` 預設 false；開啟時可讀通用 `height_provider_method`，由角色提供平台／攀爬高度，Core 不依賴角色型別。保持既有 45° 正交，不改全域狀態、Clock 或 Autoload。

`gameplay/traversal/` 負責純移動規則與本地狀態；`content/traversal/` 負責參數、幾何資料、UIKit／ProximityLabel 呈現。未改寫 `AnimalActor` 或將原型升格；獨立切片通過後才規劃擬態整合。詳見 [MOVEMENT_SLICE.md](MOVEMENT_SLICE.md)。

## 2026-10-15 移動 A 可用性接線

TraversalActor 增本地 Airborne／Attaching 狀態與統一 Space，TraversalMetrics 為場景持有的 RefCounted。角色只發 local movement_event／stepped／landed，由 Content 接 F3 或佔位反饋；噪音沿用 Bus.noise_made。DebugHUD 在有 movement_metrics 時提供獨立移動面板，舊世界模式不變。沒有新增 Autoload、Clock.Phase 或 Shader；沿用既有鏡頭高度介面。

## 員工可讀性 B（2026-10-15）

使用者核准獨立沙盒：Content StaffReadabilityLab 只讀凍結移動狀態並解析灰盒資料／聲音事件位置；GamePlay 共享平面幾何、局部 ReadabilityStaff、場景級 Metrics 負責判定／編排。沿用 StaffAwarenessMath／StaffMotor，不改正式 StaffActor 或新增 Autoload／Clock 語意。增加雙目標材質淡出與UIKit回饋，不修改鏡頭數學或 Shader；獨立 StaffAiParams .tres 防止調參波及舊關卡。

## 變形原型 A（2026-10-16）

GamePlay/forms 的 FormDef／FormSetup／FormParams 為共享資料型別，FormRules 純函式驗證與拒絕，FormController 管場景級冷卻／完整膠囊預檢／合法退回。控制器按 CLIMB 能力選用凍結 TraversalActor 或限制跳躍的 GroundFormActor，不按物種 id 分支。Content/forms 持有 .tres、FormLab 呈現與噪音接線。只用既有鏡頭接口與 Bus，不增 Autoload／全域狀態／Shader。角色更換保留腳底、朝向與下落峰值，停用舊碰撞與輸入；特效獨立。C 前搖接口見 FORMS_SLICE.md，本階段不修改員工。

### A有界推開接線

FormController先以同份完整目標膠囊／walkable_support尋找擺放，再以本體cast_motion與同層支撐驗證路徑；FormRules提供有界方向／高度純判定，FormParams集中距離／步長／取樣參數。所有查詢先完成，再_replace_body與form_changed／transform_committed／Bus事件原子提交最終位置。沒有新增Autoload、移動狀態、全域資訊或NavMesh；凍結猴移動與員工程式不變。
