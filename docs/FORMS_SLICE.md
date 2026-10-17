# 變形與空間門檻切片（2026-10-16）

目前狀態：2026-10-16使用者確認A驗收通過，結束本輪白盒驗證；不自動繼續B/C。原計畫A→B→C保留供後續排期。本輪只做A：FormDef、正式可配置初始化、本體／猴切換、冷卻與完整體型預檢、任意狀態回本體。B窄縫／可達性與C員工接線／F3統計未放行。測試稱「原型路徑」，不是未來形態獲得的完整路徑。

## A開始前：C前搖接口設計（本輪不實作）

- 原A提案為gameplay/forms/form_readability_staff.gd子類；已由下方2026-10-16使用者決策取代。C改為既有ReadabilityStaff封裝Actor場景後實例化，重用原視錐／遮擋／追捕邏輯，不建立簡化員工替身。形態接線只增加事件入口，前搖仍走既有_pause_until門禁。
- 入口：on_transform_seen(snapshot)。只接Content用當刻同份視錐／遮擋幾何確認的感知快照，不自行取得玩家座標。
- 入口立即設定CHASE／!!、awareness追捕階、最後已知位置與追捕起因「變形時被看見」，設定既有_pause_until為至少now+FormParams.witness_windup_sec（預設0.5s，載入拒絕低於公平底線）。
- ReadabilityStaff.step()現有 now>=_pause_until 門禁阻止Motor與_chase()，因此前搖內不追擊、不判定追捕到達；仍更新正常感知。期滿依原追捕／高處搜索規則，丟失視線只能用感知記憶。
- 已在CHASE時再次目擊，不刷新前搖造成可刷停步；看到／聽到同事件以看到優先。沒有形態事件時不啟動此入口，既有97項員工回歸必須通過；C另以同套情境驗證新子類的無事件相容性。
- 本體visibility_mult需要預設1的可選倍率入口，C再接，A不修改ReadabilityStaff或感知幾何。
- 追捕起因在一次追捕中保持，不被普通感知覆寫；到達提示帶起因。C統計：主動變形、強制退回分列；視線內主動變形／目擊導致追捕／冷卻與空間拒絕／被抓原因分佈／卡住時間，預設摘要，詳細時間線明確匯出。

## 已核准規則

- 正式可配置starting_form／initial_unlocked_forms：暫本體開局、猴初始解鎖。猴本輪只CLIMB，沒有THROW／TINY_GAP／SQUEEZE；本體有TINY_GAP與SQUEEZE。
- Q切換，成功變成非本體後2.5s冷卻；主動／強制回本體不受限且不清空不重置冷卻。特效0.3s不鎖操作。
- 變成猴須接地（含平台／屋頂）並容納完整碰撞體；掛牆、空中與路徑過渡均明確拒絕。主動與強制回本體任何狀態允許；掛牆／空中退回自然下落，落地噪音沿用原規則。
- 本體速度4、腳步0、可見度0.6、不跳躍；猴數值與移動算法凍結。DURATION_INFINITE=0，負持續時間載入拒絕，本輪不倒數。
- 變形聲音量1；transform近距接收上限3與hear_noise_range13同為XZ世界距離，1單位約1公尺。3公尺上限C接收端實作，A只發事件；強制退回不再發聲／目擊追捕。
- A無員工；避免可見度與變形接線尚未完成時以舊員工產生錯誤體感。F5執行FormLab；MovementLab與StaffReadabilityLab保留為獨立回歸入口，使用執行目前場景開啟。B追加窄縫，不重做已驗收地形；C才接員工。
- 身份倍率（原生區域／禁入區）、投擲、形態獲得／請求名牌、持續時間消耗均在backlog，不實作。

## 狀態

- A：使用者驗收通過，本輪白盒驗證結束，凍結為已驗收基線；31套件全綠、headless／Metal各106項的驗證紀錄保留。
- B：延後，尚未實作／驗收；結束白盒不等於窄縫與可達性已通過。
- C：延後，尚未實作／驗收；變形與員工的整合、相關F3統計仍待後續排期。

## 檔案與調參（A）

- GamePlay：form_def.gd／form_setup.gd／form_params.gd 資料；form_rules.gd 純判定；form_controller.gd 場景控制；ground_form_actor.gd 限制本體跳躍。
- Content：content/forms/{slime,monkey,prototype_setup,form_params}.tres；form_lab.gd 呈現；scenes/forms/form_lab.tscn 入口。
- 共享能力僅追加 CapabilityIds.TINY_GAP，不變舊編號。prototypes/p2_forms.{gd,tscn} 加入 tools/run_tests.sh。
- FormDef：body_size 是膠囊寬／高／深，寬深相同、高不小於寬；本體0.3×0.3×0.3，猴0.64×1×0.64。move_speed本體4、猴5.5。猴半徑保留原Resource精度，避免Vector3量化影響凍結移動。
- FormSetup：starting_form／initial_unlocked_forms 控制正式原型初始化；移除猴解鎖應得到明確拒絕，不臨時賦予能力。
- FormParams：form_cooldown_sec 2.5、effect_sec 0.3、transform_noise 1；恢復歷史32點、間隔0.4。transform_hearing_radius 3與witness_windup_sec 0.5預留C，A不假稱已接。
- 本輪請以重開場景套用資料為準，未提供運行中重新套用碰撞尺寸。
- visibility_mult／footstep_noise／native_zones／forbidden_terrain／duration_sec 為資料載體；可見度C才接，身份／地形／倒數本輪不實作。兩形態腳步皆0，猴沿用沙盒現況。

## 已知限制與手玩方式

開啟 form_lab.tscn 執行目前場景。確認Q變猴、立即Q回本體再Q得到冷卻提示；冷卻到期恢復。猴爬牆中Q可回本體下落，空中不能變猴；屋頂與對岸平台頂面可變猴。所有失敗均不耗冷卻、不發變形聲。低頂空間拒絕目前由真實碰撞故障注入測試覆蓋，可遊玩窄縫B再補。

A新場景無員工，尚不驗證目擊變形、強制被抓或形態F3計數；這些明確在C。F3仍為既有移動統計，變形會打斷原移動迴圈，不將混合形態圈用作凍結移動驗收。

## A回報澄清與B前置（2026-10-16）

- 交付仍只有A；B新增本體窄縫／示意物件／可達性檢查，C加入員工與變形感知／F3統計，不提前混入。
- 原灰盒已包含Building（頂面y=3）、LandingPlatform（頂面y=3），兩者實體邊緣x=0／3，間隙3世界單位，保留兩個雙向TraversalLink。不因A截圖視角未完整拍到就刪除間隙。此為地面／屋頂兩個高度層，不是可進入的兩層室內建築；B原計畫不新增室內樓層、不重建凍結動線。
- 接地陰影既有MovementLab.shadow，每幀向下射線投影到實際地面／平台，FormLab隨形態調整半徑；不是只有方向光投影。B沿用並回歸，無須重做。
- F3新增FormGuidance勾選；關閉後隱藏頂部任務、被動形態能力／路線文字（包括世界ProximityLabel），保留中性按鍵說明。明確操作拒絕仍顯示，避免違反拒絕可讀原則。偏好走UserPrefs，section=form_lab,key=show_guidance；預設由FormParams.show_guidance_default提供。不影響判定、角色、落點預覽或陰影。
- 歷史提案（已由下方「C來源已確認」取代；ZooP0Geometry、StaffActor及舊Autoload現已移除）：C來源待確認：專案沒有獨立員工Actor .tscn；正式世界ZooP0Geometry以StaffActor.new建立，已驗收沙盒StaffReadabilityLab以ReadabilityStaff.new建立。建議把後者封裝成PackedScene後實例化、重用同份StaffPerceptionFootprint／感知／追捕與搜索，不能把換成場景誤稱替身。若要求正式StaffActor則先提Clock／Alert／抓捕耦合隔離方案，不自行替換。原「新子類」計畫依使用者這次要求重新確認後才落地。

### C來源已確認

使用者選擇「採已驗收ReadabilityStaff場景封裝」。C將封裝並實例化該Actor，沿用原StaffPerceptionFootprint、同份視錐顯示與遮擋判定、追捕／牆下搜索／歇崗邏輯，C的現行來源方案為ReadabilityStaff；此封裝與接線仍未實作或驗收。無形態事件時須通過既有97項回歸；是否目擊、延遲與追捕到達新增測試另列。前述來源問卷已結案。

## 歷史：A屋頂邊緣拒絕版回歸（已由下方自動推開取代）

根因：本體半徑0.15可站到邊緣約0.20範圍，目標猴半徑0.32＋安全邊距0.05需要更大的支撐足跡。舊FormController只做膠囊碰撞與中心射線接地，允許在猴足跡超出平台處變身；凍結TraversalActor._step_ground在每次步行後恢復before，連往內走也可能每步退回。Space沿獨立已驗證跳躍路徑，因此仍可脫困。

修法：僅非本體變形新增目標walkable_support預檢；FormRules.footprint_offsets純函式沿用目標體型與既有edge_probe_count／edge_safety_margin，射線沿用原edge_probe_up／edge_max_drop／edge_ground_clearance／support_normal_min語意，不加新調參來源。支撐不足明確提示往平台內側移動；保留原角色／位置，不扣冷卻、不發變形聲、不偷偷平移或傳送。回本體與強制退回限制不變。未修改TraversalActor或凍結參數。

回歸先重現4項失敗，再以正式原型路徑爬上屋頂、回本體、自然等冷卻、持續往邊緣移動加Q：拒絕後可往內走0.6，再持續方向加Q並正常步行。六個屋頂中心／邊緣／角落／對岸平台採樣與實際猴_walk_footprint對照，避免預檢與移動判定分歧。實機記錄point=(-3.100604,3.002006,-4.283333)，base_support=true、target_support=false。

手玩：本體走到屋頂後緣，持續方向按Q應顯示「請往平台內側移動後再變形」且仍是本體；轉向屋頂內側退半步，再Q，猴可正常走動。不需重跑移動圈數。此為A形態接線修正，B/C仍未實作。

## 現行：A有界推開後變形（2026-10-16使用者覆寫）

此節取代「兩種空間拒絕提示」「先不自動推開」及上一版邊緣拒絕方案。只適用成功變成非本體前的擺放；回本體／強制退回／冷卻規則不改。

1. 原位置能容納完整目標膠囊且同份walkable_support有效，原位變形。
2. 否則在FormParams.push_max_distance（0.32公尺）內做32方向／16半徑取樣，各方向第一個有效範圍細化6次，取最短有效位移。方向間距11.25度、半徑步長0.02公尺、細化解析度最多約0.0003125公尺；這是有界離散候選的最近結果，不宣稱連續空間解析最短。
3. 候選沿用同一space_clear與完整目標支撐；路徑用本體膠囊連續cast_motion，起終點檢查交疊，沿途每0.04公尺檢查支撐與同高度層。候選不改Y；支撐高度容差0.02公尺僅容忍誤差，不跨樓層，不用歷史恢復點尋找推開位置。
4. 查完才原子替換角色與位置；失敗保留原角色／位置、無冷卻與聲音副作用，空間統一提示「這裡太窄」。成功光效0.3秒半徑0.65、訊號與Bus聲音均使用最終位置，C未來目擊入口也必須使用該最終位置。
5. B窄縫仍是物理空間門檻，不得推穿牆。現階段以0.45公尺真實碰撞窄縫測試夾具驗證，沒有提前實作B場景。

### 尺寸與間距實測

- 猴：膠囊半徑0.32，寬深0.64，高1.0；本體膠囊半徑0.15，高0.3。
- 變形碰撞預檢額外margin=0，沒有新增膨脹邊距；引擎body_safe_margin=0.005。
- 完整支撐邊緣預留edge_safety_margin=0.05，平台邊緣需要0.37支撐半徑；它不等於離直牆額外加0.05。
- 直牆地面實測：不用推開可容納且有支撐的中心最小離牆距離0.320000095公尺（約0.32）；測例本體中心原離牆0.17，推開0.150049210公尺。實際移動會有引擎0.005接觸安全邊距，故常見站位約0.325。
- 攀爬wall_clearance=0.08只用於附牆，不加到變形預檢；掛牆中心距離半徑＋clearance為0.40。未放寬凍結猴移動與參數。

### 本輪回歸

正式原型路徑保留開局／爬牆／屋頂，改驗邊緣向內推開變猴與繼續步行。新增靠牆原子切換／最終聲音與光效、最短方向、0.45公尺窄縫拒絕、0.02公尺薄牆掃掠（即使測試上限放大至0.8也不穿牆）、不同高度層／屋頂外無支撐拒絕、普通地面變猴後直接朝攀爬面走即可附著。單元故障注入與正式原型路徑分開，不臨時賦予能力。
