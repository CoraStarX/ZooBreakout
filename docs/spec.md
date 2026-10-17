# Borrowed Shapes — 模組與空間規格

日期：2026-10-17。狀態：現況整理與待決規格；未定案部分不得直接作為製作或搬移依據。

本文件依目前工作區（包含既有未提交變更）靜態核對，不以 Git HEAD 或歷史提案替代現況。本次只新增本文件，不更動程式、場景、Resource 或目錄結構。工作方式以 [AGENTS.md](../AGENTS.md) 為準，玩法、架構、範圍分別依 [DESIGN.md](DESIGN.md)、[ARCHITECTURE.md](ARCHITECTURE.md)、[P2_CHECKLIST.md](P2_CHECKLIST.md)。

標記含義：**現行**＝來源明定；**推算**＝附公式與條件的靜態結果；**待確認**＝需要設計決策或實測，不能視為已驗收能力。以下 m 沿用 AGENTS.md 的目前世界尺度（約 1 世界單位＝1 m），不代表已決定 1 格的大小。

## 1. 網格與模組尺寸

### 1.1 整數倍規則

令基本網格為 `g` m／格，**g 待確認**；不能從世界單位或現有建築尺寸推定為 1 m。

本次要求的整數倍規則記為：模組標準寬、高、深分別為 `nx × g`、`ny × g`、`nz × g`，其中 `nx, ny, nz` 為正整數。開口淨寬、淨高、平台淨間隙與機制有效區域若納入模組標準，同樣以正整數格描述。各類允許的整數組合尚未決定，不代表任意整數組合都可玩。

| 模組類別 | 標準尺寸表達 | 尚待決定 |
|---|---|---|
| 地板／平台／屋頂 | 寬、高（厚度）、深＝整數格 | 基本板幅、厚度與可用倍數 |
| 牆／建築／邊界 | 寬、高、深（牆厚）＝整數格 | 層高、牆厚、牆段與轉角尺寸 |
| 斜坡 | 寬、升高、水平投影深度＝整數格 | 升高與投影深度組合；斜面長不必是整數格，是否另有限制待定 |
| 門洞／窄縫／通道 | 淨寬、淨高、通道深度＝整數格 | 各形態通行餘量及允許組合，窄縫玩法尚未驗收 |
| 攀爬面 | 有效寬、高＝整數格 | 標準高度系列、頂部翻越空間 |
| 跨越區 | 平台淨間隙、落差與兩側平台尺寸以格描述（同高落差為 0） | 淨間隙系列、起落點退縮與支撐餘量 |
| 裝飾／提示／角色 | 是否納入整數格規則待確認 | 外觀包圍盒、碰撞、機制標記是否採不同精度 |

以上為規格框架，不是已實作的模組庫。需先決定「整數倍」約束的是拼接包圍盒、碰撞外形，還是全部視覺細節。角色碰撞與控制器小量偏移目前有非整數公尺數值，不得為符合網格而四捨五入。

位置吸附的基準（底角、底面中心或幾何中心）、旋轉步進、接縫容差、匯入縮放規則皆**待確認**。整數尺寸不等於中心座標必須是整數格；例如寬度為奇數格、以邊界拼接時，幾何中心可能位於半格。現有手調位置保持原樣。

### 1.2 現有幾何參照，非標準模組尺寸

來源：[movement_lab_data.tres](../content/traversal/movement_lab_data.tres) 的 `blocks`，尺寸順序為 X 寬、Y 高、Z 深；由 [movement_lab.gd](../content/traversal/movement_lab.gd) 的 `make_block()`／`_build_ramp()` 建立碰撞。

| 項目 | 現有尺寸（m） | 說明 |
|---|---|---|
| 地面 | 28 × 0.5 × 24 | 頂面 Y＝0 |
| 南／北邊界 | 28 × 2 × 0.3 | 既有牆厚 0.3 |
| 東／西邊界 | 0.3 × 2 × 24 | 既有牆厚 0.3 |
| 建築 | 6 × 3 × 5 | 中心（-3, 1.5, -2），頂面 Y＝3 |
| 落地平台 | 4 × 3 × 5 | 中心（5, 1.5, -2），頂面 Y＝3 |
| 返回斜坡 | 2 × 3.05 × 6.1 | 楔形包圍尺寸；升高／投影深度＝0.5，坡角約 26.565°（推算），非最大可走坡度規格 |
| 攀爬面 | 寬 3、高 3 | 來自 `movement_lab_data.gd` 預設，`.tres` 未覆寫 |

現有資料沒有模組格數欄位或網格驗證器；不能以這些小數的公因數反向指定 g，也不將既有幾何自動套入新標準。

## 2. 控制器參數與能力推算

### 2.1 生效來源

主入口 [form_lab.tscn](../scenes/forms/form_lab.tscn) 載入 [form_lab.gd](../content/forms/form_lab.gd)，繼承 `MovementLab`。形態清單由 [prototype_setup.tres](../content/forms/prototype_setup.tres) 指定本體與猴形態。

兩形態均引用 [traversal_params.tres](../content/traversal/traversal_params.tres)；該資源未覆寫參數，使用 [traversal_params.gd](../content/traversal/traversal_params.gd) 預設。[form_def.gd](../gameplay/forms/form_def.gd) 的 `movement_params()` 複製配置，再以形態資料覆寫 `radius`、`height`、`speed`。[form_controller.gd](../gameplay/forms/form_controller.gd) 的 `_replace_body()` 依 CLIMB 能力建立 `TraversalActor` 或 `GroundFormActor`。

### 2.2 變形碰撞尺寸

| 形態 | 寬 × 高 × 深（m） | 半徑／碰撞中心相對腳底 | 移速 | 來源 |
|---|---|---|---|---|
| 本體（slime） | 0.30 × 0.30 × 0.30 | r＝0.15；Y＝0.15 | 4.0 m/s | [slime.tres](../content/forms/slime.tres)：`body_size`、`move_speed` |
| 猴形態（monkey） | 0.64 × 1.00 × 0.64 | r＝0.32；Y＝0.50 | 5.5 m/s | [monkey.tres](../content/forms/monkey.tres)：`body_size`、`move_speed` |

這是膠囊體完整外尺寸，不是方盒。[form_rules.gd](../gameplay/forms/form_rules.gd) 的 `validate_form()` 要求寬深相等且高度不小於直徑，`capsule()` 建立預檢膠囊；[traversal_actor.gd](../gameplay/traversal/traversal_actor.gd) 的 `_ready()` 建立相同尺寸膠囊，中心上移高度的一半。本體高度等於直徑，圓柱段長為 0。

通道淨寬不能僅取角色直徑就宣稱可通行。`body_safe_margin＝0.005 m`、查詢 `collision_margin＝0`；邊緣保護／變形支撐圈半徑為 `r + edge_safety_margin`，其中後者為 0.05 m，故本體 0.20 m、猴形態 0.37 m。這些是不同用途的查詢參數，不是增加碰撞尺寸，也不是已驗收通道餘量。來源：`TraversalParams`、`TraversalActor._walk_footprint()`、`FormRules.footprint_offsets()`。

變形合法位置搜尋上限為 **0.32 m**，同層支撐高度容差 **0.02 m**；來源：[form_params.tres](../content/forms/form_params.tres)、[form_params.gd](../gameplay/forms/form_params.gd) 的 `push_max_distance`／`push_height_tolerance`。這不是穿牆距離或可升降高度。

### 2.3 攀爬高度

| 項目 | 數值與判定 | 依據 |
|---|---|---|
| 目前場景可攀爬面 | 高 3 m、寬 3 m；原點（-3, 0, 0.5） | [movement_lab_data.gd](../content/traversal/movement_lab_data.gd)：`climb_height`／`climb_width`／`climb_position`，資料資源未覆寫 |
| 控制器通用高度上限 | **沒有獨立最大高度參數；產品上限待確認** | [climb_surface.gd](../gameplay/traversal/climb_surface.gd) 的 `anchor()` 依個別 `height` 夾限；`TraversalActor._step_climb()` 依該面高度翻越，未見耐力／高度累積上限 |
| 垂直／橫向攀爬速度 | 2 m/s | `TraversalParams.climb_speed`、`_step_climb()`；不含附牆與翻上時間 |
| 猴形態腳底攀爬區間 | 面局部 Y＝0.04～3.04 m；X＝-1.18～1.18 m | `anchor()`：Y＝`landing_lift`～`height + landing_lift`；X＝±（width/2−radius） |
| 貼牆腳底位置 | 面外法線偏移 0.40 m | `radius + wall_clearance＝0.32 + 0.08` |
| 附牆／翻上條件 | 附牆距離上限 0.65 m；翻上落點在牆內 0.65 m | `attach_range`、`mantle_depth`；附牆測到 anchor 的距離，不是單純離牆距離 |
| 翻上過渡 | 0.38 s，弧線增量 0.12 m | `mantle_duration`／`mantle_arc`，仍須支撐與路徑檢查 |

3 m 高度沿面純垂直移動的理想時間為 `3/2＝1.5 s`，不含轉場、容差與阻擋。沒有全域高度限制不等於任意高牆已驗收；僅支援直立矩形攀爬面的現有規則。猴形態具 CLIMB，本體無此能力，不能沿用猴形態數值宣稱本體可攀爬。

### 2.4 跨越寬度與跳躍距離

現行「跳躍」是連結指定的跨越弧線，並非任意方向自由跳或原地跳。`TraversalActor.try_jump()` 需要有效預覽／連結；[ground_form_actor.gd](../gameplay/forms/ground_form_actor.gd) 不將 Space 傳入跳躍緩衝，本體不能跳躍。

| 項目 | 數值 | 精確意義與來源 |
|---|---|---|
| 跨越水平位移上限 | 4.8 m | `TraversalMath.jump_rejection()` 檢查起跳點至落點 XZ 距離，參數 `max_jump_distance`；不是平台淨間隙 |
| 允許落點高差 | 絕對值 ≤ 1.2 m | 同函式的 `max_jump_height`，上下高差都受限；不是弧頂高度 |
| 起跳吸附範圍 | 1.4 m | 玩家原點至起跳點的三維距離；不能加到 4.8 m 當淨跨寬 |
| 目前平台淨間隙 | 3.0 m（推算） | 建築右緣 `-3 + 6/2＝0`；平台左緣 `5 − 4/2＝3`；差為 3 |
| 目前連結水平位移 | 4.30 m（推算） | `jumps` 起點 X＝-0.65，終點 X＝3.65；差為 4.30，雙向相同 |
| 目前起落點退縮 | 各 0.65 m（推算） | 兩端各距平台邊界 0.65；`3 + 0.65 + 0.65＝4.30` |
| 固定沿用目前退縮的淨間隙代數上限 | 3.50 m（條件推算，**未驗收**） | `4.8 − 0.65 − 0.65＝3.50`；只適用同向直線、相同退縮配置，不能作通用淨寬標準 |

來源：[traversal_math.gd](../gameplay/traversal/traversal_math.gd)、[traversal_link.gd](../gameplay/traversal/traversal_link.gd) 的 `takeoff_near()`／`destination_near()`、`movement_lab_data.tres` 的 `blocks`／`jumps`、`TraversalParams`。起跳邊線的 Z 範圍為 -3.6～-0.6，落點隨最近線段點平移。

合法跨越還須完整膠囊路徑掃掠與落點支撐；`path_clear()` 使用 24 段，`supported()` 查腳底中心及 ±X／±Z 半徑共五點，支撐深度參數 0.18 m、法線 Y 下限 0.7。吸附接近另須可走路徑檢查。參數上限只是必要條件，不能單獨保證跨越成功。

### 2.5 跳躍弧線高度與時間

來源：`TraversalMath.arc_point()`、`TraversalActor._motion_point()`／`try_jump()`、`TraversalParams.jump_arc`／`jump_duration`。

弧線為 `P(t) = lerp(start, finish, t) + UP × 4a t(1−t)`，`0 ≤ t ≤ 1`，`a＝0.65 m`。這是指定路徑，不以起跳速度和重力解算；`gravity＝22 m/s²` 用在一般地面／空中移動，不能用它另算這條跨越弧線。

- **同高起落點**：最高腳底相對起點上升 **0.65 m**（t＝0.5）。目前起落點 Y＝3.04，因此理想弧頂腳底 Y＝**3.69 m**；猴形態碰撞頂部 Y＝**4.69 m**。這是幾何推算，未包含額外淨空設計餘量。
- **不同高度**：令 `d＝finish.y−start.y`，則相對起點高度為 `d t + 4a t(1−t)`；頂點 `t_peak＝clamp((d+4a)/(8a), 0, 1)`。例如允許的上升端點高差 d＝1.2 m 時，理想最高上升約 **1.38846 m**，比終點高約 0.18846 m；僅為參數邊界推算，場景未提供此高差的驗收證據。
- 跨越弧線時間 **0.5 s**。若玩家距起跳點大於 **0.18 m**，增加 **0.1 s** 吸附段，總時間 **0.6 s**；否則為 0.5 s。`_motion_point()` 的弧線仍以指定起跳點為起點，不能以玩家按鍵位置另加一段自由跳距。
- 目前 4.30 m 連結的弧線平均水平速度為 `4.30/0.5＝8.6 m/s`；上限距離對應 `4.8/0.5＝9.6 m/s`。不能用步行速度 5.5 m/s 乘跳躍時間推算距離。

跳下另走折線路徑，`drop_max_height＝4.0 m`、`drop_forward_distance＝1.2 m`、`drop_duration＝0.55 s`；這是主動下行參數，不是上跳高度或跨越淨寬。來源：`TraversalParams`、`TraversalActor.try_jump()` 的 `drop` 分支。

## 3. 目錄與命名

### 3.1 現行規則

依賴方向為 **Content → GamePlay → Core**；GamePlay 可讀共用資料型別／Resource，Core 不引用具體角色、關卡或內容腳本。檔名／目錄採 `snake_case`，類別採 `PascalCase`；腳本 `.gd`、資源 `.tres`、場景 `.tscn`。來源：AGENTS.md、ARCHITECTURE.md。

| 現行位置 | 責任與命名範例 |
|---|---|
| `core/` 既有子目錄 | 通用相機／UI／工具，例如 `core/camera/follow_camera.gd`，類別 `FollowCamera` |
| `gameplay/forms/`、`gameplay/traversal/` | 玩法規則，例如 `form_controller.gd`／`FormController`、`climb_surface.gd`／`ClimbSurface` |
| `content/forms/`、`content/traversal/`、`content/ui/` | 資料、呈現、場景組裝，例如 `monkey.tres`、`movement_lab_data.tres` |
| `content/shared/` | 共用色板、材質、shader、風格參數與環境 preset，例如 `architecture_material.tres`、`environment_preset.tscn` |
| `scenes/forms/`、`scenes/traversal/`、`scenes/ui/` | 現有場景；唯一固定測試入口為 `scenes/forms/form_lab.tscn` |
| `gameplay/staff/`、`content/staff/` | 凍結員工邏輯／資料；不接入 FormLab |
| `docs/`、`tools/`、`prototypes/` | 文件、工具、保留回歸資產；不新增獨立切片 |

### 3.2 art/kit、mechanics、levels、shared 規格草案（待確認）

下表回應未來製作分類需求，**不代表新增目錄已獲授權，不搬移現有檔案**。前三項的落點尚未由現行架構定案；最後一項已有明確實作位置。

| 分類 | 草案責任 | 命名範例（僅示意） | 與現行規則的關係 |
|---|---|---|---|
| `art/kit` | 可拼接建築美術資產，不承擔控制器規則 | `wall_straight_w2_h3_d1.glb` | 是否新增根目錄 `art/kit/`、資產格式及尺寸命名待確認 |
| `mechanics` | 可重用機制的內容組裝／配置 | `climb_panel_w3_h3.tscn`、`gap_link.tres` | 實際路徑待確認；現有規則仍在 `gameplay/traversal/`，不能自行另建平行玩法層 |
| `levels` | 關卡幾何配置及組裝 | `courtyard_01.tscn`、`courtyard_01_layout.tres` | 根目錄或 Content／scenes 下的落點待確認；不新增驗證入口 |
| `shared` | 跨模組共用風格資源 | `architecture_material.tres`、`palette_warm_courtyard.tres` | 現行位置為 `content/shared/`；不推定另建根目錄 `shared/` |

尺寸後綴 `w2_h3_d1` 僅示範「寬 2 格、高 3 格、深 1 格」，不是已選定尺寸或公尺值。是否使用此後綴、變體編號、匯出檔與來源檔的名稱對應皆待確認。範例不授權建立任何檔案或類別。

共用風格繼續集中管理；青色攀爬面與黃色跨越線沿用共用機制材質。幾何仍由內容資料提供，不寫入風格資源；環境 preset 不作獨立測試入口。

## 4. 碰撞層與遮罩

### 4.1 已登記層

來源：[project.godot](../project.godot) 的 `[layer_names]`。層編號與位元值不同：第 n 層的值為 `1 << (n−1)`，多層遮罩採位元 OR。

| 層編號 | 名稱 | 位元值 | 現況 |
|---|---|---|---|
| 1 | world | 1 | 世界幾何與世界查詢 |
| 2 | actors | 2 | 玩家碰撞層 |
| 3 | staff | 4 | 凍結員工碰撞層 |
| 4 | interact | 8 | 已命名；本次未定義新互動用途或矩陣 |
| 5 | detect | 16 | 已命名；本次未定義新偵測用途或矩陣 |
| 6～32 | 未命名 | — | 用途待確認，不自行分配 |

### 4.2 現有物件／查詢矩陣與沿用約定

| 對象 | layer | mask | 依據／限制 |
|---|---|---|---|
| 本體與猴形態 | actors＝2 | world＝1 | `TraversalActor._ready()`，`params.world_mask` 預設 1；不是 mask＝2 |
| 世界方塊與斜坡 | 未顯式覆寫，沿用 `StaticBody3D` 預設 | 未顯式覆寫，沿用預設 | `MovementLab.make_block()`／`_build_ramp()`；預期 world 行為，屬引擎預設依賴，未經本次執行確認；未來模組應明定 world 層，完整 mask 決策待確認 |
| 路徑／支撐／變形空間查詢 | 不適用 | world＝1 | `TraversalActor.query_at()`／`supported()`、`FormController` 空間與支撐查詢；排除當前角色 RID |
| 地面陰影與遮擋查詢 | 不適用 | world＝1 | `MovementLab` 的物理射線使用 `params.world_mask`；新增世界碰撞會影響這些查詢 |
| 攀爬面／跨越連結 | 不適用 | 不適用 | `ClimbSurface`／`TraversalLink` 為 Node3D，透過群組搜尋，不是 Area3D 觸發層；標記 Mesh 本身不建立物理碰撞 |
| 被變形替換的舊角色 | 0 | 0 | `FormController._replace_body()` 停用舊體後移除；不是新增碰撞層 |
| 凍結員工（未接入 FormLab） | staff＝4 | world＝1 | [readability_staff.gd](../gameplay/staff/readability_staff.gd)；僅記錄，保持凍結 |

現行玩家遮罩不包含 actors 或 staff；不可因未來新增模組就默默改為全層碰撞。物理 layer/mask 不等於渲染可見層，也不等於攀爬能力／群組。是否增加互動 Area、獨立遮擋層或角色互撞須另行定案。

## 5. 需要使用者決定的問題

1. **網格**：1 格要定為多少公尺？水平與垂直是否共用同一 g？目前沒有足夠依據填入數值。
2. **整數倍適用範圍**：要約束模組拼接包圍盒、實體碰撞，還是所有視覺細節？角色、薄牆、提示線、裝飾與控制器偏移是否例外或使用子網格？
3. **標準尺寸系列**：地板厚度、牆厚、層高、牆段長、平台寬深、斜坡升高／深度、門洞與窄縫淨尺寸，各允許哪些整數格組合？
4. **拼接與匯入**：模組原點、吸附位置、旋轉步進、接縫容差、來源模型單位與縮放規則如何定義？
5. **攀爬**：產品規格是否限制最大牆高，或完全由每個攀爬面決定？目前只有 3 m 場景參照，沒有通用上限。
6. **跨越**：要支援哪些淨間隙與落差？是否固定兩側 0.65 m 退縮，以及預留多少支撐／安全餘量？4.8 m 位移與條件推算的 3.5 m 淨間隙都不能直接當標準關卡尺寸。
7. **跳躍與淨空**：是否保持現有連結式跳躍？要用哪些高差與頂部淨空作製作／驗收標準？自由跳尚無可供規範的實作。
8. **形態通行**：本體與猴形態通道需要多少額外淨寬／淨高？是否將實際窄縫通行納入下一輪授權與驗收？目前只能確認碰撞體尺寸。
9. **目錄**：`art/kit`、`mechanics`、`levels` 是新增實體路徑，還是既有目錄的製作分類？若是實體路徑，各自放在哪一層？`shared` 是否維持 `content/shared/`？
10. **命名**：是否採用格數尺寸後綴（例如 `w2_h3_d1`）？模型來源／匯出格式、變體編號和關卡編號如何統一？
11. **碰撞矩陣**：新世界模組的 mask 是否只含 world，或需含 actors？是否需要角色互撞、interact／detect 的正式用途或獨立遮擋層？凍結 staff 範圍保持不變，除非另行明確解除。
12. **套用邊界**：新規格只約束未來模組，還是之後另行授權調整既有 FormLab 幾何？本文件不授權後者，也不變更唯一固定測試入口。

## 6. 本次驗證紀錄

- 靜態核對：已讀 AGENTS.md 與現行依據，追查主入口、形態覆寫、移動公式、幾何與碰撞設定；推算值均附來源符號或資料欄位。
- 編輯器開啟：**未執行**（本次為文件產出）。
- 主場景至少 120 個物理幀：**未執行**。
- 視窗畫面與操作：**未執行**。本文的靜態上限與推算不構成新尺寸的遊玩驗收。
- 不提交、不推送；既有工作區變更保留。
