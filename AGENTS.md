# Borrowed Shapes — 專案工作約定

## 定位與技術
藉由借用不同形態的體型與能力，把原本無路可走的空間變成通路，體驗以變形巧妙穿行環境的自由。
Godot 4.7、靜態型別 GDScript；3D 斜俯視、正交相機。

## 現行依據
玩法基線以 `docs/DESIGN.md` 為準；依賴與架構以 `docs/ARCHITECTURE.md` 為準；階段範圍查 `docs/P2_CHECKLIST.md`，實際工作以使用者本次授權為限；操作與技術現況查 `README.md`、`docs/TECH.md`。本文件規範工作方式。
`docs/MOVEMENT_SLICE.md`、`docs/FORMS_SLICE.md` 僅供查閱現行基線引用的規則與參數；逐輪試驗、歷史提案、舊產品文件與 QA 紀錄只作查證，不作新增需求、恢復舊玩法或擴大範圍的依據。文件衝突時以使用者最新明確指示為先，其餘依上述各自責任判讀；無法判定的部分先回報，不自行選用歷史設定。

## 目錄與命名
- `core/`：通用工具、相機、UI 基礎與 Bus；新增通用程式放對應既有子目錄。
- `gameplay/forms/`、`gameplay/traversal/`：變形與移動規則；新增相關邏輯放此處。
- `gameplay/staff/`：既有員工邏輯；與 `content/staff/` 的資料、參數，以及既有員工場景、診斷與回歸資產持續凍結，直到使用者明確解除指定範圍；不得自行修改或接入 FormLab。
- `content/forms/`、`content/traversal/`、`content/staff/`、`content/ui/`：配置 Resource、場景組裝腳本與呈現；新增資料放對應既有目錄。
- `content/shared/`：集中管理風格色板、共用材質／shader、風格參數與可重用環境 preset；preset 不作獨立測試入口。
- `scenes/forms/`、`scenes/traversal/`、`scenes/ui/`：現有場景；未來場景經同意後放對應位置。
- `art/kit/`：本輪授權的模組件資產（scene／mesh），不放關卡、玩法或測試入口；共用材質仍放 `content/shared/`。
- `docs/` 記設計與驗證；`tools/` 放開發工具；`prototypes/` 留存既有回歸資產，不新增切片。
檔名／資料夾用 `snake_case`，類別用 `PascalCase`；腳本 `.gd`、資源 `.tres`、場景 `.tscn`。依賴方向為 Content → GamePlay → Core。未列出的既有目錄不代表可自行擴充。

## 尺度
新 `art/kit/` 件庫經使用者確認採 **1 格＝0.5 m**，水平與垂直共用；只約束新件庫。既有場景不重新吸附、不調尺寸；其他尚未定案的空間規格仍依 `docs/spec.md`，不能從世界單位推定通用網格。
角色碰撞尺寸（寬×高×深）：本體 **0.30×0.30×0.30 m**，猴形態 **0.64×1.00×0.64 m**。
新內容製作規格：**層高3m**（完成地板頂面到頂面）、**標準牆2.5m**、樓板厚0.5m；**標準攀爬高度＝層高＝3m，單次攀爬上限3m**，更高結構需分段落腳。這是製作約束，現有控制器沒有全域高度上限，本輪不加限制、不改移動規格。可跨越淨寬規格：**待定**（目前平台間隙 3 m；跳躍位移參數上限 4.8 m，非淨寬）。

## 現有系統
- 玩家：`gameplay/traversal/traversal_actor.gd` 處理輸入、移動與狀態；`gameplay/forms/ground_form_actor.gd` 提供本體限制。
- 變形：`gameplay/forms/form_controller.gd` 負責切換、冷卻與空間預檢；同目錄 `form_rules.gd` 為判定，`content/forms/` 提供初始化與形態資料。
- 攀爬：`gameplay/traversal/climb_surface.gd` 定義攀爬面；玩家控制器執行附牆、上下與翻越。
- 跨越：`gameplay/traversal/traversal_link.gd` 定義起跳邊與落點，`traversal_math.gd` 計算判定；玩家控制器執行。

## 可重用移動元件（2026-10-17）

本輪授權的三個元件位於 `scenes/traversal/`，是組裝資產，不是測試入口。每個元件由根節點腳本、`TriggerZone/CollisionShape3D` 與 `VisualMarker` 三部分構成；斜坡另有實際承重的根層 `CollisionShape3D`。內容腳本位於 `content/traversal/`，攀爬／跨越規則仍位於 `gameplay/traversal/`。

### 放置與參數

直接將以下 scene 實例拖入既有關卡，在根節點 Inspector 設定參數。幾何、碰撞與標記會在編輯器預覽同步更新；遊戲啟動時依配置建立。維持 Scale＝(1, 1, 1)，尺寸使用匯出參數，方向使用根節點 Transform 的 Rotation；不把尚未決定的網格／尺寸規格套入現有幾何。

| 元件 | 放置原點與方向 | 匯出參數及意義 |
|---|---|---|
| `climb_surface.tscn` | 牆面底部中心，局部 +Z 朝牆外、X 橫向、Y 向上；只轉 Y 軸，保持直立。需另有實體牆與頂部支撐。 | `width` 有效寬、`height` 有效高（預設皆 3）；`required_capability` 沿用 CLIMB；`enabled` 決定是否登記攀爬候選及顯示標記；`params` 提供觸發範圍參照。 |
| `traversal_link.tscn` | 根原點為起跳線段起點；`edge_end` 是局部線段終點偏移；`landing` 是整條線段平移到落點的局部位移，可包含高差。旋轉根節點會一併轉動邊線與落點方向。需另有兩側平台。 | `edge_end`、`landing` 必須依關卡配置；`required_capability` 沿用 CLIMB；`enabled` 決定是否登記跨越候選及顯示標記；`params` 提供標記粗細與起跳範圍參照。每個實例單向，雙向通路放兩個實例。 |
| `return_ramp.tscn` | 楔形包圍盒中心；局部 -Z 為高端、+Z 為低端。以根節點 Y 旋轉調整下坡方向，將高端接上平台、低端接地。 | `width` 寬（2）、`height` 升高（3.05）、`depth` 水平投影深度（6.1）；`enabled` 決定啟動時是否有承重碰撞與視覺。坡面與凸包由相同頂點生成，world layer／mask 均明定為 1。 |

以上為世界單位，約等於公尺，並非已定案的模組格數。參數應在編輯器或 `add_child()` 前設定；不承諾執行中動態改尺寸、方向或中斷已開始的攀爬／跨越。`params` 參照應與玩家所用移動配置一致；實際判定始終以玩家當前形態的參數為準。

### 觸發、材質與現有關卡接線

- `TriggerZone` 是分離的範圍參照，layer／mask＝0，monitoring／monitorable 關閉，不產生新的進出事件或阻擋。攀爬保留群組與 anchor／意圖／屋頂下牆判定，跨越保留最近線段點／距離／完整路徑／落點支撐判定；不可改成 Area overlap 即執行動作。攀爬 Box 參照內外接近範圍，跨越 Capsule 參照線段周圍起跳範圍；這些外包範圍不等於合法操作判定。斜坡沿用實體楔形行走，沒有新增返回傳送或觸發動作。
- 三者的 `VisualMarker` 預設分別引用 `content/shared/climb_marker_material.tres`、`traversal_marker_material.tres`、`return_ramp_material.tres`，保留舊入口顏色；共用材質的調整在資源處進行。
- FormLab 繼續由既有 `StyleFoundation` 注入共用 `mechanism_material`／`surface_material` 與逐實例 shader 參數；攀爬青色、跨越黃色與斜坡平台色角色維持原樣，不新增 shader 或風格系統。
- `MovementLab`（及繼承它的 FormLab）現在引用並實例化上述三個 PackedScene。位置與尺寸仍由 `movement_lab_data` 提供，沒有把關卡座標寫入元件。舊入口斜坡為保留 alpha 遮擋淡出會複製共用材質；FormLab 隨即套用原有共用 shader 與逐實例透明度。
- 目前攀爬面仍為位置 (-3, 0, 0.5)、寬高 3；跨越雙向線段仍為 X=-0.65／3.65、Y=3.04、Z=-3.6～-0.6、平移位移 ±4.3；斜坡仍為中心 (5.5, 1.525, 3.45)、尺寸 (2, 3.05, 6.1)。不調整既有場景手工細節或員工資產。

### 本輪驗證

引擎為 `4.7.stable.official.5b4e0cb0f`，以下 Godot 命令均在沙盒外執行：

- 編輯器開啟：**通過**。`/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_component_editor.log --quit-after 180`，必要匯入完成，沒有錯誤或警告；為結束驗證依 `--quit-after` 主動退出，退出碼 0，不宣稱使用者手動正常關閉驗收。
- 主場景啟動：**通過（無頭）**。`tools/run_tests.sh` 僅執行 FormLab，使用 `--fixed-fps 60 --quit-after 180`（物理步長 60 Hz，超過 120 物理幀），退出碼 0，沒有錯誤或警告。日誌位於 `${TMPDIR}/borrowed_shapes_tests/form_lab.log`。
- 畫面與操作：**受阻**。已用 `Godot --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_component_window.log res://scenes/forms/form_lab.tscn` 啟動視窗版，Metal／Forward+ 初始化且日誌無錯誤或警告；UI 工具只能綁定既有 `movement_lab.tscn` 編輯器，無法取得獨立遊戲視窗。未確認相機、HUD、移動、變形、攀爬、跨越與斜坡往返。因結束受阻驗證而對本次程序送 SIGTERM，退出碼 143，屬主動終止，不列異常，也不視為正常關閉通過。
- 未新增機制或測試場景；未提交、未推送。原有工作區修改保留。

## 基礎模組件庫與組合規則（2026-10-17）

既有三件方向已通過，2.5m標準牆與剖面已通過；批次01牆角／填充塊已通過並製作，牆端合併柱子延期。1m短牆已通過並製作；批次02已結案，直線／轉角基座與邊緣收口均決定不做，不新增資產。新件庫g＝0.5m，水平與垂直共用；規則只適用新內容，不改既有FormLab幾何、攀爬面或移動規格，不搭關卡、不新增測試場景。

### 已決定的製作數值

| 項目 | 決定值 | 定義與驗收界線 |
|---|---|---|
| 層高 | **3m（6格）** | 完成地板頂面到上一層完成地板頂面，包含0.5m樓板厚度。 |
| 標準牆高 | **2.5m（5格）** | 下層完成地板頂面到上層樓板底面。 |
| 標準攀爬高度 | **＝層高＝3m（6格）** | 攀爬面連續覆蓋2.5m牆面＋0.5m樓板側面，不將牆高當作整段攀爬高度。 |
| 單次攀爬上限 | **3m** | 更高結構需分段落腳，每段高度≤3m，落腳處另須滿足角色支撐、淨空與重新附牆條件。是新內容製作上限；現有ClimbSurface.height可配置更高，程式沒有全域夾限，本輪不改控制器或增加機制。 |
| 通行淨高 | **1.5m（3格）** | 行走面到最低實體碰撞面；是走路淨高，不是跳躍／翻越淨空。 |
| 一般通道淨寬 | **1m（2格）** | 兩側碰撞內表面淨距，猴0.64m置中時理想單側餘量0.18m；仍待操作驗收。 |
| 窄縫淨寬 | **0.5m（1格）** | 本體0.3m置中時單側餘量0.1m，猴0.64m大於縫寬；窄縫淨高、深度及實際通行待確認。 |

決定理由：沿用已驗收的3m攀爬面高度，不動移動規格。角色尺寸、jump_arc=0.65m、max_jump_height=1.2m、max_jump_distance=4.8m與翻越參數保持；整層高差3m仍不能以現有跨越取代攀爬。以上新規格不回改既有關卡。

### 尺寸依據與待確認項

| 依據 | 現行值／推算 | 來源檔案與限制 |
|---|---|---|
| 本體碰撞外尺寸 | 0.30×0.30×0.30 m，半徑 0.15 | `content/forms/slime.tres` 的 body_size；`gameplay/forms/form_def.gd` 的 movement_params()／collision_radius()；`gameplay/traversal/traversal_actor.gd` 的膠囊建置。 |
| 猴形態碰撞外尺寸 | 0.64×1.00×0.64 m，半徑 0.32 | `content/forms/monkey.tres`、同上形態／玩家腳本。不是方盒通行保證；不將角色尺寸吸附或取整。 |
| 場景攀爬高 | 3m（現行）；新內容單次製作上限3m | `content/traversal/movement_lab_data.gd` climb_height 預設 3，`.tres` 未覆寫；`gameplay/traversal/climb_surface.gd` anchor() 依個別面 height 夾限，`traversal_actor.gd` 依面高翻越。沒有獨立全域高度上限；本輪只記製作約束。 |
| 跨越弧頂增量 | 同高起落時腳底最高 +0.65 m（推算） | `content/traversal/traversal_params.gd` jump_arc；`.tres` 未覆寫；`gameplay/traversal/traversal_math.gd` arc_point()：lerp+UP×4a·t(1−t)。不是自由跳高度。 |
| 跨越終點高差 | 絕對值≤1.2 m（現行參數） | 同參數 max_jump_height，`traversal_math.gd` jump_rejection() 比較起落點 Y；不是弧頂，也不能推出可跳上任意 1.2 m 台階。需有效連結、路徑與支撐。 |
| 跨越水平位移 | ≤4.8 m；現行連結 4.3 m、淨間隙 3 m | max_jump_distance 與 `content/traversal/movement_lab_data.tres`；淨間隙系列**待確認**。本體無跳躍，見 `gameplay/forms/ground_form_actor.gd`。 |
| 現有返回坡 | 高3.05／長6.1，比例0.5（推算） | `movement_lab_data.tres` ReturnRamp；樣件取高3、長6，保持比例0.5及整數格。最大可走坡度、坡端通行餘量**待確認**。 |

**樣件尺寸的選擇理由**：牆件自身沒有攀爬能力；牆長 2 m、地板 2×2 m、斜坡寬 2 m 是本輪作者流程樣本，不能由角色或跳躍數值唯一推出，是否作量產標準**待確認**。牆厚／地板厚 0.5 m 是新網格最小正整數厚度的選擇，不沿用既有0.3 m牆厚。通行尺寸、層高與標準牆高已由使用者另作上述設計決定，不宣稱它們能由角色大小唯一推導或已操作驗收；同高猴形態跨越至少涉及1.0+0.65＝1.65 m理想身體高度，尚須起跳落點抬升、碰撞與安全餘量，不能直接將1.65取整當層高規格。

| scene（`art/kit/`） | 預設寬×高×深（格／m） | 碰撞與方向 |
|---|---|---|
| `wall_straight_w2_h5_d1.tscn` | 2×5×1／1×2.5×0.5 | 固定短牆；BoxShape3D，沿用直牆pivot。 |
| `wall_straight_w4_h5_d1.tscn` | 4×5×1／2×2.5×0.5 | 標準牆；BoxShape3D，X牆長、Y向上、Z厚度。 |
| `wall_corner_w2_h5_d2.tscn` | 2×5×2／1×2.5×1 | L形Mesh＋兩獨立Box，外角底部pivot。 |
| `filler_w1_h1_d1.tscn` | 1×1×1／0.5×0.5×0.5 | BoxMesh＋BoxShape3D，底角pivot。 |
| `floor_w4_h1_d4.tscn` | 4×1×4／2×0.5×2 | BoxShape3D；頂面＝根Y+0.5。 |
| `ramp_w4_h6_d12.tscn` | 4×6×12／2×3×6 | ConvexPolygonShape3D 楔形；局部-Z高端、+Z低端。 |

命名 `<類別>[_變體]_w<格數>_h<格數>_d<格數>` 採 snake_case；w/h/d 是局部X/Y/Z拼接包圍尺寸，坡長是水平投影。斜坡檔名描述預設值；實例參數修改不產生新資產／不改場景檔名，將來獲授權保存固定變體時再依實際格數命名。

### 腳本型件與純模型件的放置責任

- **所有件的對外scene與視覺來源**放 `art/kit/`：包含純模型牆／地板scene、BoxMesh或外部模型，以及掛腳本的參數化斜坡scene。掛腳本不改變資產入口位置；正式模型亦沿用這些scene。
- **件的參數化建置／內容組裝腳本**放對應既有 `content/` 子目錄。本件 `kit_ramp.gd` 放 `content/traversal/`，因它負責可行走表面的尺寸、白盒Mesh與碰撞組裝，與該目錄既有 movement_lab／返回坡內容職責相同；不讀取玩家輸入、不實作攀爬或跨越判定。不是因為腳本就自動屬於GamePlay。
- **玩法規則腳本**仍放 `gameplay/traversal/` 等對應既有目錄；本件沒有新增玩法。共用材質保持 `content/shared/`。純模型件不為形式一致而加空腳本；腳本型件也不將建置程式藏進外部模型匯入檔。
- 其他腳本型件按實際責任選既有Content落點，不將所有通用建築腳本都歸入traversal；找不到合適既有目錄時先提案，不擴目錄。本輪不搬移任何既有檔案。

### 參數化斜坡：建議與實作

採用 `content/traversal/kit_ramp.gd` 的 `@tool`／`@export` 參數化，而非小單位加填充塊。理由：現有需求有不同升高與水平長度；單一楔形能直接表達，避免多段碰撞接縫、填充塊數量與獨立新件。這是資產建置，不新增移動機制；原 FormLab 返回坡不改接此件。

- 根Inspector的 `width`（預設2）、`height`（3）、`length`（6）以公尺輸入；setter 四捨五入至0.5 m倍數，最小0.5 m。編輯器自動更新；改參數後維持Scale＝1。任意比例不代表已驗收可走，特別是高度增加但長度不變時。
- 同一組寬／高／長建立6頂點楔形凸包與8面白盒Mesh。碰撞是獨立Shape資源，沒有從視覺Mesh重新烘焙；改材質或正式Mesh不改碰撞。
- `visual_mesh` 是正式Mesh替換槽，非空時腳本不覆寫該Mesh；保留節點結構、碰撞及共用材質。正式Mesh需符合目前參數的包圍尺寸與幾何中心原點（奇數格寬／長的子節點偏移由腳本處理）；不自動縮放或改碰撞配合錯誤來源。直牆／地板仍直接替換 `Visual/MeshInstance3D.mesh`。只換網格，不換整棵匯入scene。
- 原創 `ramp_w4_h6_d12.obj` 保留為預設尺寸參照／scene初始Mesh；進入樹後白盒由參數生成。沒有外部素材或貼圖依賴。未增加填充件、玩法Area或攀爬／跨越功能。

### Pivot、節點與旋轉佔位（方案A，Y維持底部）

使用者採用方案A並明定Y維持底部，**Y沒有必須置中的理由**。牆的「基準面中心」在此精確定義為基準面水平方向中心、底邊中點；高度由底部向上。所有已建立件均維持根Y在底部、Scale=1、Mesh／碰撞獨立，水平pivot依其拼接責任定義。

| 件 | 根局部外邊界與子節點偏移 | 0.5m格線核對 |
|---|---|---|
| 標準牆2×2.5×0.5 | X[-1,1]、Y[0,2.5]、Z[0,0.5]；兩子節點皆在(0,1.25,0.25)。 | 三軸外邊界皆0.5倍數，沿用基準面水平中心／Y底部。 |
| 地板2×0.5×2 | X/Z[-1,1]、Y[0,0.5]；兩個子節點皆在(0,0.25,0)。 | 三軸最小／最大邊界皆0.5倍數，維持XZ中心／Y底部。 |
| 預設坡2×3×6 | X[-1,1]、Y[0,3]、Z[-3,3]；兩個子節點皆在(0,1.5,0)。 | 預設各邊界及6楔形頂點皆在0.5格點。寬／長奇數格時，該軸子節點中心向正軸偏移0.25m，不移根；例如寬1.5m範圍[-0.5,1]。 |

參數化坡的水平根是最近幾何中心負側的格點錨點：偶數格與幾何中心重合，奇數格中心位於根+0.25m。一般式為 n格尺寸範圍 `[-floor(n/2)×0.5, ceil(n/2)×0.5]`。因此@export寬／長仍允許任意正整數格，不必犧牲0.5m尺寸步進或將根移到半格。未來牆長若改成奇數格，不能直接沿用水平置中契約，需另行設計格點錨點；本輪固定4格牆長符合要求。

```text
KitPiece (Node3D，根Y在底部；水平pivot依上表)
├── Visual (Node3D)
│   └── MeshInstance3D
└── Body (StaticBody3D，layer=1 / mask=1)
    └── CollisionShape3D
```

牆／牆角／填充塊預設引用 `content/shared/kit_material.tres`（building），地板／斜坡引用 `content/shared/kit_platform_material.tres`（platform）；兩者共用現有architecture shader，詳見「風格Resource化」。正式Mesh仍以幾何中心建模，沿用對應子節點偏移；碰撞不讀取視覺Mesh。牆／地板Box、坡為獨立實心楔形凸包。

根只允許Y軸90°倍數旋轉。格點邊界旋轉後仍落0.5格線；90°／270°交換寬深，180°把牆厚翻到基準面另一側或反轉坡高低端，**不保證原地旋轉仍佔相同矩形**。旋轉後須檢查新佔位與支撐。內部子節點0.25偏移合法，平移吸附限制適用根與拼接邊界。

### 編輯器吸附與 GridMap 適用性

**所有件的外邊界必須落在0.5m格線；根平移吸附0.5m、旋轉90°、Scale=1。** 此處外邊界指軸向包圍盒邊界、拼接面位置及楔形端點；斜面為連續表面，不要求斜面每個內點的座標都是0.5倍數。正式Mesh須符合尺寸契約，不得越出標準包圍盒。本輪不更改使用者編輯器偏好。

不再使用0.25m根吸附或奇偶格放置相位補償；必要偏移在資產子節點中完成。所有已建立件與坡奇偶格參數在四種90°朝向均需核對視覺／碰撞邊界。

採scene吸附。GridMap能使用不同尺寸Mesh／碰撞，但跨多格件不自動登記其餘格子的佔用；參數化腳本與逐實例Inspector不會隨MeshLibrary成為scene，分離Body與material_override亦需轉換。本輪不建立GridMap／MeshLibrary，沿用既有場景組裝流程。依據：[Godot官方Using GridMaps](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html)。

### 垂直堆疊、牆角與牆端

- **牆底起點**：只有牆的整個水平足跡都落在承重地板範圍內，才可令牆根Y＝該支撐地板頂面。不能只因旁邊有同標高地板，就假設外側牆受支撐。地板外側的牆需有下方既有支撐，或改放置／重複既有地板件；不能憑StaticBody不掉落就視為有支撐。具備完整支撐後，地板根Y＝b、厚t時牆根Y＝b+t。地板根0／厚0.5時牆根0.5，標準2.5m牆頂3.0。牆件不含地板厚，不從樓層地板底部起算牆高。
- **純牆堆疊**：第二段牆根Y＝第一段牆根Y+牆高，尺寸與中心線一致、端面貼齊。標準牆第一段根0.5、高2.5時第二段根3.0，不能把這稱為完整樓層間距。
- **標準夾樓板堆疊**：下層板根Y=0、頂0.5；2.5m牆根Y=0.5、頂3.0；上層樓板根Y=3.0、頂3.5；完成地板頂面間距3.5−0.5=3m。下一層牆根Y=3.5。牆外側與樓板側面齊平，禁止沿攀爬面新增突出屋簷或台階。
- **直線牆端**：未旋轉等長牆的根沿X相差2 m即可端面對接；Y轉90°後沿Z相差2 m。端面與外觀都封閉，不添加端蓋件或藏入重疊段。
- **90°牆角**：新內容轉角一律使用 `art/kit/wall_corner_w2_h5_d2.tscn`；不再使用「一面貫通、一面抵住」的兩直牆對接做法。舊離線預覽／既有手調關卡僅作歷史，不在本輪搬移。牆角根為外角底部、局部X/Z[0,1]；直牆僅與角件端面接觸，不穿插或把角件疊在已有實體轉角上。未旋轉角件的兩端面是X=1、Z[0,0.5]及Z=1、X[0,0.5]；例如2m直牆根(2,b,0)、Y轉0°接X端，另一根(0,b,2)、Y轉90°接Z端。若角件無法配合所需尺寸，記錄缺件，不默默恢復舊對接法。
- **坡端**：坡底根Y＝低端標高，高端Y＝根Y+height；高端接地板**頂面**，平台實體位於高端之外，不穿入楔形。若用預設3m升高接地板頂面3m，地板根Y為2.5。低端尖線無額外台階；實際角色通過、邊緣保護與接縫容差仍需另行操作驗收。

### 前輪三件放置遷移與預覽（歷史，現行剖面見下節）

全專案搜尋三件scene路徑／檔名：未發現外部關卡scene或內容腳本引用，只有資產自身與文件；沒有可搬動的遊戲實例，不改FormLab或其他手調場景。來源牆Mesh／Shape向+Z偏移0.25m已同步修改。若外部未存檔實例仍採舊pivot，保持世界幾何的遷移式為 `新根 = 舊根 − 根Basis × Vector3(0,0,0.25)`；不改旋轉或尺寸。這是一次性遷移，不是日後吸附步長。

離線預覽遷移：牆A舊根(0,0.5,-1.25)→**(0,0.5,-1.5)**、Y轉0°；牆B舊根(-0.75,0.5,0)→**(-1,0.5,0)**、Y轉90°。世界足跡仍分別X[-1,1]/Z[-1.5,-1]與X[-1,-0.5]/Z[-1,1]，完整落在支撐板內，轉角只在Z=-1端面相接。牆根全部落0.5格點。

四塊既有地板根維持(-1,0,-1)、(1,0,-1)、(-1,0,1)、(1,0,1)，聯集X/Z[-2,2]、Y[0,0.5]；坡根維持(0,0,2.5)，參數width2、height0.5、length1，高端Z2/Y0.5、低端Z3/Y0。地板與坡不需遷移。此是三種件的離線PNG，不新增4×4地板資產、通道、窄縫或組合scene。舊PNG保留為歷史，不再作放置依據；新版見聊天附圖 `kit_pivot_a.png`。

### 新標準牆使用與堆疊剖面

新增唯一資產 `art/kit/wall_straight_w4_h5_d1.tscn`，寬2m／高2.5m／厚0.5m，沿用既有節點結構、獨立BoxShape3D與`content/shared/kit_material.tres`。它是純模型件，無新增腳本／@export；尺寸固定，不以Scale改高。拖入時根放在基準面底邊中點，厚度向局部+Z展開，根吸附0.5m、Y旋轉90°、Scale=1；正式mesh保持幾何中心建模，替換`Visual/MeshInstance3D.mesh`，不改碰撞。

新版離線PNG `kit_standard_wall_section.png` 為X=0的YZ剖面；只畫既有地板兩次、新標準牆與攀爬面配置線，不建立任何組合scene／關卡，也不將攀爬元件接入新牆資產。剖面採：

| 元件／參照 | 根位置與方向 | 世界範圍 |
|---|---|---|
| 下層既有地板 | (0,0,0.5)，不旋轉 | X[-1,1]、Y[0,0.5]、Z[-0.5,1.5]；覆蓋牆底及外側起步區。 |
| 2.5m標準牆 | (0,0.5,0)，不旋轉 | X[-1,1]、Y[0.5,3]、Z[0,0.5]；基準面Z=0，外露攀爬側為Z=0.5。 |
| 上層既有樓板 | (0,3,-0.5)，不旋轉 | X[-1,1]、Y[3,3.5]、Z[-1.5,0.5]；外側與牆齊平Z=0.5。 |
| 3m攀爬面配置線 | (0,0.5,0.5)，局部+Z向外，width=2、height=3 | 由Y0.5至3.5，Z0.5不變；下2.5m沿牆面，上0.5m沿樓板側面。攀爬面原點與牆pivot不同，不能直接共用根座標。 |

這裡width=2是配合2m牆件的內容配置，height仍沿用現行3m；不改原FormLab攀爬面寬高或位置。青色線表示有效幾何平面，實際VisualMarker尚有0.025m子節點偏移，不作碰撞／格線基準。單一連續攀爬面跨牆與板，不在接縫拆成兩個攀爬元件。

**翻越落點**：依`climb_surface.gd` anchor()與`traversal_actor.gd` _step_climb()，猴半徑0.32＋wall_clearance0.08使腳底原點沿面外偏0.40m，頂端腳底示意為(0,3.54,0.90)。落點局部座標(x,3+landing_lift,-mantle_depth)，取x=0得到世界**(0,3.54,-0.15)**；其承重面位於Y3.5，落點在板外緣Z0.5內側0.65m，腳底抬高0.04m是既有容差。五點支撐在X±0.32與Z[-0.47,0.17]，皆位於上層板範圍，不能把落點放在牆頂Y3.0。翻越弧線增量0.12m，示意最高腳底3.66、猴頂4.66；應檢查上方淨空及整段膠囊掃掠，不以靜態落點取代實測。來源：`content/traversal/traversal_params.gd`、`gameplay/traversal/traversal_math.gd` arc_point()、`gameplay/traversal/traversal_actor.gd` path_clear()/supported()。

**接縫／不連續項**：
- Y0.5為下層地板／牆接觸，Y3.0為牆／上層板接觸；幾何淨間距均0、無穿插。Y3.0仍有獨立碰撞體接縫，Z0.5側面共平面、沒有台階；角色擦縫是否穩定仍待視窗操作驗收。
- Y3.5是垂直攀爬面轉為水平樓板的90°頂部邊，透過既有翻越弧線銜接，不是攀爬面繞彎；落點與膠囊通路須維持空曠。
- 此剖面沒有屋簷／倒角／突出基座；將來若使樓板側面外凸、退縮或改成斜面，單一矩形攀爬面便不能自動貼合，須另審接縫與配置。不得把尚未批准的其他件加到這條攀爬路徑。

### 翻越平台／屋頂的最小進深

進深D由攀爬外緣往平台內側量到另一端支撐邊界，量的是實體支撐面，不是裝飾Mesh。依現行翻越落點退縮`mantle_depth=0.65m`及猴碰撞半寬`radius=0.32m`，完整膠囊／五點支撐的幾何最低條件為 **D≥0.65+0.32=0.97m**；按0.5m格線向上取整，最低整格物理進深為 **1.0m（2格，僅絕對下限，不是製作合格門檻）**。1m時落點至遠邊只餘0.35m，扣猴半寬僅0.03m，這不是已驗收的舒適餘量。近邊條件0.65−0.32=0.33m，不能用它替代遠邊進深。

來源：`content/traversal/traversal_params.gd` mantle_depth；`content/forms/monkey.tres` body_size.x=0.64、`gameplay/forms/form_def.gd` collision_radius()/movement_params()；`gameplay/traversal/traversal_actor.gd` _step_climb()將局部Z設成−mantle_depth，supported()查中心與±radius五點。

**製作檢查門檻：至少1.5m（3格）進深。** 現行_walk_footprint()另以radius+edge_safety_margin=0.32+0.05=0.37m檢查邊緣保護圈；要求落點整圈均有支撐時D≥0.65+0.37=1.02m，向上取整為1.5m。1m只滿足前述幾何最低，不能宣稱落地後邊緣保護圈完整或各方向操作通過。`body_safe_margin=0.005m`是碰撞求解參數，不重複加成角色半寬；0.05m保護圈也不是碰撞體加厚。依使用者批次01回覆，步驟10人工檢查正式採1.5m門檻；1m僅註記物理絕對下限，不新增引擎限制。

如有對向牆／障礙，內側淨距另需容納膠囊、碰撞餘量及整段翻越弧線，不能只核對支撐板深。橫向也須覆蓋落點±0.32m，完整步行圈則±0.37m；本次最低進深不是任意寬度平台的通行保證。前輪剖面上層板深2m，滿足兩種進深條件，無需改圖或資產尺寸。

### 攀爬與翻越路徑的裝飾規則

攀爬面與翻越路徑所在的面保持平齊；牆面／樓板側面連續共平面，不能因裝飾加凸台、退台或斜角改變碰撞通路。屋簷、倒角、飾條只用在非攀爬面；若用在攀爬面，**只能是無碰撞視覺Mesh，且不凸出攀爬平面**。例如外法線+Z、攀爬平面Z=0.5時，該裝飾所有頂點須Z≤0.5，不能把機制VisualMarker的既有偏移當作裝飾凸出的許可。翻越落點、膠囊掃掠與頭頂淨空仍須保持；無碰撞外觀也不能遮住機制標記或使路徑判讀失真。

### 批次01已批准件：牆角與填充塊

使用者已確認牆角與填充塊；本輪僅製作這兩件。共用材質 `content/shared/kit_material.tres`，根吸附0.5m、Y旋轉90°、Scale=1；根Y在底部、水平以已批准底角格點定位。沒有玩法腳本或機制。

| scene | 尺寸／pivot | 使用與碰撞 |
|---|---|---|
| `art/kit/wall_corner_w2_h5_d2.tscn` | 外包1×2.5×1m；X/Z[0,1]、Y[0,2.5]；根在外角底部(0,0,0)。 | 專用90°L形轉角，厚0.5m。單一L形Mesh來自同目錄原創OBJ，子節點(0.5,1.25,0.5)；Body內兩Box獨立於Mesh：A為X[0,0.5]/Z[0,1]，B為X[0.5,1]/Z[0,0.5]，兩者皆Y[0,2.5]、只在端面相接。 |
| `art/kit/filler_w1_h1_d1.tscn` | 0.5m立方體；三軸[0,0.5]，底角pivot。 | 補實際整格空缺，不能填入淨空／落點；Mesh與獨立Box子節點均(0.25,0.25,0.25)。用量超標只人工警示，不自動刪除。 |

節點仍為KitPiece/Visual/MeshInstance3D與KitPiece/Body；角件多一個`Body/CollisionShape3D_B`，保留原`Body/CollisionShape3D`。正式mesh替換同一Visual節點，保持包圍尺寸與幾何中心原點，不由模型烘焙碰撞。原批次01 PNG仍為通過的離線設計依據，非Godot遊戲截圖。

**填充塊警告初值建議N=16**：單一內容區塊超過16個（第17個起）提示「檢查是否缺少較大規格件／應簡化組裝」。16個0.5m塊已可鋪成2×2m單層，超過此量適合作早期重複補洞訊號；不是引擎效能上限、禁止數量或自動合併門檻。區塊指作者明確劃分的一個組裝範圍，人工計數各填充塊實例一次，不能為避警告任意拆區；沒有區塊定義時先記待確認，不自行新增分區系統。只記步驟10待辦，本輪不實作工具；N可依M4實際用量調整。

### 已批准固定短牆與後續批次暫停

短牆已選**固定尺寸**，1m預覽已通過並建立唯一新件 `art/kit/wall_straight_w2_h5_d1.tscn`：1×2.5×0.5m、X[-0.5,0.5]、Y[0,2.5]、Z[0,0.5]，沿用直牆基準面水平中心／Y底部pivot。Mesh與獨立Box子節點均(0,1.25,0.25)，引用共用kit_material；根0.5m吸附／Y旋轉90°／Scale=1。2格牆長為偶數格，四種90°朝向外邊界仍落0.5格線；純模型件、無@export牆長腳本，不新增其他尺寸。正式Mesh以幾何中心建模，替換Visual/MeshInstance3D.mesh，不改Body碰撞。
**批次02結案：決定不做。** 直線／轉角基座及幾何邊緣收口均不製作，理由與延期狀態見下表。先前離線PNG與剖面僅留作歷史提案，不再視為待批准製作清單。

| 項目 | 決定／狀態 | 原因與日後處理 |
|---|---|---|
| 直線／轉角基座 | **決定不做** | Y=0不透明地面會遮擋Y[-0.5,0]基座；凸出基座會侵占0.5m窄縫與1.0m通道的淨寬。不為露出基座而搬移既有地板、牆或斜坡。 |
| 邊緣收口 | **決定不做幾何** | 依使用者結案判定，5mm／10mm內凹在遊戲畫面中不可見，幾何成本無效益。日後若需要外觀細節，改用材質細節，不新增幾何；本輪不實作材質或風格。樓板Y=3.5的90°頂邊仍維持完整。 |
| 牆端／柱子 | **本輪不做，合併延期** | 白盒幾何相同，避免重複資產；待正式Mesh確實需要端部造型時才重新提案。 |
| 倒角、樓梯 | **本輪不做，延期** | 尚無M4實際缺件證據；只在實際缺少時記錄用途與證據，不預先製作。 |
| 屋簷 | **本輪不做，延期** | 當前無必要挑簷需求，突出幾何可能侵入翻越路徑；歷史設計不是製作授權。 |

### 批次02結案規則盤點（2026-10-17）

以下六項均已寫入既有規則，本輪核對保留，沒有調整數值或擴大實作：

- 層高3m（完成地板頂面到頂面）、標準牆2.5m，見「已決定的製作數值」。
- 標準攀爬高度＝層高＝3m；單次攀爬上限3m，更高結構分段落腳。
- 平台／屋頂進深製作檢查門檻1.5m；1m僅為物理絕對下限，見「步驟10」。
- 新內容轉角一律使用牆角件；不恢復兩直牆貫通／抵住對接法。
- **機制色不屬於色板角色**；青色攀爬與黃色跨越提示使用固定機制色，不隨A/B切換。
- 當時三角色材質為提案；現行kit僅building／platform兩角色，FormLab保留既有ground，接線見「風格Resource化」。基座／收口取消不新增角色。

本輪補充的是「決定不做」原因與現行狀態、歷史提案失效標示，以及上述盤點索引；既有六項決定無缺漏。未新增資產、未搭關卡、未做風格實作、未提交。

**牆端／柱子合併為同一延期項目**，白盒幾何相同不重複建資產；等正式mesh實際需要端部造型時再提案／製作，不因牆端名稱而增加碰撞。倒角、樓梯同樣延期，M4實際缺少時才記錄用途與證據；不預先恢復排程。

### 平屋頂與短牆選擇依據

**平屋頂可直接引用現有 `art/kit/floor_w4_h1_d4.tscn`，不新增資產。** 它已有2×0.5×2m封閉BoxMesh、獨立BoxShape與共用材質，可作最上層板。維持Y底部、Scale=1，按0.5m根吸附拼接；攀爬側外緣須與牆齊平。單塊深2m足以容納上述1.5m進深建議；後續只替換其正式Mesh即可，不需空的「roof」包裝scene。坡屋頂、排水形狀或突出簷口不在本次範圍。

| 短牆方案 | 優點 | 缺點與約束 |
|---|---|---|
| 牆長@export參數化 | 單一scene產生1／2m等尺寸，編輯器調長可同步Mesh與碰撞，減少重複檔案。 | 需@tool腳本、幾何重建與正式Mesh尺寸契約；1格等奇數格長必須改用格點錨點或限制偶數格，不能維持水平置中並宣稱所有外界仍落0.5格線。Inspector值不代表已驗收拼接；工具維護與誤設風險較高。 |
| 固定尺寸多件 | 建議先只加1m與現有2m；兩者皆偶數格，可直接沿用基準面水平中心／Y底部，正式Mesh與Box一致且放置清楚，不需建置腳本。 | 多scene／Mesh需同步材質及節點契約，尺寸增多時維護成本上升。不能為補縫任意Scale；更多尺寸仍需逐件批准。 |

**已選固定尺寸，1m規格預覽已確認並完成建立。** 上表保留為選擇依據；不實作參數化牆長或製作其他尺寸。

### 屋簷與邊緣收口設計（歷史提案；收口已決定不做）

- **屋簷：單側平頂短簷板。** 整段長2m、厚0.5m、投影深0.5m，在非攀爬側作水平挑簷；外包尺寸與拼接面均整格，使用獨立Box碰撞。攀爬側不放這個凸出件，連接到攀爬側之前在格線端面收止，不繞角伸入翻越走廊。若要在攀爬側延續外觀，只能改為主牆／樓板內的無碰撞、齊平或內凹視覺條，不沿用凸出件碰撞；這個視覺替換也需另行製作授權。
- **邊緣收口：樓板側面的齊平帶狀內凹。** 在既有0.5m厚樓板側面，用共用材質與Mesh內的分段／淺內凹表現，外包不變，不加凸出的護沿；非攀爬面可沿用母板碰撞，若作獨立件則必須替換相應母板段，不能重疊Box。攀爬側版本只能是無碰撞Mesh，最外點位於既有攀爬平面，沒有遮住標記或抬高板頂；採替換側面或內凹避免共面閃爍。尚未建立任何簷板／收口資產或材質變體。

### 步驟 10：製作驗證檢查清單（基礎AABB已實作，其餘待辦）

清單記錄模組製作驗證；本輪補強Box資產數學檢查、正式負向測試與固定組合清單，其他警示／作者資料檢查仍待辦。不再使用暫存腳本作物理查詢。

- [x] `python3 tools/check_kit_box_aabbs.py`：Box資產四種90°朝向的0.5m格線、內部無正體積重疊、地板底面零間距及足跡完整支撐；另讀固定清單檢查3組Box組合互不重疊與5處接縫零間距／接觸面積；第四組斜坡只比對高邊座標，不檢查碰撞。
- [x] `python3 tools/test_kit_box_aabbs.py`：/tmp資產副本製造0.1m位移、兩Box重疊與5種不支援寫法，逐案例確認FAIL與退出碼1。預期負向失敗是測試通過；非預期結果立即停下、不自動重試。
- [ ] 翻越平台／屋頂自攀爬邊緣往內的實體支撐進深**至少1.5m**才符合製作檢查門檻；保護圈需求0.65+0.37=1.02m>1m。1m只註記為由0.97m向上取整的物理絕對下限，不能作合格門檻。另核對橫向支撐、對向障礙、頭頂淨空；不新增自動檢查。
- [ ] 單一內容區塊的填充塊實例數**超過N時警告，初值建議N=16**，即第17個起提示檢查缺件／過度碎片化。人工明訂區塊與計數範圍，非效能硬限、不自動合併或刪除；本輪只記待辦，不實作。
- [ ] 攀爬面、樓板側面與翻越通路保持平齊；屋簷／倒角／飾條只放非攀爬面，攀爬面裝飾必須無碰撞且不凸出平面，落點／掃掠空間不能被侵入。
- [ ] 可行走坡度超過45°時警示（atan(height/length)>45°）；只提示，不自動夾限或改寫高度／長度，不改玩家floor_max_angle。
- [ ] 碰撞體間距須為0.5m倍數：檢查相對軸向碰撞表面之間的淨距，包含通道寬、淨高與平台間隙；端面接觸0m合法，穿插不是合法間距。不是量pivot中心距或任意兩斜面間最短歐氏距離；斜面接縫按楔形端點與指定拼接方向核對。

### 正式Box AABB工具、負向測試與固定組合

命令：`python3 tools/check_kit_box_aabbs.py`、`python3 tools/test_kit_box_aabbs.py`。兩者只用Python標準函式庫，不啟動Godot、不做物理查詢。正式檢查只讀art/kit；測試另複製資產至 `/tmp/borrowed_shapes_aabb_*/art/kit`，僅修改副本，透過受限的`--fixture-kit`選項執行同一正式檢查器，不接受任意其他專案／目錄。測試副本保留供檢視，原資產雜湊必須不變。

**支援語法**：plain、非繼承.tscn（單行header／property），本地BoxShape3D subresource的size為純數值Vector3；Node3D／MeshInstance3D／StaticBody3D／CollisionShape3D節點，以純數值position平移。外部視覺Mesh／材質只作不執行的引用。每Box以Decimal計算min/max；端面相接合法，三軸交集皆正才判定重疊。固定組合可在資料中指定Y軸quarter-turn 0..3，但不代表支援.tscn內的旋轉屬性。

**不支援必須FAIL、非零退出，禁止略過**：節點rotation／rotation_degrees／quaternion／scale／transform（包括明寫單位縮放）；任何節點的script，包括Visual腳本及腳本／@export動態尺寸；尺寸／位置運算式或多行語法；外部碰撞Shape、繼承／instance節點、AnimationPlayer等未支援節點類別、未知幾何屬性、重複key、缺祖先及停用碰撞。清單也列在腳本docstring，可用`--help`查閱。

**既有斜坡是明確範圍排除**：只有已知的 `ramp_w4_h6_d12.tscn` 因ConvexPolygonShape3D而列EXCLUDED、0個Box檢查，不能宣稱通過；它必須維持只有明定的凸包碰撞，若混入Box／其他碰撞會報錯。其他資產遇非Box直接FAIL，不再用一般SKIP掩蓋未知寫法。此排除不檢查斜坡腳本／形狀，不擴大Box工具範圍。

每個資產檢查四種Y軸90°朝向，根按原始Y底部放到既有floor_w4_h1_d4.tscn頂面；不得自動補償錯誤的底部。每Box底面必須正好碰板頂、完整足跡在板內。地板自身以另一塊同款板疊放核對。格線計數單位為min/max座標值（每Box每朝向6個），不重疊為Box配對數（單Box時N/A、0對），floor_gap為底面數、footprint為足跡矩形數。失敗輸出FAIL並非零退出，不自動修復或重試。

**小型固定清單** `tools/kit_box_combinations.json` 是數學資料，不是關卡scene。前三組為Box組合：1m短牆在地板上；角件接兩面2m標準直牆；2.5m標準牆＋下層地板＋上層樓板。第四組ramp_high_edge_to_floor只比對高邊點與地板頂面座標，斜坡仍不做碰撞檢查。清單指定資產檔名、位置、quarter-turn與接縫方向／預期接觸面積。各組互比所有Box（含角件內部Box），並核對每個宣告接縫確實零間距且有指定正接觸面積，不能把邊／角碰到當完整接縫。沒有搭建／存檔或執行任何組合場景。組合接縫優先於其格線診斷，以便抬牆時直接報出間隙；之後仍須通過格線檢查。測試副本會讀取同一/tmp範圍內複製的固定清單，不改正式清單。

負向測試每案僅執行一次檢查器，預期退出碼1及指定診斷才算PASS：Box位移0.1m、兩Box重疊、節點旋轉、單位縮放、script設定尺寸、尺寸運算式、外部Shape。預期負向子程序失敗不是非預期驗證失敗；若測試runner或正式檢查出現非預期結果，立即停止回報，不連跑。

**步驟10後續擴充（本輪不實作）**：重用解析／AABB與固定清單接縫資料，增加獨立規則函式及具名計數。平台1.5m門檻需另有已核准的「平台Box／攀爬邊方向」，填充塊N=16需作者區塊與實例範圍，不能由資產來源數量推定；本輪3組清單也不是任意關卡／區塊掃描。坡度與裝飾mesh凸出檢查超出Box數學範圍，需另行授權，暫留人工清單。數學通過不能替代畫面與角色操作驗收。

### 大型坡與最大坡度建議

指定補測對象為現有 `ramp_w4_h6_d12.tscn` 預設寬2、高3、水平長6m，坡角atan(3/6)約26.565°，頂面法線(0,0.894427,0.447214)。使用暫存檢查腳本載入**單一指定資產**，不建立關卡或專案測試scene；區分凸包／射線／視覺獨立性證據與角色實際行走驗收。

**建議需要坡度製作限制**，至少針對「可行走坡」增加超限警示，避免任意height／length都被誤當可走。現有玩家未覆寫CharacterBody3D的floor_max_angle，官方預設45°；支撐查詢另要求normal.y≥0.7，對應約45.573°。製作警示應採較嚴的45°（height≤length），並為接縫與邊緣行走保留實測餘量；本次26.565°低於此門檻，但不因此宣稱往返操作已通過。45°是引擎判定界線，不是產品舒適坡度規格。參考：[CharacterBody3D.floor_max_angle](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html#class-characterbody3d-property-floor-max-angle)、`traversal_actor.gd` supported()與`traversal_params.gd` support_normal_min。

本輪只提出警示方案，**不自動夾限或改寫坡長／高度、不改玩家參數**；警示工具已記入步驟10待辦，本輪不實作。若將來批准45°警示，3m高坡至少長3m，現有6m長仍作較緩樣本。

### 前輪三件修訂驗證（歷史紀錄）

引擎 `4.7.stable.official.5b4e0cb0f`，Godot命令均在沙盒外執行。

- 靜態核對：**通過**。三件節點路徑一致、Mesh／Shape各有自己的節點與資源、XZ中心與Y底部偏移正確；四種90°朝向的包圍邊界／奇偶格中心相位、預覽牆角零體積接觸與坡高端／地板頂標高已核對。斜坡生成使用同一尺寸資料的6頂點凸包與8三角面，正式visual_mesh分支不生成或讀取視覺來改碰撞；未宣稱各種參數已操作驗收。
- 編輯器開啟：**通過**。逐件執行 `/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file <log> --quit-after 180 res://art/kit/<scene>`。斜坡含新工具腳本載入，直牆／地板含pivot修訂，均無錯誤或警告。日誌 `/tmp/borrowed_shapes_kit_revision_editor.log`、`/tmp/borrowed_shapes_kit_revision_wall_editor.log`、`/tmp/borrowed_shapes_kit_revision_floor_editor.log`。以quit-after主動結束驗證，退出碼均0，不宣稱手動正常關閉驗收。
- 主場景啟動：**通過（無頭）**。`tools/run_tests.sh` 只跑既有FormLab，固定60 FPS、180幀，超過120物理幀，退出碼0，無錯誤或警告；樣件沒有接入，這項只驗證既有入口未受影響。
- 畫面與操作：**未執行**。組合PNG為離線投影，不是Godot遊戲截圖；未在關卡中實測角色碰撞、坡端通行或互動調參。未建立關卡／測試場景，未製作其餘件，未提交、未推送。
- 工作區保護：既有檔案雜湊比對只允許本次三個件庫scene及本節文件修改，其他既有修改保留。新增僅斜坡資產建置腳本（及Godot自動UID）與工作區外預覽，不新增其他模組。

### 前輪支撐修正與大型坡補測（歷史紀錄，2026-10-17）

本輪專案內只更新本文件，三件scene、腳本、材質與既有場景均未改動。新版離線預覽為 `kit_support_review.png`（工作區外輸出，聊天附圖）；已核對四塊板的聯集為X/Z[-2,2]，牆A／B足跡完整落在其內，底面Y=0.5與板頂一致，轉角僅端面接觸。圖含層高3m、淨高1.5m、一般通道淨寬1m、窄縫淨寬0.5m的規格卡；不將卡片數字誤當已建立或驗收的通道。

- **編輯器開啟：通過。** Godot `4.7.stable.official.5b4e0cb0f`，沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_support_editor.log --quit-after 180 res://art/kit/ramp_w4_h6_d12.tscn`，載入完成、無錯誤或警告。quit-after主動結束驗證，退出碼0；不視為手動關閉驗收。
- **指定大型坡幾何／物理補測：通過（無頭）。** 沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_large_ramp_check.log --script /tmp/borrowed_shapes_large_ramp_check.gd`，退出碼0，無錯誤或警告。暫存腳本只載入既有指定坡件，59項檢查通過：6點凸包尺寸2×3×6m、Y底部0／高端3；15個頂面射線高度符合y=1.5−0.5z且法線正確，最大高度誤差約2.38×10⁻⁷m；側外射線不命中、底面與高端命中；小球在低坡上方不碰撞、楔形內部碰撞；替換visual_mesh後凸包點完全不變。此證據確認大型楔形碰撞，不代表角色行走驗收。
- **主場景啟動：通過（無頭）。** `tools/run_tests.sh` 重新執行預設唯一FormLab，固定60 FPS、180幀（超過120物理幀），退出碼0、無錯誤或警告。日誌 `${TMPDIR}/borrowed_shapes_tests/form_lab.log`。前次因自動審核用量限制未執行，本輪重試已成功。
- **畫面與操作：未執行。** 本輪PNG是離線幾何示意，未進行視窗相機／HUD或角色走坡、通道、窄縫操作驗收。沒有搭建關卡或新測試scene。
- **待使用者選擇：** pivot A／B與最大製作坡度／警示方案皆尚未實作。其餘件暫停；沒有提交或推送。

### 前輪方案A與0.5m邊界驗證（歷史紀錄，2026-10-17）

- 修改：牆scene的Mesh／Shape同步偏移至(0,1.5,0.25)，根為基準面水平中心／Y底部；坡腳本為奇數格寬／長補子節點偏移，更新其pivot metadata。地板不需改動。預覽已遷移牆根，沒有新增或更動關卡實例。
- **資產邊界核對：通過（無頭）。** 沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_pivot_a_check.log --script /tmp/borrowed_shapes_pivot_a_check.gd`。暫存腳本逐件載入既有三件，四種90°朝向核對凸包／盒體頂點及Mesh包圍邊界；坡另測16組寬／長奇偶格組合、高2.5m，共3241項檢查通過，退出碼0、無錯誤或警告。不把離線圖當引擎檢查結果，亦未新增專案測試檔或scene。
- **大型坡回歸：通過（無頭）。** 沿用前輪暫存檢查腳本，沙盒外命令同前輪但log改為 `/tmp/borrowed_shapes_pivot_a_large_ramp.log`；59項楔形幾何／物理與視覺獨立性檢查再次通過，退出碼0、無錯誤或警告。預設2×3×6m幾何保持。
- **主場景啟動：通過（無頭）。** 沙盒外執行 `tools/run_tests.sh`，只執行既有FormLab、固定60 FPS／180幀，超過120物理幀；退出碼0、無錯誤或警告。日誌 `${TMPDIR}/borrowed_shapes_tests/form_lab.log`。
- **畫面與操作：未執行。** 新PNG僅離線預覽，未進行視窗相機／HUD與角色走坡／攀爬／跨越驗收。
- 工作區雜湊核對：本輪只改AGENTS.md、牆scene、坡scene metadata及kit_ramp.gd；沒有新增或刪除專案檔案，其餘既有變更保留。層高兩案待選、步驟10兩項未實作；其餘件未製作，未搭關卡，未提交／推送。

### 前輪2.5m標準牆驗證（歷史紀錄）（2026-10-17）

- **靜態核對：通過。** 新件2×2.5×0.5m、格數4×5×1、Mesh／BoxShape3D獨立、節點結構與原牆一致、共用kit_material、子節點偏移(0,1.25,0.25)；四種90°朝向外邊界皆落0.5m格線。離線堆疊地板頂面差3m、牆／板接觸0間距、攀爬面Z0.5連續、中央翻越落點五點支撐投影均在上層板內。此為幾何核對，不是碰撞操作驗收。
- **編輯器開啟：通過。** Godot `4.7.stable.official.5b4e0cb0f`，沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_standard_wall_editor.log --quit-after 180 res://art/kit/wall_straight_w4_h5_d1.tscn`，必要載入完成，沒有錯誤或警告。quit-after主動結束，退出碼0，不宣稱手動正常關閉驗收。
- **主場景啟動：通過（無頭）。** 沙盒外執行 `tools/run_tests.sh`，只跑既有FormLab、固定60 FPS／180幀，超過120物理幀，退出碼0、無錯誤或警告；日誌 `${TMPDIR}/borrowed_shapes_tests/form_lab.log`。新件未接入FormLab，這項僅確認原入口維持正常。
- **畫面與操作：未執行。** 剖面PNG為離線示意，沒有在遊戲中組裝或實測新牆／樓板接縫、3m攀爬與翻越落點，不宣稱整組已驗收。
- **工作區保護：** 與本輪開始雜湊比對，僅修改AGENTS.md、新增 `art/kit/wall_straight_w4_h5_d1.tscn`；其他既有變更保留，無刪除，無新增腳本或其他件。預覽位於工作區外。11件候選未開始。未搭關卡、未提交、未推送。

### 前輪規則與前三件預覽核對（歷史紀錄，2026-10-17）

- **靜態核對：通過。** 翻越退縮0.65＋猴半寬0.32＝0.97m，整格下限1m；完整步行保護圈需求0.65＋0.37＝1.02m，整格建議1.5m；來源與兩種判定界線已區分。三件提案的Box邊界／L形拼接均0.5m倍數，L形兩Box只端面相接；四種90°旋轉仍保留格線，根Scale=1。預覽已目視核對文字與幾何。
- **編輯器開啟：未執行。主場景啟動：未執行。畫面與操作：未執行。** 本輪只改規則與離線預覽，不修改或建立資產／場景，未重新啟動Godot，不沿用前輪結果宣稱新件通過。
- **工作區保護：** 與本輪起點雜湊比對僅AGENTS.md修改，無新增／刪除專案檔案；PNG／繪圖腳本在工作區外。牆角／牆端／填充塊等預覽待審，基座下一批，屋簷／邊緣收口只作文字提案，短牆方案待選；柱子／倒角／樓梯延後至M4實際缺件時再記錄。未搭關卡、未提交／推送。

### 前輪批次01製作與短牆預覽驗證（歷史紀錄，2026-10-17）

- **靜態核對：通過。** 角件OBJ為封閉L形，面法線朝外，體積1.875m³等於兩個無體積重疊Box的聯集；角件與填充塊外包尺寸／底角pivot、四種90°旋轉格線與共用材質已核對。1m短牆預覽沿用直牆pivot，尚無短牆scene。牆端資產不存在。
- **編輯器開啟：通過。** Godot `4.7.stable.official.5b4e0cb0f`，沙盒外逐件執行 `/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file <log> --quit-after 180 res://art/kit/<scene>`；scene分別為wall_corner_w2_h5_d2.tscn、filler_w1_h1_d1.tscn，OBJ匯入與必要載入完成、無錯誤或警告。日誌 `/tmp/borrowed_shapes_batch_01_corner_editor.log`、`/tmp/borrowed_shapes_batch_01_filler_editor.log`，退出碼均0；quit-after主動結束驗證，不宣稱手動正常關閉驗收。
- **暫存資產物理核對：失敗（驗證腳本型別錯誤，未完成）。** 沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_batch_01_assets_check.log --script /tmp/borrowed_shapes_batch_01_assets_check.gd`；腳本第30行將條件式產生的Array賦值給Array[Vector3]，引發SCRIPT ERROR。這是本次暫存驗證腳本錯誤，不直接判定為專案資產錯誤。依驗證標準立即停止後續Godot驗證，未修復或重試；對本次程序PID41863送SIGTERM，退出碼143，屬錯誤後主動結束，不另列異常退出或正常關閉通過。未完成射線、凹口與各朝向物理核對。
- **主場景啟動：未執行。** 因上述錯誤停止，未執行本輪FormLab門禁，不用前輪結果替代。
- **畫面與操作：未執行。** 短牆圖是離線幾何預覽，未在Godot視窗驗收新件呈現、接縫或角色通行；沒有搭建關卡。
- **工作區保護：** 起點雜湊比對僅修改AGENTS.md；新增角件scene、原創OBJ與Godot自動.import，以及填充塊scene，其他原有變更未改動、無刪除。新件未接入FormLab或其他關卡。預覽與暫存驗證腳本位於工作區外；未提交／推送。

### 前輪1m短牆與唯一獲准補測重跑（歷史紀錄，2026-10-17）

- 新增僅 `art/kit/wall_straight_w2_h5_d1.tscn` 這一件；尺寸、直牆pivot、獨立碰撞、共用材質與節點結構靜態核對通過。其他件／玩家規格不改。
- **編輯器開啟：通過。** 引擎 `4.7.stable.official.5b4e0cb0f`，沙盒外執行 `/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_short_wall_editor.log --quit-after 180 res://art/kit/wall_straight_w2_h5_d1.tscn`，載入完成、無錯誤或警告。quit-after主動結束，退出碼0，不宣稱手動正常關閉驗收。
- **物理補測：失敗（暫存驗證腳本排除清單錯誤，未完成）。** 依本輪明確授權修正Array型別並只重跑一次，日誌 `/tmp/borrowed_shapes_batch_01_assets_retry.log`；第一件牆角的「no penetrating floor overlap (0.1mm inset)」斷言失敗，退出碼1。靜態診斷確認`query.exclude.append(...)`只修改getter回傳複本，排除自身未生效；不可把此結果判定為資產與地板穿插。未再次修正／執行，三件完整碰撞範圍、不重疊及地板接觸驗證尚未通過。詳見[成本與互動紀錄](docs/cost_log.md)。
- **主場景啟動：未執行。畫面與操作：未執行。** 按使用者「若再失敗停下」指示，不執行後續Godot驗證，不用前輪結果替代。
- **cost-log：** 本次請求1輪；前次失敗＋本次修復共2輪，模型只記可確認的GPT-6，精確ID未知；前次型別失敗與本次排除清單失敗均已記錄，不推估Token／費用。
- **工作區保護：** 只修改本文件、新增1m短牆及使用者要求的 `docs/cost_log.md`；暫存檢查腳本在工作區外，未新增測試scene。第二批未開始，未搭關卡，未提交／推送。

### 前輪正式AABB工具驗證（歷史紀錄，2026-10-17）

- **正式數學檢查：通過。** `python3 tools/check_kit_box_aabbs.py`僅執行一次，退出碼0：6個Box資產、共7個Box，各四種90°朝向的格線／資產內不重疊／與地板接觸核對通過。斜坡明列SKIP，未涵蓋非Box碰撞。未使用暫存腳本或物理查詢。
- **編輯器開啟：未執行。主場景啟動：未執行。畫面與操作：未執行。** 本輪只新增Python數學工具與文件分類，不啟動Godot，不宣稱角色通行／操作通過。
- **cost-log：** 前兩次驗證腳本失敗均歸為「驗證重工」，與資產修改拆列；本輪為「驗證工具建置」，可見迭代共3輪、所用模型GPT-6／精確ID未知。
- **工作區保護：** 新增tools/check_kit_box_aabbs.py，只改本文件與docs/cost_log.md；資產、場景、移動規格與既有修改保留。第二批未開始，未搭關卡、未提交／推送。
### 前輪AABB補強輸出與驗證（歷史紀錄，2026-10-17）

以下數字均為PASS數量；「N/A(0)」代表單Box沒有內部配對。資產測四種90°朝向，格線按min/max純量座標計數。

| 資產 | Box數 | 格線 | 內部不重疊 | 地板接縫 | 完整足跡 |
|---|---:|---:|---:|---:|---:|
| filler_w1_h1_d1.tscn | 1 | 24 | N/A(0) | 4 | 4 |
| floor_w4_h1_d4.tscn | 1 | 24 | N/A(0) | 4 | 4 |
| wall_corner_w2_h5_d2.tscn | 2 | 48 | 4 | 8 | 8 |
| wall_straight_w2_h5_d1.tscn | 1 | 24 | N/A(0) | 4 | 4 |
| wall_straight_w4_h5_d1.tscn | 1 | 24 | N/A(0) | 4 | 4 |
| ramp_w4_h6_d12.tscn | 0（EXCLUDED） | 未檢查 | 未檢查 | 未檢查 | 未檢查 |

| 固定組合 | Box數 | 格線PASS | 不重疊PASS | 零間距／面積接縫PASS |
|---|---:|---:|---:|---:|
| wall_on_floor | 2 | 12 | 1 | 1 |
| corner_with_two_walls | 4 | 24 | 6 | 2 |
| wall_2_5m_with_upper_slab | 3 | 18 | 3 | 2 |

- 正式檢查：通過，`python3 tools/check_kit_box_aabbs.py`執行1次、退出碼0，6個Box資產／7個Box／3組固定清單。
- 負向測試：通過，`python3 tools/test_kit_box_aabbs.py`執行1次、退出碼0；7個案例各自子程序退出碼1且錯誤訊息吻合，無非預期失敗或重試。指定兩案副本為 `/tmp/borrowed_shapes_aabb_0y_uf81e/art/kit`（0.1m位移）、`/tmp/borrowed_shapes_aabb_vqb5jnkf/art/kit`（Box重疊）。
- 編輯器開啟：未執行。畫面與操作：未執行。FormLab無頭門禁：通過。沙盒外最後執行一次`tools/run_tests.sh`，只跑FormLab、固定60 FPS／180幀，超過120物理幀，退出碼0，無錯誤或警告。引擎`4.7.stable.official.5b4e0cb0f`，日誌`${TMPDIR}/borrowed_shapes_tests/form_lab.log`；依quit-after主動結束，不宣稱手動正常關閉或角色操作驗收。
- 工作區保護：只更新tools內的檢查／測試／固定組合資料及AGENTS.md／cost-log，原資產不改、第二批未開始，未提交／推送。

### 前輪批次01結案小項與第二批提案（歷史紀錄，2026-10-17）

**計數口徑**：每個Box的floor_gap=4，確實是0／90／180／270°各檢查一次底面與地板接縫。格線不是4個座標，而是每朝向6個min/max座標，所以單Box為24，雙Box角件為48；角件內部不重疊PASS(4)則是一對Box×4朝向。固定組合只檢查清單指定姿態，seam=1／2是接縫數，不是四朝向。

**抬牆負向案例**：測試在 `/tmp/borrowed_shapes_aabb_1vz3m7rf` 複製資產及清單，只把wall_on_floor牆根Y由0.5改0.6；檢查器正確輸出 `FAIL: wall_on_floor: seam floor->wall gap=0.10m (expected 0)`、退出碼1。但是新增測試器斷言要求文字0.1m，將Decimal等值格式0.10m誤判，導致test_kit_box_aabbs.py本輪整體退出碼1。前7個案例符合預期；新子程序確實驗出0.1m接縫，**新增自動測試尚不能宣稱通過**。依失敗即停規則未再修正／重跑；此為驗證格式斷言錯誤，不是資產錯誤，已記cost-log驗證重工。

**斜坡高邊座標組合**：固定清單新增ramp_high_edge_to_floor。只讀既有斜坡保存的點與碰撞子節點位移，取最高的兩點；不執行@tool、不重建參數、不做凸包碰撞。坡根(0,0,3)，保存高邊為(-1,3,0)與(1,3,0)；地板根(0,2.5,-1)，頂面Y3、外緣Z0、X[-1,1]。兩端點各比對高度、外緣Z、X覆蓋，共6項通過，輸出collision=NOT_CHECKED。僅支援此已保存預設坡、未旋轉配置；動態尺寸／參數覆寫不在驗證範圍。

正式檢查本輪執行1次、退出碼0，6個Box資產／7個Box／3個Box組合＋1個座標組合通過。負向測試器執行1次、退出碼1，錯誤如上。未再啟動Godot；編輯器、FormLab門禁、畫面與操作本輪均未執行，不改寫前輪已通過紀錄。

**第二批三件預覽（未製作）**：預覽僅在工作區外PNG，使用現有kit固定色值示意，不修改共用材質。

| 提案 | 尺寸／碰撞範圍 | 裝飾面／放置限制 |
|---|---|---|
| 直線基座 | 2×0.5×0.5m；一Box，X[-1,1]、Y[0,0.5]、Z[0,0.5]；基準面水平中心／Y底部pivot。 | 非攀爬面，位於樓板下方，不疊到完成地板頂以抬高標準層高。例：樓板底Y0時基座根Y−0.5、頂Y0，與板接觸不穿插；需另核對地基支撐。 |
| 轉角基座 | 1×0.5×1m L形，外角底部pivot；Box A=X[0,0.5]/Y[0,0.5]/Z[0,1]，B=X[0.5,1]/Y[0,0.5]/Z[0,0.5]。 | 非攀爬面，作樓板下轉角支承／收口，替換碎填充塊，不覆在完整牆角／地板上，不在附牆起點做凸台。 |
| 齊平邊緣收口 | 視覺替換槽2×0.5×0.5m，X[-1,1]/Y[0,0.5]/Z[-0.5,0]；自身沒有碰撞。圖中灰色母樓板Box為X[-1,1]/Y[0,0.5]/Z[-2,0]，仍由母板承重。 | 攀爬面，青色基準平面Z0，視覺所有頂點Z≤0；替換母板側面區段避免共面閃爍，不增加凸出護沿／碰撞，不遮機制標記。 |

紅線為擬議新增基座碰撞，灰線為既有樓板碰撞參照，青線為攀爬平面。收口是視覺替換方案，尚未授權建立無碰撞scene或變更工具的資產排除規則。三件仍待確認；屋簷不製作，牆端／柱子、倒角、樓梯維持延期。

**風格現況（唯讀查證）**：
- `content/shared/kit_material.tres` 是StandardMaterial3D，albedo固定為(0.788235294,0.745098039,0.658823529,1)，數值與暖石色板building相同，但**沒有引用色板Resource，也沒有StyleFoundation接線**；換B不會自動改kit色。
- `content/shared/environment_preset.tscn` 已建立，包含DirectionalLight3D、WorldEnvironment及StyleFoundation腳本。`content/forms/form_lab.gd`在_ready()實例化、_build_environment()加入樹；FormLab原有建築由style.configure_block()套共享ShaderMaterial。
- FormLab A/B選擇入口為 `content/shared/style_settings.tres` 的palette，現為A（palette_warm_courtyard.tres），可換B（palette_cool_architecture.tres）後重新載入，由StyleFoundation.apply_palette()套到建築材質與環境。只改這一個入口適用於已接入的FormLab風格；**不適用於尚未接入的獨立kit材質**，目前不能宣稱整套kit＋FormLab一處切換。沒有修改任何材質、色板、preset或風格腳本。

### 批次02：測試修復、收口剖面與風格提案（歷史紀錄，2026-10-17）

基座與收口製作提案已由上方「批次02結案：決定不做」取代；下列尺寸、替代放置與待確認語句僅為歷史，不構成製作授權。下方三角色／StandardMaterial提案已由「風格Resource化」取代，只保留歷史。

**唯一獲准的測試器修復**：將抬牆案例的文字比對改為解析seam gap數值，採Decimal與0.1比較、容差1e−6，另要求子程序退出碼非0及FAIL診斷。依本輪授權只修正並執行 `python3 tools/test_kit_box_aabbs.py` 一次；8個負向案例全部通過，測試器退出碼0。抬牆案例gap=0.10m、差值0、子程序退出碼1；副本 `/tmp/borrowed_shapes_aabb_ugsh6n3k/art/kit`。未改檢查器、組合清單或資產；本次歸類cost-log「驗證重工」。

**邊緣收口側面剖面（提案，未製作）**：使用前輪已通過堆疊座標，樓板Y[3,3.5]、外側攀爬平面Z=0.5、內側為−Z。新圖 `kit_edge_trim_section.png` 為X=0剖面，水平軸放大只為看清內凹，尺寸標註為準。

- 建議標準內凹d=**0.005m（5mm）**，最大允許d_max=**0.010m（10mm）**。視覺外表面Z=0.5−d，不向+Z凸出；視覺表面與攀爬平面最大差距10mm、只向內。這是待審美術規格，不是由body_safe_margin、wall_clearance推導的物理容差或已驗收值。
- **Y=3.5的90°頂邊不得倒角或內凹**，頂面保持Y=3.5；側面上緣Y[3.4,3.5]保留100mm完整平面Z=0.5，頂邊差距為0。
- 側面中段Y[3.15,3.35]採內凹；Y[3.10,3.15]與[3.35,3.40]僅作側面視覺過渡，Y[3.0,3.10]亦保持Z=0.5。不得把過渡延伸到頂邊／水平走面，不遮住機制標記。
- 母樓板碰撞面仍Z=0.5，與攀爬平面差距始終0；收口本身無碰撞，作母板側面Mesh區段替換，避免共面疊加。母板／牆碰撞和翻越落點維持既有配置。此圖不替代畫面／操作驗收，需使用者確認剖面才可製作。

**基座可見性與用途（不製作）**：若不透明地面在Y=0且覆蓋基座足跡，基座Y[-0.5,0]整段在地面下，從地面以上看不到側面；頂面與地面共平面，不能靠重疊閃爍當外露裝飾。它只有地下支承／填充、架空地板或低地側露基礎的用途；若當前內容沒有這類需求，不應為裝飾而製作。

| 替代放置方案 | 座標與可見性 | 代價／限制 |
|---|---|---|
| A：放在本來就較低的地勢／架空外側 | 保持基座Y[-0.5,0]與原樓板位置，鄰側地面若Y≤−0.5，側面可露出最多0.5m。 | 不把整個地面下挖；斜坡低端及通行接地區仍維持Y0。只適合既有非攀爬、非行走外側有低地／架空的內容，沒有這種地形就不用。層高與攀爬不變。 |
| B：整套地板／牆組裝抬高0.5m，基座留在地上 | 基座Y[0,0.5]，下層樓板Y[0.5,1]、標準牆Y[1,3.5]、上層板Y[3.5,4]；地面Y0時基座側面可見，完成地板頂面仍相差3m。 | 這是另行授權才可採用的放置變更，不搬既有場景；攀爬面底升至Y1、高仍3。若斜坡也整體抬高，低端會離Y0地面0.5m，不能直接這樣搬；須另審坡尺寸／端點連接，不自行調整。 |

兩方案都要維持基座／樓板端面相接、零穿插，且攀爬／翻越側不得增加凸台。直線與轉角基座繼續暫停製作；原PNG僅保留為提案歷史。

**kit色板接線提案（僅提案，不修改）**：建議先用**3個共享角色材質**，不按模型或A/B另複製多套。

| 角色材質（擬議） | StylePalette欄位 | 使用範圍 |
|---|---|---|
| 建築：沿用kit_material.tres | building | 牆、短牆、牆角、填充塊、將來獲准的基座；填充塊的角色按用途另指定，不靠位置猜。 |
| 平台：擬增kit_platform_material.tres | platform | 樓板／屋頂、斜坡、視覺邊緣收口。 |
| 地面：擬增kit_ground_material.tres | ground | 作地表／庭院用途的地板；同一floor場景作屋頂時選平台角色，不因Mesh相同強制同色。 |

highlight保留給既有光照／環境與建築Shader亮部；ink保留給既有背景／描邊，不先增第四、第五個kit角色材質。青色／黃色機制標記繼續使用既有機制材質與固定色，不加入可切換建築角色。

**引用與更新方案**：純StandardMaterial3D目前不會自動讀StylePalette。提案給角色材質加輕量Resource腳本，導出palette:StylePalette與固定role，刷新時以該欄位更新albedo；資源本身引用色板，不只抄一個Color常數。唯一選擇入口仍為style_settings.tres.palette；擬擴充既有StyleFoundation.apply_palette()，在FormLab初始化／明確切換時將同一色板Resource轉交給3個角色材質，同步既有建築Shader與環境，禁止讓3個材質各自獨立選A/B。

每個StyleFoundation在記憶體建立每角色一份材質實例，同角色所有Mesh共用；不深複製色板，保持palette引用一致。刷新只改本次場景的材質實例，不ResourceSaver寫回來源.tres，不逐模型Make Unique。初始來源引用A；未接入StyleFoundation的獨立kit預覽不承諾自動跟隨主入口切換，編輯器同步預覽需日後另審。本提案只接顏色與現有環境，不增Shader，也不宣稱StandardMaterial3D因此取得既有描邊／toon功能。所有擬議腳本、材質與接線本輪均未建立／修改。

**A/B驗收方案（以既有FormLab為準，未執行）**：
1. 待實作另獲批准後，在FormLab既有建築／平台／地面幾何使用3個角色材質作樣本，不新建關卡或測試scene。記錄A時的材質角色、palette引用、albedo欄位及固定相機畫面；不以受光照後像素值代替albedo驗證。
2. 只把style_settings.tres.palette從A換成B，重新載入FormLab（或明確呼叫既有apply_palette）；3個角色材質引用同一個B，albedo分別等於B的building／platform／ground，環境／Sun仍由同入口更新，同角色材質身分共用。
3. 比對A/B切換前後尺寸、位置、碰撞、攀爬／跳躍參數與節點接線不變；機制青色／黃色不變，HUD與相機正常。依正式範圍實際操作移動、變形、攀爬、翻越、跨越與坡端，不將純色板變更視為操作已通過。
4. 沙盒外編輯器載入無錯誤／警告、FormLab無頭至少120物理幀；視窗固定相機A/B畫面及以上操作各自回報。切回A確認可逆，不寫玩家偏好、不自動保存資產。任何診斷停止，不另建入口。

**本輪驗證與保護**：只重跑一次正式負向測試器，8案通過、退出碼0；原資產雜湊不變。未啟動Godot，編輯器／FormLab／視窗操作本輪未執行。新增僅工作區外剖面PNG；專案只修改測試器、本文件及cost-log。沒有製作基座／收口、沒有改材質／色板／preset／其他資產，未提交／推送、未搭關卡。


## 風格Resource化（2026-10-17，現行）

本輪只做風格接線；沒有新增kit件／關卡scene，沒有改Mesh、碰撞、位置、尺寸或玩法。舊提案中3個kit角色／StandardMaterial更新方案由本節取代。

- 共用材質方案：沿用`content/shared/kit_material.tres`作building，僅新增`kit_platform_material.tres`作platform；共用一份`kit_role_material.gd`（及引擎UID）。兩材質都是KitRoleMaterial／ShaderMaterial，引用**既有且未修改**的`architecture.gdshader`，與FormLab建築同shader，包含現有toon／描邊能力。不建立kit ground材質。
- 唯一選擇入口是`style_settings.tres.palette`。材質引用StyleSettings，palette getter保留該Resource引用，不保存各自A/B選項或RGB副本。StyleSettings.palette setter發出changed；StyleFoundation由settings刷新既有建築／環境及每角色一份共用材質實例。不深複製色板、不ResourceSaver寫回來源、不逐模型Make Unique。
- 編輯器：@tool材質在資源載入／延後初始化及palette引用切換時刷新；不自動保存來源。色板內容原地改欄位、其他風格參數的即時Inspector同步不作本輪承諾；本輪驗收只切換palette Resource。
- 每Mesh的`color_role`、`shape_size`、`ramp_shape`保留為**instance uniform**，不在共用材質上改寫尺寸。固定scene明寫其參數；kit_ramp.gd每次重建同步Vector3(width,height,length)及ramp_shape=true，奇數格子節點偏移／Mesh與凸包生成保持原樣。

| kit scene | 角色 | instance shape_size／ramp_shape |
|---|---|---|
| wall_straight_w2_h5_d1.tscn | building | (1,2.5,0.5)／false |
| wall_straight_w4_h5_d1.tscn | building | (2,2.5,0.5)／false |
| wall_corner_w2_h5_d2.tscn | building | (1,2.5,1)／false |
| filler_w1_h1_d1.tscn | 預設building | (0.5,0.5,0.5)／false |
| floor_w4_h1_d4.tscn | platform | (2,0.5,2)／false |
| ramp_w4_h6_d12.tscn | platform | 預設(2,3,6)，依參數刷新／true |

填充塊補平台時由作者明確替換為共用platform材質，並把Visual/MeshInstance3D的color_role設為1；預設building為0。不按位置猜用途、不複製材質或新增填充塊變體。材質role欄位供辨識／驗收，實際著色使用Mesh的color_role。

**決定不做**：暗色帶與額外shader功能升級。本輪只改接現有shader，不新增shader或修改shader演算法。重評條件：**M4實際畫面顯示樓層線不足**。

**已知限制**：現有描邊按Box／楔形推算，L形牆角凹角描邊不完整；**M4截圖時需檢查**，本輪不擴寫演算法。預設outline／toon均關閉；A/B驗收維持來源開關，不為驗收切換效果。

### 本輪驗收與工具

- `tools/check_kit_style.py`唯讀追蹤kit scene及其引用的.tres／.gd／shader：15個依賴，角色色常數只能在A/B palette Resource；StyleSettings中固定機制色為明確例外。兩角色材質引用相同architecture shader／StyleSettings。
- `tools/style_color_reference.py`離線列出青、黃對A/B五個色板欄位的相對亮度、亮度對比與HSV環形色相差。sRGB線性化後用0.2126/0.7152/0.0722計算亮度、(L高+0.05)/(L低+0.05)計算比值；HSV色相差不是感知色差，也不代表遊戲受光照像素對比。僅供參考、沒有門檻。B platform對青色比值1.533、色相差24.88°。
- `style_capture.gd`仍只從FormLab的`--style-capture=絕對路徑`入口執行。A→B→原色板只賦值settings.palette，不直接套色板函式，不切後製／描邊／toon。檢查色值、palette引用、共用材質身分、原FormLab幾何、固定機制青／黃／描邊色完全不變；原設定恢復，不保存Resource或偏好。
- 驗收例外：同一工具在獨立SubViewport／World3D記憶體實例化既有下層地板(0,0,0.5)、2.5m牆(0,0.5,0)、上層板(0,3,-0.5)，另用既有青色標記覆蓋牆與樓板側面；沒有保存組合scene，不作玩法驗收。相機正交size=5.5、位置(5,4.5,8)、朝向(0,1.65,0)。標記width=0.8、height=3、位置(-0.5,0.5,0.5)，禁用候選登記，只顯示原機制材質。
- **已通過的剖面基準圖**：[A](docs/style_section_a.png)、[B](docs/style_section_b.png)，由前輪視窗renderer的原PNG逐位元複製，不重新渲染或改色。圖中青色標記寬0.8m，是驗收工具本輪風格實作時明確選的材質取樣寬度：0.8÷2m牆寬=40%，中心X=-0.5、橫向X[-0.9,-0.1]，保留旁邊背景以同時觀察牆／樓板角色色與機制色。不是原本完整攀爬配置，也不是shader把標記縮窄；僅存在截圖工具的記憶體剖面、禁用攀爬候選。上方「新標準牆使用與堆疊剖面」規定的有效攀爬配置線仍為width=2、height=3；既有FormLab仍為width=3、height=3，位於(-3,0,0.5)，並無改動。基準圖核准的是角色材質／辨識度，不能把0.8m解讀為新的攀爬寬度規格。
- **黃色跨越線A/B證據**：[FormLab A](docs/style_form_lab_a.png)、[FormLab B](docs/style_form_lab_b.png)，沿用前輪同相機／同效果開關截圖；本輪只複製及檢視，未啟動Godot或改色。畫面左上屋頂黃線為起跳線X=-0.65、Y=3.04、Z[-3.6,-0.6]，位於Building頂面Y=3（building角色，A #C9BEA8／B #A8B9C9）；右側平台黃線為反向起跳線X=3.65、相同Y/Z範圍，位於LandingPlatform頂面Y=3（platform角色，A #829384／B #788D99）。黃線比承重頂面高0.04m，不是畫在空隙或ground角色上；兩線都使用既有固定機制黃#FFC73D及深色邊。A/B兩張中兩條黃線均可辨識，右側平台本體部分超出畫面；不外推所有視角。PNG受光照的背景像素不等於上述來源albedo色值。
- 工具逐資源核對6個kit scene角色／同shader與shape參數；斜坡測(1.5,2.5,5.5)及恢復(2,3,6)，核對shader尺寸、Mesh包圍盒與恢復後凸包點相同。

引擎`4.7.stable.official.5b4e0cb0f`；Godot均在沙盒外執行，無錯誤／警告，退出碼0：

1. **編輯器載入通過**：首次`Godot --editor --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_style_editor_initial.log --quit-after 180 res://art/kit/wall_straight_w4_h5_d1.tscn`完成匯入。其後逐一對6個kit scene執行`Godot --editor --path <專案> --quit-after 180 res://art/kit/<scene>`；日誌`/tmp/borrowed_shapes_style_editor_<scene名>.log`。每次前後203個來源檔SHA256與`git status --porcelain=v1 --untracked-files=all`完全不變，證據`/tmp/borrowed_shapes_editor_guard.json`。工作區含本輪未提交實作差異，非字面乾淨；通過的是載入未產生額外來源改動。quit-after為主動結束，不宣稱手動正常關閉。
2. **主場景啟動通過（無頭）**：`tools/run_tests.sh`只執行FormLab，固定60FPS／180幀，超過120物理幀；日誌`${TMPDIR}/borrowed_shapes_tests/form_lab.log`。
3. **A/B自動核對通過（無頭與視窗各一次）**：`Godot [--headless] --path <專案> --log-file <log> res://scenes/forms/form_lab.tscn -- --style-capture=/tmp/borrowed_shapes_style_capture`；log分別`/tmp/borrowed_shapes_style_check.log`與`/tmp/borrowed_shapes_style_window.log`。至少150物理幀後開始；工具完成後主動quit(0)。截圖為`form_lab_a.png`、`form_lab_b.png`、`section_a.png`、`section_b.png`，皆在該輸出目錄。
4. **畫面檢查通過（本次限定項目）**：已檢視視窗renderer輸出的FormLab B畫面及A/B剖面；相機／HUD可見，B平台側面上青色標記在該固定視角仍可辨識，沒有改色。不外推到所有距離／角度；未執行移動／變形／攀爬／跨越操作。
5. **幾何回歸通過**：`python3 tools/check_kit_box_aabbs.py`一次，現有5個Box資產／6個Box／4組（3組Box＋1組坡高邊座標）通過；凸包仍不列Box碰撞通過。`python3 tools/test_kit_box_aabbs.py`一次，8案通過；原始件的節點結構／位置／Shape數值／碰撞圖層與本輪開始快照相同。解析器只新增MeshInstance3D上3項合法視覺uniform的嚴格字面解析，沒有放寬script／transform／碰撞檢查。

沒有新增kit件、關卡或保存驗收scene，沒有提交／推送；本輪工作記於docs/cost_log.md。

## 美術與場景保護
風格集中管理於色板、光照、共用材質與環境 preset，不逐模型客製風格。青色攀爬面、黃色跨越線應使用共用材質；尚未共用的部分須先提案，不能自行擴建系統。
FormLab 的風格基底集中於 `content/shared/`（執行驗證狀態查 README）：
- `style_settings.tres` 選擇色板；A 為暖石庭院，B 為冷霧建築。`style_settings.gd` 集中開關、描邊／色階參數、固定機制色與區塊視覺角色。
- `architecture_material.tres`／`architecture.gdshader` 為建築表面，`mechanism_material.tres`／`mechanism.gdshader` 為固定色的 unlit 機制提示。
- `environment_preset.tscn` 集中光照、霧、SSAO、Glow 與色調映射；`style_foundation.gd` 將色板套用至材質與環境。
- `content/forms/form_lab.gd` 接入風格；`content/traversal/movement_lab_data.tres` 持續提供原始幾何，尺寸與位置不屬於風格資料。
- `content/traversal/movement_lab.gd` 保留其他既有入口的原始材質與環境；`content/forms/slime.tres`、`monkey.tres`、`form_params.tres` 仍為形態與效果呈現來源。
新增美術範圍仍須依本次使用者授權，不由現有共用化推定可擴建系統。
不得擅改手工調整的場景位置、角度、顏色等編輯器細節。

## 工作邊界與驗證
唯一固定測試場景為 `scenes/forms/form_lab.tscn`；日常與手動驗證一律使用它，`tools/run_tests.sh` 預設也只跑此場景。既有其他場景／回歸資產保留，不自行刪除、改接或另設測試入口；只有使用者明確要求執行指定既有回歸套件時，才可透過工具具名執行，不預設全跑。
禁止新增獨立白盒切片或各機制專用測試場景；禁止自行新增機制、系統或目錄結構。
新增任何場景或檔案須先獲使用者授權；已明確同意的新增範圍內不重複詢問，超出範圍才另行確認。只指定修正目標不視為授權新增獨立場景、系統或目錄。每次只做指定範圍。完成時列出改動與驗證結果；未獲明確授權不提交、不推送。
開始前檢查工作區既有變更，區分本次與原有修改；不覆蓋、還原、清理或提交非本次產生的變更。同檔已有修改時只編輯本次授權段落，保留其他內容；無法安全區分或發現衝突時先回報。

### 唯讀驗證範圍
「只驗證、不修改檔案」預設禁止修改專案原始碼、場景、Resource、設定與文件；允許 Godot 自動產生或更新匯入快取、編輯器狀態及驗證日誌，不代表允許新增測試腳本或場景。驗證時不主動更改玩家偏好、不儲存場景、不提交或推送。
若使用者明確要求「包含快取與日誌在內，完全不寫檔」，先說明一般 Godot 啟動可能寫入的限制；無法保證時只做靜態檢查並回報未執行項目，不自行加上可能影響引擎啟動的寫入封鎖。

### 驗證標準
Godot 驗證在沙盒外執行。以下三項分別回報通過、失敗、受阻或未執行，不以無頭載入取代畫面與操作驗收：
- 編輯器開啟：專案載入與必要匯入完成，無錯誤或警告。
- 主場景啟動：`scenes/forms/form_lab.tscn` 完成載入，至少持續執行 120 個物理幀，無錯誤或警告；標明使用無頭或視窗模式。
- 畫面與操作：在視窗模式確認相機與 HUD 顯示，並依本次範圍檢查移動、變形、攀爬或跨越；只回報實際驗證過的項目。
「受阻」指已嘗試但因權限、工具或視窗綁定限制無法完成，例如只能控制編輯器而無法取得遊戲視窗；「未執行」指本次尚未嘗試。受阻時記錄阻礙與已取得的證據，不判定遊戲失敗，也不宣稱該項通過。
從引擎啟動、匯入、場景執行到關閉，任何錯誤、警告、崩潰或非預期非零退出碼都立即停止後續 Godot 驗證並回報。為結束驗證而主動關閉或終止程序須標明原因與退出碼，不列為異常退出，也不能據此宣稱正常關閉通過。記錄命令、版本、診斷與未完成項目；環境或引擎層失敗不能直接判定為專案程式錯誤，不自行修復或重試。
