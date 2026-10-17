# 模組件庫 cost-log

日期：2026-10-17。只記可核對的工作，不估算未取得的費用。

## 固定欄位與計數口徑

主表固定順序：**日期、互動輪次、類別、所用模型、項目、結果、明細**。每欄只放簡短值；診斷、命令、退出碼與證據全部放在表外對應明細，不加臨時欄位。

1輪＝一則使用者工作指示及對應助理執行／回覆，工具與進度訊息不另計。可見追蹤範圍目前共**15輪**，從「批次01回覆」到本次「風格Resource化結案提交與推送」；第7輪為提交請求與範圍澄清，未提交；表內同輪拆成不同工作類別，不重複累加輪數。不是整個專案的總互動輪數。

所用模型僅能確認為GPT-6，精確模型ID／部署版本未知；Token、金額、精確工時未取得，不填0或推估。

類別：資產修改＝實際資產工作；驗證重工＝驗證腳本錯誤的失敗與返工；驗證工具建置＝初版正式工具；**驗證工具化**＝正式工具的摘要計數、負向測試、嚴格語法與固定組合補強。**決定不做**＝取消資產製作或本輪不做的延期決定，逐項說明原因並區分取消與延期；不改寫先前提案／驗證歷史。兩次驗證失敗維持「驗證重工」，不歸入資產修改。

## 主表

| 日期 | 互動輪次 | 類別 | 所用模型 | 項目 | 結果 | 明細 |
|---|---:|---|---|---|---|---|
| 2026-10-17 | 1 | 資產修改 | GPT-6／精確ID未知 | 牆角、填充塊與短牆預覽 | 完成 | A1 |
| 2026-10-17 | 1 | 驗證重工 | GPT-6／精確ID未知 | 暫存補測型別錯誤 | 失敗、停止 | R1 |
| 2026-10-17 | 2 | 資產修改 | GPT-6／精確ID未知 | 唯一1m短牆 | 完成 | A2 |
| 2026-10-17 | 2 | 驗證重工 | GPT-6／精確ID未知 | 暫存補測排除清單錯誤 | 失敗、停止 | R2 |
| 2026-10-17 | 3 | 驗證工具建置 | GPT-6／精確ID未知 | 正式Box AABB初版 | 通過 | R3 |
| 2026-10-17 | 4 | 驗證工具化 | GPT-6／精確ID未知 | AABB補強與負向測試 | 通過 | R4 |
| 2026-10-17 | 5 | 驗證工具化 | GPT-6／精確ID未知 | 計數澄清、斜坡高邊座標組合 | 正式檢查通過 | R5 |
| 2026-10-17 | 5 | 驗證重工 | GPT-6／精確ID未知 | 抬牆測試文字格式斷言 | 測試器失敗、停止 | R5 |
| 2026-10-17 | 5 | 內容提案 | GPT-6／精確ID未知 | 直線基座、轉角基座、齊平收口 | 預覽完成、待審 | P5 |
| 2026-10-17 | 6 | 驗證重工 | GPT-6／精確ID未知 | 間隙數值解析／容差修復 | 8案通過 | R6 |
| 2026-10-17 | 6 | 內容提案 | GPT-6／精確ID未知 | 收口剖面、基座替代與色板接線 | 待審、未製作 | P6 |
| 2026-10-17 | 8 | 範圍決策 | GPT-6／精確ID未知 | 全部變更授權與三批提交規劃 | 待確認、未提交 | S8 |
| 2026-10-17 | 9 | 提交執行 | GPT-6／精確ID未知 | 核准分組與提交候選門禁 | 驗證通過、按核准分組提交 | C9 |
| 2026-10-17 | 10 | 決定不做 | GPT-6／精確ID未知 | 基座、收口取消及延期項目結案 | 文件完成、未新增資產 | D10 |
| 2026-10-17 | 11 | 內容提案 | GPT-6／精確ID未知 | 風格唯讀盤點與A/B剖面 | 預覽完成、未實作 | S11 |
| 2026-10-17 | 12 | 內容提案 | GPT-6／精確ID未知 | 兩角色材質方案與角色對照 | 計畫完成、未實作 | S12 |
| 2026-10-17 | 13 | 資產修改 | GPT-6／精確ID未知 | 風格Resource化與指定刪除 | 完成、未提交 | S13 |
| 2026-10-17 | 13 | 驗證工具化 | GPT-6／精確ID未知 | A/B入口、引用掃描與色差參考 | 通過 | V13 |
| 2026-10-17 | 13 | 決定不做 | GPT-6／精確ID未知 | 暗帶與額外shader功能升級 | 不做、M4條件重評 | D13 |
| 2026-10-17 | 14 | 驗證證據整理 | GPT-6／精確ID未知 | 剖面基準圖、標記寬度與黃線A/B | 完成、未提交 | V14 |
| 2026-10-17 | 15（本輪） | 提交執行 | GPT-6／精確ID未知 | 風格Resource化結案提交與推送 | 使用者核准、提交候選核對 | C15 |

## A1／A2：資產修改明細

A1新增牆角、填充塊，編輯器載入通過，1m短牆只預覽。A2新增唯一1m短牆，靜態核對與編輯器載入通過。驗證腳本的兩次失敗分別記R1、R2，不與這些資產修改合併。

## R1／R2：驗證重工明細（歷史紀錄）

- 修正後腳本第94行使用 `query.exclude.append(body.get_rid())`；第32行射線亦用相同寫法。
- Godot的`exclude` getter回傳複本，append不會更新查詢屬性，必須明確寫回。因此被測件自身沒有被排除，重疊查詢包含自身；探測Box本來就位於自身碰撞體內，本次檢查不能作為與地板穿插的有效證據。這是助理暫存驗證腳本的第二個錯誤，不據此修改資產。
- 官方依據：[PhysicsShapeQueryParameters3D.exclude](https://docs.godotengine.org/en/stable/classes/class_physicsshapequeryparameters3d.html#class-physicsshapequeryparameters3d-property-exclude)、[PhysicsRayQueryParameters3D.exclude](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html#class-physicsrayqueryparameters3d-property-exclude)。此診斷只讀腳本／文件，未再次執行Godot。
- 前次失敗日誌：`/tmp/borrowed_shapes_batch_01_assets_check.log`；失敗腳本快照：`/tmp/borrowed_shapes_batch_01_assets_check_failed.gd`。
- 本次唯一重跑命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/howard/game/borrowed-shapes --log-file /tmp/borrowed_shapes_batch_01_assets_retry.log --script /tmp/borrowed_shapes_batch_01_assets_check.gd`。
- 引擎：`4.7.stable.official.5b4e0cb0f`；本次失敗日誌：`/tmp/borrowed_shapes_batch_01_assets_retry.log`。程序已以退出碼1結束，沒有殘留待終止程序。
- 三件完整物理補測未完成，填充塊與短牆未進入物理檢查；未執行本輪FormLab門禁或視窗操作。未開始第二批、未搭關卡、未提交／推送。

## R3：正式AABB初版（歷史紀錄）

- 命令：`python3 tools/check_kit_box_aabbs.py`；執行次數1，退出碼0。
- 檢查範圍固定為art/kit/*.tscn內明確定義的BoxShape3D；只讀檔案、不啟動Godot、不執行場景腳本，不再用暫存腳本做物理查詢。
- 使用現有floor_w4_h1_d4.tscn的Box作虛擬接觸參照，逐資產檢查；不載入或搭建關卡、不代表跨資產關卡配置或角色操作驗收。
- 前兩次物理腳本失敗保留原始診斷，分類改為驗證重工，不改寫成資產失敗，也不以該輪數學通過宣稱其物理補測曾通過。

## R4：本輪驗證工具化

- 正式腳本：`tools/check_kit_box_aabbs.py`；負向測試：`tools/test_kit_box_aabbs.py`；固定組合清單：`tools/kit_box_combinations.json`（純數學位置與接縫資料，沒有建立關卡scene）。
- 命令`python3 tools/check_kit_box_aabbs.py`執行1次、退出碼0：6個Box資產／7個Box、四種朝向；逐項計數見[AGENTS.md本輪摘要](../AGENTS.md)。3組合共10個不重疊配對、5個零間距／指定面積接縫通過。既有斜坡明列NON-BOX範圍排除，0個Box檢查，非通過。
- 命令`python3 tools/test_kit_box_aabbs.py`執行1次、退出碼0：7個負向案例均取得預期FAIL、子程序退出碼1。涵蓋0.1m位移、Box重疊、旋轉、縮放、腳本設定尺寸、尺寸運算式、外部Shape；沒有非預期失敗或重試。
- 指定副本：`/tmp/borrowed_shapes_aabb_0y_uf81e/art/kit`（位移）、`/tmp/borrowed_shapes_aabb_vqb5jnkf/art/kit`（重疊）。其餘副本路徑在測試輸出。原資產雜湊不變。
- 不支援的Box場景寫法一律FAIL、非零退出；支援／不支援清單在腳本說明與AGENTS.md，不跳過未知格式。既有凸包斜坡僅作明確範圍排除，不擴大幾何檢查。
- FormLab無頭門禁：通過。最後在沙盒外執行一次`tools/run_tests.sh`，只有FormLab，`--fixed-fps 60 --quit-after 180`，超過120物理幀；退出碼0、無錯誤或警告。引擎4.7.stable.official.5b4e0cb0f，日誌`${TMPDIR}/borrowed_shapes_tests/form_lab.log`，不代表視窗操作驗收。
- 未啟動編輯器、未執行視窗操作；工具通過不等於角色操作驗收。第二批未開始、舊3m牆保留，未搭關卡、未提交／推送。

## R5：結案小項與驗證格式重工

- 正式檢查`python3 tools/check_kit_box_aabbs.py`執行1次、退出碼0；資產與前三組數學檢查維持通過，新增斜坡高邊座標6項通過、collision=NOT_CHECKED。沒有物理查詢或Godot執行。
- 負向測試`python3 tools/test_kit_box_aabbs.py`執行1次、整體退出碼1；前7案符合預期，第8案在/tmp副本將牆根Y0.5改0.6，子程序正確回報`seam floor->wall gap=0.10m (expected 0)`、退出碼1。
- 新增測試斷言比對文字0.1m，未容納Decimal輸出的0.10m，因此錯誤地把正確子程序結果判為不符合。這是助理的驗證格式斷言錯誤，不是資產失敗。立即停止，未修正或重跑，不宣稱新增測試器通過。
- 副本：`/tmp/borrowed_shapes_aabb_1vz3m7rf/art/kit`，對應複製清單在同範圍tools/kit_box_combinations.json。正式資產未改。
- 已澄清4次floor_gap＝四種90°朝向；每Box格線24＝6個min/max座標×4，固定組合接縫數不代表四種朝向。
- 本輪編輯器、FormLab及視窗操作未執行；未提交／推送。

## P5：第二批預覽與風格現況查閱

- 「三件」按直線基座、轉角基座與齊平邊緣收口提出；只繪圖與記錄尺寸、攀爬面分類、碰撞範圍，未建立資產、未搭關卡。選收口優先於屋簷，是因現有樓板／攀爬配置更需要齊平收口，不增加翻越障礙。
- 唯讀核對kit材質、色板Resource與環境preset：kit_material仍為固定色，未接palette；FormLab已有preset與單入口palette切換，但不涵蓋獨立kit材質。沒有修改風格檔案。

## R6：唯一獲准測試器數值修復（驗證重工）

- 本輪僅修正tools/test_kit_box_aabbs.py的抬牆斷言：解析seam gap數值，Decimal與0.1比較，容差1e−6；要求FAIL及子程序非零退出碼，不再依賴0.1／0.10的字面格式。
- 依明確授權只執行一次`python3 tools/test_kit_box_aabbs.py`，測試器退出碼0、8案全部通過。抬牆解析值0.10、與0.1的差為0、子程序退出碼1；副本`/tmp/borrowed_shapes_aabb_ugsh6n3k/art/kit`。
- 前輪格式斷言失敗保留R5歷史，不改寫成資產錯誤；本輪修復歸「驗證重工」，不與資產修改混合。未改正式AABB檢查器／組合清單，未重跑其他門禁，未啟動Godot。

## P6：剖面與只提案範圍

- 收口剖面提議5mm標準內凹、10mm上限；Y3.5的90°頂邊與Y[3.4,3.5]側面保留完整，碰撞面／攀爬平面仍Z0.5。僅繪工作區外PNG，未製作或修改資產。
- 已說明Y[-0.5,0]基座被Y0不透明地面遮蔽，只有地下支承／低地架空用途；替代為既有低地外露或整組抬高0.5m，後者須另審坡端接地，兩案都不直接搬既有場景。
- 色板提案為3個共享角色材質，對應building／platform／ground，統一StyleSettings.palette入口與StyleFoundation刷新；FormLab A/B驗收方案只寫文件，無任何風格程式／資產改動。
- 本輪專案只改測試器、AGENTS.md與cost-log，基座／收口仍待確認；未搭關卡、未提交／推送。

## S8：全部變更提交範圍決策

- 第7輪使用者要求先提交；助理發現原有重構／刪除與本次工作混合，提出範圍澄清，未暫存或提交。第8輪使用者明確授權「目前全部變更」，視為不得提交非本次變更約定的例外；本輪只讀盤點，唯一文件修改為本cost-log紀錄。
- 分支borrowed-shapes；本機legacy-dual-animal tag不存在，未連線／fetch，不能據此判斷遠端tag。暫存區空；新增未追蹤51、修改34、刪除207，共292個檔案。
- 提案(1)：WIP重構與刪除基線，239檔（新增3／修改29／刪除207）；提案(2)：件庫、移動元件、AABB工具、cost-log、AGENTS.md整檔，以及FormLab風格接線／content/shared依賴，53檔（新增48／修改5）。AGENTS.md包含重置期改寫與件庫規則，不拆hunk。
- 提案(3)：舊3m牆另案刪除，現未刪除，須使用者另行確認；目前工具沒有具名引用此牆；後續需核對目錄枚舉檢查的計數並更新現行資產文件，歷史驗證紀錄保留，不自行執行。
- .godot/的117個快取檔及scenes/.DS_Store已忽略；兩個kit .obj.import未忽略，屬匯入設定／UID，建議隨來源mesh提交，不提交其指向的.godot生成快取。icon.svg.import已追蹤且無變更；未發現其他暫存／日誌／pyc檔。
- 本輪git diff --check退出碼0。未啟動Godot或重跑測試；第(1)批單獨基線尚未建立／驗證，不宣稱全綠。先前完整工作區FormLab無頭門禁曾通過，不能代替拆分後基線驗證；未驗證視窗操作。
- 只提出訊息草稿與範圍，等待確認才執行(1)/(2)，不推送、不刪牆、不搭關卡。

## C9：核准兩批本機提交

- 使用者核准S8推薦分組，執行(1)WIP重構／刪除基線與(2)件庫／移動元件／風格依賴／驗證工具／AGENTS.md整檔。不推送；舊3m牆保留，第(3)批未獲刪除確認、不執行。
- 提交前完整工作區執行python3 tools/check_kit_box_aabbs.py一次，退出碼0；6個Box資產／7個Box／4個固定組合通過，斜坡只比對高邊座標、不代表碰撞檢查。
- 執行python3 tools/test_kit_box_aabbs.py一次，退出碼0、8個負向案例通過、原資產不變，沒有重試。
- 沙盒外執行tools/run_tests.sh一次，退出碼0、ALL GREEN (1 checks)，預設只跑FormLab，固定60 FPS／180幀，無錯誤或警告；日誌${TMPDIR}/borrowed_shapes_tests/form_lab.log。quit-after主動結束，不宣稱手動正常關閉。編輯器與視窗操作本輪未執行。
- 以上為完整提交候選結果，不代表第(1)批單獨狀態通過；第一批訊息明訂WIP與拆分後基線未獨立執行門禁，第二批記錄完整候選門禁通過。
- 第一批暫存路徑精確核對239檔通過；git diff --cached --check退出碼2：原未追蹤docs/decoupling-log.md第696、697、716、717、733、734、754、755行歷史測試輸出有尾端空白。先前未暫存git diff --check未涵蓋該未追蹤檔；保留歷史原文，第一批訊息如實標註，不視為Godot門禁失敗。

## D10：批次02結案與決定不做

- 直線／轉角基座：決定不做。Y=0地面遮擋Y[-0.5,0]基座；凸出基座會侵占0.5m窄縫與1.0m通道淨寬，不為基座改動既有放置。
- 邊緣收口：決定不做幾何。使用者判定5mm／10mm內凹在遊戲畫面不可見；日後若需要改用材質細節，不新增幾何。本輪不實作風格或材質。
- 牆端／柱子：歸「決定不做」類別，但狀態為合併延期，並非永久取消。白盒幾何相同，不重複製作；待正式Mesh需要端部造型才重新提案。
- 倒角／樓梯：本輪不做、延期；M4實際缺件時才記錄用途與證據。屋簷：本輪不做、延期；沒有必要挑簷需求，且突出幾何可能侵入翻越路徑。
- AGENTS.md盤點六項既有決定均已存在：層高3m／牆2.5m、標準攀爬＝層高＝3m、平台檢查1.5m、轉角用牆角件、固定機制色不屬色板角色、三角色材質提案。補結案原因、狀態表及盤點索引，歷史基座／收口提案標示已被取代，未改數值。
- 僅修改AGENTS.md及本cost-log；本輪開始工作區乾淨。只做文件核對與差異／空白檢查，未啟動Godot，編輯器、FormLab與視窗操作均未執行。未新增資產、未搭關卡、未提交／推送，舊3m牆仍保留。

## S11／S12：風格盤點與計畫

- 第11輪只讀AGENTS.md、cost-log與git log，核對固定kit材質、FormLab shader及色板；工作區外繪A/B角色配色剖面。沒有修改專案、未啟動Godot。
- 第12輪確認預覽通過，提出共用.tres／sub-resource／執行期實例比較，推薦最少兩角色共用材質；列6個保留kit件與當時尚未刪除樣件的角色，指出L形描邊限制及原FormLab無平台背景攀爬標記配置。只計畫、未實作。

## S13：風格Resource化實作

- 開始工作區乾淨。依最新明確通知先刪除`art/kit/wall_straight_w4_h6_d1.tscn`，移除AGENTS.md相關提及，未同步該材質。上方歷史提交／刪除延期紀錄保留，不改寫歷史。
- 沿用kit_material.tres作building，新增唯一kit_platform_material.tres及共用kit_role_material.gd／Godot UID；都引用未修改的architecture.gdshader。kit只有building／platform；FormLab ground保留，沒有新ground材質。
- 材質引用StyleSettings，palette getter來自唯一settings.palette；@tool載入／palette引用切換時刷新。StyleFoundation每角色一份場景材質實例，同角色共用、色板不深複製、不保存來源。instance uniform保存各Mesh的color_role／shape_size／ramp_shape，坡重建同步尺寸，無幾何／碰撞改動。
- 填充塊預設building；補平台時作者明確改共用平台材質及color_role=1，不自動猜用途。L形凹角描邊不完整記為已知限制，M4截圖需檢查。

## V13：驗收工具與結果

- 修改既有style_capture.gd，A→B→原色板只寫記憶體settings.palette，不直接apply_palette、不切後製／toon／描邊。核對三色板角色值及兩kit角色palette引用、shader一致、材質身分、機制青／黃／描邊色值完全不變。
- 使用者明確授權記憶體剖面例外：同一FormLab工具以SubViewport實例化下層板＋2.5m牆＋上層板，配置既有青色標記跨至樓板側面；不存scene、不接玩法，不搭遊戲關卡。核對6個kit資源及坡尺寸(1.5,2.5,5.5)／(2,3,6)同步，恢復後凸包點相同。
- 新增tools/check_kit_style.py一次執行通過：追蹤15個kit scene及引用.tres／腳本／shader依賴，角色色常數僅允許palette，固定機制預設明確排除。新增tools/style_color_reference.py一次執行，輸出青黃對A/B五角色的亮度對比與HSV環形色相差，僅供參考無門檻；B平台對青色1.533、24.88°，不是受光照後像素對比。
- AABB解析器只補3個Mesh視覺uniform的嚴格字面格式。python3 tools/check_kit_box_aabbs.py執行一次、退出碼0：5個Box資產／6個Box／3組Box＋1組坡高邊座標；凸包碰撞仍非檢查範圍。python3 tools/test_kit_box_aabbs.py一次、退出碼0，8案全部通過，原資產不變。另與本輪開始快照比對，6件節點／位置／Shape／碰撞圖層相同。沒有非預期失敗或重試。
- Godot 4.7.stable.official.5b4e0cb0f均在沙盒外。編輯器首次載入及6件逐一載入均退出0、無錯誤／警告；quit-after 180主動結束，不宣稱手動正常關閉。首次日誌/tmp/borrowed_shapes_style_editor_initial.log；逐件/tmp/borrowed_shapes_style_editor_<scene名>.log。首次匯入後逐件前後203個來源檔SHA256及git status完全相同，證據/tmp/borrowed_shapes_editor_guard.json；含本輪實作差異，並非整個工作區字面乾淨，確認@tool未新增來源改動。
- tools/run_tests.sh一次通過，只跑FormLab，固定60FPS／180幀，退出0、無錯誤／警告；${TMPDIR}/borrowed_shapes_tests/form_lab.log。FormLab帶--style-capture=/tmp/borrowed_shapes_style_capture，以無頭及視窗各一次完成A/B/A核對，退出0；日誌/tmp/borrowed_shapes_style_check.log、/tmp/borrowed_shapes_style_window.log。工具完成後主動quit(0)，不宣稱使用者手動關閉。
- 已檢視視窗renderer的A/B剖面與FormLab B截圖：HUD／相機可見；B色板樓板側面的青色標記在指定固定視角可辨識，未改色，不外推所有鏡頭。截圖位於/tmp/borrowed_shapes_style_capture/{form_lab_a,form_lab_b,section_a,section_b}.png。未執行移動／變形／攀爬／跨越操作驗收。
- 預覽時系統Python沒有matplotlib，改用既有繪圖依賴，未安裝套件；首次讀取兩個不存在的猜測檔名後改讀實際architecture檔，無專案改動。這些屬盤點工具查找，不是Godot／資產驗證失敗。Python匯入檢查器產生的本輪__pycache__已移除。

## D13：決定不做

- 暗色帶與額外shader功能升級決定不做；重評條件為「M4實際畫面顯示樓層線不足」。本輪僅改接現有architecture shader，未修改shader程式。
- 不新增kit幾何件、不搭關卡、不保存驗收scene，不提交／推送；成本金額與Token未取得，不估算。


## V14：基準圖保存、青色寬度與黃色跨越線證據

- 使用者通過前輪A/B剖面，明確要求複製到docs/；本輪新增docs/style_section_a.png、style_section_b.png作基準圖，另保存前輪FormLab原截圖style_form_lab_a.png、style_form_lab_b.png作黃線A/B證據。四張均與/tmp/borrowed_shapes_style_capture來源逐位元／SHA256相同，無裁切、重繪或改色。
- 青色40%寬來自前輪新增驗收工具明設width=0.8／牆寬2m，目的是露出角色背景色與機制色供並看；與材質／shader縮放無關。只影響禁用候選的記憶體剖面，非攀爬製作規格。AGENTS.md正式剖面width=2／height=3、原FormLab width=3／height=3均未改；本輪補明此差異，沒有改驗收程式或重截圖。
- 已檢視既有FormLab A/B全畫面。左上屋頂黃線位於Building（building，A #C9BEA8／B #A8B9C9）；右側黃線位於LandingPlatform（platform，A #829384／B #788D99）。對照movement_lab_data.tres、StyleSettings.block_roles及VisualMarker建置確認，兩起跳線Y=3.04、支撐頂Y=3，X分別-0.65／3.65，Z[-3.6,-0.6]；不是ground或空隙背景。固定機制黃#FFC73D不變，A/B兩線都可辨識；右平台部分超出畫面，不外推其他視角。
- 本輪只改AGENTS.md、cost-log並新增上述4張證據PNG；原有實作變更保留。SHA256複製核對及git diff --check通過，沒有新Godot執行或門禁重跑；前輪執行紀錄不改寫成本輪結果。沒有改色、kit／玩法、場景或工具，不提交／推送。


## C15：風格Resource化結案提交與推送

- 使用者確認A/B剖面與補充證據通過，明確授權整理、提交及推送本輪風格Resource化。目標為現有borrowed-shapes分支與origin（GitHub CoraStarX/ZooBreakout），不改main。
- 提交範圍：兩個kit角色材質／共用Resource腳本與UID、StyleSettings單入口及StyleFoundation接線、6件視覺instance uniform與坡同步、指定刪除資產、既有A/B驗收工具與AABB視覺語法擴充、硬編碼依賴掃描／色差參考工具、AGENTS.md／cost-log、4張核准PNG及其Godot .import設定。共28個檔案；.import屬匯入設定／UID，不包含其指向的.godot快取。
- 建議並採用單筆訊息：feat: 將 kit 角色材質接入共用風格 Resource。
- 提交前git diff --check通過；前輪Godot、AABB、8案負向、A/B色值與機制色、來源不改寫證據均已通過且使用者結案，本輪未改實作程式，不重跑門禁。暫存後另核對精確路徑及git diff --cached --check。
- 本節是提交候選的授權／範圍紀錄；實際提交SHA、推送結果與最後工作區狀態以Git及聊天回報為準，不預寫成功。上方歷史「未提交／推送」保留各輪事實。
