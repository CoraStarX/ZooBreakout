# 員工可讀性沙盒 B

狀態（2026-10-16）：依白盒結項裁決，獨立員工可讀性作已驗收凍結基線；自動回歸97項。下方逐輪「待手玩」為歷史記錄；陌生玩家可歸因性尚無獨立完成紀錄，後續仍需保留驗證。移動 A 已通過手玩並凍結。

## 開啟與操作

在原 Zoo Breakout 專案開啟 scenes/traversal/staff_readability_lab.tscn，執行目前場景（macOS 可用 Fn+F6 或右上「執行目前場景」）。F5 的正式舊關卡與原 movement_lab 入口保留。

WASD、Space、E 語意沿用移動 A。F3 開啟統計，「複製統計」預設輸出員工事件摘要＋移動計數短摘要；「複製完整診斷」才附事件 JSON、0.1秒警覺時間線與移動輸入記錄，「重置統計」同時清除兩者。重置不傳送玩家或重設員工行為。

本沙盒只有一名員工、一條固定地面巡邏路線；每圈歇崗。沒有 Clock 日程、全域 Alert、拘留、傳送、變形或第二名員工。

## 規則

- 感知完全用 XZ 平面，不做垂直視角或向上射線。範圍、方向、牆面裁切、近側屋頂邊帶由同一份星形多邊形產生；顯示網格與命中判定都讀它。外弧為有限分段，不是另用理想圓弧判定。
- 一格=1m，首先遇到的建築近側屋頂向內0.5格可見；不穿透建築看遠側。屋頂深處安全，外側貼牆可見。
- 攀爬投影至攀爬面外側落點，視覺可見後乘1.5；空中跨越在建築外按一般地面可見度。來源按攀爬面固定，剛附著與高處不換來源。
- 地面貼牆仍是地面目標。事件位置以短射線確認實際支撐面，再用 ground_probe_height 容許接地殘高；不靠單一絕對高度分界。攀爬／空中視覺快照仍不可當地面追到。
- 員工碰撞半徑只影響尋路，不將玩家誤判為高處。原始記憶位置不變；精確位置不可達時，改選既有點網中距目標最近、且路徑可達的接近點。找不到合法候選仍明確記錄 unreachable，不能偽造已到達。
- 搜索期間重新看見地面玩家立即轉調查，停止掃視舊點；重新起算≥0.5s預警。持續看見時維持調查／累積，不在調查與搜索間逐幀切換。高處來源搜索／冷卻規則不變。
- awareness 沿用 StaffAwarenessMath 的距離／速度倍率、累積／衰減。頭上 ?→!→!!；進追捕前至少0.5秒可見預警。原始 min_telegraph_sec=0.55。
- 只在看見或實際聽見後更新記憶；決策只讀記憶位置與可達牆下點。聲音來源解析只使用 noise_made 的事件位置，不查詢玩家的當前位置。
- 高處目標：走到合法牆下點後才開始8秒搜索；丟失視線時接近牆下的路程不吃掉8秒。搜索中只有同一高處來源的聲音最多延長一次8秒，總時間最多16秒。地面聲音或不同高處來源可引起新的調查，不延長舊搜索。
- 放棄後，同來源5秒冷卻。期間不反覆起疑、重追／重開搜索；同一建築／攀爬面用穩定識別，無區域識別時才用位置容差。冷卻結束允許重新感知；重新出現的地面目標仍可追逐。
- 每圈歇崗6秒，關閉視覺，聽距×0.6且不可為零，頭上 Zz／休息。調查或追逐時延後休息；休息被噪音打斷不補睡，下一圈再安排。
- 追捕到達僅記錄與回饋：短音＋畫面邊框，冷卻3秒，員工停步0.75秒。玩家控制不鎖定、沒有拘留或傳送。
- 玩家與員工共同參與鏡頭遮擋淡出，碰撞與感知不隨材質透明而改變。員工標「地面員工」避免淡出造成樓層誤讀。新沙盒世界標籤只留短名，操作詳情沿用底部 HUD。
- 既有 jump／climb／landing 接口與落地最低高度門檻留在凍結 TraversalParams。沙盒員工的 climb 接收冷卻1.5s；聽覺增量=基礎28×音量（上限1）×距離衰減（近端1，聽距邊緣0.2），聽距外不累積。冷卻只在實際聽見時起算，不改原移動發聲端。
- 安全玩家出生點由 StaffReadabilityLayout.player_spawn 配置，不在初始員工視錐內；移動 A 原場景出生點不改。

## 分層與資料流

    凍結 TraversalActor → Content 感知接線 → 投影／來源／牆下點
    灰盒資料 → 平面障礙 → StaffPerceptionFootprint → 同一份網格／可見判定
    noise_made → 聽距判定 → 事件位置記憶
    感知結果 → StaffAwarenessMath → ReadabilityStaff 局部狀態
                                    ├─ StaffMotor＋地面路點圖
                                    ├─ 到達回饋 → UIKit／佔位短音
                                    └─ StaffReadabilityMetrics → F3／複製

局部狀態為 WORK／SUSPICIOUS／INVESTIGATE／CHASE／SEARCH／RETURN／REST。高處接近沿用 INVESTIGATE，沒有全域狀態機。正式 StaffActor、StaffSense、Clock、Alert、CaptureFlow 不改。

## 檔案清單

新增：

- gameplay/staff/staff_readability_params.gd：沙盒可調 Resource。
- gameplay/staff/staff_perception_footprint.gd：純投影、輪廓、聽覺、來源比較、搜索延長與地面點網。
- gameplay/staff/readability_staff.gd：局部感知／決策／移動接線。
- gameplay/staff/staff_readability_metrics.gd：時間線、計數、全部追捕來源。
- content/staff/staff_readability_params.tres、readability_staff_ai_params.tres：獨立資源，不引用正式員工調參檔。
- content/traversal/staff_readability_layout.gd/.tres：巡邏／牆下點資料。
- content/traversal/staff_readability_lab.gd、scenes/traversal/staff_readability_lab.tscn：重用原灰盒的場景與呈現。
- prototypes/p2_staff_readability.gd/.tscn：回歸套件。

修改：content/ui/debug_hud.gd（可選員工統計）、tools/run_tests.sh（登記套件）及本輪設計／架構／QA文件。引擎產生對應 .uid。

## 主要調參

| Resource／欄位 | 預設 | 試玩重點 |
|---|---:|---|
| grid_unit_m／roof_edge_cells | 1m／0.5格 | 邊帶是否好理解；改格尺寸會同時改邊帶 |
| climb_visibility_mult | 1.5 | 貼牆風險是否可歸因 |
| ground_probe_height／ground_height_tolerance | 0.25m／0.15m | 前者為事件位置上下支撐射線與殘高容差；後者確認支撐面屬地面層。不要用前者擴大視錐 |
| search_sec／search_max_mult／search_cooldown_sec | 8s／2／5s | 搜索壓力與等待感；總上限=基礎×倍率 |
| rest_sec／rest_hearing_mult／rest_hearing_floor | 6s／0.6／0.1 | 歇崗是否可讀，近距聲音仍能打斷 |
| arrival_cooldown_sec／arrival_pause_sec | 3s／0.75s | 到達是否連續刷次數、回饋是否清楚 |
| warning_stage_sec／investigate_stage_min_sec／chase_stage_min_sec | 0.15s／0s／0s | ?最短停留、!調查最短停留、!!追捕前搖下限。保留原有行為，見下方觀察項 |
| climb_noise_cooldown_sec／hearing_far_gain_mult | 1.5s／0.2 | 攀爬接收冷卻／聽距邊緣警覺增量倍率；與音量相乘 |
| fan_segments | 64 | 有限輪廓精度；顯示與判定一起改 |
| occlusion_alpha／feedback_sec | 0.22／0.65s | 淡出與追捕回饋是否看得懂 |
| metrics_interval_sec／metrics_limit／event_limit | 0.1s／1800／200 | 詳細時間線約3分鐘；一般事件環容量 |
| 獨立 readability_staff_ai_params | 視距7m／視角55°／累積42每秒／衰減20每秒／預警0.55s | 勿改正式 default_staff_ai_params |
| StaffReadabilityLayout.player_spawn | (-8.8,0.04,5) | 只改沙盒玩家出生，保持初始視錐外 |
| StaffReadabilityLayout | 1圈5點＋兩棟建築牆下點 | 點位留在地面並通過半徑擴張的可達性檢查 |

F3與預設複製提供追捕（首次看見時間／經過秒數）、搜索起訖／延長／中斷、每次歇崗是否被聽見的摘要；時間線只由「複製完整診斷」明確取得。**每次追捕來源另外保留至重置**，不被高頻聲音擠出一般事件環。重置或離開場景後不保留；這不是存檔系統。

## 測試與手玩

自動化覆蓋：共享三角網格與判定195個位置、三種投影、攀爬倍率、預警時長、每圈歇崗／打斷、聽覺底線、同源冷卻、一次延長／16秒上限、牆下起算、地面貼牆分類、到達冷卻、來源追溯與F3複製／重置。

物理測試跑兩圈巡邏；真實 InputMap 流程用原始累積42每秒，由視覺自然觸發追逐，再附牆上屋頂、牆下搜索與放棄。不臨時賦予能力；故障注入的快累積參數獨立複製，不污染原始 Resource。

手玩不用刷圈：

1. 從地面觀察 ?／!／!!，確認能說出自己為何被注意。
2. 比較屋頂邊帶與深處、貼牆及跨間隙的風險；被追逐後上屋頂觀察放棄。
3. 等一圈休息，靠近製造既有移動聲音，確認「閉眼但聽得到」。
4. 查看F3來源；請陌生玩家描述被發現原因，再核對紀錄。

## 已知限制／建議事項

- 這是靜態灰盒的平面矩形遮擋模型，斜坡整個 footprint 對員工作不可通行／遮擋處理；不支援任意旋轉建築、動態遮擋或垂直視野。擴大關卡時另行評估。
- 半透明可見不等於員工感知可見，需由使用者與陌生玩家確認投影／邊帶是否直覺；自動測試不能代替可歸因性驗收。
- 本輪不調整凍結移動；若發現問題只記錄。
- 既有 p2_full_loop Soft天數預算 pending=1 為舊關卡待決，與本沙盒無關。
- 不實作變形、窄縫、史萊姆、第二員工、日程、NavMesh或美術資源。手玩後再決定下一階段。

## 手玩後最小修正（2026-10-15）

手玩 62.95s 落地事件 y=0.158888m，舊 0.15m 絕對分界誤標高處，且延長條件只檢查聲音可達性，讓地面搜索意外延長。已改用事件位置下的實際支撐面，延長必須同時是「高處搜索＋同來源高處聲音」。沒有查詢聲音來源目前座標，也沒有改噪音發送端。

手玩斜坡末端 (4.556193,0,6.572217) 與貼牆位置通過地面分類，但在員工半徑擴張後無路徑。已保留感知記憶，另選合法既有點網接近點；剛附牆的低高度也先走高處分類取得牆下點。零距離路徑亦需通過障礙檢查。F3 聽覺事件附 reachable／key／support_y，approach_selected 附原目標與合法接近點。

回歸先於修正重現四項失敗；新增原始手玩座標、七秒持續搜索不反覆 unreachable、低附牆、不同來源／地面聲音不延長、無候選拒絕與純支撐判定。追捕開始計數仍是進入 CHASE 的次數，包含到達後恢復追逐，不等於獨立發現次數。

手玩尚需確認：留在屋頂直到放棄與冷卻、歇崗聲音調查、陌生玩家能否說出被發現原因。移動 A 不要求補圈，凍結不變。

上一輪驗證：tools/run_tests.sh ALL GREEN（30 suites），員工headless／原生各71項；移動149項不變。原生七秒手玩座標重播無不可達事件且記憶保持，兩種解析度已檢查。證據見 qa_reports/staff_readability_fix_validation.txt。既有full_loop pending=1未改。

## 陌生玩家試玩前修訂（本輪）

1. 玩家出生改用沙盒獨立資料，第一秒無視覺接觸；真實 InputMap 測試從安全點自然走入視野，不再把角色先放進視錐。
2. 持續攀爬發聲不是刻意難度設計：凍結移動端每0.9m發一次0.08音量的事件，但舊員工不論音量／距離一律+28，造成接線失真。採1.5s接收冷卻並對增量做音量／距離衰減，保留貼牆視覺×1.5；六秒微音回歸不會把awareness釘在100。
3. 三階段不是固定0.5／0.6／0.7秒倒數，仍由警覺閾值、距離、視覺與狀態控制。既有?最短0.15s與總預警0.55s保持；新增!／!!最短時間接口預設0，表示不額外延長原節奏。使用者觀察值只列入試玩，不直接套成新數值。
4. 真實玩家自動附牆→攀爬發聲，在歇崗視覺關閉期間喚起調查，F3記錄歇崗起訖與聽見次數。這是自動回歸，不代表陌生玩家可讀性通過。
5. 搜索重新看見地面玩家的轉調查已獲使用者另行核准；不調高視野或累積速度、不取消高處同源冷卻。
6. 預設複製不再附數千行逐幀資訊。追捕／搜索／歇崗摘要事件保留至重置，詳細診斷仍為環形記錄；重置發生在歇崗中時會標示該次聽見。

變動檔案：StaffReadabilityLayout（出生）、StaffReadabilityLab（接線）、StaffReadabilityParams／StaffPerceptionFootprint／ReadabilityStaff（節流、衰減、階段下限、重新接觸）、StaffReadabilityMetrics／debug_hud（摘要與明確完整匯出）、p2_staff_readability（回歸）。另修p2_alert_tiers的測試同步：等待實際施工進度後才測Alert5中止，不改施工規則或斷言。

已知限制／試玩觀察：既有地面點網與靜態遮擋限制不變；?／!／!!時長與重新接觸轉向是否自然仍需手玩。舊p2_exposure的隨機巡邏曾量到44%／46%，差距略低於2百分點斷言；未放寬暴露門檻或改舊關卡，後續宜固定測試隨機來源以提升可重現性。

統計口徑：首次看見是實際視覺接觸段的第一筆樣本，不是警覺達標或冷卻結束時間；離開視野超過lose_target_grace_sec後的新接觸才重新起算。到達後恢復追逐仍另算一次CHASE開始，可能共用同一視覺接觸起點；重新預警依然獨立給足至少0.5秒。已補停步期間持續看見的回歸。
